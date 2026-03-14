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

import numpy as np

from .types import (
    ChannelType, PatternDirection, PatternResult, PatternType, Wave,
    XAttemptLog,
)
from .config import DetectorConfig
from .diagnostics import DiagnosticLog, NULL_DIAG
from .channels import get_a_channel_slope
from . import validators as V
from . import candidates as C
from .filters import tick_speed_filter, divergence_filter

PriceFn = Callable[[int], float]


def _snapshot_wave(wave: Wave) -> dict:
    """Capture current wave state as a plain dict for partial-pattern rendering."""
    d: dict = {}
    for label in ('p', 'x', 'a', 'b', 'c', 'd', 'e', 'f'):
        idx = getattr(wave, f'{label}_idx', 0)
        price = getattr(wave, f'{label}_price', 0.0)
        if idx > 0 or (label == 'x' and price != 0.0):
            d[f'{label}_idx'] = idx
            d[f'{label}_price'] = price
    d['x_less_than_a'] = wave.x_less_than_a
    d['is_bullish'] = wave.is_bullish
    return d


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

        # Precompute local extrema arrays (numpy) — avoids per-bar Python loops
        n = len(candles)
        if n >= 3:
            lo, hi = candles.low, candles.high
            self._low_extrema = np.empty(n, dtype=bool)
            self._low_extrema[0] = self._low_extrema[-1] = False
            self._low_extrema[1:-1] = (lo[1:-1] <= lo[:-2]) & (lo[1:-1] <= lo[2:])

            self._high_extrema = np.empty(n, dtype=bool)
            self._high_extrema[0] = self._high_extrema[-1] = False
            self._high_extrema[1:-1] = (hi[1:-1] >= hi[:-2]) & (hi[1:-1] >= hi[2:])
        else:
            self._low_extrema = np.zeros(n, dtype=bool)
            self._high_extrema = np.zeros(n, dtype=bool)

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
    ) -> List[PatternResult] | Tuple[List[PatternResult], Dict[int, List[XAttemptLog]], list]:
        """Find all patterns matching *cfg* in the loaded candle data.

        Args:
            cfg: Detection configuration.
            collect_traces: When True, also returns a dict mapping each
                x_idx to the list of ``XAttemptLog`` entries produced,
                plus a flat sequential detection log.
                Return type becomes ``(results, traces, detection_log)``.

        Returns:
            List of ``PatternResult`` objects, OR a
            ``(results, traces, detection_log)`` tuple when
            ``collect_traces=True``.
        """
        search_start = self._total_bars
        if cfg.max_search_bars > 0 and cfg.max_search_bars < self._total_bars:
            search_start = cfg.max_search_bars

        results: List[PatternResult] = []
        traces: Dict[int, List[XAttemptLog]] = {} if collect_traces else None  # type: ignore
        detection_log: list = [] if collect_traces else None  # type: ignore

        for active_ct in cfg.channel_types_to_run():
            if collect_traces:
                detection_log.append({
                    'type': 'channel',
                    'channel': active_ct.value,
                })

            last_drawn_idx = -9999

            for x_idx in range(search_start, cfg.b_max + 10, -1):
                # Try X as LOW
                pat, attempts = self._try_from_x(
                    x_idx, True, active_ct, cfg, last_drawn_idx, collect_traces
                )
                if collect_traces and attempts:
                    traces.setdefault(x_idx, []).extend(attempts)
                    self._log_attempts(detection_log, attempts, active_ct.value)
                if pat is not None:
                    results.append(pat)
                    last_drawn_idx = pat.wave.last_point(pat.pattern_type)[0]

                # Try X as HIGH
                pat, attempts = self._try_from_x(
                    x_idx, False, active_ct, cfg, last_drawn_idx, collect_traces
                )
                if collect_traces and attempts:
                    traces.setdefault(x_idx, []).extend(attempts)
                    self._log_attempts(detection_log, attempts, active_ct.value)
                if pat is not None:
                    results.append(pat)
                    last_drawn_idx = pat.wave.last_point(pat.pattern_type)[0]

        if collect_traces:
            return results, traces, detection_log
        return results

    def find_all_progressive(
        self,
        cfg: DetectorConfig,
        chunk_size: int = 500,
    ):
        """Generator: yield detection results in chunks for progressive loading.

        Always collects traces (``collect_traces=True``) so that every chunk
        carries full per-candle diagnostic data for the narrative summary.

        Yields ``dict`` with keys:
          - ``patterns``: ``List[PatternResult]``
          - ``traces``: ``Dict[int, List[XAttemptLog]]``
          - ``detection_log``: ``list``
          - ``bars_scanned``: ``int`` (cumulative X positions processed)
          - ``total_bars``: ``int`` (total X positions to process)
          - ``done``: ``bool``
        """
        search_start = self._total_bars
        if cfg.max_search_bars > 0 and cfg.max_search_bars < self._total_bars:
            search_start = cfg.max_search_bars

        end_idx = cfg.b_max + 10
        channel_types = cfg.channel_types_to_run()
        scan_range = max(search_start - end_idx, 0)
        total_to_scan = scan_range * len(channel_types)

        chunk_patterns: List[PatternResult] = []
        chunk_traces: Dict[int, List[XAttemptLog]] = {}
        chunk_log: list = []
        bars_in_chunk = 0
        total_scanned = 0

        for active_ct in channel_types:
            chunk_log.append({
                'type': 'channel',
                'channel': active_ct.value,
            })

            last_drawn_idx = -9999

            for x_idx in range(search_start, end_idx, -1):
                # Try X as LOW
                pat, attempts = self._try_from_x(
                    x_idx, True, active_ct, cfg, last_drawn_idx, True,
                )
                if attempts:
                    chunk_traces.setdefault(x_idx, []).extend(attempts)
                    self._log_attempts(chunk_log, attempts, active_ct.value)
                if pat is not None:
                    chunk_patterns.append(pat)
                    last_drawn_idx = pat.wave.last_point(pat.pattern_type)[0]

                # Try X as HIGH
                pat, attempts = self._try_from_x(
                    x_idx, False, active_ct, cfg, last_drawn_idx, True,
                )
                if attempts:
                    chunk_traces.setdefault(x_idx, []).extend(attempts)
                    self._log_attempts(chunk_log, attempts, active_ct.value)
                if pat is not None:
                    chunk_patterns.append(pat)
                    last_drawn_idx = pat.wave.last_point(pat.pattern_type)[0]

                bars_in_chunk += 1
                total_scanned += 1

                if bars_in_chunk >= chunk_size:
                    yield {
                        'patterns': chunk_patterns,
                        'traces': chunk_traces,
                        'detection_log': chunk_log,
                        'bars_scanned': total_scanned,
                        'total_bars': total_to_scan,
                        'done': False,
                    }
                    chunk_patterns = []
                    chunk_traces = {}
                    chunk_log = []
                    bars_in_chunk = 0

        # Final yield (always emitted, signals completion)
        yield {
            'patterns': chunk_patterns,
            'traces': chunk_traces,
            'detection_log': chunk_log,
            'bars_scanned': total_scanned,
            'total_bars': total_to_scan,
            'done': True,
        }

    @staticmethod
    def _log_attempts(log: list, attempts: list, channel: str) -> None:
        """Append attempt entries to the flat detection log."""
        for a in attempts:
            log.append({
                'type': 'attempt',
                'channel': channel,
                'x_idx': a.x_idx,
                'x_is_low': a.x_is_low,
                'b_idx': a.b_idx,
                'b_price': a.b_price,
                'succeeded': a.succeeded,
                'rejected_at': a.rejected_at,
                'step_reached': a.step_reached,
                'steps': [{
                    'step': s.step, 'passed': s.passed,
                    'detail': s.detail, 'value': s.value,
                    'threshold_min': s.threshold_min,
                    'threshold_max': s.threshold_max,
                } for s in a.steps],
            })

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
    ) -> Tuple[Optional[PatternResult], list]:
        """Try to build a pattern starting from X at *x_idx*.

        Returns ``(PatternResult | None, list_of_XAttemptLog)``.
        The list is populated only when collect_traces=True; otherwise
        it is empty.
        """
        x_price = self._low(x_idx) if x_is_low else self._high(x_idx)
        if x_price == 0:
            return None, []

        # -- B candidate search --
        b_cands = self._collect_b_candidates(x_idx, x_price, x_is_low, cfg)

        if collect_traces and not b_cands:
            # Record the "no B found" attempt
            attempt = XAttemptLog(x_idx=x_idx, x_is_low=x_is_low)
            attempt.reject(
                "B_SEARCH",
                f"No B candidates found in range [{x_idx - cfg.b_max}, {x_idx - cfg.b_min - 1}]",
            )
            # Minimal partial_wave with just X point
            attempt.partial_wave = {
                'x_idx': x_idx, 'x_price': x_price,
                'x_less_than_a': False, 'is_bullish': False,
            }
            return None, [attempt]

        if not b_cands:
            return None, []

        # Try each B candidate — collect ALL attempts for tracing
        all_attempts: list = []
        for b_idx, b_price in b_cands:
            bars_x_b = x_idx - b_idx
            if bars_x_b <= 0:
                continue
            result, attempt = self._try_with_b(
                x_idx, x_price, x_is_low, b_idx, b_price, bars_x_b,
                channel_type, cfg, last_drawn_idx, collect_traces,
            )
            if collect_traces and attempt:
                all_attempts.append(attempt)
            if result is not None:
                return result, all_attempts

        return None, all_attempts

    def _collect_b_candidates(
        self,
        x_idx: int,
        x_price: float,
        x_is_low: bool,
        cfg: DetectorConfig,
    ) -> List[tuple]:
        """Collect and sort B candidates using precomputed numpy extrema."""
        b_start = x_idx - 1 - cfg.b_min
        b_end = max(x_idx - cfg.b_max, 1)

        if b_start <= b_end or b_start <= 0:
            return []

        b_start = min(b_start, self._total_bars)

        extrema = self._low_extrema if x_is_low else self._high_extrema
        prices = self._candles.low if x_is_low else self._candles.high

        # Numpy slice + nonzero — replaces per-bar Python loop
        mask = extrema[b_end:b_start + 1]
        if not mask.any():
            return []

        local_idx = np.nonzero(mask)[0]
        abs_idx = local_idx + b_end
        cand_prices = prices[abs_idx]

        # Sort: ascending for lows, descending for highs
        order = np.argsort(cand_prices) if x_is_low else np.argsort(-cand_prices)
        return [(int(abs_idx[i]), float(cand_prices[i])) for i in order]

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
        # Use NULL_DIAG when not tracing — eliminates millions of DiagnosticRecord allocations
        diag = DiagnosticLog() if collect_traces else NULL_DIAG
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

        # -- Find A (max deviation from XB slope) — VECTORISED with numpy --
        a_bar_range = np.arange(b_idx + 1, x_idx)
        if len(a_bar_range) == 0:
            if attempt:
                attempt.reject("A_FIND", "No bars between X and B for A search")
                attempt.partial_wave = _snapshot_wave(wave)
            return None, attempt

        a_offsets = x_idx - a_bar_range
        xb_vals = x_price + a_offsets * xb_slope

        if x_is_low:
            a_prices = self._candles.high[a_bar_range]
            devs = a_prices - xb_vals
        else:
            a_prices = self._candles.low[a_bar_range]
            devs = xb_vals - a_prices

        best_pos = int(np.argmax(devs))
        max_dev = float(devs[best_pos])
        a_idx = int(a_bar_range[best_pos])
        a_price = float(a_prices[best_pos])

        if a_idx == -1 or max_dev <= 0:
            if attempt:
                attempt.reject(
                    "A_FIND",
                    f"No valid A point (max_dev={max_dev:.5f} ≤ 0 or no candidate)",
                    value=max_dev,
                )
                attempt.partial_wave = _snapshot_wave(wave)
            return None, attempt

        if a_idx >= x_idx or a_idx <= b_idx:
            if attempt:
                attempt.reject(
                    "A_FIND",
                    f"A at bar {a_idx} outside X({x_idx})..B({b_idx}) range",
                    value=float(a_idx),
                )
                attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
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
        z = x_price + a_offset * xb_slope
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
                attempt.partial_wave = _snapshot_wave(wave)
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
                        attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
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
            attempt.partial_wave = _snapshot_wave(wave)

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
                attempt.partial_wave = _snapshot_wave(wave)
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
                attempt.partial_wave = _snapshot_wave(wave)
            return None

        # Pattern direction filter
        if cfg.pattern_direction == PatternDirection.BULLISH and not wave.is_bullish:
            if attempt:
                attempt.reject("DIRECTION", "Pattern is bearish but filter requires bullish")
                attempt.partial_wave = _snapshot_wave(wave)
            return None
        if cfg.pattern_direction == PatternDirection.BEARISH and wave.is_bullish:
            if attempt:
                attempt.reject("DIRECTION", "Pattern is bullish but filter requires bearish")
                attempt.partial_wave = _snapshot_wave(wave)
            return None

        # Overlap filter
        if cfg.only_draw_most_recent and cfg.min_bars_between_patterns > 0:
            if last_drawn_idx != -9999 and (last_drawn_idx - last_idx) < cfg.min_bars_between_patterns:
                if attempt:
                    attempt.reject(
                        "OVERLAP",
                        f"Too close to previous pattern (gap={last_drawn_idx - last_idx} < min={cfg.min_bars_between_patterns})",
                    )
                    attempt.partial_wave = _snapshot_wave(wave)
                return None

        # Success
        direction_str = "BULLISH" if wave.is_bullish else "BEARISH"
        if attempt:
            attempt.succeed(
                f"{ptype.name} {direction_str} pattern confirmed via {channel_type.value} channel"
            )
            attempt.partial_wave = _snapshot_wave(wave)

        return PatternResult(
            wave=copy.deepcopy(wave),
            pattern_type=ptype,
            channel_type=channel_type,
            is_bullish=wave.is_bullish,
            diagnostics=diag.snapshot(),
        )
