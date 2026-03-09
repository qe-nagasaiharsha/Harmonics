"""Post-detection filters: tick speed and divergence.

These are applied in ``finalize_pattern`` after all geometric
validation passes.  They are optional — most configurations
leave them disabled.
"""

from __future__ import annotations

from typing import Callable

from .types import DivergenceType

PriceFn = Callable[[int], float]


def tick_speed_filter(
    x_idx: int,
    last_idx: int,
    tick_min_speed: int,
    time_fn: PriceFn,
) -> bool:
    """Return True if the pattern passes the tick speed filter.

    The filter rejects patterns where the average seconds-per-bar
    exceeds ``tick_min_speed``.  If ``tick_min_speed`` is very large
    (default 500_000) this effectively disables the filter.
    """
    bars = x_idx - last_idx
    if bars <= 0:
        return True
    seconds = int(time_fn(last_idx) - time_fn(x_idx))
    if seconds / bars < tick_min_speed:
        return True
    return False


def divergence_filter(
    idx1: int,
    idx2: int,
    idx3: int,
    direction: int,
    divergence_type: DivergenceType,
    high_fn: PriceFn,
    low_fn: PriceFn,
    volume_fn: PriceFn,
    time_fn: PriceFn,
) -> bool:
    """Return True if the three-point divergence filter passes.

    Args:
        idx1, idx2, idx3: Bar indices of consecutive pattern points.
        direction: +1 for bullish, -1 for bearish.
        divergence_type: Which divergence to check.
    """
    if divergence_type == DivergenceType.NONE:
        return True

    h1, h2, h3 = high_fn(idx1), high_fn(idx2), high_fn(idx3)
    l1, l2, l3 = low_fn(idx1), low_fn(idx2), low_fn(idx3)

    leg1_up = h1 - l2
    leg2_up = h3 - l2
    leg1_down = h2 - l1
    leg2_down = h2 - l3

    second_bigger = (
        (leg2_up > leg1_up) if direction == 1 else (leg2_down > leg1_down)
    )

    # Time values (idx decreases toward present in MT5 convention)
    sec1 = int(time_fn(idx2) - time_fn(idx1))
    sec2 = int(time_fn(idx3) - time_fn(idx2))
    bars1 = idx1 - idx2
    bars2 = idx2 - idx3

    if bars1 == 0 or bars2 == 0:
        return False

    # Volume sums
    vol1 = sum(volume_fn(i) for i in range(idx1, idx2 - 1, -1))
    vol2 = sum(volume_fn(i) for i in range(idx2, idx3 - 1, -1))

    if divergence_type == DivergenceType.TIME:
        spb1, spb2 = sec1 / bars1, sec2 / bars2
        if (second_bigger and spb2 < spb1) or (not second_bigger and spb2 > spb1):
            return True

    elif divergence_type == DivergenceType.VOLUME:
        if (second_bigger and vol2 < vol1) or (not second_bigger and vol2 > vol1):
            return True

    elif divergence_type == DivergenceType.TIME_VOLUME:
        vpb1 = vol1 / bars1 if bars1 else 0
        vpb2 = vol2 / bars2 if bars2 else 0
        if (second_bigger and vpb2 < vpb1) or (not second_bigger and vpb2 > vpb1):
            return True

    return False
