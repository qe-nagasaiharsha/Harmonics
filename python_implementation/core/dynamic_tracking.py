"""Dynamic Last Point tracking for live trading.

After a pattern is detected, the slope from the previous-to-last point
through the last point is extended forward.  When price breaks through
this extension AND the break point satisfies all three constraints
(range, channel, slope validation), it becomes a new "dynamic last
point" and a fresh Golden Line is computed from it.

This process repeats up to ``max_dynamic_iterations`` times.
"""

from __future__ import annotations

import copy
from typing import Callable, List, Optional

from .types import (
    DynamicPoint, GoldenLineResult, PatternType, Wave,
)
from .config import DetectorConfig
from .diagnostics import DiagnosticLog
from .channels import (
    channel_widths_for_a,
    channel_widths_for_xb,
    compute_channel_center_a,
    compute_channel_center_xb,
    get_a_channel_slope,
    is_in_channel,
)
from . import validators as V
from .golden_line import compute_golden_line

PriceFn = Callable[[int], float]


def track_dynamic_points(
    wave: Wave,
    ptype: PatternType,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    close_fn: PriceFn,
) -> List[DynamicPoint]:
    """Find dynamic last points by tracking slope extension breaks.

    Returns a list of ``DynamicPoint`` objects, each with its own
    computed golden line.
    """
    if not cfg.enable_dynamic_last_point:
        return []

    bars_x_b = wave.x_idx - wave.b_idx
    if bars_x_b <= 0:
        return []

    xb_slope = (wave.b_price - wave.x_price) / bars_x_b
    a_slope = get_a_channel_slope(xb_slope, cfg.channel_type)

    # Determine search parameters based on pattern type
    _PTYPE_CONFIG = {
        PatternType.XAB: dict(
            prev_attr=("x_idx", "x_price"),
            last_attr=("b_idx", "b_price"),
            origin_attr="a_idx",
            use_a_channel=False,
        ),
        PatternType.XABC: dict(
            prev_attr=("a_idx", "a_price"),
            last_attr=("c_idx", "c_price"),
            origin_attr="b_idx",
            use_a_channel=True,
        ),
        PatternType.XABCD: dict(
            prev_attr=("b_idx", "b_price"),
            last_attr=("d_idx", "d_price"),
            origin_attr="c_idx",
            use_a_channel=False,
        ),
        PatternType.XABCDE: dict(
            prev_attr=("c_idx", "c_price"),
            last_attr=("e_idx", "e_price"),
            origin_attr="d_idx",
            use_a_channel=True,
        ),
        PatternType.XABCDEF: dict(
            prev_attr=("d_idx", "d_price"),
            last_attr=("f_idx", "f_price"),
            origin_attr="e_idx",
            use_a_channel=False,
        ),
    }

    pc = _PTYPE_CONFIG[ptype]
    prev_idx = getattr(wave, pc["prev_attr"][0])
    prev_price = getattr(wave, pc["prev_attr"][1])
    current_last_idx = getattr(wave, pc["last_attr"][0])
    current_last_price = getattr(wave, pc["last_attr"][1])
    search_origin = getattr(wave, pc["origin_attr"])
    use_a_channel = pc["use_a_channel"]

    min_pct, max_pct = cfg.segment_range(ptype)
    valid_start = search_origin - int(bars_x_b * min_pct * 0.01)
    valid_end = search_origin - int(bars_x_b * max_pct * 0.01)
    if valid_start >= search_origin:
        valid_start = search_origin - 1
    valid_end = max(valid_end, 1)

    # Channel width params
    if use_a_channel:
        ch_upper, ch_lower = channel_widths_for_a(
            wave.x_less_than_a, cfg.a_upper_width_pct, cfg.a_lower_width_pct,
        )
    else:
        ch_upper, ch_lower = channel_widths_for_xb(
            wave.x_less_than_a, cfg.xb_upper_width_pct, cfg.xb_lower_width_pct,
        )

    results: List[DynamicPoint] = []
    working_wave = copy.deepcopy(wave)

    for iteration in range(1, cfg.max_dynamic_iterations + 1):
        bars_prev_last = prev_idx - current_last_idx
        if bars_prev_last <= 0:
            break

        slope = (current_last_price - prev_price) / bars_prev_last

        new_idx = -1
        new_price = 0.0
        search_from = min(current_last_idx - 1, valid_start)

        for i in range(search_from, valid_end - 1, -1):
            if i > valid_start or i < valid_end:
                continue

            bars_from_prev = prev_idx - i
            slope_val = prev_price + bars_from_prev * slope

            # Break detection
            if working_wave.is_bullish:
                candle_price = low_fn(i)
                break_found = candle_price < slope_val
            else:
                candle_price = high_fn(i)
                break_found = candle_price > slope_val

            if not break_found:
                continue

            # Channel validation
            if use_a_channel:
                center = compute_channel_center_a(
                    working_wave.a_price, working_wave.a_idx, a_slope, i,
                )
            else:
                center = compute_channel_center_xb(
                    working_wave.x_price, working_wave.x_idx, xb_slope, i,
                )
            if not is_in_channel(candle_price, center, ch_upper, ch_lower):
                continue

            # Local extremum check
            if working_wave.is_bullish:
                prev_c = low_fn(i + 1)
                next_c = low_fn(i - 1)
                is_ext = candle_price <= prev_c and candle_price <= next_c
            else:
                prev_c = high_fn(i + 1)
                next_c = high_fn(i - 1)
                is_ext = candle_price >= prev_c and candle_price >= next_c

            if not is_ext:
                continue

            # Slope validation
            dyn_diag = DiagnosticLog()
            if not _validate_dynamic_segment(
                ptype, i, candle_price, working_wave,
                xb_slope, a_slope, cfg, high_fn, low_fn, dyn_diag,
            ):
                continue

            new_idx = i
            new_price = candle_price
            break

        if new_idx == -1:
            break

        current_last_idx = new_idx
        current_last_price = new_price

        # Update working wave
        working_wave.set_last_point(ptype, new_idx, new_price)

        # Compute golden line for this dynamic point
        gl = compute_golden_line(working_wave, ptype, cfg, high_fn, low_fn, close_fn)

        results.append(DynamicPoint(
            idx=new_idx,
            price=new_price,
            iteration=iteration,
            golden_line=gl,
        ))

    return results


def _validate_dynamic_segment(
    ptype: PatternType,
    new_idx: int,
    new_price: float,
    wave: Wave,
    xb_slope: float,
    a_slope: float,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> bool:
    """Validate slope rules for a dynamic last point.

    Mirrors ``validate_dynamic_segment`` in MQL5 — applies the same
    per-segment validators and span containment as initial detection.
    """
    if ptype == PatternType.XAB:
        new_slope = (new_price - wave.x_price) / (wave.x_idx - new_idx)
        if not V.validate_xb_segment(
            wave.x_idx, new_idx, wave.x_price, new_slope,
            wave.x_less_than_a, low_fn if wave.x_less_than_a else high_fn, diag,
        ):
            return False
        return V.validate_span_containment(
            wave.x_idx, wave.x_price, new_idx, new_price,
            not wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, diag,
            rule_id="1.13/2.13", span_label="X→B dyn",
        )

    elif ptype == PatternType.XABC:
        bars_ac = wave.a_idx - new_idx
        if bars_ac <= 0:
            return False
        ac_slope = (new_price - wave.a_price) / bars_ac
        # Fix 1 dynamic
        if not V.validate_ab_with_real_ac(
            wave.a_idx, wave.b_idx, wave.a_price, ac_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        if not V.validate_bc_segment(
            wave.b_idx, new_idx, wave.x_price, wave.x_idx,
            wave.a_price, wave.a_idx, xb_slope, ac_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        return V.validate_span_containment(
            wave.a_idx, wave.a_price, new_idx, new_price,
            wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, diag,
            rule_id="1.14/2.14", span_label="A→C dyn",
        )

    elif ptype == PatternType.XABCD:
        bars_ac = wave.a_idx - wave.c_idx
        if bars_ac <= 0:
            return False
        ac_slope = (wave.c_price - wave.a_price) / bars_ac
        bars_bd = wave.b_idx - new_idx
        if bars_bd <= 0:
            return False
        bd_slope = (new_price - wave.b_price) / bars_bd
        # Fix 2 dynamic
        if not V.validate_bc_with_bd(
            wave.b_idx, wave.c_idx, wave.b_price, bd_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        if not V.validate_cd_segment(
            wave.c_idx, new_idx, wave.a_price, wave.a_idx,
            wave.b_price, wave.b_idx, ac_slope, bd_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        return V.validate_span_containment(
            wave.b_idx, wave.b_price, new_idx, new_price,
            not wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, diag,
            rule_id="1.15/2.15", span_label="B→D dyn",
        )

    elif ptype == PatternType.XABCDE:
        bars_bd = wave.b_idx - wave.d_idx
        if bars_bd <= 0:
            return False
        bd_slope = (wave.d_price - wave.b_price) / bars_bd
        bars_ce = wave.c_idx - new_idx
        if bars_ce <= 0:
            return False
        ce_slope = (new_price - wave.c_price) / bars_ce
        # Fix 3 dynamic
        if not V.validate_cd_with_ce(
            wave.c_idx, wave.d_idx, wave.c_price, ce_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        if not V.validate_de_segment(
            wave.d_idx, new_idx, wave.b_price, wave.b_idx,
            wave.c_price, wave.c_idx, bd_slope, ce_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        return V.validate_span_containment(
            wave.c_idx, wave.c_price, new_idx, new_price,
            wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, diag,
            rule_id="1.16/2.16", span_label="C→E dyn",
        )

    elif ptype == PatternType.XABCDEF:
        bars_ce = wave.c_idx - wave.e_idx
        if bars_ce <= 0:
            return False
        ce_slope = (wave.e_price - wave.c_price) / bars_ce
        bars_df = wave.d_idx - new_idx
        if bars_df <= 0:
            return False
        df_slope = (new_price - wave.d_price) / bars_df
        # Fix 4 dynamic
        if not V.validate_de_with_df(
            wave.d_idx, wave.e_idx, wave.d_price, df_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        if not V.validate_ef_segment(
            wave.e_idx, new_idx, wave.c_price, wave.c_idx,
            wave.d_price, wave.d_idx, ce_slope, df_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct, high_fn, low_fn, diag,
        ):
            return False
        return V.validate_span_containment(
            wave.d_idx, wave.d_price, new_idx, new_price,
            not wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, diag,
            rule_id="1.17/2.17", span_label="D→F dyn",
        )

    return False
