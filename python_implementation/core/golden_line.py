"""Golden Line algorithm — proprietary trading signal computation.

The Golden Line algorithm:
1. Selects a slope line through pattern points (conditional selection
   based on relative positions — e.g., XD vs BD for XABCD).
2. Finds an FG separator line that divides candles between SP and last
   point into "above" and "below" groups.
3. Iterates slope percentages to find M (max-above) and N (max-below)
   points that satisfy the equality tolerance.
4. Draws the MN line as the "Golden Line" and searches for trade signals
   where price crosses the extended MN line while remaining within the
   slope extension channel.

Signal logic:
  - SELL: close < golden line (while HIGH hasn't broken slope extension)
  - BUY:  close > golden line (while LOW hasn't broken slope extension)

The algorithm uses the OPPOSITE price type from the last point:
  - Last point is HIGH → computations use LOWs
  - Last point is LOW  → computations use HIGHs
"""

from __future__ import annotations

import math
from typing import Callable, Optional

from .types import (
    GoldenLineResult, PatternType, SignalType, Wave,
)
from .config import DetectorConfig

PriceFn = Callable[[int], float]


def compute_golden_line(
    wave: Wave,
    ptype: PatternType,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    close_fn: PriceFn,
) -> Optional[GoldenLineResult]:
    """Compute the golden line for a detected pattern.

    Dispatches to uptrend or downtrend based on ``wave.x_less_than_a``.
    """
    if wave.x_less_than_a:
        return _golden_line_uptrend(wave, ptype, cfg, high_fn, low_fn, close_fn)
    return _golden_line_downtrend(wave, ptype, cfg, high_fn, low_fn, close_fn)


# ===================================================================
# Setup helpers — slope selection per pattern type
# ===================================================================

def _setup_uptrend(
    wave: Wave,
    ptype: PatternType,
) -> Optional[dict]:
    """Determine slope array, SP, Z, and last point for uptrend golden line."""
    # For X<A: B=LOW, C=HIGH, D=LOW, E=HIGH, F=LOW
    if ptype == PatternType.XAB:
        last_price, last_idx = wave.b_price, wave.b_idx
        sp_price, sp_idx = wave.a_price, wave.a_idx
        bars_slope = wave.x_idx - wave.b_idx
        if bars_slope <= 0:
            return None
        step = (wave.b_price - wave.x_price) / bars_slope
        slope_arr = [wave.x_price + i * step for i in range(bars_slope + 1)]
        z_offset = wave.x_idx - wave.a_idx
        if z_offset < 0 or z_offset > bars_slope:
            return None
        z_price = slope_arr[z_offset]
        z_idx = wave.a_idx
        return dict(
            last_price=last_price, last_idx=last_idx,
            sp_price=sp_price, sp_idx=sp_idx,
            z_price=z_price, z_idx=z_idx,
            step_slope=step, slope_arr=slope_arr,
            bars_slope=bars_slope, final_diff=0.0,
            slope_selection="XB",
        )

    elif ptype == PatternType.XABC:
        last_price, last_idx = wave.c_price, wave.c_idx
        sp_price, sp_idx = wave.b_price, wave.b_idx
        bars_slope = wave.a_idx - wave.c_idx
        if bars_slope <= 0:
            return None
        step = (wave.c_price - wave.a_price) / bars_slope
        slope_arr = [wave.a_price + i * step for i in range(bars_slope + 1)]
        b_offset = wave.a_idx - wave.b_idx
        if b_offset < 0 or b_offset > bars_slope:
            return None
        z_price = slope_arr[b_offset]
        z_idx = wave.b_idx
        return dict(
            last_price=last_price, last_idx=last_idx,
            sp_price=sp_price, sp_idx=sp_idx,
            z_price=z_price, z_idx=z_idx,
            step_slope=step, slope_arr=slope_arr,
            bars_slope=bars_slope, final_diff=0.0,
            slope_selection="AC",
        )

    elif ptype == PatternType.XABCD:
        last_price, last_idx = wave.d_price, wave.d_idx
        sp_price, sp_idx = wave.c_price, wave.c_idx

        # XD array
        bars_xd = wave.x_idx - wave.d_idx
        if bars_xd <= 0:
            return None
        step_xd = (wave.d_price - wave.x_price) / bars_xd
        xd_arr = [wave.x_price + i * step_xd for i in range(bars_xd + 1)]

        # BD array
        bars_bd = wave.b_idx - wave.d_idx
        if bars_bd <= 0:
            return None
        step_bd = (wave.d_price - wave.b_price) / bars_bd
        bd_arr = [wave.b_price + i * step_bd for i in range(bars_bd + 1)]

        # Condition: B lower than XD line at B's position
        b_off = wave.x_idx - wave.b_idx
        b_is_lower = wave.b_price < xd_arr[b_off]

        if b_is_lower:
            c_off = wave.x_idx - wave.c_idx
            if c_off < 0 or c_off >= len(xd_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=xd_arr[c_off], z_idx=wave.c_idx,
                step_slope=step_xd, slope_arr=xd_arr,
                bars_slope=bars_xd, final_diff=0.0,
                slope_selection="XD",
            )
        else:
            c_off = wave.b_idx - wave.c_idx
            if c_off < 0 or c_off >= len(bd_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=bd_arr[c_off], z_idx=wave.c_idx,
                step_slope=step_bd, slope_arr=bd_arr,
                bars_slope=bars_bd, final_diff=0.0,
                slope_selection="BD",
            )

    elif ptype == PatternType.XABCDE:
        last_price, last_idx = wave.e_price, wave.e_idx

        # AE array
        bars_ae = wave.a_idx - wave.e_idx
        if bars_ae <= 0:
            return None
        step_ae = (wave.e_price - wave.a_price) / bars_ae
        ae_arr = [wave.a_price + i * step_ae for i in range(bars_ae + 1)]

        # CE array
        bars_ce = wave.c_idx - wave.e_idx
        if bars_ce <= 0:
            return None
        step_ce = (wave.e_price - wave.c_price) / bars_ce
        ce_arr = [wave.c_price + i * step_ce for i in range(bars_ce + 1)]

        c_off_ae = wave.a_idx - wave.c_idx
        c_is_higher = wave.c_price > ae_arr[c_off_ae]

        d_off_ae = wave.a_idx - wave.d_idx
        b_off_ae = wave.a_idx - wave.b_idx
        d_diff = wave.d_price - ae_arr[d_off_ae]
        b_diff = wave.b_price - ae_arr[b_off_ae]

        if c_is_higher:
            if d_diff > b_diff:
                sp_price, sp_idx = wave.d_price, wave.d_idx
                z_price = ae_arr[d_off_ae]
                z_idx = wave.d_idx
                final_diff = wave.d_price - z_price
            else:
                sp_price, sp_idx = wave.b_price, wave.b_idx
                z_price = ae_arr[b_off_ae]
                z_idx = wave.b_idx
                final_diff = b_diff
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=z_price, z_idx=z_idx,
                step_slope=step_ae, slope_arr=ae_arr,
                bars_slope=bars_ae, final_diff=final_diff,
                slope_selection="AE",
            )
        else:
            d_off_ce = wave.c_idx - wave.d_idx
            sp_price, sp_idx = wave.d_price, wave.d_idx
            z_price = ce_arr[d_off_ce]
            z_idx = wave.d_idx
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=z_price, z_idx=z_idx,
                step_slope=step_ce, slope_arr=ce_arr,
                bars_slope=bars_ce, final_diff=d_diff,
                slope_selection="CE",
            )

    elif ptype == PatternType.XABCDEF:
        last_price, last_idx = wave.f_price, wave.f_idx
        sp_price, sp_idx = wave.e_price, wave.e_idx

        # XF array
        bars_xf = wave.x_idx - wave.f_idx
        if bars_xf <= 0:
            return None
        step_xf = (wave.f_price - wave.x_price) / bars_xf
        xf_arr = [wave.x_price + i * step_xf for i in range(bars_xf + 1)]

        # DF array
        bars_df = wave.d_idx - wave.f_idx
        if bars_df <= 0:
            return None
        step_df = (wave.f_price - wave.d_price) / bars_df
        df_arr = [wave.d_price + i * step_df for i in range(bars_df + 1)]

        d_off = wave.x_idx - wave.d_idx
        d_is_lower = wave.d_price < xf_arr[d_off]

        if d_is_lower:
            e_off = wave.x_idx - wave.e_idx
            if e_off < 0 or e_off >= len(xf_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=xf_arr[e_off], z_idx=wave.e_idx,
                step_slope=step_xf, slope_arr=xf_arr,
                bars_slope=bars_xf, final_diff=0.0,
                slope_selection="XF",
            )
        else:
            e_off = wave.d_idx - wave.e_idx
            if e_off < 0 or e_off >= len(df_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=df_arr[e_off], z_idx=wave.e_idx,
                step_slope=step_df, slope_arr=df_arr,
                bars_slope=bars_df, final_diff=0.0,
                slope_selection="DF",
            )
    return None


def _setup_downtrend(
    wave: Wave,
    ptype: PatternType,
) -> Optional[dict]:
    """Determine slope array, SP, Z for downtrend golden line.

    Mirrors ``_setup_uptrend`` with opposite conditional comparisons.
    """
    if ptype == PatternType.XAB:
        last_price, last_idx = wave.b_price, wave.b_idx
        sp_price, sp_idx = wave.a_price, wave.a_idx
        bars_slope = wave.x_idx - wave.b_idx
        if bars_slope <= 0:
            return None
        step = (wave.b_price - wave.x_price) / bars_slope
        slope_arr = [wave.x_price + i * step for i in range(bars_slope + 1)]
        z_off = wave.x_idx - wave.a_idx
        if z_off < 0 or z_off > bars_slope:
            return None
        return dict(
            last_price=last_price, last_idx=last_idx,
            sp_price=sp_price, sp_idx=sp_idx,
            z_price=slope_arr[z_off], z_idx=wave.a_idx,
            step_slope=step, slope_arr=slope_arr,
            bars_slope=bars_slope, final_diff=0.0,
            slope_selection="XB",
        )

    elif ptype == PatternType.XABC:
        last_price, last_idx = wave.c_price, wave.c_idx
        sp_price, sp_idx = wave.b_price, wave.b_idx
        bars_slope = wave.a_idx - wave.c_idx
        if bars_slope <= 0:
            return None
        step = (wave.c_price - wave.a_price) / bars_slope
        slope_arr = [wave.a_price + i * step for i in range(bars_slope + 1)]
        b_off = wave.a_idx - wave.b_idx
        if b_off < 0 or b_off > bars_slope:
            return None
        return dict(
            last_price=last_price, last_idx=last_idx,
            sp_price=sp_price, sp_idx=sp_idx,
            z_price=slope_arr[b_off], z_idx=wave.b_idx,
            step_slope=step, slope_arr=slope_arr,
            bars_slope=bars_slope, final_diff=0.0,
            slope_selection="AC",
        )

    elif ptype == PatternType.XABCD:
        last_price, last_idx = wave.d_price, wave.d_idx
        sp_price, sp_idx = wave.c_price, wave.c_idx

        bars_xd = wave.x_idx - wave.d_idx
        if bars_xd <= 0:
            return None
        step_xd = (wave.d_price - wave.x_price) / bars_xd
        xd_arr = [wave.x_price + i * step_xd for i in range(bars_xd + 1)]

        bars_bd = wave.b_idx - wave.d_idx
        if bars_bd <= 0:
            return None
        step_bd = (wave.d_price - wave.b_price) / bars_bd
        bd_arr = [wave.b_price + i * step_bd for i in range(bars_bd + 1)]

        b_off = wave.x_idx - wave.b_idx
        b_is_higher = wave.b_price > xd_arr[b_off]

        if b_is_higher:
            c_off = wave.x_idx - wave.c_idx
            if c_off < 0 or c_off >= len(xd_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=xd_arr[c_off], z_idx=wave.c_idx,
                step_slope=step_xd, slope_arr=xd_arr,
                bars_slope=bars_xd, final_diff=0.0,
                slope_selection="XD",
            )
        else:
            c_off = wave.b_idx - wave.c_idx
            if c_off < 0 or c_off >= len(bd_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=bd_arr[c_off], z_idx=wave.c_idx,
                step_slope=step_bd, slope_arr=bd_arr,
                bars_slope=bars_bd, final_diff=0.0,
                slope_selection="BD",
            )

    elif ptype == PatternType.XABCDE:
        last_price, last_idx = wave.e_price, wave.e_idx

        bars_ae = wave.a_idx - wave.e_idx
        if bars_ae <= 0:
            return None
        step_ae = (wave.e_price - wave.a_price) / bars_ae
        ae_arr = [wave.a_price + i * step_ae for i in range(bars_ae + 1)]

        bars_ce = wave.c_idx - wave.e_idx
        if bars_ce <= 0:
            return None
        step_ce = (wave.e_price - wave.c_price) / bars_ce
        ce_arr = [wave.c_price + i * step_ce for i in range(bars_ce + 1)]

        c_off_ae = wave.a_idx - wave.c_idx
        c_is_lower = wave.c_price < ae_arr[c_off_ae]

        d_off_ae = wave.a_idx - wave.d_idx
        b_off_ae = wave.a_idx - wave.b_idx
        d_diff = ae_arr[d_off_ae] - wave.d_price
        b_diff = ae_arr[b_off_ae] - wave.b_price

        if c_is_lower:
            d_off_ce = wave.c_idx - wave.d_idx
            sp_price, sp_idx = wave.d_price, wave.d_idx
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=ce_arr[d_off_ce], z_idx=wave.d_idx,
                step_slope=step_ce, slope_arr=ce_arr,
                bars_slope=bars_ce, final_diff=sp_price - ce_arr[d_off_ce],
                slope_selection="CE",
            )
        else:
            if d_diff > b_diff:
                sp_price, sp_idx = wave.d_price, wave.d_idx
                z_price = ae_arr[d_off_ae]
                z_idx = wave.d_idx
            else:
                sp_price, sp_idx = wave.b_price, wave.b_idx
                z_price = ae_arr[b_off_ae]
                z_idx = wave.b_idx
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=z_price, z_idx=z_idx,
                step_slope=step_ae, slope_arr=ae_arr,
                bars_slope=bars_ae, final_diff=sp_price - z_price,
                slope_selection="AE",
            )

    elif ptype == PatternType.XABCDEF:
        last_price, last_idx = wave.f_price, wave.f_idx
        sp_price, sp_idx = wave.e_price, wave.e_idx

        bars_xf = wave.x_idx - wave.f_idx
        if bars_xf <= 0:
            return None
        step_xf = (wave.f_price - wave.x_price) / bars_xf
        xf_arr = [wave.x_price + i * step_xf for i in range(bars_xf + 1)]

        bars_df = wave.d_idx - wave.f_idx
        if bars_df <= 0:
            return None
        step_df = (wave.f_price - wave.d_price) / bars_df
        df_arr = [wave.d_price + i * step_df for i in range(bars_df + 1)]

        d_off = wave.x_idx - wave.d_idx
        d_is_higher = wave.d_price > xf_arr[d_off]

        if d_is_higher:
            e_off = wave.x_idx - wave.e_idx
            if e_off < 0 or e_off >= len(xf_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=xf_arr[e_off], z_idx=wave.e_idx,
                step_slope=step_xf, slope_arr=xf_arr,
                bars_slope=bars_xf, final_diff=0.0,
                slope_selection="XF",
            )
        else:
            e_off = wave.d_idx - wave.e_idx
            if e_off < 0 or e_off >= len(df_arr):
                return None
            return dict(
                last_price=last_price, last_idx=last_idx,
                sp_price=sp_price, sp_idx=sp_idx,
                z_price=df_arr[e_off], z_idx=wave.e_idx,
                step_slope=step_df, slope_arr=df_arr,
                bars_slope=bars_df, final_diff=0.0,
                slope_selection="DF",
            )
    return None


# ===================================================================
# Core golden line computation (shared between uptrend & downtrend)
# ===================================================================

def _compute_golden(
    setup: dict,
    last_is_high: bool,
    signal_is_sell: bool,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    close_fn: PriceFn,
) -> Optional[GoldenLineResult]:
    """Shared golden line computation after setup."""
    last_price = setup["last_price"]
    last_idx = setup["last_idx"]
    sp_price = setup["sp_price"]
    sp_idx = setup["sp_idx"]
    z_price = setup["z_price"]
    z_idx = setup["z_idx"]
    step_slope = setup["step_slope"]
    slope_arr = setup["slope_arr"]
    bars_slope = setup["bars_slope"]
    final_diff = setup["final_diff"]

    if sp_idx <= last_idx:
        return None

    # Default final_diff
    if final_diff == 0:
        final_diff = sp_price - z_price

    # -- FG separator search --
    total_iter = int((100 - cfg.f_percentage) / cfg.fg_increasing_percentage) + 2
    separate_found = False
    idxs_above: list[int] = []
    idxs_below: list[int] = []
    fg_arr: list[float] = []
    fg_start_price = 0.0
    bars_fg = 0

    for q in range(total_iter + 1):
        idxs_above.clear()
        idxs_below.clear()

        p_check = cfg.f_percentage + q * cfg.fg_increasing_percentage
        if p_check > 100:
            p_check = 100

        fg_start_price = z_price + final_diff * p_check * 0.01
        bars_fg = z_idx - last_idx
        if bars_fg <= 0:
            continue

        fg_arr = [fg_start_price + i * step_slope for i in range(bars_fg + 1)]

        # Last bar limit check
        if last_is_high:
            if low_fn(last_idx) <= fg_arr[bars_fg]:
                continue
        else:
            if high_fn(last_idx) >= fg_arr[bars_fg]:
                continue

        # Divide candles
        for i in range(sp_idx - last_idx + 1):
            candle_idx = sp_idx - i
            candle_price = low_fn(candle_idx) if last_is_high else high_fn(candle_idx)
            fg_offset = min(i, bars_fg)
            fg_val = fg_arr[fg_offset]

            if last_is_high:
                above = candle_price > fg_val
            else:
                above = candle_price >= fg_val

            if above:
                idxs_above.append(i)
            else:
                idxs_below.append(i)

        if idxs_above and idxs_below:
            separate_found = True
            break

    if not separate_found:
        return None

    # -- Matrix computation: find M and N --
    bars_sp_to_last = sp_idx - last_idx

    max_j = int(cfg.first_line_percentage / cfg.first_line_decrease_percentage)
    for j in range(max_j, -1, -1):
        cur_slope_pct = cfg.first_line_percentage - j * cfg.first_line_decrease_percentage
        slope_per_bar = (sp_price * cur_slope_pct * 0.01) / bars_sp_to_last if bars_sp_to_last > 0 else 0

        first_line = []
        for i in range(bars_sp_to_last + 1):
            if last_is_high:
                first_line.append(sp_price + slope_per_bar * i)
            else:
                first_line.append(sp_price - slope_per_bar * i)

        # Compute diffs for above and below groups
        above_diffs: list[float] = []
        above_offsets: list[int] = []
        below_diffs: list[float] = []
        below_offsets: list[int] = []

        for offset in idxs_above:
            if offset > bars_sp_to_last:
                continue
            candle_idx = sp_idx - offset
            actual = low_fn(candle_idx) if last_is_high else high_fn(candle_idx)
            fl_val = first_line[offset]
            diff = (fl_val - actual) if last_is_high else (actual - fl_val)
            above_diffs.append(diff)
            above_offsets.append(offset)

        for offset in idxs_below:
            if offset > bars_sp_to_last:
                continue
            candle_idx = sp_idx - offset
            actual = low_fn(candle_idx) if last_is_high else high_fn(candle_idx)
            fl_val = first_line[offset]
            diff = (fl_val - actual) if last_is_high else (actual - fl_val)
            below_diffs.append(diff)
            below_offsets.append(offset)

        if not above_diffs or not below_diffs:
            continue

        max_above_diff = max(above_diffs)
        max_below_diff = max(below_diffs)

        if max_below_diff < 0 or max_above_diff < 0:
            continue

        # M/N validation
        ref_price = abs(sp_price - last_price)
        if ref_price < 1e-10:
            continue
        diff_pct = abs(max_above_diff - max_below_diff) / ref_price
        if diff_pct > cfg.max_below_max_above_diff_percentage * 0.01 and diff_pct != 1.0:
            continue

        # Get M and N
        max_above_i = above_diffs.index(max_above_diff)
        max_below_i = below_diffs.index(max_below_diff)

        max_above_offset = above_offsets[max_above_i]
        max_below_offset = below_offsets[max_below_i]

        max_above_idx = sp_idx - max_above_offset
        max_below_idx = sp_idx - max_below_offset

        max_above_price = low_fn(max_above_idx) if last_is_high else high_fn(max_above_idx)
        max_below_price = low_fn(max_below_idx) if last_is_high else high_fn(max_below_idx)

        if max_below_price > max_above_price:
            continue

        # Temporal ordering validation
        if last_is_high:
            if max_below_idx <= max_above_idx:
                continue
        else:
            if max_below_idx >= max_above_idx:
                continue

        # MN length check
        if cfg.mn_length_percent > 0:
            min_mn_bars = int(cfg.mn_length_percent * 0.01 * bars_sp_to_last)
            if abs(max_above_idx - max_below_idx) < min_mn_bars:
                continue

        # Build MN array
        if last_is_high:
            bars_mn = max_below_idx - max_above_idx
            if bars_mn <= 0:
                continue
            step_mn = (max_above_price - max_below_price) / bars_mn
            mn_start_price = max_below_price - (max_above_price - max_below_price) * cfg.mn_buffer_percent * 0.01
            mn_start_idx = max_below_idx
            mn_total = mn_start_idx - last_idx + cfg.mn_extension_bars
        else:
            bars_mn = max_above_idx - max_below_idx
            if bars_mn <= 0:
                continue
            step_mn = (max_below_price - max_above_price) / bars_mn
            mn_start_price = max_above_price + (max_above_price - max_below_price) * cfg.mn_buffer_percent * 0.01
            mn_start_idx = max_above_idx
            mn_total = mn_start_idx - last_idx + cfg.mn_extension_bars

        if mn_total <= 0:
            continue

        mn_arr = [mn_start_price + i * step_mn for i in range(mn_total)]

        # Build slope extension
        slope_ext_total = bars_slope + cfg.mn_extension_bars
        slope_ext = []
        for i in range(slope_ext_total):
            if i <= bars_slope:
                slope_ext.append(slope_arr[i] if i < len(slope_arr) else last_price)
            else:
                slope_ext.append(last_price + (i - bars_slope) * step_slope)

        # Search for signal
        signal: Optional[SignalType] = None
        signal_idx: Optional[int] = None
        signal_price: Optional[float] = None

        for i in range(1, cfg.mn_extension_bars):
            sig_idx = last_idx - i
            if sig_idx < 1:
                break

            mn_offset = mn_start_idx - last_idx + i
            if mn_offset >= len(mn_arr):
                break
            trend_price = mn_arr[mn_offset]

            se_offset = bars_slope + i
            if se_offset >= len(slope_ext):
                break
            se_price = slope_ext[se_offset]

            c_high = high_fn(sig_idx)
            c_low = low_fn(sig_idx)
            c_close = close_fn(sig_idx)

            if signal_is_sell:
                bp = c_close if cfg.extension_break_close else c_high
                if bp > se_price:
                    break
                if c_close >= trend_price:
                    continue
                signal = SignalType.SELL
                signal_idx = sig_idx
                signal_price = c_high
            else:
                bp = c_close if cfg.extension_break_close else c_low
                if bp < se_price:
                    break
                if c_close <= trend_price:
                    continue
                signal = SignalType.BUY
                signal_idx = sig_idx
                signal_price = c_low
            break

        # Compute golden line end point
        ext_bars = min(cfg.mn_extension_bars, last_idx)
        mn_end_offset = mn_start_idx - last_idx + ext_bars - 1

        if mn_end_offset <= 0 or mn_end_offset >= len(mn_arr):
            # Fallback
            return GoldenLineResult(
                mn_start_idx=mn_start_idx,
                mn_start_price=mn_start_price,
                mn_end_idx=last_idx,
                mn_end_price=last_price,
                signal=signal,
                signal_idx=signal_idx,
                signal_price=signal_price,
                slope_selection=setup["slope_selection"],
            )

        return GoldenLineResult(
            mn_start_idx=mn_start_idx,
            mn_start_price=mn_start_price,
            mn_end_idx=last_idx - ext_bars + 1,
            mn_end_price=mn_arr[mn_end_offset],
            signal=signal,
            signal_idx=signal_idx,
            signal_price=signal_price,
            fg_start_idx=z_idx,
            fg_start_price=fg_start_price,
            fg_end_idx=last_idx,
            fg_end_price=fg_arr[bars_fg] if fg_arr else None,
            slope_selection=setup["slope_selection"],
        )

    # Exhausted all iterations
    return None


def _golden_line_uptrend(
    wave: Wave,
    ptype: PatternType,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    close_fn: PriceFn,
) -> Optional[GoldenLineResult]:
    """Golden line for X<A patterns."""
    setup = _setup_uptrend(wave, ptype)
    if setup is None:
        return None

    # For uptrend: B=LOW, C=HIGH, D=LOW, E=HIGH, F=LOW
    last_is_high = ptype in (PatternType.XABC, PatternType.XABCDE)
    signal_is_sell = last_is_high

    return _compute_golden(setup, last_is_high, signal_is_sell, cfg, high_fn, low_fn, close_fn)


def _golden_line_downtrend(
    wave: Wave,
    ptype: PatternType,
    cfg: DetectorConfig,
    high_fn: PriceFn,
    low_fn: PriceFn,
    close_fn: PriceFn,
) -> Optional[GoldenLineResult]:
    """Golden line for X>A patterns."""
    setup = _setup_downtrend(wave, ptype)
    if setup is None:
        return None

    # For downtrend: B=HIGH, C=LOW, D=HIGH, E=LOW, F=HIGH
    last_is_high = ptype in (PatternType.XAB, PatternType.XABCD, PatternType.XABCDEF)
    signal_is_sell = last_is_high

    return _compute_golden(setup, last_is_high, signal_is_sell, cfg, high_fn, low_fn, close_fn)
