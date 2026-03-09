"""Main pattern detection orchestrator.

Mirrors the MQL5 ``find_all_patterns → try_find_pattern_from_x →
try_build_pattern_with_b`` cascade, producing ``PatternResult`` objects
with full diagnostic logs.

When ``collect_traces=True`` is passed to ``find_all``, every X-candle
attempt (both successes and failures) is captured as an ``XAttemptLog``
so the interactive dashboard can show exactly why each bar succeeded or
failed at every step of detection.
"""

from __future__ import annotations

import copy
from typing import Callable, Dict, List, Optional, Tuple

from .types import (
    ChannelType, PatternDirection, PatternResult, PatternType, Wave,
    XAttemptLog,
)
from .config import DetectorConfig
from .diagnostics import DiagnosticLog
from .channels import get_a_channel_slope
from . import validators as V
from . import candidates as C
from .filters import tick_speed_filter, divergence_filter

PriceFn = Callable[[int], float]


class PatternDetector:
    """Stateless pattern detector operating on vectorised candle data.

    Usage::

        from data.loader import load_csv
        candles = load_csv("EURUSD_H1.csv")
        cfg = DetectorConfig(pattern_type=PatternType.XABCD)
        detector = PatternDetector(candles)
        results = detector.find_all(cfg)

        # With per-candle traces for the dashboard:
        results, traces = detector.find_all(cfg, collect_traces=True)
    """

    def __init__(self, candles) -> None:
        self._candles = candles
        self._total_bars = len(candles) - 1

    # -- Price accessor helpers (match MQL5 iHigh / iLow / iClose) --

    def _high(self, idx: int) -> float:
        return self._candles.high_at(idx)

    def _low(self, idx: int) -> float:
        return self._candles.low_at(idx)

    def _close(self, idx: int) -> float:
        return self._candles.close_at(idx)

    def _volume(self, idx: int) -> float:
        return self._candles.volume_at(idx)

    def _time(self, idx: int) -> float:
        return self._candles.time_at(idx)

    # ===================================================================
    # Public API
    # ===================================================================

    def find_all(
        self,
        cfg: DetectorConfig,
        collect_traces: bool = False,
    ) -> List[PatternResult] | Tuple[List[PatternResult], Dict[int, List[XAttemptLog]]]:
        """Find all patterns matching *cfg* in the loaded candle data.

        Args:
            cfg: Detection configuration.
            collect_traces: When True, also returns a dict mapping each
                x_idx to the list of ``XAttemptLog`` entries produced.
                Return type becomes ``(results, traces)``.

        Returns:
            List of ``PatternResult`` objects, OR a ``(results, traces)``
            tuple when ``collect_traces=True``.
        """
        search_start = self._total_bars
        if cfg.max_search_bars > 0 and cfg.max_search_bars < self._total_bars:
            search_start = cfg.max_search_bars

        results: List[PatternResult] = []
        traces: Dict[int, List[XAttemptLog]] = {} if collect_traces else None  # type: ignore

        for active_ct in cfg.channel_types_to_run():
            last_drawn_idx = -9999

            for x_idx in range(search_start, cfg.b_max + 10, -1):
                # Try X as LOW
                pat, attempt = self._try_from_x(
                    x_idx, True, active_ct, cfg, last_drawn_idx, collect_traces
                )
                if collect_traces and attempt:
                    traces.setdefault(x_idx, []).append(attempt)
                if pat is not None:
                    results.append(pat)
                    last_drawn_idx = pat.wave.last_point(pat.pattern_type)[0]

                # Try X as HIGH
                pat, attempt = self._try_from_x(
                    x_idx, False, active_ct, cfg, last_drawn_idx, collect_traces
                )
                if collect_traces and attempt:
                    traces.setdefault(x_idx, []).append(attempt)
                if pat is not None:
                    results.append(pat)
                    last_drawn_idx = pat.wave.last_point(pat.pattern_type)[0]

        if collect_traces:
            return results, traces
        return results

    # ===================================================================
    # Internal: cascade
    # ===================================================================

    def _try_from_x(
        self,
        x_idx: int,
        x_is_low: bool,
        channel_type: ChannelType,
        cfg: DetectorConfig,
        last_drawn_idx: int,
        collect_traces: bool,
    ) -> Tuple[Optional[PatternResult], Optional[XAttemptLog]]:
        """Try to build a pattern starting from X at *x_idx*.

        Returns ``(PatternResult | None, XAttemptLog | None)``.
        XAttemptLog is only populated when collect_traces=True.
        """
        x_price = self._low(x_idx) if x_is_low else self._high(x_idx)
        if x_price == 0:
            return None, None

        # -- B candidate search --
        b_cands = self._collect_b_candidates(x_idx, x_price, x_is_low, cfg)

        if collect_traces and not b_cands:
            # Record the "no B found" attempt
            attempt = XAttemptLog(x_idx=x_idx, x_is_low=x_is_low)
            attempt.reject(
                "B_SEARCH",
                f"No B candidates found in range [{x_idx - cfg.b_max}, {x_idx - cfg.b_min - 1}]",
            )
            return None, attempt

        if not b_cands:
            return None, None

        # Try each B candidate in order — return on first success
        last_attempt: Optional[XAttemptLog] = None
        for b_idx, b_price in b_cands:
            bars_x_b = x_idx - b_idx
            if bars_x_b <= 0:
                continue
            result, attempt = self._try_with_b(
                x_idx, x_price, x_is_low, b_idx, b_price, bars_x_b,
                channel_type, cfg, last_drawn_idx, collect_traces,
            )
            if collect_traces:
                last_attempt = attempt
            if result is not None:
                return result, attempt

        # Return the last attempt (most informative) when collect_traces
        return None, last_attempt

    def _collect_b_candidates(
        self,
        x_idx: int,
        x_price: float,
        x_is_low: bool,
        cfg: DetectorConfig,
    ) -> List[tuple]:
        """Collect and sort B candidates (local extrema in range)."""
        b_start = x_idx - 1 - cfg.b_min
        b_end = max(x_idx - cfg.b_max, 0)

        price_fn = self._low if x_is_low else self._high
        cands: list[tuple[int, float]] = []

        for i in range(b_start, b_end, -1):
            if i <= 0:
                break
            curr = price_fn(i)
            prev = price_fn(i + 1)
            nxt = price_fn(i - 1)

            if x_is_low:
                is_ext = curr <= prev and curr <= nxt
            else:
                is_ext = curr >= prev and curr >= nxt

            if is_ext:
                cands.append((i, curr))

        cands.sort(key=lambda c: c[1], reverse=not x_is_low)
        return cands

    def _try_with_b(
        self,
        x_idx: int,
        x_price: float,
        x_is_low: bool,
        b_idx: int,
        b_price: float,
        bars_x_b: int,
        channel_type: ChannelType,
        cfg: DetectorConfig,
        last_drawn_idx: int,
        collect_traces: bool,
    ) -> Tuple[Optional[PatternResult], Optional[XAttemptLog]]:
        """Build pattern with specific B. Returns (PatternResult|None, XAttemptLog|None)."""
        diag = DiagnosticLog()
        wave = Wave()
        wave.x_idx = x_idx
        wave.x_price = x_price
        wave.b_idx = b_idx
        wave.b_price = b_price

        # Initialise the attempt log
        attempt: Optional[XAttemptLog] = None
        if collect_traces:
            attempt = XAttemptLog(
                x_idx=x_idx, x_is_low=x_is_low,
                b_idx=b_idx, b_price=b_price,
            )
            attempt.add_step(
                "B_SEARCH", True,
                f"B found at bar {b_idx} price={b_price:.5f} (bars_x_b={bars_x_b})",
                value=float(bars_x_b),
            )

        xb_slope = (b_price - x_price) / bars_x_b

        # -- Find A (max deviation from XB slope) --
        xb_array = [x_price + j * xb_slope for j in range(bars_x_b + 1)]

        max_dev = -1e300
        a_idx = -1
        a_price = 0.0

        for i in range(x_idx - 1, b_idx, -1):
            offset = x_idx - i
            if offset >= len(xb_array):
                continue
            xb_val = xb_array[offset]
            if x_is_low:
                price = self._high(i)
                dev = price - xb_val
            else:
                price = self._low(i)
                dev = xb_val - price
            if dev > max_dev:
                max_dev = dev
                a_idx = i
                a_price = price

        if a_idx == -1 or max_dev <= 0:
            if attempt:
                attempt.reject(
                    "A_FIND",
                    f"No valid A point (max_dev={max_dev:.5f} ≤ 0 or no candidate)",
                    value=max_dev,
                )
            return None, attempt

        if a_idx >= x_idx or a_idx <= b_idx:
            if attempt:
                attempt.reject(
                    "A_FIND",
                    f"A at bar {a_idx} outside X({x_idx})..B({b_idx}) range",
                    value=float(a_idx),
                )
            return None, attempt

        if attempt:
            attempt.add_step(
                "A_FIND", True,
                f"A at bar {a_idx} price={a_price:.5f} max_dev={max_dev:.5f}",
                value=max_dev,
            )

        wave.a_idx = a_idx
        wave.a_price = a_price
        wave.x_less_than_a = x_price < a_price

        # -- B retracement --
        xa_diff = a_price - x_price
        if abs(xa_diff) < 1e-10:
            if attempt:
                attempt.reject("XB_RETRACE", "XA diff near zero — degenerate pattern")
            return None, attempt

        xb_retrace = (b_price - x_price) / xa_diff * 100
        if xb_retrace < cfg.x_to_a_b_min or xb_retrace > cfg.x_to_a_b_max:
            if attempt:
                attempt.reject(
                    "XB_RETRACE",
                    f"XB retracement={xb_retrace:.2f}% outside [{cfg.x_to_a_b_min:.1f}%, {cfg.x_to_a_b_max:.1f}%]",
                    value=xb_retrace,
                    threshold_min=cfg.x_to_a_b_min,
                    threshold_max=cfg.x_to_a_b_max,
                )
            return None, attempt

        if attempt:
            attempt.add_step(
                "XB_RETRACE", True,
                f"XB retrace={xb_retrace:.2f}% in [{cfg.x_to_a_b_min:.1f}%, {cfg.x_to_a_b_max:.1f}%]",
                value=xb_retrace,
                threshold_min=cfg.x_to_a_b_min,
                threshold_max=cfg.x_to_a_b_max,
            )

        # -- A width check --
        a_offset = x_idx - a_idx
        if a_offset < 0 or a_offset >= len(xb_array):
            if attempt:
                attempt.reject("A_WIDTH", f"A offset {a_offset} out of XB array bounds")
            return None, attempt

        z = xb_array[a_offset]
        b_start_local = x_idx - 1 - cfg.b_min
        dyn_candles = max(b_start_local - b_idx, 0)
        inc_val = (dyn_candles // cfg.every_increasing_of_value + 1) * cfg.width_increasing_percentage_x_to_b
        dyn_max = cfg.max_width_percentage + inc_val
        dyn_min = cfg.min_width_percentage + inc_val

        if x_is_low:
            a_upper = z + z * dyn_max * 0.01
            a_lower = z + z * dyn_min * 0.01
            a_in_range = a_lower <= a_price <= a_upper
        else:
            a_upper = z - z * dyn_max * 0.01
            a_lower = z - z * dyn_min * 0.01
            a_in_range = a_upper <= a_price <= a_lower

        if not a_in_range:
            if attempt:
                attempt.reject(
                    "A_WIDTH",
                    f"A price={a_price:.5f} outside width band [{min(a_lower,a_upper):.5f}, {max(a_lower,a_upper):.5f}] (dyn_min={dyn_min:.1f}%, dyn_max={dyn_max:.1f}%)",
                    value=a_price,
                    threshold_min=min(a_lower, a_upper),
                    threshold_max=max(a_lower, a_upper),
                )
            return None, attempt

        if attempt:
            attempt.add_step(
                "A_WIDTH", True,
                f"A price={a_price:.5f} in [{min(a_lower,a_upper):.5f}, {max(a_lower,a_upper):.5f}]",
                value=a_price,
                threshold_min=min(a_lower, a_upper),
                threshold_max=max(a_lower, a_upper),
            )

        # -- Secondary extreme scan --
        for i in range(a_idx - 1, b_idx, -1):
            if x_is_low:
                cand_price = self._high(i)
                is_more = cand_price > a_price
            else:
                cand_price = self._low(i)
                is_more = cand_price < a_price

            if is_more:
                a_idx = i
                a_price = cand_price
                wave.a_idx = a_idx
                wave.a_price = a_price
                wave.x_less_than_a = x_price < a_price

                new_retrace = (b_price - x_price) / (a_price - x_price) * 100
                if new_retrace < cfg.x_to_a_b_min or new_retrace > cfg.x_to_a_b_max:
                    if attempt:
                        attempt.reject(
                            "A_SECONDARY",
                            f"Secondary A retrace={new_retrace:.2f}% outside range after scan",
                            value=new_retrace,
                        )
                    return None, attempt

        if attempt:
            attempt.add_step(
                "A_SECONDARY", True,
                f"Secondary A scan complete → A at bar {wave.a_idx} price={wave.a_price:.5f}",
            )

        # -- Validate XB segment --
        if not V.validate_xb_segment(
            x_idx, b_idx, x_price, xb_slope, x_is_low,
            self._low if x_is_low else self._high, diag,
        ):
            if attempt:
                first_fail = next((r for r in diag.failures), None)
                detail = first_fail.details if first_fail else "XB segment check failed"
                attempt.reject("XB_SEGMENT", f"XB strict check failed: {detail}")
            return None, attempt

        if attempt:
            attempt.add_step("XB_SEGMENT", True, f"All XB segment bars pass strict slope check")

        # -- X→B span containment --
        if not V.validate_span_containment(
            x_idx, x_price, b_idx, b_price,
            not wave.x_less_than_a,
            cfg.slope_buffer_pct, self._high, self._low, diag,
            rule_id="1.13/2.13", span_label="X→B",
        ):
            if attempt:
                first_fail = next((r for r in diag.failures), None)
                detail = first_fail.details if first_fail else "span containment failed"
                attempt.reject("XB_SPAN", f"X→B span containment failed: {detail}")
            return None, attempt

        if attempt:
            attempt.add_step("XB_SPAN", True, "X→B span containment passed")

        # -- P point --
        bars_p_x = int(cfg.px_length_percentage * 0.01 * bars_x_b)
        if self._total_bars - x_idx < bars_p_x:
            if attempt:
                attempt.reject(
                    "P_POINT",
                    f"Not enough bars before X for P (need {bars_p_x}, have {self._total_bars - x_idx})",
                )
            return None, attempt

        wave.p_idx = x_idx + bars_p_x
        wave.p_price = x_price - bars_p_x * xb_slope

        if not V.validate_px_segment(
            wave.p_idx, x_idx, wave.p_price, xb_slope, x_is_low,
            self._low if x_is_low else self._high, diag,
        ):
            if attempt:
                first_fail = next((r for r in diag.failures if r.segment == "P→X"), None)
                detail = first_fail.details if first_fail else "PX segment failed"
                attempt.reject("PX_SEGMENT", f"P→X segment check failed: {detail}")
            return None, attempt

        if attempt:
            attempt.add_step(
                "PX_SEGMENT", True,
                f"P at bar {wave.p_idx} price={wave.p_price:.5f}, all PX bars pass",
            )

        a_slope = get_a_channel_slope(xb_slope, channel_type)

        # -- XAB pattern --
        if cfg.pattern_type == PatternType.XAB:
            wave.is_bullish = wave.b_price < wave.a_price
            result = self._finalize(wave, PatternType.XAB, channel_type, cfg, diag, last_drawn_idx, attempt)
            return result, attempt

        # -- C, D, E, F cascading search --
        c_is_low = b_price > a_price
        c_cands = C.get_c_candidates(
            wave, bars_x_b, xb_slope, a_slope, c_is_low,
            cfg, self._high, self._low, diag,
        )
        if not c_cands:
            if attempt:
                attempt.reject("C_SEARCH", "No valid C candidates found")
            return None, attempt

        if attempt:
            attempt.add_step("C_SEARCH", True, f"Found {len(c_cands)} C candidates")

        for c_idx_val, c_price_val in c_cands:
            wave.c_idx = c_idx_val
            wave.c_price = c_price_val

            if cfg.pattern_type == PatternType.XABC:
                wave.is_bullish = c_price_val < b_price
                result = self._finalize(wave, PatternType.XABC, channel_type, cfg, diag, last_drawn_idx, attempt)
                if result is not None:
                    return result, attempt
                continue

            d_is_low = c_price_val > b_price
            d_cands = C.get_d_candidates(
                wave, bars_x_b, xb_slope, d_is_low,
                cfg, self._high, self._low, diag,
            )
            if not d_cands:
                continue

            for d_idx_val, d_price_val in d_cands:
                wave.d_idx = d_idx_val
                wave.d_price = d_price_val

                if cfg.pattern_type == PatternType.XABCD:
                    wave.is_bullish = d_price_val < c_price_val
                    result = self._finalize(wave, PatternType.XABCD, channel_type, cfg, diag, last_drawn_idx, attempt)
                    if result is not None:
                        if attempt:
                            attempt.add_step(
                                "POINTS",  True,
                                f"C=bar{c_idx_val}({c_price_val:.5f}) D=bar{d_idx_val}({d_price_val:.5f})",
                            )
                        return result, attempt
                    continue

                e_is_low = d_price_val > c_price_val
                e_cands = C.get_e_candidates(
                    wave, bars_x_b, a_slope, e_is_low,
                    cfg, self._high, self._low, diag,
                )
                if not e_cands:
                    continue

                for e_idx_val, e_price_val in e_cands:
                    wave.e_idx = e_idx_val
                    wave.e_price = e_price_val

                    if cfg.pattern_type == PatternType.XABCDE:
                        wave.is_bullish = e_price_val < d_price_val
                        result = self._finalize(wave, PatternType.XABCDE, channel_type, cfg, diag, last_drawn_idx, attempt)
                        if result is not None:
                            return result, attempt
                        continue

                    f_is_low = e_price_val > d_price_val
                    f_cands = C.get_f_candidates(
                        wave, bars_x_b, xb_slope, f_is_low,
                        cfg, self._high, self._low, diag,
                    )
                    if not f_cands:
                        continue

                    for f_idx_val, f_price_val in f_cands:
                        wave.f_idx = f_idx_val
                        wave.f_price = f_price_val
                        wave.is_bullish = f_price_val < e_price_val
                        result = self._finalize(wave, PatternType.XABCDEF, channel_type, cfg, diag, last_drawn_idx, attempt)
                        if result is not None:
                            return result, attempt

        # If we exhausted all candidates without success, note it
        if attempt and not attempt.succeeded:
            if not attempt.rejected_at:
                attempt.reject(
                    "CASCADE",
                    f"All C/D/E/F candidate combinations tried — no valid pattern found",
                )

        return None, attempt

    # ===================================================================
    # Finalize
    # ===================================================================

    def _finalize(
        self,
        wave: Wave,
        ptype: PatternType,
        channel_type: ChannelType,
        cfg: DetectorConfig,
        diag: DiagnosticLog,
        last_drawn_idx: int,
        attempt: Optional[XAttemptLog] = None,
    ) -> Optional[PatternResult]:
        """Apply post-detection filters and build the result object."""
        last_idx, _ = wave.last_point(ptype)

        # Tick speed filter
        if not tick_speed_filter(wave.x_idx, last_idx, cfg.tick_min_speed, self._time):
            if attempt:
                attempt.reject("TICK_SPEED", "Tick speed filter rejected pattern")
            return None

        # Divergence filter
        direction = 1 if wave.is_bullish else -1
        div_points = {
            PatternType.XAB: (wave.x_idx, wave.a_idx, wave.b_idx),
            PatternType.XABC: (wave.a_idx, wave.b_idx, wave.c_idx),
            PatternType.XABCD: (wave.b_idx, wave.c_idx, wave.d_idx),
            PatternType.XABCDE: (wave.c_idx, wave.d_idx, wave.e_idx),
            PatternType.XABCDEF: (wave.d_idx, wave.e_idx, wave.f_idx),
        }
        idx1, idx2, idx3 = div_points[ptype]
        if not divergence_filter(
            idx1, idx2, idx3, direction, cfg.divergence_type,
            self._high, self._low, self._volume, self._time,
        ):
            if attempt:
                attempt.reject("DIVERGENCE", f"Divergence filter ({cfg.divergence_type.value}) rejected pattern")
            return None

        # Pattern direction filter
        if cfg.pattern_direction == PatternDirection.BULLISH and not wave.is_bullish:
            if attempt:
                attempt.reject("DIRECTION", "Pattern is bearish but filter requires bullish")
            return None
        if cfg.pattern_direction == PatternDirection.BEARISH and wave.is_bullish:
            if attempt:
                attempt.reject("DIRECTION", "Pattern is bullish but filter requires bearish")
            return None

        # Overlap filter
        if cfg.only_draw_most_recent and cfg.min_bars_between_patterns > 0:
            if last_drawn_idx != -9999 and (last_drawn_idx - last_idx) < cfg.min_bars_between_patterns:
                if attempt:
                    attempt.reject(
                        "OVERLAP",
                        f"Too close to previous pattern (gap={last_drawn_idx - last_idx} < min={cfg.min_bars_between_patterns})",
                    )
                return None

        # Success
        direction_str = "BULLISH" if wave.is_bullish else "BEARISH"
        if attempt:
            attempt.succeed(
                f"{ptype.name} {direction_str} pattern confirmed via {channel_type.value} channel"
            )

        return PatternResult(
            wave=copy.deepcopy(wave),
            pattern_type=ptype,
            channel_type=channel_type,
            is_bullish=wave.is_bullish,
            diagnostics=diag.snapshot(),
        )
