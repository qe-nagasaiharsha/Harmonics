# Part 2: Input Parameters Reference

Complete reference for every configurable input, covering both the MQ5 script and the Python backend/frontend equivalents.

---

## Group: Pattern Type

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Pattern Type | `pattern_type` | `pattern_type` | `XABCD` | How many points: XAB, XABC, XABCD, XABCDE, XABCDEF |
| Pattern Direction | `pattern_direction` | `pattern_direction` | `Both` | Filter: Bullish, Bearish, or Both |

### Pattern Direction Notes
- **Bullish:** `last_point_price < previous_point_price` (e.g., D < C in XABCD)
- **Bearish:** `last_point_price > previous_point_price` (e.g., D > C in XABCD)
- **Both:** No filter applied

---

## Group: Length Properties

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| B Min | `b_min` | `b_min` | 20 | Minimum bars from X to B |
| B Max | `b_max` | `b_max` | 100 | Maximum bars from X to B |
| PX Length % | `px_length_percentage` | `px_length_percentage` | 10 | P→X segment length as % of X→B span |
| BC Min % | `min_b_to_c_btw_x_b` | `min_b_to_c_btw_x_b` | 0 | Min B→C length as % of XB span |
| BC Max % | `max_b_to_c_btw_x_b` | `max_b_to_c_btw_x_b` | 100 | Max B→C length as % of XB span |
| CD Min % | `min_c_to_d_btw_x_b` | `min_c_to_d_btw_x_b` | 0 | Min C→D length as % of XB span |
| CD Max % | `max_c_to_d_btw_x_b` | `max_c_to_d_btw_x_b` | 100 | Max C→D length as % of XB span |
| DE Min % | `min_d_to_e_btw_x_b` | `min_d_to_e_btw_x_b` | 0 | Min D→E length as % of XB span |
| DE Max % | `max_d_to_e_btw_x_b` | `max_d_to_e_btw_x_b` | 100 | Max D→E length as % of XB span |
| EF Min % | `min_e_to_f_btw_x_b` | `min_e_to_f_btw_x_b` | 0 | Min E→F length as % of XB span |
| EF Max % | `max_e_to_f_btw_x_b` | `max_e_to_f_btw_x_b` | 100 | Max E→F length as % of XB span |

### Segment Length Calculation
Each subsequent segment length is expressed as a % of the original XB bar-span:
```
BC_bars_allowed = [XB_bars * min_bc%, XB_bars * max_bc%]
```
For example, with XB = 50 bars and BC max = 100%, C can be up to 50 bars after B.

---

## Group: Retracement Properties

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Max A retrace % from X | `max_width_percentage` | `max_width_percentage` | 100 | Maximum A retracement from XB slope value at A's bar |
| Min A retrace % from X | `min_width_percentage` | `min_width_percentage` | 0 | Minimum A retracement from XB slope value at A's bar |
| Max B retrace % from XA | `x_to_a_b_max` | `x_to_a_b_max` | 100 | Maximum B retracement relative to XA move |
| Min B retrace % from XA | `x_to_a_b_min` | `x_to_a_b_min` | -100 | Minimum B retracement relative to XA move |

### A Retracement Formula (Q2 Implementation)

The `min_width_percentage` / `max_width_percentage` inputs do **NOT** measure how far A is from X. They measure how far A has deviated from the **XB slope line** at A's exact bar position.

```
z = price on XB slope line at bar index of A

For X < A (uptrend):
  valid_range = [z + z * min_pct / 100 ,  z + z * max_pct / 100]
  A is valid if: valid_range[0] <= a_price <= valid_range[1]

For X > A (downtrend):
  valid_range = [z - z * max_pct / 100 ,  z - z * min_pct / 100]
  A is valid if: valid_range[0] <= a_price <= valid_range[1]
```

**Example (uptrend, X < A):**
- X = 1.0000 at bar 100, B = 1.0200 at bar 50 (XB span = 50 bars, slope goes up)
- At bar 80 (20 bars from X), XB slope value `z` ≈ 1.0080
- A price = 1.0180
- Retracement = (1.0180 - 1.0080) / 1.0080 × 100 = ~0.99%
- If min=0.5%, max=2%: valid (0.99% is within range)
- If min=0.5%, max=0.8%: **invalid** (0.99% exceeds max)

**Why this matters:** Setting min=0%, max=100% is very permissive (any deviation is fine). Setting min=5%, max=50% requires A to be meaningfully above/below the slope but not excessively so.

### B Retracement Formula
```
xb_retrace = (b_price - x_price) / (a_price - x_price) * 100
```
B must retrace within `[x_to_a_b_min, x_to_a_b_max]` as a percentage of the XA move.
- 100% means B retraces all the way to X (same level as X)
- 50% means B is halfway between X and A
- Negative values mean B overshoots beyond X

---

## Group: Dynamic Height Properties

These inputs expand detection ranges when B is found further from X than `b_min`.

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Every candle count increase | `every_increasing_of_value` | `every_increasing_of_value` | 5 | Number of additional bars per expansion step |
| A retrace increase % per step | `width_increasing_percentage_x_to_b` | `width_increasing_percentage_x_to_b` | 0 | Amount to add to both min and max A retracement per step |
| Price buffer % AC/BD/CE | `width_increasing_percentage_a_e` | `width_increasing_percentage_a_e` | 0 | Per-step increase to A-channel and XB-channel widths |

### How Expansion Steps Are Calculated

```python
dynamic_candles_count = max(0, (x_idx - 1 - b_min) - b_idx)
# Number of bars B is past the minimum distance

increment_steps = int(dynamic_candles_count / every_increasing_of_value) + 1
# How many expansion steps have occurred

incremental_width = increment_steps * width_increasing_percentage_x_to_b
# Total added retracement %

dynamic_max_pct = max_width_percentage + incremental_width
dynamic_min_pct = min_width_percentage + incremental_width
```

**Key behavior:** Min and max both shift by the same amount. The **window width** (max - min) stays constant; the entire acceptable range **shifts upward** together.

### Example
- b_min = 20, every_increasing_of_value = 5
- min_width_percentage = 1%, max_width_percentage = 2% (window = 1%)
- width_increasing_percentage_x_to_b = 1%

| B found at bar | Bars past b_min | Steps | Effective min% | Effective max% |
|----------------|-----------------|-------|----------------|----------------|
| 20 (at b_min) | 0 | 1 | 2% | 3% |
| 25 | 5 | 2 | 3% | 4% |
| 30 | 10 | 3 | 4% | 5% |
| 35 | 15 | 4 | 5% | 6% |

---

## Group: Validation

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Slope Buffer % | `slope_buffer_pct` | `slope_buffer_pct` | 0 | % tolerance on non-XB slope boundaries (AC, BD, CE, DF) |
| Only most recent | `only_draw_most_recent` | `only_draw_most_recent` | true | Skip patterns within `min_bars` of the previous one |
| Min bars between patterns | `min_bars_between_patterns` | `min_bars_between_patterns` | 10 | Minimum spacing between drawn patterns |
| Strict XB validation | `strict_xb_validation` | `strict_xb_validation` | false | Force strict (no-touch) for all slopes, not just XB |

---

## Group: Channel Type

| Parameter | MQ5 Input | Python Field | Default | Options |
|-----------|-----------|--------------|---------|---------|
| Channel Type | `channel_type` | `channel_type` | `Parallel` | Parallel, Straight, Non_Parallel, All_Types |

| Value | A-Channel Slope | Effect |
|-------|-----------------|--------|
| `Parallel` | Same as XB slope | A-channel runs parallel to XB — classic harmonic structure |
| `Straight` | 0 (horizontal) | A-channel is a flat horizontal band |
| `Non_Parallel` | Negative XB slope | A-channel mirrors XB — converging channel |
| `All_Types` | All three run simultaneously | Detects patterns for all channel types in one pass |

---

## Group: Channel Width Settings

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| XB upper width % | `xb_upper_width_pct` | `xb_upper_width_pct` | 0.5 | Upper boundary of XB channel as % of X's price |
| XB lower width % | `xb_lower_width_pct` | `xb_lower_width_pct` | 0.5 | Lower boundary of XB channel as % of X's price |
| A upper width % | `a_upper_width_pct` | `a_upper_width_pct` | 0.5 | Upper boundary of A channel as % of A's price |
| A lower width % | `a_lower_width_pct` | `a_lower_width_pct` | 0.5 | Lower boundary of A channel as % of A's price |

### Width Formula
```
upper_boundary(i) = center_line(i) + |anchor_price| * width_pct / 100
lower_boundary(i) = center_line(i) - |anchor_price| * width_pct / 100
```
Where `anchor_price` = X price (for XB channel) or A price (for A channel).

### Upper/Lower Swap for X > A
When X > A (downtrend config), upper and lower inputs are swapped internally:
```
effective_upper = x_less_than_a ? xb_upper_width_pct : xb_lower_width_pct
effective_lower = x_less_than_a ? xb_lower_width_pct : xb_upper_width_pct
```
This keeps user-facing "upper" semantics consistent regardless of pattern orientation.

---

## Group: Channel Extension

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Extension bars | `channel_extension_bars` | `channel_extension_bars` | 200 | How many bars past the last pattern point to draw channels |

---

## Group: Golden Line Settings

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Separator height % | `f_percentage` | `f_percentage` | 50 | Starting % for FG separator line search |
| Separator increment % | `fg_increasing_percentage` | `fg_increasing_percentage` | 5 | % step for FG separator iteration |
| Initial slope % | `first_line_percentage` | `first_line_percentage` | 4 | Starting slope for First Line matrix |
| Slope decrease % | `first_line_decrease_percentage` | `first_line_decrease_percentage` | 0.01 | Step to reduce slope per iteration |
| MN equality tolerance % | `maxBelow_maxAbove_diff_percentage` | `max_below_max_above_diff_percentage` | 40 | Max % difference between M and N distances |
| MN buffer % | `mn_buffer_percent` | `mn_buffer_percent` | 0 | Safety margin — moves golden line away from price |
| MN min length % | `mn_length_percent` | `mn_length_percent` | 0 | Minimum golden line segment length (0=no minimum) |
| MN extension bars | `mn_extension_bars` | `mn_extension_bars` | 20 | Bars to extend golden line into the future |
| Break on close | `extension_break_close` | `extension_break_close` | false | Use CLOSE price for signal detection (else HIGH/LOW) |

---

## Group: Dynamic Last Point (Live Trading)

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Enable | `enable_dynamic_last_point` | `enable_dynamic_last_point` | true | Track last point updates in live trading |
| Max iterations | `max_dynamic_iterations` | `max_dynamic_iterations` | 10 | Max number of dynamic updates per pattern |
| Label color | `dynamic_last_point_color` | — | White | Color of dynamic point labels in MQ5 |

---

## Group: Filters

| Parameter | MQ5 Input | Python Field | Default | Description |
|-----------|-----------|--------------|---------|-------------|
| Divergence type | `divergence_type` | `divergence_type` | None | None, Time, Volume, or Time+Volume divergence filter |
| Tick min speed | `tick_min_speed` | `tick_min_speed` | 500000 | Minimum seconds-per-bar for tick chart validation |

---

## Frontend ↔ Backend Parameter Mapping

The React frontend sends config as JSON to `POST /api/detect`. All parameters are now fully mapped:

```
ConfigPanel.jsx input → DEFAULT_CFG key → ConfigInput (Pydantic) → DetectorConfig (Python)
```

**Fully wired inputs (frontend → backend):**
- All Length Properties (b_min, b_max, px_length, BC/CD/DE/EF ranges)
- All Retracement Properties (A min/max, B min/max)
- All Dynamic Height Properties (every_increasing, width_x_to_b, width_a_e)
- All Channel Width Settings (xb_upper/lower, a_upper/lower, extension_bars)
- All Validation settings (slope_buffer, only_recent, min_bars)
- Channel type, pattern type, pattern direction
- Divergence filter, dynamic last point toggle

---

**Next:** [Part 3: Pattern Detection & Channels](03_PATTERN_DETECTION_AND_CHANNELS.md)
