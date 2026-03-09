# Part 4: Golden Line Algorithm

The golden line (MN line) is the core trading signal generator. This document covers the complete algorithm from slope selection to signal generation.

---

## Table of Contents

1. [Algorithm Overview](#algorithm-overview)
2. [Key Terminology](#key-terminology)
3. [The Opposite Price Type Rule](#the-opposite-price-type-rule)
4. [Signal Type Determination](#signal-type-determination)
5. [Step 1: Slope Selection (Per Pattern Type)](#step-1-slope-selection)
6. [Step 2: FG Separator Line](#step-2-fg-separator-line)
7. [Step 3: Matrix Computation — Finding M and N](#step-3-matrix-computation)
8. [Step 4: MN Line Construction](#step-4-mn-line-construction)
9. [Step 5: Signal Search](#step-5-signal-search)
10. [Uptrend vs Downtrend Differences](#uptrend-vs-downtrend-differences)
11. [Fallback Behavior](#fallback-behavior)
12. [Input Parameters Used](#input-parameters-used)

---

## Algorithm Overview

The golden line algorithm (from `AbdullahProjSourceCode.mq5`) works in 5 steps:

```
1. SLOPE SELECTION    → Choose which slope line to use based on pattern geometry
2. FG SEPARATOR       → Find a horizontal-ish divider that splits candles into above/below groups
3. MATRIX COMPUTATION → Iterate slope lines to find M (max above FG) and N (max below FG) points
4. MN LINE            → Build a trend line from M to N, extended into the future
5. SIGNAL SEARCH      → Check if price crosses the MN line in the extension zone
```

Two separate functions implement this:
- `golden_line_uptrend()` (lines 1679-2194) — for X < A patterns
- `golden_line_downtrend()` (lines 2201-2714) — for X > A patterns

---

## Key Terminology

| Term | Meaning |
|------|---------|
| **Last point** | The final point of the pattern (C for XABC, D for XABCD, etc.) |
| **SP** | "Second Point" — the point before the last point (B for XABC, C for XABCD, etc.) |
| **Z** | The slope line's value at SP's bar position — the "projected" SP on the slope |
| **FG line** | Separator line between Z and SP that divides candles into above/below groups |
| **FirstLine** | Iterating slope line from SP used to measure deviations |
| **M** | Point of maximum deviation above FG from FirstLine |
| **N** | Point of maximum deviation below FG from FirstLine |
| **MN line** | The golden line — a trend line connecting M and N, extended forward |
| **SlopeArray** | Array of slope values from anchor to last point |

---

## The Opposite Price Type Rule

**Critical rule from the original source code:** The golden line algorithm uses the **opposite** price type from the last point.

- If last point is **HIGH** → algorithm uses **LOW** prices for calculations
- If last point is **LOW** → algorithm uses **HIGH** prices for calculations

This is applied in:
- FG separator candle division (lines 1930-1953, 2449-2473)
- Last bar limit check (lines 1921-1927, 2441-2447)
- Difference calculations for M/N finding (lines 1994-2024, 2514-2544)
- M/N price extraction (lines 2051-2052, 2571-2572)

---

## Signal Type Determination

The signal type alternates based on pattern depth and X vs A relationship:

### Uptrend (X < A) — `golden_line_uptrend()`
Point types: X=LOW, A=HIGH, B=LOW, C=HIGH, D=LOW, E=HIGH, F=LOW

| Pattern | Last Point | Last Is | Uses | Signal |
|---------|-----------|---------|------|--------|
| XABC | C | HIGH | LOWs | **SELL** |
| XABCD | D | LOW | HIGHs | **BUY** |
| XABCDE | E | HIGH | LOWs | **SELL** |
| XABCDEF | F | LOW | HIGHs | **BUY** |

### Downtrend (X > A) — `golden_line_downtrend()`
Point types: X=HIGH, A=LOW, B=HIGH, C=LOW, D=HIGH, E=LOW, F=HIGH

| Pattern | Last Point | Last Is | Uses | Signal |
|---------|-----------|---------|------|--------|
| XABC | C | LOW | HIGHs | **BUY** |
| XABCD | D | HIGH | LOWs | **SELL** |
| XABCDE | E | LOW | HIGHs | **BUY** |
| XABCDEF | F | HIGH | LOWs | **SELL** |

**Key insight for downtrend (lines 2207-2208):**
```mql5
bool last_is_high = (ptype == XABCD || ptype == XABCDEF);
bool signal_is_sell = last_is_high;
```

Compare with uptrend (lines 1685-1686):
```mql5
bool last_is_high = (ptype == XABC || ptype == XABCDE);
bool signal_is_sell = last_is_high;
```

In both cases: **HIGH last → SELL signal, LOW last → BUY signal**.

---

## Step 1: Slope Selection

The slope determines the "trend line" used throughout the algorithm. The selection logic differs by pattern type.

### XABC (Simple — both uptrend & downtrend)
- **Slope:** AC (A to C)
- **SP:** B
- **Z:** AC slope value at B's position
- **Lines:** 1698-1714 (uptrend), 2222-2238 (downtrend)

```
SlopeArray built from A to C
step_slope = (c_price - a_price) / (a_idx - c_idx)
z_price = SlopeArray[a_idx - b_idx]  // AC value at B
```

### XABCD (Conditional)
Creates **two** slope arrays and picks one:

**Uptrend (X<A):** Lines 1716-1762
1. **XD slope** — from X to D
2. **BD slope** — from B to D
3. Check: `b_is_lower = (b_price < XDArray[b_offset])` — is B below the XD line?
4. If B is lower → use **XD slope**, Z = XD value at C
5. If B is NOT lower → use **BD slope**, Z = BD value at C

**Downtrend (X>A):** Lines 2240-2285
1. Same two arrays (XD and BD)
2. Check: `b_is_higher = (b_price > XDArray[b_offset])` — is B above the XD line?
3. If B is higher → use **XD slope**, Z = XD value at C
4. If B is NOT higher → use **BD slope**, Z = BD value at C

**SP:** C for XABCD (lines 1719, 2243)

### XABCDE (Conditional with SP selection)
Creates **two** slope arrays with complex SP logic:

**Uptrend (X<A):** Lines 1763-1830
1. **AE slope** — from A to E
2. **CE slope** — from C to E
3. Check: `c_is_higher = (c_price > AEArray[c_offset])` — is C above the AE line?
4. If C is higher → use **AE slope**, SP = D or B (whichever is farther from AE)
5. If C is NOT higher → use **CE slope**, SP = D

**Downtrend (X>A):** Lines 2287-2349
1. Same two arrays (AE and CE)
2. Check: `c_is_lower = (c_price < AEArray[c_offset])` — is C below the AE line?
3. If C is lower → use **CE slope**, SP = D
4. If C is NOT lower → use **AE slope**, SP = D or B (whichever is farther from AE)

The `final_diff_for_fg` variable stores the SP-to-Z distance for FG calculation.

### XABCDEF (Conditional — follows XABCD pattern)
Creates **two** slope arrays:

**Uptrend (X<A):** Lines 1831-1876
1. **XF slope** — from X to F
2. **DF slope** — from D to F
3. Check: `d_is_lower = (d_price < XFArray[d_offset])` — is D below the XF line?
4. If D is lower → use **XF slope**, Z = XF value at E
5. If D is NOT lower → use **DF slope**, Z = DF value at E

**Downtrend (X>A):** Lines 2351-2396
1. Same (XF and DF)
2. Check: `d_is_higher = (d_price > XFArray[d_offset])`
3. Mirror logic

**SP:** E for XABCDEF (lines 1834, 2354)

---

## Step 2: FG Separator Line

**Purpose:** Split the candles between SP and last point into "above" and "below" groups.

**Lines:** 1884-1961 (uptrend), 2404-2481 (downtrend)

### Construction
The FG line starts at height `f_percentage`% between Z and SP, then iterates:

```
for q = 0 to total_iterations:
  p_to_check = f_percentage + q * fg_increasing_percentage
  fg_start_price = z_price + final_diff_for_fg * p_to_check / 100
  FGArray[i] = fg_start_price + i * step_slope  // Parallel to slope
```

### Last Bar Limit Check
Before accepting an FG position, the last bar must pass a limit check using the **opposite price type**:
- Last is HIGH → check: `iLow(last_idx) > FGArray[bars_fg]` (must be above)
- Last is LOW → check: `iHigh(last_idx) < FGArray[bars_fg]` (must be below)

### Candle Division
Each candle between SP and last point is classified:
- **Above FG:** Using opposite price type, the price is above FG value
- **Below FG:** Using opposite price type, the price is below FG value

The FG position is accepted when both groups have at least one candle.

### Input Parameters
- `f_percentage` — starting height (default 50%)
- `fg_increasing_percentage` — increment per iteration (default 5%)
- `draw_fg_line` — whether to visualize the FG line

---

## Step 3: Matrix Computation

**Purpose:** Find the M (maximum above) and N (maximum below) points by iterating slope lines.

**Lines:** 1966-2042 (uptrend), 2486-2562 (downtrend)

### FirstLine Construction
For each iteration `j`:
```
current_slope_pct = first_line_percentage - j * first_line_decrease_percentage
slope_per_bar = (sp_price * current_slope_pct / 100) / bars_sp_to_last

If last_is_high (SELL): FirstLine[i] = sp_price + slope_per_bar * i  (slopes UP)
If !last_is_high (BUY): FirstLine[i] = sp_price - slope_per_bar * i  (slopes DOWN)
```

### Difference Calculation
For each candle in the above-FG and below-FG groups:
```
If last_is_high: diff = FirstLine[offset] - iLow(candle_idx)    // FirstLine - LOW
If !last_is_high: diff = iHigh(candle_idx) - FirstLine[offset]  // HIGH - FirstLine
```

### M and N Selection
- **M** = candle with maximum difference in the above-FG group
- **N** = candle with maximum difference in the below-FG group

### Validation Conditions
All must pass for a valid M/N pair:

1. `max_below_diff >= 0 && max_above_diff >= 0` (line 2032)
2. `max_below_price <= max_above_price` (line 2055) — N must be below M
3. **Temporal ordering** (lines 2059-2063):
   - SELL: max_below must be AFTER max_above (lower bar index = more recent)
   - BUY: max_below must be BEFORE max_above (higher bar index = older)
4. **Equality tolerance** (lines 2036-2040): `|max_above_diff - max_below_diff| / |sp_price - last_price| <= maxBelow_maxAbove_diff_percentage / 100`
5. **Minimum MN length** (lines 2066-2069): If `mn_length_percent > 0`, the bar distance between M and N must be ≥ `mn_length_percent`% of SP-to-last distance

### Input Parameters
- `first_line_percentage` — initial slope of FirstLine (default 4%)
- `first_line_decrease_percentage` — decrement per iteration (default 0.01%)
- `maxBelow_maxAbove_diff_percentage` — M/N equality tolerance (default 40%)
- `mn_length_percent` — minimum MN bar distance (default 0)

---

## Step 4: MN Line Construction

**Lines:** 2072-2109 (uptrend), 2592-2629 (downtrend)

### For SELL (last_is_high)
```
MN starts from max_below (N point), slopes UP toward max_above (M point)
bars_m_n = max_below_idx - max_above_idx
step_mn = (max_above_price - max_below_price) / bars_m_n

// Apply MN buffer (safety margin)
max_below_price -= (max_above_price - max_below_price) * mn_buffer_percent / 100

mn_start_idx = max_below_idx
mn_start_price = max_below_price (after buffer)
MNArray[i] = max_below_price + i * step_mn
```

### For BUY (!last_is_high)
```
MN starts from max_above (M point), slopes DOWN toward max_below (N point)
bars_m_n = max_above_idx - max_below_idx
step_mn = (max_below_price - max_above_price) / bars_m_n

// Apply MN buffer (safety margin)
max_above_price += (max_above_price - max_below_price) * mn_buffer_percent / 100

mn_start_idx = max_above_idx
mn_start_price = max_above_price (after buffer)
MNArray[i] = max_above_price + i * step_mn
```

---

## Step 5: Signal Search

**Lines:** 2122-2161 (uptrend), 2642-2681 (downtrend)

The signal search scans bars beyond the last point, up to `mn_extension_bars`:

```
for i = 1 to mn_extension_bars:
  signal_idx = last_idx - i  // Moving forward in time
  trend_price = MNArray[mn_offset]  // Golden line value at this bar
  slope_ext_price = SlopeExtArray[slope_ext_offset]  // Slope extension value
```

### SELL Signal Logic
```
1. break_price = extension_break_close ? candle_close : candle_high
2. If break_price > slope_ext_price → STOP (price broke above slope, signal invalidated)
3. If candle_close >= trend_price → CONTINUE (hasn't crossed golden line yet)
4. If candle_close < trend_price → SELL SIGNAL (draw sell arrow)
```

### BUY Signal Logic
```
1. break_price = extension_break_close ? candle_close : candle_low
2. If break_price < slope_ext_price → STOP (price broke below slope, signal invalidated)
3. If candle_close <= trend_price → CONTINUE (hasn't crossed golden line yet)
4. If candle_close > trend_price → BUY SIGNAL (draw buy arrow)
```

### Important: Only ONE signal per golden line
The loop breaks after the first signal or invalidation — at most one arrow is drawn.

### Input Parameters
- `mn_extension_bars` — search range (default 20 bars)
- `extension_break_close` — use CLOSE vs HIGH/LOW for break detection (default false)

---

## Uptrend vs Downtrend Differences

The two functions (`golden_line_uptrend` and `golden_line_downtrend`) are **structurally identical** but differ in conditional checks for slope selection:

| Decision Point | Uptrend (X<A) | Downtrend (X>A) |
|----------------|---------------|-----------------|
| XABCD: Which slope? | B lower than XD? → use XD | B higher than XD? → use XD |
| XABCDE: Which slope? | C higher than AE? → use AE | C lower than AE? → use CE |
| XABCDEF: Which slope? | D lower than XF? → use XF | D higher than XF? → use XF |

The signal generation logic, FG separator, and matrix computation are **identical** in both functions — only the slope selection conditionals are mirrored.

---

## Fallback Behavior

If the matrix computation fails to find valid M/N points after exhausting all FirstLine iterations, a **fallback golden line** is drawn (lines 2188-2193, 2708-2713):

```
draw_golden_line_obj("golden_fallback", x_idx, sp_idx, sp_price,
                     last_idx - mn_extension_bars, last_price, golden_line_color)
```

This draws a simple line from SP to the last point extended by `mn_extension_bars`, but **no signal arrow** is generated.

---

## Input Parameters Used

| Parameter | Where in Algorithm | Purpose |
|-----------|-------------------|---------|
| `f_percentage` | FG separator start | Initial separator height |
| `fg_increasing_percentage` | FG separator iteration | Increment per try |
| `first_line_percentage` | Matrix computation | Initial FirstLine slope |
| `first_line_decrease_percentage` | Matrix computation | FirstLine slope decrement |
| `maxBelow_maxAbove_diff_percentage` | M/N validation | Equality tolerance |
| `mn_buffer_percent` | MN construction | Safety margin |
| `mn_length_percent` | M/N validation | Minimum MN bar distance |
| `mn_extension_bars` | Signal search + drawing | Extension range |
| `extension_break_close` | Signal search | Break detection price type |
| `draw_golden_line` | Finalize + drawing | Enable/disable MN line |
| `draw_fg_line` | Drawing | Enable/disable FG line |
| `golden_line_color` | Drawing | MN line color |
| `fg_line_color` | Drawing | FG line color |

---

**Previous:** [Part 3: Pattern Detection & Channel System](03_PATTERN_DETECTION_AND_CHANNELS.md)
**Next:** [Part 5: Dynamic Last Points, Filters & Visual System](05_DYNAMIC_POINTS_FILTERS_VISUALS.md)
