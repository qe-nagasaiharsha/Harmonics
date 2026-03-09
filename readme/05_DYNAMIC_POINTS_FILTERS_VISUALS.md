# Part 5: Dynamic Points, Filters & Visual System

## Dynamic Last Point Tracking

When `enable_dynamic_last_point = true`, after a complete pattern is drawn the system searches for additional "dynamic" last points — places where the terminal point of the pattern could have updated as price continued.

### How It Works

1. Starting from the detected last point (e.g., D for XABCD), extend the slope from the previous point through the last point
2. Search forward for any candle that **breaks below** (bullish pattern) or **above** (bearish) this slope extension
3. The break must be:
   - Within the valid range defined by the segment's min/max% inputs
   - Within the appropriate channel (A-channel for C/E, XB-channel for D/F)
   - A local extremum
   - Passing slope validation for the segment
4. If found, this becomes a new "dynamic" last point — draw a golden line from it too
5. Repeat up to `max_dynamic_iterations` times

### Use Case
In live trading: if the market continues past the initially detected D point and forms a new lower low (still within channel), the system tracks this new D automatically.

---

## Filters

### Divergence Filter

When `divergence_type ≠ None`, patterns are only drawn when divergence exists between leg sizes or time/volume:

| Type | Condition |
|------|-----------|
| `None` | No filter — all patterns pass |
| `Time` | Second leg takes less time per bar than first leg when it's bigger (or more time when smaller) |
| `Volume` | Second leg has lower total volume when it's bigger (or higher when smaller) |
| `Time_Volume` | Combined: volume per bar comparison |

### Tick Speed Filter
`tick_min_speed` sets a minimum seconds-per-bar threshold. This is primarily for tick charts: if the bars are very fast (many ticks per second), patterns on fast tick charts may be filtered out.

### Pattern Spacing Filter
`min_bars_between_patterns` + `only_draw_most_recent`:
- When `only_draw_most_recent = true`, only one pattern per `min_bars_between_patterns` window is drawn (most recent wins)
- When false, all valid patterns are drawn regardless of spacing

---

## Visual System

### Pattern Lines (drawn by `draw_pattern()`)
| Segment | Color Input | Style |
|---------|-------------|-------|
| P→X | `px_color` (Red) | Solid |
| X→A | `xa_color` (White) | Solid |
| A→B | `ab_color` (White) | Solid |
| B→C | `bc_color` (White) | Solid |
| C→D | `cd_color` (White) | Solid |
| D→E | `de_color` (White) | Solid |
| E→F | `ef_color` (White) | Solid |

### Channel Lines (drawn by `draw_channels()`)

**XB Channel (3 lines):**
| Line | Style | Width | Color |
|------|-------|-------|-------|
| Center | Solid | 2 | `xb_channel_color` (Aqua) |
| Upper boundary | Dotted | 1 | `xb_channel_color` (Aqua) |
| Lower boundary | Dotted | 1 | `xb_channel_color` (Aqua) |

**A Channel (3 lines):**
| Line | Style | Width | Color |
|------|-------|-------|-------|
| Center | Solid | 2 | `a_channel_color` (Lime) |
| Upper boundary | Dotted | 1 | `a_channel_color` (Lime) |
| Lower boundary | Dotted | 1 | `a_channel_color` (Lime) |

All channels extend `channel_extension_bars` bars past the last detected pattern point.

### Labels (drawn by `draw_all_labels()`)
- Labels X, B, D, F appear **below** their bars (these are the bottom points in uptrend config)
- Labels A, C, E appear **above** their bars (these are the top points in uptrend config)
- For downtrend config (X > A), positions flip

### Golden Line
- Drawn in `golden_line_color` (Gold), width 3, solid
- Extended `mn_extension_bars` bars past the MN segment
- Optional FG separator line in `fg_line_color` (Khaki)

### Arrows
- BUY signal: upward arrow in `arrow_buy_color` (Violet), size `arrow_size`
- SELL signal: downward arrow in `arrow_sell_color` (Red), size `arrow_size`

### Dynamic Last Point Labels
- Labels L1, L2, L3... in `dynamic_last_point_color` (White)
- Positioned above/below bar depending on point type

---

## Frontend Dashboard Visual System

The React frontend (`ChartContainer.jsx`) renders patterns on a `lightweight-charts` candlestick chart:

### Chart Layers (per pattern)

1. **Zigzag line** (P→X→A→B→C→...→last point)
   - Bull: `#10b981` (green), Bear: `#ef4444` (red)
   - Dashed line style when not selected; solid when selected
   - Markers at each wave point label (P, X, A, B, C, D, E, F)

2. **XB Channel** — 3 series:
   - Center: solid, width 2, bright green/red
   - Upper: dotted, width 1, same color
   - Lower: dotted, width 1, same color

3. **A Channel** — 3 series:
   - Center: solid, width 2, soft green/red
   - Upper: dotted, width 1, same color
   - Lower: dotted, width 1, same color

4. **Golden line** — solid yellow (`#facc15`), width 2

### A-Channel Slope in Frontend
The frontend computes A-channel slope based on `pattern.channel_type`:
```javascript
if (channelType === 'straight')     a_slope = 0
if (channelType === 'non_parallel') a_slope = -xb_slope
else                                a_slope = xb_slope  // parallel
```
This ensures the visual channel matches the detection logic regardless of channel type.

### Channel Width Calculation in Frontend
Uses the config values from the sidebar inputs:
```javascript
const xbUpOff = Math.abs(w.x_price) * xb_up_pct * 0.01
const xbLoOff = Math.abs(w.x_price) * xb_lo_pct * 0.01
const aUpOff  = Math.abs(w.a_price) * a_up_pct  * 0.01
const aLoOff  = Math.abs(w.a_price) * a_lo_pct  * 0.01
```
Upper/lower percentages swap for X > A patterns to maintain consistent visual semantics.

### Channel Extension in Frontend
Lines are extended `channel_extension_bars` bars past the most-recent pattern point. The extension idx is included in the line series if a time mapping exists (bar is within the scanned data range).

### Selected Pattern Highlight
Clicking a pattern in the pattern list highlights it:
- Zigzag becomes solid, brighter color, width 2
- Channel lines remain their colors but become slightly brighter

---

## Detection Trace (Log Panel)

The right-side panel shows **per-candle detection attempts** when you hover or click a candle.

### What Is Shown
For each X candidate at the hovered bar:
- Whether B candidates were found
- A_FIND: was A detected and with what deviation
- XB_RETRACE: was B's retracement within range
- A_WIDTH: was A's retracement from XB slope within range
- XB_SEGMENT, PX_SEGMENT: slope validation passes/fails
- C/D/E/F search results

### Scrollability Fix
The attempts list is a scrollable flex container (`overflow-y: auto; min-height: 0`). The `min-height: 0` is critical for flex containers to enable scrolling — without it, the container expands to fit content and scroll never activates.

### Pinned Mode
- Clicking a candle **pins** the trace panel so it stays visible while reading
- Click the "📌 Pinned — click to unlock" badge to return to hover mode
- The pinned bar is highlighted in the chart toolbar

---

## Q2 + Q3 Implementation Summary

### Q2 — A Retracement from XB Slope at A's Bar
**The key insight:** A is not validated against X's price, but against the **XB slope line value** at the exact candle where A appears. This provides a much more geometrically meaningful constraint.

**Frontend impact:** The min/max_width_percentage inputs in the Retracement Properties section directly control this. The label in the UI reads "A Retrace % from XB line" to make this clear.

**Backend:** `detector.py` lines around `z = xb_array[a_offset]` — this is the Q2 validation.

### Q3 — Dynamic Height Expansion
**The key insight:** When patterns have a longer XB span, a rigid detection window might miss valid patterns. Dynamic height allows the detection to relax its constraints proportionally as B is found further from X.

**Three expansion dimensions:**
1. A retracement window shifts up (both min and max increase by the same amount)
2. A-channel width expands (both boundaries move further from center)
3. XB-channel width expands

**Freeze point:** Once B is detected, all expansions freeze. The expanded channels then extend forward for CDEF detection without further modification.

---

**Back to:** [Part 1: Overview](01_OVERVIEW_AND_ARCHITECTURE.md)
