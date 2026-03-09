# Part 3: Pattern Detection & Channels

## Detection Cascade

All patterns follow the same cascading search: X → B (and A) → C → D → E → F.
Each step produces a sorted list of candidates; the system tries each in order and stops at the first complete valid pattern.

---

## Step 1: Finding X

Every bar in the scanned history is tried as X in two ways:
- **X as LOW** (`x_is_low = true`): `x_price = iLow(x_idx)` → A will be a HIGH above
- **X as HIGH** (`x_is_low = false`): `x_price = iHigh(x_idx)` → A will be a LOW below

---

## Step 2: Finding B and A Together

B and A are found together because A's position depends on the XB slope.

### B Candidate Collection
Candidates are collected from bars `[x_idx - b_min - 1]` down to `[x_idx - b_max]`:
- If X is LOW → look for LOCAL MINIMA (bars lower than both neighbors)
- If X is HIGH → look for LOCAL MAXIMA (bars higher than both neighbors)

Candidates are sorted by extremeness (most extreme B first).

### A Candidate (Max Deviation)
For each B candidate, the XB slope line is computed. Then A is chosen as the candle between X and B with the greatest deviation from this line:
- X is LOW → search HIGHs between X and B; A = bar with max `(price - xb_value)`
- X is HIGH → search LOWs between X and B; A = bar with max `(xb_value - price)`

### A Retracement Validation (Q2)
At A's bar position, read the XB slope value `z`. Check:
```
X < A (uptrend):  z + z*min_pct% ≤ a_price ≤ z + z*max_pct%
X > A (downtrend): z - z*max_pct% ≤ a_price ≤ z - z*min_pct%
```
Dynamic expansion (Q3) may adjust min/max based on how far B is from x_idx.

### Secondary Scan (Extreme Override)
After retracement validation passes, scan candles between the valid A and B:
- X < A: if any candle has a higher HIGH than A → that becomes the new A
- X > A: if any candle has a lower LOW than A → that becomes the new A
This guarantees A is always the most extreme point in the XB span.

### B Retracement Validation
```
xb_retrace = (b_price - x_price) / (a_price - x_price) * 100
Must be in [x_to_a_b_min, x_to_a_b_max]
```

---

## Step 3: XB Segment Validation

All candles **between X and B** must respect the XB slope:
- X is LOW → every LOW between X and B must be **above** the XB slope value (no candle dips below the slope)
- X is HIGH → every HIGH between X and B must be **below** the XB slope value

This is strict (no buffer). If `strict_xb_validation = true`, this check also applies to all other slopes.

---

## Step 4: PX Segment Validation

P is computed as a virtual point before X:
```
bars_p_x = px_length_percentage / 100 * bars_x_b
p_idx = x_idx + bars_p_x
p_price = x_price - bars_p_x * xb_slope
```
All candles between P and X must respect the XB slope extended backward (same direction check as XB).

---

## Step 5: Finding C (in A-Channel)

C candidates are searched from `b_idx - (XB_bars * min_bc%)` to `b_idx - (XB_bars * max_bc%)`.

For each C candidate:
1. **Channel check:** C must be within the A-channel band centered on `aAt(c_idx)`
2. **Local extremum:** C must be a local HIGH (if c_is_low = false) or LOCAL LOW
3. **AB re-validation with real AC slope:** Now that C is known, check all candles A→B against the real AC slope
4. **BC segment validation:** All candles B→C must stay between XB extension (strict) and AC line (with buffer)
5. **AC span containment:** All candles A→C on the same side as A must not exceed the AC slope

### `c_is_low` determination
```
c_is_low = (b_price > a_price)  ← i.e., if B < A then C is LOW; if B > A then C is HIGH
```

---

## Step 6: Finding D (in XB-Channel)

D candidates searched from `c_idx - (XB_bars * min_cd%)` to `c_idx - (XB_bars * max_cd%)`.

For each D candidate:
1. **Channel check:** D must be within the XB-channel band
2. **Local extremum check**
3. **BC re-validation with real BD slope:** Check B→C candles against BD slope
4. **CD segment validation:** All candles C→D must stay between BD (with buffer) and AC extension (strict)
5. **BD span containment:** B→D candles on the same side as B must not exceed BD slope

### `d_is_low` determination
```
d_is_low = (c_price > b_price)  ← d_is_low == c_is_low in most cases
```

---

## Step 7: Finding E (in A-Channel)

E candidates searched from `d_idx - (XB_bars * min_de%)` to `d_idx - (XB_bars * max_de%)`.

For each E candidate:
1. **Channel check:** E must be within the A-channel band
2. **Local extremum check**
3. **CD re-validation with real CE slope:** Check C→D candles against CE slope
4. **DE segment validation:** All candles D→E must stay between BD extension (strict) and CE (with buffer)
5. **CE span containment**

---

## Step 8: Finding F (in XB-Channel)

F candidates searched from `e_idx - (XB_bars * min_ef%)` to `e_idx - (XB_bars * max_ef%)`.

For each F candidate:
1. **Channel check:** F must be within the XB-channel band
2. **Local extremum check**
3. **DE re-validation with real DF slope**
4. **EF segment validation:** All candles E→F must stay between DF (with buffer) and CE extension (strict)
5. **DF span containment**

---

## Channel Bands: Center, Upper, Lower

Each channel has three lines drawn on the chart:

### XB Channel (cyan/aqua)
```
center(i) = x_price + xb_slope * (x_idx - i)
upper(i)  = center(i) + |x_price| * xb_upper_pct / 100   [dotted]
lower(i)  = center(i) - |x_price| * xb_lower_pct / 100   [dotted]
```
- Center: **solid line**, width 2
- Upper & Lower boundaries: **dotted lines**, width 1

### A Channel (lime/green)
```
center(i) = a_price + a_slope * (a_idx - i)
upper(i)  = center(i) + |a_price| * a_upper_pct / 100   [dotted]
lower(i)  = center(i) - |a_price| * a_lower_pct / 100   [dotted]
```
- Center: **solid line**, width 2
- Upper & Lower boundaries: **dotted lines**, width 1

### A-Channel Slope Modes
| `channel_type` | `a_slope` | Effect |
|----------------|-----------|--------|
| `parallel` | `= xb_slope` | A-channel runs parallel to XB — classic harmonic |
| `straight` | `= 0` | A-channel is horizontal |
| `non_parallel` | `= -xb_slope` | A-channel mirrors XB slope (converging channel) |

### Width Swapping for X > A
When `x_less_than_a = false`, upper and lower widths swap:
```python
effective_upper = upper_pct if x_less_than_a else lower_pct
effective_lower = lower_pct if x_less_than_a else upper_pct
```
This keeps "upper" meaning "further from center, in the direction away from price action" regardless of whether the channel is above or below.

---

## Segment Slope Validation Rules Summary

| Segment | Validation against (strict) | Validation against (with buffer) |
|---------|-----------------------------|---------------------------------|
| X→B | XB slope (strict) | — |
| P→X | XB backward (strict) | — |
| A→B | AC slope | — |
| B→C | XB extension (strict) | AC line (+buffer) |
| C→D | AC extension (strict) | BD line (±buffer) |
| D→E | BD extension (strict) | CE line (±buffer) |
| E→F | CE extension (strict) | DF line (±buffer) |

**Strict** means the price must not touch or cross the slope line.  
**Buffer** means the price can go `slope_buffer_pct%` past the line before failing.

---

## Span Containment Rules

After finding each pair of same-channel points, ALL candles between them on the same side must respect their connecting slope:

| Rule | Scope | Check |
|------|-------|-------|
| X→B containment | All candles between X and B | LOWs ≥ XB (X<A) or HIGHs ≤ XB (X>A) |
| A→C containment | All candles between A and C | HIGHs ≤ AC (X<A) or LOWs ≥ AC (X>A) |
| B→D containment | All candles between B and D | LOWs ≥ BD (X<A) or HIGHs ≤ BD (X>A) |
| C→E containment | All candles between C and E | HIGHs ≤ CE (X<A) or LOWs ≥ CE (X>A) |
| D→F containment | All candles between D and F | LOWs ≥ DF (X<A) or HIGHs ≤ DF (X>A) |

---

**Next:** [Part 4: Golden Line Algorithm](04_GOLDEN_LINE_ALGORITHM.md)
