# Dynamic Last Point Tracking (`core/dynamic_tracking.py`)

## Overview

After a pattern is detected, the slope from the previous-to-last point
through the last point is extended forward. When price breaks through
this extension AND the break point satisfies all three constraints
(range, channel, slope validation), it becomes a new "dynamic last point"
and a fresh Golden Line is computed from it.

This process repeats up to `max_dynamic_iterations` times, allowing the
pattern to "walk forward" through price data.

## Algorithm

### 1. Setup

Determine previous point and last point based on pattern type:

| Pattern  | Previous | Last | Search Origin | Channel   |
|----------|----------|------|---------------|-----------|
| XAB      | X        | B    | A             | XB        |
| XABC     | A        | C    | B             | A-channel |
| XABCD    | B        | D    | C             | XB        |
| XABCDE   | C        | E    | D             | A-channel |
| XABCDEF  | D        | F    | E             | XB        |

### 2. Slope Extension

```
slope = (current_last_price - prev_price) / (prev_idx - current_last_idx)
slope_value_at_bar_i = prev_price + (prev_idx - i) * slope
```

### 3. Break Detection

For each bar in the valid range (searching from last point forward):

- **BULLISH** (last point is LOW): Break found if `LOW < slope_value`
- **BEARISH** (last point is HIGH): Break found if `HIGH > slope_value`

### 4. Three Constraints

Each potential dynamic point must pass all three:

#### Constraint 1: Range Limits
The bar must fall within the valid segment range (same percentages
as initial detection: `min_X_to_Y_btw_x_b` / `max_X_to_Y_btw_x_b`).

#### Constraint 2: Channel Membership + Local Extremum
- The price must fall within the appropriate channel (A-channel for
  C/E points, XB-channel for B/D/F points)
- The bar must be a local extremum (local min for lows, local max for highs)

#### Constraint 3: Slope Validation
All candles between the previous point and the dynamic point must pass
the same validation rules as initial detection. This includes:

- Re-validation fixes (Fix 1-4) with the new slope
- Per-segment slope validation
- Span containment

### 5. Iteration

When a valid dynamic point is found:
1. Update the working wave's last point
2. Compute a new Golden Line from the updated wave
3. Record the `DynamicPoint` with its golden line
4. Continue searching from the new last point

### Dynamic Slope Validation Details

#### XAB Dynamic
- `validate_xb_segment()` with new X->B' slope
- `validate_span_containment()` for X->B' span

#### XABC Dynamic
- Calculate new AC slope with dynamic C position
- Fix 1: Re-validate A->B with new AC slope
- `validate_bc_segment()` with new AC slope
- `validate_span_containment()` for A->C' span

#### XABCD Dynamic
- Calculate AC slope (original C) and new BD slope
- Fix 2: Validate B->C against new BD slope
- `validate_cd_segment()` with new BD slope
- `validate_span_containment()` for B->D' span

#### XABCDE Dynamic
- Calculate BD slope (original D) and new CE slope
- Fix 3: Re-validate C->D against new CE slope
- `validate_de_segment()` with new CE slope
- `validate_span_containment()` for C->E' span

#### XABCDEF Dynamic
- Calculate CE slope (original E) and new DF slope
- Fix 4: Validate D->E against new DF slope
- `validate_ef_segment()` with new DF slope
- `validate_span_containment()` for D->F' span

## Consistency Note

All buffer-side checks in dynamic tracking use `slope_buffer_pct`
identically to the initial detection code. The same validators and span
containment functions are called with the same parameters.
