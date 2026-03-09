"""Channel computation — XB-channel and A-channel geometry.

The dual-channel system constrains where CDEF points can appear:
  - XB-channel: defined by X→B slope, hosts D and F points
  - A-channel:  slope determined by channel_type, hosts C and E points

Width parameters swap for X>A so that user-facing "upper" / "lower"
semantics remain consistent regardless of pattern orientation.
"""

from __future__ import annotations

from .types import ChannelType


def get_a_channel_slope(xb_slope: float, channel_type: ChannelType) -> float:
    """Compute the A-channel slope from the XB slope and channel mode.

    Args:
        xb_slope: The slope of the X→B line (price per bar).
        channel_type: One of Parallel, Straight, Non_Parallel.

    Returns:
        The A-channel slope in price-per-bar units.
    """
    if channel_type == ChannelType.PARALLEL:
        return xb_slope
    if channel_type == ChannelType.STRAIGHT:
        return 0.0
    if channel_type == ChannelType.NON_PARALLEL:
        return -xb_slope
    # Fallback (should never hit — ALL_TYPES is expanded before calling)
    return xb_slope


def is_in_channel(
    price: float,
    center: float,
    upper_pct: float,
    lower_pct: float,
) -> bool:
    """Check whether *price* falls within a channel band.

    Band boundaries::

        upper = center + |center| * upper_pct / 100
        lower = center - |center| * lower_pct / 100

    Matches MQL5 ``is_in_channel`` exactly.
    """
    abs_center = abs(center)
    upper = center + abs_center * upper_pct * 0.01
    lower = center - abs_center * lower_pct * 0.01
    return lower <= price <= upper


def channel_widths_for_xb(
    x_less_than_a: bool,
    xb_upper_width_pct: float,
    xb_lower_width_pct: float,
) -> tuple[float, float]:
    """Return ``(effective_upper_pct, effective_lower_pct)`` for XB-channel.

    When X>A the input semantics swap so the user always thinks
    "upper = away from price action, lower = toward price action".
    """
    if x_less_than_a:
        return xb_upper_width_pct, xb_lower_width_pct
    return xb_lower_width_pct, xb_upper_width_pct


def channel_widths_for_a(
    x_less_than_a: bool,
    a_upper_width_pct: float,
    a_lower_width_pct: float,
) -> tuple[float, float]:
    """Return ``(effective_upper_pct, effective_lower_pct)`` for A-channel."""
    if x_less_than_a:
        return a_upper_width_pct, a_lower_width_pct
    return a_lower_width_pct, a_upper_width_pct


def compute_channel_center_xb(
    x_price: float,
    x_idx: int,
    xb_slope: float,
    bar_idx: int,
) -> float:
    """XB-channel center value at a given bar."""
    return x_price + (x_idx - bar_idx) * xb_slope


def compute_channel_center_a(
    a_price: float,
    a_idx: int,
    a_slope: float,
    bar_idx: int,
) -> float:
    """A-channel center value at a given bar."""
    return a_price + (a_idx - bar_idx) * a_slope
