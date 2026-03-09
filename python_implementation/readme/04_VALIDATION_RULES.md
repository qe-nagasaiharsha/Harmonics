# Validation Rules (`core/validators.py`)

## Overview

Every validation function iterates over candles in a segment and checks
HIGH or LOW prices against slope boundaries. Every single bar check emits
a `DiagnosticRecord` BEFORE returning pass/fail.

Rule numbering follows the spec:
- **Case 1** (X < A): rules 1.1 - 1.17
- **Case 2** (X > A): rules 2.1 - 2.17

## Operator Conventions

- **Strict** (red line): No buffer applied. Exact comparison operators.
- **Buffer** (blue line): `slope_buffer_pct` applied as `|slope_val| * pct / 100`.

The strict/buffer pattern alternates between segments:
- **Odd segments** (B->C, D->E): XB-side is strict, A-side has buffer
- **Even segments** (C->D, E->F): A-side is strict, XB-side has buffer

---

## Segment Rules

### PX Segment (rules 1.1 / 2.1) - STRICT

Validates backward extension from X.

| Case | Rule | Check | Operator | Fails when      |
|------|------|-------|----------|-----------------|
| X<A  | 1.1  | LOWs  | `<`      | LOW < PX value  |
| X>A  | 2.1  | HIGHs | `>`      | HIGH > PX value |

### XB Segment (rules 1.2 / 2.2) - STRICT

Validates candles between X and B against XB slope line.

| Case | Rule | Check | Operator | Fails when       |
|------|------|-------|----------|------------------|
| X<A  | 1.2  | LOWs  | `<=`     | LOW <= XB value  |
| X>A  | 2.2  | HIGHs | `>=`     | HIGH >= XB value |

### AB Segment (rules 1.3 / 2.3) - BUFFER

Validates A->B candles against AC proxy slope with buffer.

| Case | Rule | Check | Threshold      | Fails when            |
|------|------|-------|----------------|-----------------------|
| X<A  | 1.3  | HIGHs | AC + buffer    | HIGH > AC + buffer    |
| X>A  | 2.3  | LOWs  | AC - buffer    | LOW < AC - buffer     |

**Fix 1** re-validates this segment with real AC slope after C is found.

### BC Segment (rules 1.4+1.5 / 2.4+2.5) - MIXED

Two checks per bar: XB extension (strict) + AC slope (buffer).

| Case | Rule | Check | Type   | Threshold   | Fails when          |
|------|------|-------|--------|-------------|---------------------|
| X<A  | 1.4  | LOWs  | strict | XB ext      | LOW < XB ext        |
| X<A  | 1.5  | HIGHs | buffer | AC + buffer | HIGH > AC + buffer  |
| X>A  | 2.4  | HIGHs | strict | XB ext      | HIGH > XB ext       |
| X>A  | 2.5  | LOWs  | buffer | AC - buffer | LOW < AC - buffer   |

**Fix 2** re-validates B->C against BD slope after D is found.

### CD Segment (rules 1.6+1.7 / 2.6+2.7) - MIXED

| Case | Rule | Check | Type   | Threshold   | Fails when          |
|------|------|-------|--------|-------------|---------------------|
| X<A  | 1.6  | HIGHs | strict | AC ext      | HIGH >= AC ext      |
| X<A  | 1.7  | LOWs  | buffer | BD - buffer | LOW < BD - buffer   |
| X>A  | 2.6  | LOWs  | strict | AC ext      | LOW <= AC ext       |
| X>A  | 2.7  | HIGHs | buffer | BD + buffer | HIGH > BD + buffer  |

**Fix 3** re-validates C->D against CE slope after E is found.

### DE Segment (rules 1.8+1.9 / 2.8+2.9) - MIXED

| Case | Rule | Check | Type   | Threshold   | Fails when          |
|------|------|-------|--------|-------------|---------------------|
| X<A  | 1.8  | LOWs  | strict | BD ext      | LOW <= BD ext       |
| X<A  | 1.9  | HIGHs | buffer | CE + buffer | HIGH > CE + buffer  |
| X>A  | 2.8  | HIGHs | strict | BD ext      | HIGH >= BD ext      |
| X>A  | 2.9  | LOWs  | buffer | CE - buffer | LOW < CE - buffer   |

**Fix 4** re-validates D->E against DF slope after F is found.

### EF Segment (rules 1.10+1.11 / 2.10+2.11) - MIXED

| Case | Rule  | Check | Type   | Threshold   | Fails when          |
|------|-------|-------|--------|-------------|---------------------|
| X<A  | 1.10  | HIGHs | strict | CE ext      | HIGH >= CE ext      |
| X<A  | 1.11  | LOWs  | buffer | DF - buffer | LOW < DF - buffer   |
| X>A  | 2.10  | LOWs  | strict | CE ext      | LOW <= CE ext       |
| X>A  | 2.11  | HIGHs | buffer | DF + buffer | HIGH > DF + buffer  |

---

## Span Containment (rules 1.13-1.17 / 2.13-2.17)

Same-side points are connected by a slope line. ALL candles between them
must stay within this slope + buffer.

| Rule       | Span | check_upper | X<A Check             | X>A Check             |
|------------|------|-------------|------------------------|-----------------------|
| 1.13/2.13  | X->B | !x_lt_a     | LOWs >= slope - buf    | HIGHs <= slope + buf  |
| 1.14/2.14  | A->C | x_lt_a      | HIGHs <= slope + buf   | LOWs >= slope - buf   |
| 1.15/2.15  | B->D | !x_lt_a     | LOWs >= slope - buf    | HIGHs <= slope + buf  |
| 1.16/2.16  | C->E | x_lt_a      | HIGHs <= slope + buf   | LOWs >= slope - buf   |
| 1.17/2.17  | D->F | !x_lt_a     | LOWs >= slope - buf    | HIGHs <= slope + buf  |

The `check_upper` parameter alternates with each span:
- XB-side spans (X->B, B->D, D->F): `check_upper = !x_less_than_a`
- A-side spans (A->C, C->E): `check_upper = x_less_than_a`

---

## Diagnostics

Every bar check creates a `DiagnosticRecord`:

```python
DiagnosticRecord(
    rule_id="1.4",                    # Spec rule reference
    rule_name="BC XB-ext strict support",  # Human-readable
    segment="B->C",                   # Which segment
    bar_idx=42,                       # Which bar was tested
    passed=True,                      # Pass or fail
    check_type="strict",              # "strict" or "buffer"
    price_checked=149.35,             # Actual candle price
    threshold=149.28,                 # What it was compared against
    operator="<",                     # The comparison operator
    buffer_value=0.0,                 # Buffer amount (0 for strict)
    details="LOW=149.35 vs XB_ext=149.28"  # Tooltip text
)
```

This means you can inspect every single decision the engine made, at
every single bar, for every rule — even for patterns that were rejected.
