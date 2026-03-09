"""Candidate collection and sorting for C, D, E, F points.

Each ``get_point_X_candidates`` function mirrors its MQL5 counterpart:
  1. Iterate the valid bar range
  2. Check channel membership
  3. Check local extremum
  4. Apply re-validation fix (Fix 1–4)
  5. Validate the preceding segment
  6. Validate span containment
  7. Collect passing candidates
  8. Sort by extremeness (deepest swing first)
"""

from __future__ import annotations

from typing import List, Tuple, Callable

from .types import Wave
from .config import DetectorConfig
from .diagnostics import DiagnosticLog
from .channels import (
    compute_channel_center_a,
    compute_channel_center_xb,
    channel_widths_for_a,
    channel_widths_for_xb,
    is_in_channel,
)
from . import validators as V

PriceFn = Callable[[int], float]
Candidate = Tuple[int, float]  # (bar_idx, price)


def _is_local_extremum(
    idx: int,
    is_low: bool,
    price_fn: PriceFn,
) -> bool:
    """Check if bar at *idx* is a local min (is_low) or max (!is_low)."""
    curr = price_fn(idx)
    prev = price_fn(idx + 1)
    nxt = price_fn(idx - 1)
    if is_low:
        return curr <= prev and curr <= nxt
    return curr >= prev and curr >= nxt


def _sort_candidates(
    candidates: List[Candidate],
    take_extreme_high: bool,
) -> List[Candidate]:
    """Sort candidates by extremeness (most extreme first).

    ``take_extreme_high = !point_is_low``:
      - Seeking LOW  → sort lowest first  (ascending)
      - Seeking HIGH → sort highest first (descending)
    """
    return sorted(candidates, key=lambda c: c[1], reverse=take_extreme_high)


# ---------------------------------------------------------------------------
# C candidates
# ---------------------------------------------------------------------------

def get_c_candidates(
    wave: Wave,
    bars_x_b: int,
    xb_slope: float,
    a_slope: float,
    c_is_low: bool,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> List[Candidate]:
    """Collect all valid C candidates in the A-channel."""
    c_price_fn = low_fn if c_is_low else high_fn
    take_extreme_high = not c_is_low

    c_min_idx = wave.b_idx - int(bars_x_b * cfg.min_b_to_c_btw_x_b * 0.01)
    c_max_idx = wave.b_idx - int(bars_x_b * cfg.max_b_to_c_btw_x_b * 0.01)
    if c_min_idx >= wave.b_idx:
        c_min_idx = wave.b_idx - 1
    if c_max_idx < 1:
        c_max_idx = 1

    a_upper, a_lower = channel_widths_for_a(
        wave.x_less_than_a, cfg.a_upper_width_pct, cfg.a_lower_width_pct,
    )

    results: List[Candidate] = []

    for i in range(c_min_idx, c_max_idx - 1, -1):
        if i <= 0:
            break
        c_price = c_price_fn(i)

        # 1. Channel membership
        center = compute_channel_center_a(wave.a_price, wave.a_idx, a_slope, i)
        if not is_in_channel(c_price, center, a_upper, a_lower):
            continue

        # 2. Local extremum
        if not _is_local_extremum(i, c_is_low, c_price_fn):
            continue

        # 3. AC slope for Fix 1 and segment validation
        bars_a_c = wave.a_idx - i
        if bars_a_c <= 0:
            continue
        ac_slope = (c_price - wave.a_price) / bars_a_c

        # Fix 1: re-validate A→B with real AC slope
        fix1_diag = DiagnosticLog()
        if not V.validate_ab_with_real_ac(
            wave.a_idx, wave.b_idx, wave.a_price, ac_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, fix1_diag,
        ):
            continue

        # 4. Validate B→C segment
        bc_diag = DiagnosticLog()
        if not V.validate_bc_segment(
            wave.b_idx, i,
            wave.x_price, wave.x_idx, wave.a_price, wave.a_idx,
            xb_slope, ac_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, bc_diag,
        ):
            continue

        # 5. A→C span containment (rule 1.14/2.14)
        span_diag = DiagnosticLog()
        if not V.validate_span_containment(
            wave.a_idx, wave.a_price, i, c_price,
            wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, span_diag,
            rule_id="1.14/2.14", span_label="A→C",
        ):
            continue

        results.append((i, c_price))

    return _sort_candidates(results, take_extreme_high)


# ---------------------------------------------------------------------------
# D candidates
# ---------------------------------------------------------------------------

def get_d_candidates(
    wave: Wave,
    bars_x_b: int,
    xb_slope: float,
    d_is_low: bool,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> List[Candidate]:
    """Collect all valid D candidates in the XB-channel."""
    d_price_fn = low_fn if d_is_low else high_fn
    take_extreme_high = not d_is_low

    d_min_idx = wave.c_idx - int(bars_x_b * cfg.min_c_to_d_btw_x_b * 0.01)
    d_max_idx = wave.c_idx - int(bars_x_b * cfg.max_c_to_d_btw_x_b * 0.01)
    if d_min_idx >= wave.c_idx:
        d_min_idx = wave.c_idx - 1
    if d_max_idx < 1:
        d_max_idx = 1

    xb_upper, xb_lower = channel_widths_for_xb(
        wave.x_less_than_a, cfg.xb_upper_width_pct, cfg.xb_lower_width_pct,
    )

    # AC slope (already known)
    bars_a_c = wave.a_idx - wave.c_idx
    if bars_a_c <= 0:
        return []
    ac_slope = (wave.c_price - wave.a_price) / bars_a_c

    results: List[Candidate] = []

    for i in range(d_min_idx, d_max_idx - 1, -1):
        if i <= 0:
            break
        d_price = d_price_fn(i)

        # 1. XB channel membership
        center = compute_channel_center_xb(wave.x_price, wave.x_idx, xb_slope, i)
        if not is_in_channel(d_price, center, xb_upper, xb_lower):
            continue

        # 2. Local extremum
        if not _is_local_extremum(i, d_is_low, d_price_fn):
            continue

        # 3. BD slope
        bars_b_d = wave.b_idx - i
        if bars_b_d <= 0:
            continue
        bd_slope = (d_price - wave.b_price) / bars_b_d

        # Fix 2: re-validate B→C with BD slope
        fix2_diag = DiagnosticLog()
        if not V.validate_bc_with_bd(
            wave.b_idx, wave.c_idx, wave.b_price, bd_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, fix2_diag,
        ):
            continue

        # 4. Validate C→D segment
        cd_diag = DiagnosticLog()
        if not V.validate_cd_segment(
            wave.c_idx, i,
            wave.a_price, wave.a_idx, wave.b_price, wave.b_idx,
            ac_slope, bd_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, cd_diag,
        ):
            continue

        # 5. B→D span containment (rule 1.15/2.15)
        span_diag = DiagnosticLog()
        if not V.validate_span_containment(
            wave.b_idx, wave.b_price, i, d_price,
            not wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, span_diag,
            rule_id="1.15/2.15", span_label="B→D",
        ):
            continue

        results.append((i, d_price))

    return _sort_candidates(results, take_extreme_high)


# ---------------------------------------------------------------------------
# E candidates
# ---------------------------------------------------------------------------

def get_e_candidates(
    wave: Wave,
    bars_x_b: int,
    a_slope: float,
    e_is_low: bool,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> List[Candidate]:
    """Collect all valid E candidates in the A-channel."""
    e_price_fn = low_fn if e_is_low else high_fn
    take_extreme_high = not e_is_low

    e_min_idx = wave.d_idx - int(bars_x_b * cfg.min_d_to_e_btw_x_b * 0.01)
    e_max_idx = wave.d_idx - int(bars_x_b * cfg.max_d_to_e_btw_x_b * 0.01)
    if e_min_idx >= wave.d_idx:
        e_min_idx = wave.d_idx - 1
    if e_max_idx < 1:
        e_max_idx = 1

    a_upper, a_lower = channel_widths_for_a(
        wave.x_less_than_a, cfg.a_upper_width_pct, cfg.a_lower_width_pct,
    )

    # BD slope (already known)
    bars_b_d = wave.b_idx - wave.d_idx
    if bars_b_d <= 0:
        return []
    bd_slope = (wave.d_price - wave.b_price) / bars_b_d

    results: List[Candidate] = []

    for i in range(e_min_idx, e_max_idx - 1, -1):
        if i <= 0:
            break
        e_price = e_price_fn(i)

        # 1. A-channel membership
        center = compute_channel_center_a(wave.a_price, wave.a_idx, a_slope, i)
        if not is_in_channel(e_price, center, a_upper, a_lower):
            continue

        # 2. Local extremum
        if not _is_local_extremum(i, e_is_low, e_price_fn):
            continue

        # 3. CE slope
        bars_c_e = wave.c_idx - i
        if bars_c_e <= 0:
            continue
        ce_slope = (e_price - wave.c_price) / bars_c_e

        # Fix 3: re-validate C→D with CE slope
        fix3_diag = DiagnosticLog()
        if not V.validate_cd_with_ce(
            wave.c_idx, wave.d_idx, wave.c_price, ce_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, fix3_diag,
        ):
            continue

        # 4. Validate D→E segment
        de_diag = DiagnosticLog()
        if not V.validate_de_segment(
            wave.d_idx, i,
            wave.b_price, wave.b_idx, wave.c_price, wave.c_idx,
            bd_slope, ce_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, de_diag,
        ):
            continue

        # 5. C→E span containment (rule 1.16/2.16)
        span_diag = DiagnosticLog()
        if not V.validate_span_containment(
            wave.c_idx, wave.c_price, i, e_price,
            wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, span_diag,
            rule_id="1.16/2.16", span_label="C→E",
        ):
            continue

        results.append((i, e_price))

    return _sort_candidates(results, take_extreme_high)


# ---------------------------------------------------------------------------
# F candidates
# ---------------------------------------------------------------------------

def get_f_candidates(
    wave: Wave,
    bars_x_b: int,
    xb_slope: float,
    f_is_low: bool,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    diag: DiagnosticLog,
) -> List[Candidate]:
    """Collect all valid F candidates in the XB-channel."""
    f_price_fn = low_fn if f_is_low else high_fn
    take_extreme_high = not f_is_low

    f_min_idx = wave.e_idx - int(bars_x_b * cfg.min_e_to_f_btw_x_b * 0.01)
    f_max_idx = wave.e_idx - int(bars_x_b * cfg.max_e_to_f_btw_x_b * 0.01)
    if f_min_idx >= wave.e_idx:
        f_min_idx = wave.e_idx - 1
    if f_max_idx < 1:
        f_max_idx = 1

    xb_upper, xb_lower = channel_widths_for_xb(
        wave.x_less_than_a, cfg.xb_upper_width_pct, cfg.xb_lower_width_pct,
    )

    # CE slope (already known)
    bars_c_e = wave.c_idx - wave.e_idx
    if bars_c_e <= 0:
        return []
    ce_slope = (wave.e_price - wave.c_price) / bars_c_e

    results: List[Candidate] = []

    for i in range(f_min_idx, f_max_idx - 1, -1):
        if i <= 0:
            break
        f_price = f_price_fn(i)

        # 1. XB channel membership
        center = compute_channel_center_xb(wave.x_price, wave.x_idx, xb_slope, i)
        if not is_in_channel(f_price, center, xb_upper, xb_lower):
            continue

        # 2. Local extremum
        if not _is_local_extremum(i, f_is_low, f_price_fn):
            continue

        # 3. DF slope
        bars_d_f = wave.d_idx - i
        if bars_d_f <= 0:
            continue
        df_slope = (f_price - wave.d_price) / bars_d_f

        # Fix 4: re-validate D→E with DF slope
        fix4_diag = DiagnosticLog()
        if not V.validate_de_with_df(
            wave.d_idx, wave.e_idx, wave.d_price, df_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, fix4_diag,
        ):
            continue

        # 4. Validate E→F segment
        ef_diag = DiagnosticLog()
        if not V.validate_ef_segment(
            wave.e_idx, i,
            wave.c_price, wave.c_idx, wave.d_price, wave.d_idx,
            ce_slope, df_slope,
            wave.x_less_than_a, cfg.slope_buffer_pct,
            high_fn, low_fn, ef_diag,
        ):
            continue

        # 5. D→F span containment (rule 1.17/2.17)
        span_diag = DiagnosticLog()
        if not V.validate_span_containment(
            wave.d_idx, wave.d_price, i, f_price,
            not wave.x_less_than_a,
            cfg.slope_buffer_pct, high_fn, low_fn, span_diag,
            rule_id="1.17/2.17", span_label="D→F",
        ):
            continue

        results.append((i, f_price))

    return _sort_candidates(results, take_extreme_high)
