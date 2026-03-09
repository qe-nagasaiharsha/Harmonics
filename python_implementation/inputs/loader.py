"""Load DetectorConfig from the inputs Excel file.

Reads the config.xlsx file (column A = parameter name, column C = value)
and constructs a fully populated DetectorConfig instance plus the data
file path.
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional, Tuple

import openpyxl

from python_implementation.core.config import DetectorConfig
from python_implementation.core.types import (
    ChannelType, DivergenceType, PatternDirection, PatternType,
)


# ---------------------------------------------------------------------------
# Enum mappers (display string -> enum value)
# ---------------------------------------------------------------------------

_PATTERN_TYPE_MAP = {
    "XAB": PatternType.XAB,
    "XABC": PatternType.XABC,
    "XABCD": PatternType.XABCD,
    "XABCDE": PatternType.XABCDE,
    "XABCDEF": PatternType.XABCDEF,
}

_PATTERN_DIR_MAP = {
    "bullish": PatternDirection.BULLISH,
    "bearish": PatternDirection.BEARISH,
    "both": PatternDirection.BOTH,
}

_CHANNEL_TYPE_MAP = {
    "parallel": ChannelType.PARALLEL,
    "straight": ChannelType.STRAIGHT,
    "non_parallel": ChannelType.NON_PARALLEL,
    "all_types": ChannelType.ALL_TYPES,
}

_DIVERGENCE_MAP = {
    "none": DivergenceType.NONE,
    "time": DivergenceType.TIME,
    "volume": DivergenceType.VOLUME,
    "time_volume": DivergenceType.TIME_VOLUME,
}

_BOOL_MAP = {
    "true": True, "1": True, "yes": True,
    "false": False, "0": False, "no": False,
}


def _parse_bool(val) -> bool:
    """Convert various truthy/falsy representations to bool."""
    if isinstance(val, bool):
        return val
    return _BOOL_MAP.get(str(val).strip().lower(), False)


def load_config(
    path: str | Path | None = None,
) -> Tuple[DetectorConfig, str]:
    """Read the inputs Excel file and return (config, data_file_path).

    Args:
        path: Path to the config.xlsx file. If None, uses the default
              location at ``inputs/config.xlsx``.

    Returns:
        A tuple of ``(DetectorConfig, data_file_path)``.
        ``data_file_path`` is the string from the "data_file_path" row,
        which may be empty if the user hasn't set it.

    Raises:
        FileNotFoundError: If the config file doesn't exist.
        ValueError: If a required enum value is invalid.
    """
    if path is None:
        path = Path(__file__).parent / "config.xlsx"
    path = Path(path)

    if not path.exists():
        raise FileNotFoundError(
            f"Config file not found: {path}\n"
            f"Run: python -m python_implementation.inputs.create_template"
        )

    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb["Inputs"]

    # Read all parameter -> value pairs (column A = param, column C = value)
    params: dict[str, object] = {}
    for row in ws.iter_rows(min_row=2, max_col=5, values_only=False):
        param_cell = row[0]  # Column A
        value_cell = row[2]  # Column C

        param_name = param_cell.value
        if param_name is None or str(param_name).startswith("__"):
            continue

        # Skip group header rows (merged cells have no param name)
        param_name = str(param_name).strip()
        if not param_name:
            continue

        params[param_name] = value_cell.value

    wb.close()

    # Extract data file path
    data_file_path = str(params.pop("data_file_path", "") or "")

    # Build DetectorConfig by mapping each parameter
    cfg_kwargs = {}

    # Pattern type
    if "pattern_type" in params and params["pattern_type"]:
        val = str(params["pattern_type"]).strip().upper()
        if val in _PATTERN_TYPE_MAP:
            cfg_kwargs["pattern_type"] = _PATTERN_TYPE_MAP[val]

    # Pattern direction
    if "pattern_direction" in params and params["pattern_direction"]:
        val = str(params["pattern_direction"]).strip().lower()
        if val in _PATTERN_DIR_MAP:
            cfg_kwargs["pattern_direction"] = _PATTERN_DIR_MAP[val]

    # Channel type
    if "channel_type" in params and params["channel_type"]:
        val = str(params["channel_type"]).strip().lower()
        if val in _CHANNEL_TYPE_MAP:
            cfg_kwargs["channel_type"] = _CHANNEL_TYPE_MAP[val]

    # Divergence type
    if "divergence_type" in params and params["divergence_type"]:
        val = str(params["divergence_type"]).strip().lower()
        if val in _DIVERGENCE_MAP:
            cfg_kwargs["divergence_type"] = _DIVERGENCE_MAP[val]

    # Boolean fields
    for field_name in (
        "only_draw_most_recent", "extension_break_close",
        "enable_dynamic_last_point", "strict_xb_validation",
    ):
        if field_name in params and params[field_name] is not None:
            cfg_kwargs[field_name] = _parse_bool(params[field_name])

    # Integer fields
    for field_name in (
        "b_min", "b_max", "max_search_bars",
        "every_increasing_of_value", "min_bars_between_patterns",
        "channel_extension_bars", "fg_increasing_percentage",
        "mn_extension_bars", "max_dynamic_iterations", "tick_min_speed",
    ):
        if field_name in params and params[field_name] is not None:
            try:
                cfg_kwargs[field_name] = int(params[field_name])
            except (ValueError, TypeError):
                pass

    # Float fields
    for field_name in (
        "px_length_percentage",
        "min_b_to_c_btw_x_b", "max_b_to_c_btw_x_b",
        "min_c_to_d_btw_x_b", "max_c_to_d_btw_x_b",
        "min_d_to_e_btw_x_b", "max_d_to_e_btw_x_b",
        "min_e_to_f_btw_x_b", "max_e_to_f_btw_x_b",
        "max_width_percentage", "min_width_percentage",
        "x_to_a_b_max", "x_to_a_b_min",
        "width_increasing_percentage_x_to_b",
        "width_increasing_percentage_a_e",
        "slope_buffer_pct",
        "xb_upper_width_pct", "xb_lower_width_pct",
        "a_upper_width_pct", "a_lower_width_pct",
        "f_percentage", "first_line_percentage",
        "first_line_decrease_percentage",
        "max_below_max_above_diff_percentage",
        "mn_buffer_percent", "mn_length_percent",
    ):
        if field_name in params and params[field_name] is not None:
            try:
                cfg_kwargs[field_name] = float(params[field_name])
            except (ValueError, TypeError):
                pass

    return DetectorConfig(**cfg_kwargs), data_file_path


def print_config(cfg: DetectorConfig, data_path: str) -> None:
    """Print the loaded configuration for verification."""
    print("=" * 60)
    print("  PXABCDEF Configuration (from Excel)")
    print("=" * 60)
    print(f"  Data File:          {data_path or '(not set)'}")
    print(f"  Pattern Type:       {cfg.pattern_type.name}")
    print(f"  Pattern Direction:  {cfg.pattern_direction.value}")
    print(f"  Channel Type:       {cfg.channel_type.value}")
    print(f"  B Range:            [{cfg.b_min}, {cfg.b_max}]")
    print(f"  Max Search Bars:    {cfg.max_search_bars or 'all'}")
    print(f"  Slope Buffer %:     {cfg.slope_buffer_pct}")
    print(f"  XB Width:           upper={cfg.xb_upper_width_pct}%, lower={cfg.xb_lower_width_pct}%")
    print(f"  A Width:            upper={cfg.a_upper_width_pct}%, lower={cfg.a_lower_width_pct}%")
    print(f"  Dynamic Tracking:   {'ON' if cfg.enable_dynamic_last_point else 'OFF'} (max {cfg.max_dynamic_iterations})")
    print(f"  Divergence:         {cfg.divergence_type.value}")
    print(f"  MN Extension Bars:  {cfg.mn_extension_bars}")
    print("=" * 60)
