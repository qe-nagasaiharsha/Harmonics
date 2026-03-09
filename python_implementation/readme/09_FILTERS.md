# Post-Detection Filters (`core/filters.py`)

## Overview

After all geometric validation passes, two optional filters can reject
patterns before finalization. Most configurations leave them disabled.

These filters are applied in `PatternDetector._finalize()`.

---

## Tick Speed Filter

**Purpose**: Reject patterns where price action is too slow (low liquidity).

**Calculation**:
```
seconds = time(last_point) - time(x_point)
bars = x_idx - last_idx
seconds_per_bar = seconds / bars

Pass if: seconds_per_bar < tick_min_speed
```

**Default**: `tick_min_speed = 500,000` (approx 5.8 days per bar).
With the default value, this filter is effectively disabled — only
extremely slow patterns on very high timeframes would be rejected.

**Config**: `cfg.tick_min_speed`

---

## Divergence Filter

**Purpose**: Detect divergence between price movement and time/volume.
Passes when the second leg shows divergence from the first leg.

**Three-Point Comparison**:
The filter compares the last three relevant points, which vary by pattern:

| Pattern  | Points Compared |
|----------|----------------|
| XAB      | X, A, B        |
| XABC     | A, B, C        |
| XABCD    | B, C, D        |
| XABCDE   | C, D, E        |
| XABCDEF  | D, E, F        |

**Leg Calculations**:
```
leg1_up = HIGH(idx1) - LOW(idx2)      # First leg upward range
leg2_up = HIGH(idx3) - LOW(idx2)      # Second leg upward range
leg1_down = HIGH(idx2) - LOW(idx1)    # First leg downward range
leg2_down = HIGH(idx2) - LOW(idx3)    # Second leg downward range

second_bigger = (bullish) ? leg2_up > leg1_up : leg2_down > leg1_down
```

### Divergence Types

#### Time Divergence (`DivergenceType.TIME`)
Compares seconds-per-bar between legs:
```
spb1 = seconds1 / bars1
spb2 = seconds2 / bars2

Pass if: (second_bigger AND spb2 < spb1) OR (!second_bigger AND spb2 > spb1)
```
Divergence = bigger leg moved faster, or smaller leg moved slower.

#### Volume Divergence (`DivergenceType.VOLUME`)
Compares total volume between legs:
```
vol1 = sum(volume[idx1..idx2])
vol2 = sum(volume[idx2..idx3])

Pass if: (second_bigger AND vol2 < vol1) OR (!second_bigger AND vol2 > vol1)
```
Divergence = bigger leg had less volume, or smaller leg had more volume.

#### Time+Volume Divergence (`DivergenceType.TIME_VOLUME`)
Compares volume-per-bar between legs:
```
vpb1 = vol1 / bars1
vpb2 = vol2 / bars2

Pass if: (second_bigger AND vpb2 < vpb1) OR (!second_bigger AND vpb2 > vpb1)
```

#### None (`DivergenceType.NONE`)
Always passes. This is the default — no divergence filtering.

**Config**: `cfg.divergence_type`
