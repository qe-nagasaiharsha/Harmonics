# Part 1: Overview & Architecture

## Golden Line PXABCDEF Channels V3

**MQ5 File:** `GOLDEN LINE PXABCDEF CHANNELS V3 - Harsha.mq5`  
**Python Backend:** `python_implementation/` (FastAPI + detection engine)  
**Frontend:** `frontend/` (React + lightweight-charts)  
**Platform:** MetaTrader 5 (MQL5 Expert Advisor) + standalone Python dashboard  
**Version:** 3.00  
**Origin:** Golden Line Algorithm from `AbdullahProjSourceCode.mq5`

---

## Table of Contents

1. [What This System Does](#what-this-system-does)
2. [Core Concepts Summary](#core-concepts-summary)
3. [X>A vs X<A — Golden Line Type](#xa-vs-xa--golden-line-type)
4. [Bullish vs Bearish — Pattern Direction](#bullish-vs-bearish--pattern-direction)
5. [The Dual-Channel System](#the-dual-channel-system)
6. [A Point Detection Logic](#a-point-detection-logic)
7. [Dynamic Height Properties (Q3)](#dynamic-height-properties-q3)
8. [Architecture & Execution Flow](#architecture--execution-flow)
9. [Data Structures](#data-structures)
10. [File Map](#file-map)

---

## What This System Does

This is a dual-mode system:

### MQ5 Script (MetaTrader 5)
1. **Scans historical price data** for harmonic-like wave patterns (XAB, XABC, XABCD, XABCDE, XABCDEF)
2. **Validates each pattern** against a dual-channel system (XB-channel + A-channel) with strict slope rules
3. **Computes a "Golden Line"** (MN line) using a matrix algorithm derived from `AbdullahProjSourceCode.mq5`
4. **Generates BUY/SELL signals** when price crosses the golden line
5. **Tracks dynamic last points** for live trading

### Python Dashboard
1. **FastAPI backend** (`python_implementation/api/server.py`) mirrors the MQ5 detection logic in Python
2. **React frontend** (`frontend/`) provides an interactive chart with all pattern overlays
3. **Per-candle detection traces** allow stepping through exactly why each bar succeeded or failed

---

## Core Concepts Summary

| # | Concept | Description |
|---|---------|-------------|
| 1 | **Pattern Direction** | BULLISH = last_point < previous_point; BEARISH = last_point > previous_point |
| 2 | **Golden Line Type** | UPTREND = X < A (X is LOW); DOWNTREND = X > A (X is HIGH) |
| 3 | **Golden Line Algorithm** | SP = previous-to-last point; uses OPPOSITE price type from last point |
| 4 | **Signal Type** | Alternates with pattern: UPTREND X<A → XABC=SELL, XABCD=BUY |
| 5 | **Slope Validation** | Based on X vs A relationship, determines which prices check which slopes |
| 6 | **Channel System** | XB-channel for B/D/F points; A-channel for C/E points |
| 7 | **A Retracement (Q2)** | A must retrace min/max % from the XB slope value at A's bar position |
| 8 | **Dynamic Height (Q3)** | As B search extends further from X, channel widths and retracement ranges expand |

---

## X>A vs X<A — Golden Line Type

**This is NOT the same as Bullish/Bearish.** This is the critical structural distinction.

### When X < A (`x_less_than_a = true`, Uptrend Config)
- X is a **LOW** point, A is a **HIGH** point
- XB slope connects two lows; A-channel sits above connecting highs
- Point types: X=LOW, A=HIGH, B=LOW, C=HIGH, D=LOW, E=HIGH, F=LOW
- Golden line: `golden_line_uptrend()`
- Signal: XABC=SELL, XABCD=BUY, XABCDE=SELL, XABCDEF=BUY

### When X > A (`x_less_than_a = false`, Downtrend Config)
- X is a **HIGH** point, A is a **LOW** point
- XB slope connects two highs; A-channel sits below connecting lows
- Point types: X=HIGH, A=LOW, B=HIGH, C=LOW, D=HIGH, E=LOW, F=HIGH
- Golden line: `golden_line_downtrend()`
- Signal: XABC=BUY, XABCD=SELL, XABCDE=BUY, XABCDEF=SELL

---

## Bullish vs Bearish — Pattern Direction

Determined by the **last two detected points**:

- **BULLISH:** `last_point_price < previous_point_price` (e.g., XABCD: D < C)
- **BEARISH:** `last_point_price > previous_point_price` (e.g., XABCD: D > C)

The `pattern_direction` input filters patterns; the golden line and slope validation are always driven by `x_less_than_a`.

---

## The Dual-Channel System

### XB-Channel (cyan/aqua lines)
- **Anchor:** X and B connected by slope
- **Slope:** `xb_slope = (b_price - x_price) / (x_idx - b_idx)`
- **Points detected inside:** D and F
- **Width:** `xb_upper_width_pct`, `xb_lower_width_pct`
- **Visual:** Center (solid) + upper boundary (dotted) + lower boundary (dotted)

### A-Channel (lime/green lines)
- **Anchor:** Point A
- **Slope:** Derived from `channel_type`:
  - `Parallel` → same as XB slope
  - `Straight` → 0.0 (horizontal)
  - `Non_Parallel` → negative XB slope (mirror)
- **Points detected inside:** C and E
- **Width:** `a_upper_width_pct`, `a_lower_width_pct`
- **Visual:** Center (solid) + upper boundary (dotted) + lower boundary (dotted)

### Channel Interaction
```
X < A (Uptrend):
  XB-channel = Support floor  → B, D, F land near or on this
  A-channel  = Resistance ceiling → C, E land near or on this

X > A (Downtrend):
  XB-channel = Resistance ceiling → B, D, F land near or on this
  A-channel  = Support floor      → C, E land near or on this
```

---

## A Point Detection Logic

Point A is found using two-stage logic:

### Stage 1: Maximum deviation from XB slope (Q2 implementation)
1. Build the XB slope array from X to B
2. For each candle between X and B:
   - If X is LOW: use HIGH prices, measure deviation `price - xb_value`
   - If X is HIGH: use LOW prices, measure deviation `xb_value - price`
3. The candle with **maximum deviation** is the initial A candidate

### Stage 2: Retracement filter (Q2 — "A retrace % from XB line")
At the bar index where A was found, compute the XB slope value at that position:
```
z = XBArray[a_offset]  (price on XB slope line at A's candle)
```
Then validate A's price is within the allowed retracement range:
```
For X < A (uptrend): a_price must be in [z + z*min%, z + z*max%]
For X > A (downtrend): a_price must be in [z - z*max%, z - z*min%]
```
This is the `min_width_percentage` / `max_width_percentage` input pair. It measures **how far A has moved from the XB slope** expressed as a percentage of the XB slope value at A's position.

**Example:** X=100, B=200, 100 bars apart. At bar 60, XB slope value = 160. A is at 300. Retracement = (300-160)/160 × 100 = 87.5%. If min=50%, max=100%, this A is valid (87.5% is within range).

### Stage 3: Secondary scan (extreme override)
After a valid A is found:
- **X < A:** Scan all candles between the validated A and B — if any candle has a higher HIGH than A's price, that becomes the new A (no retracement check needed)
- **X > A:** Scan all candles between the validated A and B — if any candle has a lower LOW than A's price, that becomes the new A (no retracement check needed)

---

## Dynamic Height Properties (Q3)

When B is not found at the minimum length (`b_min`) and the search extends further back, the system can automatically **expand its detection ranges** to catch patterns where B appears at a greater distance from X.

### Input 1: Every Candle Count Increase (`every_increasing_of_value`)
- Base interval: `b_min` candles
- For each additional `every_increasing_of_value` candles beyond `b_min`, one "increment step" is applied
- Example: b_min=20, increase=5 → steps at bars 25, 30, 35, 40...

### Input 2: A Retracement Increase (`width_increasing_percentage_x_to_b`)
- Each increment step adds this % to both `min_width_percentage` AND `max_width_percentage`
- The **width** (max - min) stays constant; the entire window **shifts upward**
- Example: min=1%, max=2%, increase=1% → at step 1: min=2%, max=3%; step 2: min=3%, max=4%

### Input 3: A Slope Channel Width Increase (`width_increasing_percentage_a_e` in original, reflected in Q3 design)
- Each increment step adds this % to both `a_upper_width_pct` AND `a_lower_width_pct`
- The A-channel band **expands** (both boundaries move further from center)

### Input 4: XB Slope Channel Width Increase
- Each increment step adds this % to both `xb_upper_width_pct` AND `xb_lower_width_pct`
- The XB-channel band **expands**

**Key rules:**
- Dynamic expansion only applies during B search (before B is detected)
- Once B is detected, the channel widths and retracement ranges are **frozen** at the expanded values
- Those frozen channel values then extend into the future for CDEF detection
- XB channel and A channel continue to extend after B is detected, but no further expansion happens

---

## Architecture & Execution Flow

```
OnInit()
  └── update_rates()
  └── find_all_patterns()
        └── for each channel_type (or all 3 if All_Types):
              └── for each x_idx from search_start down:
                    ├── try_find_pattern_from_x(x_idx, x_is_low=true)
                    └── try_find_pattern_from_x(x_idx, x_is_low=false)
                          └── Collect B candidates (local extrema b_min..b_max from X)
                          └── Sort candidates by extremeness
                          └── for each B candidate:
                                └── try_build_pattern_with_b()
                                      ├── Find A (max deviation from XB slope) [Stage 1]
                                      ├── Validate A retracement (Q2) [Stage 2]
                                      ├── Secondary scan for more extreme A [Stage 3]
                                      ├── Validate B retracement vs XA
                                      ├── Validate XB segment, PX segment
                                      ├── Find C candidates (in A-channel)
                                      │   └── for each C: find D (in XB-channel)
                                      │       └── for each D: find E (in A-channel)
                                      │           └── for each E: find F (in XB-channel)
                                      └── finalize_pattern()
                                            ├── tick_speed_filter()
                                            ├── divergence_filter()
                                            ├── pattern_direction filter
                                            ├── overlap/spacing check
                                            ├── draw_pattern() + draw_channels() + draw_labels()
                                            ├── golden_line_uptrend() or golden_line_downtrend()
                                            └── track_dynamic_last_points()
```

---

## Data Structures

### `wave_struct`
```mql5
struct wave_struct {
   double p_price, x_price, a_price, b_price, c_price, d_price, e_price, f_price;
   int    p_idx,   x_idx,   a_idx,   b_idx,   c_idx,   d_idx,   e_idx,   f_idx;
   bool is_bullish;     // Pattern direction: last < prev = bullish
   bool x_less_than_a;  // Golden line type: X < A = uptrend config
};
```
Global instance `g_wave` is reset before each pattern attempt via `reset_wave()`.

### Python equivalents
- `Wave` dataclass in `python_implementation/core/types.py`
- `PatternResult` wraps wave + channel_type + golden_line + diagnostics
- `XAttemptLog` captures per-candle step traces for the dashboard

---

## File Map

| File | Purpose |
|------|---------|
| `GOLDEN LINE PXABCDEF CHANNELS V3 - Harsha.mq5` | Main MQ5 script (all detection + drawing) |
| `AbdullahProjSourceCode.mq5` | Original source — golden line algorithm reference |
| `python_implementation/core/detector.py` | Python detection orchestrator |
| `python_implementation/core/candidates.py` | CDEF candidate point helpers |
| `python_implementation/core/validators.py` | All slope validation functions |
| `python_implementation/core/channels.py` | Channel geometry (slopes, widths) |
| `python_implementation/core/golden_line.py` | Golden line (MN) computation |
| `python_implementation/core/config.py` | `DetectorConfig` — all input parameters |
| `python_implementation/core/types.py` | Data types: Wave, PatternResult, etc. |
| `python_implementation/api/server.py` | FastAPI endpoints: `/api/defaults`, `/api/detect` |
| `frontend/src/App.jsx` | Root React component, state management |
| `frontend/src/components/ConfigPanel.jsx` | All configuration inputs |
| `frontend/src/components/ChartContainer.jsx` | Chart rendering + channel/pattern overlays |
| `frontend/src/components/LogPanel.jsx` | Detection trace display (scrollable) |

---

**Next:** [Part 2: Input Parameters Reference](02_INPUT_PARAMETERS_REFERENCE.md)
