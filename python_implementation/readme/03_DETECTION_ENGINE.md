# Detection Engine

## Overview (`core/detector.py`)

The `PatternDetector` class orchestrates the entire detection cascade. It
mirrors the MQL5 flow: `find_all_patterns -> try_find_pattern_from_x ->
try_build_pattern_with_b` with full diagnostic logging.

```python
from python_implementation.core.detector import PatternDetector
from python_implementation.core.config import DetectorConfig
from python_implementation.data.loader import load_file

candles = load_file("USDJPY_M1.csv")
cfg = DetectorConfig(pattern_type=PatternType.XABCD)
detector = PatternDetector(candles)
results = detector.find_all(cfg)
```

## Detection Flow

### 1. Outer Loop (`find_all`)

```
For each channel_type in cfg.channel_types_to_run():
    For each x_idx from search_start down to (b_max + 10):
        Try X as LOW  -> _try_from_x(x_idx, x_is_low=True)
        Try X as HIGH -> _try_from_x(x_idx, x_is_low=False)
```

### 2. B Candidate Collection (`_collect_b_candidates`)

Scans `[x_idx - b_min, x_idx - b_max]` for local extrema:
- If X is LOW: finds local minima (LOW <= neighbors)
- If X is HIGH: finds local maxima (HIGH >= neighbors)

**Sorting**: `sort(key=price, reverse=not x_is_low)`
- X is LOW -> sort ascending (deepest lows first)
- X is HIGH -> sort descending (highest highs first)

### 3. Pattern Building (`_try_with_b`)

For each B candidate:

#### A Point Detection (Maximum Deviation)
1. Build XB slope array: `XBArray[i] = x_price + i * xb_slope`
2. Scan all bars between X and B for maximum deviation from XB line:
   - X<A (uptrend): `deviation = HIGH - XBArray[offset]` (peak above)
   - X>A (downtrend): `deviation = XBArray[offset] - LOW` (dip below)
3. Point with maximum deviation becomes A

#### A Validation
- **B retracement**: `(b_price - x_price) / (a_price - x_price) * 100`
  must be within `[x_to_a_b_min, x_to_a_b_max]`
- **A retracement from XB**: A price must be within dynamic percentage
  range from XB line at A's position
- **Dynamic height**: The range widens based on how far B is from X:
  ```
  dynamic_candles = (x_idx - 1 - b_min) - b_idx
  inc_val = (dynamic_candles // every_increasing_of_value + 1) * width_increasing_percentage_x_to_b
  ```

#### Secondary Extreme Scan
After finding A by maximum deviation from slope, scan from A toward B
for an even more extreme price:
- X<A: find any HIGH > a_price between A and B
- X>A: find any LOW < a_price between A and B

This is needed because maximum slope deviation doesn't always correspond
to the most extreme price (especially with steep slopes). If a more
extreme price is found, A is updated and B retracement is re-checked.

#### XB Validation
- `validate_xb_segment()` — strict, no buffer
- `validate_span_containment()` — X->B span (rule 1.13/2.13)

#### P Point
- Extends XB slope backward from X
- `p_idx = x_idx + int(px_length_percentage * 0.01 * bars_x_b)`
- `p_price = x_price - bars_p_x * xb_slope`
- Validated with `validate_px_segment()`

#### C/D/E/F Cascading Search
Nested iteration through candidates:
```
For each C candidate (most extreme first):
    For each D candidate (most extreme first):
        For each E candidate (most extreme first):
            For each F candidate (most extreme first):
                If finalize() succeeds -> return result
```

First valid pattern found at any depth returns immediately.

### 4. Finalization (`_finalize`)

Before accepting a pattern, applies filters:
1. **Tick speed filter** — rejects patterns that are too slow
2. **Divergence filter** — checks price/time/volume divergence
3. **Pattern direction filter** — bullish/bearish match
4. **Overlap filter** — minimum bar spacing between patterns

---

## Channel System (`core/channels.py`)

### Dual-Channel Architecture

The engine uses two channel systems simultaneously:

#### XB-Channel (Support/Resistance from X and B)
- **Slope**: `xb_slope = (b_price - x_price) / (x_idx - b_idx)`
- **Center at bar i**: `x_price + (x_idx - i) * xb_slope`
- **Hosts**: B, D, F points (XB-side points)

#### A-Channel (Retracement from A)
- **Slope**: Depends on `channel_type`:
  - Parallel: `a_slope = xb_slope`
  - Straight: `a_slope = 0.0`
  - Non-Parallel: `a_slope = -xb_slope`
- **Center at bar i**: `a_price + (a_idx - i) * a_slope`
- **Hosts**: C, E points (A-side points)

### Channel Width and Width Swapping

Channel boundaries:
```
upper = center + |center| * upper_pct / 100
lower = center - |center| * lower_pct / 100
```

When `x_less_than_a = False` (X > A), upper and lower widths SWAP:
```python
# XB channel
if x_less_than_a:
    effective_upper = xb_upper_width_pct
    effective_lower = xb_lower_width_pct
else:
    effective_upper = xb_lower_width_pct  # SWAPPED
    effective_lower = xb_upper_width_pct  # SWAPPED
```

This ensures the user-facing semantics remain consistent: "upper" always
means "away from price action" regardless of pattern orientation.

---

## Candidate Collection (`core/candidates.py`)

### Per-Point Candidate Pipeline

Each `get_X_candidates()` function follows the same 7-step pipeline:

1. **Range calculation**: Determine valid bar range from segment length percentages
2. **Channel membership**: Point must be within the appropriate channel
3. **Local extremum**: Point must be a local min or max compared to neighbors
4. **Re-validation fix**: Apply retrospective validation (see below)
5. **Segment validation**: All candles in the preceding segment must pass slope rules
6. **Span containment**: Same-side slope check with buffer
7. **Sort by extremeness**: Most pronounced swing first

### Channel Assignment

| Point | Channel    | Why                                  |
|-------|-----------|--------------------------------------|
| B     | XB        | B defines XB slope (always in XB)    |
| C     | A-channel | First retracement from A             |
| D     | XB        | Continuation in XB direction         |
| E     | A-channel | Second retracement from A            |
| F     | XB        | Final continuation in XB direction   |

### Candidate Sorting

```python
take_extreme_high = not point_is_low
```

- Seeking LOW point -> sort lowest (deepest) first
- Seeking HIGH point -> sort highest first

This ensures the most extreme valid candidate is tried first.

### Re-Validation Fixes (1-4)

When a later point is discovered, it reveals the TRUE slope of a line pair.
Earlier segments must be re-validated with this new information:

| Fix | Trigger   | Re-validates | With slope | Rule                      |
|-----|-----------|-------------|------------|---------------------------|
| 1   | C found   | A->B        | Real AC    | HIGHs/LOWs vs AC + buffer |
| 2   | D found   | B->C        | BD slope   | LOWs/HIGHs vs BD + buffer |
| 3   | E found   | C->D        | CE slope   | HIGHs/LOWs vs CE + buffer |
| 4   | F found   | D->E        | DF slope   | LOWs/HIGHs vs DF + buffer |

**Why needed**: During initial detection, segments are validated with proxy
slopes (e.g., A-channel slope for AB). When the actual paired point is
found (e.g., C), the true slope (AC) may be different, requiring re-check.
