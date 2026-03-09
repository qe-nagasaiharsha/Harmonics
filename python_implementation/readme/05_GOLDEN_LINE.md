# Golden Line Algorithm (`core/golden_line.py`)

## Overview

The Golden Line is a proprietary trading signal algorithm. After a pattern
is detected, it computes a trend line (the "MN line") through the pattern
and generates BUY/SELL signals when price crosses this line.

The algorithm has 5 steps:
1. **Slope Selection** — Choose which slope to use based on geometry
2. **FG Separator** — Find a horizontal divider splitting candles
3. **Matrix Computation** — Find M (max above) and N (max below) points
4. **MN Line** — Build the golden line from M to N, extended forward
5. **Signal Search** — Check for price crossings in the extension zone

## Key Concepts

### Terminology

| Term      | Meaning                                                    |
|-----------|------------------------------------------------------------|
| Last      | Final point of the pattern (B, C, D, E, or F)             |
| SP        | "Second Point" — point before last (A, B, C, D, or E)     |
| Z         | Slope line's value at SP's bar position                    |
| FG line   | Separator between Z and SP dividing candles above/below    |
| FirstLine | Iterating slope line from SP measuring deviations          |
| M         | Point of maximum deviation above FG                        |
| N         | Point of maximum deviation below FG                        |
| MN line   | The golden line — trend from M to N, extended forward      |

### The Opposite Price Type Rule

The algorithm consistently uses the **opposite price type** from the last point:
- Last point is **HIGH** -> algorithm uses **LOW** prices for calculations
- Last point is **LOW** -> algorithm uses **HIGH** prices for calculations

This applies to: FG candle division, last bar limit check, difference
calculations, M/N price extraction.

### Signal Type Determination

| Direction | Pattern  | Last Point | Signal |
|-----------|----------|------------|--------|
| Uptrend   | XABC     | C (HIGH)   | SELL   |
| Uptrend   | XABCD    | D (LOW)    | BUY    |
| Uptrend   | XABCDE   | E (HIGH)   | SELL   |
| Uptrend   | XABCDEF  | F (LOW)    | BUY    |
| Downtrend | XABC     | C (LOW)    | BUY    |
| Downtrend | XABCD    | D (HIGH)   | SELL   |
| Downtrend | XABCDE   | E (LOW)    | BUY    |
| Downtrend | XABCDEF  | F (HIGH)   | SELL   |

**Rule**: HIGH last -> SELL signal, LOW last -> BUY signal.

## Step 1: Slope Selection

The slope selection is conditional and pattern-specific. The algorithm
dispatches to `_setup_uptrend()` or `_setup_downtrend()` based on
`wave.x_less_than_a`.

### XABC (Simple)
- Slope: A->C line
- SP: B
- Z: AC slope value at B's position

### XABCD (Conditional)
1. Build XD slope (X to D) and BD slope (B to D)
2. Check if B is below/above the XD line:
   - Uptrend: if B lower than XD -> use XD, else BD
   - Downtrend: if B higher than XD -> use XD, else BD
3. SP: C, Z: chosen slope at C's position

### XABCDE (Conditional with SP selection)
1. Build AE slope (A to E) and CE slope (C to E)
2. Uptrend: if C higher than AE line -> use AE, SP = D or B (whichever
   is farther from AE line); else use CE, SP = D
3. Downtrend: if C lower than AE -> use CE, SP = D;
   else use AE, SP = D or B (whichever is farther)

### XABCDEF (Conditional)
1. Build XF slope (X to F) and DF slope (D to F)
2. Check if D is below/above the XF line:
   - Uptrend: if D lower than XF -> use XF, else DF
   - Downtrend: if D higher than XF -> use XF, else DF
3. SP: E, Z: chosen slope at E's position

## Step 2: FG Separator

Iteratively searches for a line that divides candles between SP and last
into "above" and "below" groups:

```
for q = 0 to max_iterations:
    p_check = f_percentage + q * fg_increasing_percentage
    fg_start = z_price + final_diff * p_check / 100
    FGArray = [fg_start + i * step_slope for i in range(bars)]

    # Last bar limit: opposite price must not cross FG at last bar
    # Divide candles using opposite price type
    # If both above[] and below[] are non-empty -> separator found
```

## Step 3: Matrix Computation

Iterates over slope percentages to find M and N:

```
for j = max_j down to 0:
    slope_pct = first_line_percentage - j * first_line_decrease_percentage
    slope_per_bar = (sp_price * slope_pct / 100) / bars_sp_to_last

    # Build FirstLine from SP
    # Calculate diffs between FirstLine and opposite price type
    # Find max diff in above-FG group (M) and below-FG group (N)

    # Validate: both diffs >= 0
    # Validate: |max_above - max_below| / |sp - last| <= tolerance
    # Validate: max_below_price < max_above_price
    # Validate: temporal ordering (SELL: N after M; BUY: N before M)
    # Validate: minimum segment length
```

## Step 4: MN Line Construction

Once M and N are found:

**For SELL (last_is_high)**:
```
MN starts from N (max_below), slopes UP to M (max_above)
mn_start_price adjusted by mn_buffer_percent (moves away from price)
```

**For BUY (!last_is_high)**:
```
MN starts from M (max_above), slopes DOWN to N (max_below)
mn_start_price adjusted by mn_buffer_percent (moves away from price)
```

## Step 5: Signal Search

Scans bars beyond the last point up to `mn_extension_bars`:

**SELL Signal**:
```
1. break_price = close (or high if extension_break_close=False)
2. If break_price > slope_extension -> STOP (invalidated)
3. If close >= golden_line -> CONTINUE (not yet crossed)
4. If close < golden_line -> SELL SIGNAL
```

**BUY Signal**:
```
1. break_price = close (or low if extension_break_close=False)
2. If break_price < slope_extension -> STOP (invalidated)
3. If close <= golden_line -> CONTINUE (not yet crossed)
4. If close > golden_line -> BUY SIGNAL
```

Only one signal per golden line (search stops after first signal or invalidation).

## Fallback

If the matrix computation fails to find valid M/N after exhausting all
iterations, no golden line is produced (returns `None`).
