"""Detector configuration — mirrors every MQL5 input parameter.

A single ``DetectorConfig`` instance drives the entire engine.  Field names
follow the MQL5 naming convention so that ``.set`` files can be loaded
directly with trivial key-mapping.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .types import ChannelType, DivergenceType, PatternDirection, PatternType


@dataclass
class DetectorConfig:
    """All tunable knobs for the PXABCDEF detection engine."""

    # ----- Pattern type -----
    pattern_type: PatternType = PatternType.XABCD
    pattern_direction: PatternDirection = PatternDirection.BOTH

    # ----- Length properties -----
    b_min: int = 20
    b_max: int = 100
    max_search_bars: int = 0  # 0 = search all available history
    px_length_percentage: float = 10.0

    min_b_to_c_btw_x_b: float = 0.0
    max_b_to_c_btw_x_b: float = 100.0
    min_c_to_d_btw_x_b: float = 0.0
    max_c_to_d_btw_x_b: float = 100.0
    min_d_to_e_btw_x_b: float = 0.0
    max_d_to_e_btw_x_b: float = 100.0
    min_e_to_f_btw_x_b: float = 0.0
    max_e_to_f_btw_x_b: float = 100.0

    # ----- Retracement properties -----
    max_width_percentage: float = 100.0
    min_width_percentage: float = 0.0
    x_to_a_b_max: float = 100.0
    x_to_a_b_min: float = -100.0

    # ----- Dynamic height properties -----
    every_increasing_of_value: int = 5
    width_increasing_percentage_x_to_b: float = 0.0
    width_increasing_percentage_a_e: float = 0.0

    # ----- Validation -----
    strict_xb_validation: bool = False
    only_draw_most_recent: bool = True
    min_bars_between_patterns: int = 10
    slope_buffer_pct: float = 0.0

    # ----- Channel type -----
    channel_type: ChannelType = ChannelType.PARALLEL

    # ----- Channel width settings -----
    xb_upper_width_pct: float = 0.5
    xb_lower_width_pct: float = 0.5
    a_upper_width_pct: float = 0.5
    a_lower_width_pct: float = 0.5

    # ----- Channel extension -----
    channel_extension_bars: int = 200

    # ----- Golden line settings -----
    f_percentage: float = 50.0
    fg_increasing_percentage: int = 5
    first_line_percentage: float = 4.0
    first_line_decrease_percentage: float = 0.01
    max_below_max_above_diff_percentage: float = 40.0
    mn_buffer_percent: float = 0.0
    mn_length_percent: float = 0.0
    mn_extension_bars: int = 20
    extension_break_close: bool = False

    # ----- Dynamic last point (live trading) -----
    enable_dynamic_last_point: bool = True
    max_dynamic_iterations: int = 10

    # ----- Filters -----
    divergence_type: DivergenceType = DivergenceType.NONE
    tick_min_speed: int = 500_000

    # ----- Helpers -----

    def segment_range(self, ptype: PatternType) -> tuple[float, float]:
        """Return ``(min_pct, max_pct)`` for the segment ending at *ptype*."""
        mapping = {
            PatternType.XAB: (0.0, 100.0),
            PatternType.XABC: (self.min_b_to_c_btw_x_b, self.max_b_to_c_btw_x_b),
            PatternType.XABCD: (self.min_c_to_d_btw_x_b, self.max_c_to_d_btw_x_b),
            PatternType.XABCDE: (self.min_d_to_e_btw_x_b, self.max_d_to_e_btw_x_b),
            PatternType.XABCDEF: (self.min_e_to_f_btw_x_b, self.max_e_to_f_btw_x_b),
        }
        return mapping[ptype]

    def channel_types_to_run(self) -> list[ChannelType]:
        """Expand ``All_Types`` into the three concrete types."""
        if self.channel_type == ChannelType.ALL_TYPES:
            return [ChannelType.PARALLEL, ChannelType.STRAIGHT, ChannelType.NON_PARALLEL]
        return [self.channel_type]
