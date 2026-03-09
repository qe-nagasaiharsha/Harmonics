# Dashboard and CLI

## CLI Entry Point (`main.py`)

The engine provides three commands:

### `detect` — Run Pattern Detection

```bash
python -m python_implementation.main detect <data_file> [options]
```

**Arguments:**
| Argument       | Default    | Description                          |
|----------------|-----------|--------------------------------------|
| `data_file`    | (required) | Path to CSV or Excel file            |
| `--pattern`    | XABCD     | XAB, XABC, XABCD, XABCDE, XABCDEF  |
| `--channel`    | parallel  | parallel, straight, non_parallel, all_types |
| `--buffer`     | 0.0       | Slope buffer percentage              |
| `--b-min`      | 20        | Minimum bars X to B                  |
| `--b-max`      | 100       | Maximum bars X to B                  |
| `--max-bars`   | 0         | Max bars to search (0 = all)         |
| `--json-output`| ""        | Path to write JSON results           |

**Example:**
```bash
python -m python_implementation.main detect data/USDJPY_M1.csv --pattern XABCD --channel parallel --buffer 0.5
```

**Output:**
```
Loading data from: data/USDJPY_M1.csv
Loaded 19157 bars

Found 3 pattern(s)

--- Pattern #0 [XABCD] [BULLISH] ---
  Channel: parallel
  P: idx=85 price=149.23500
  X: idx=78 price=149.28000
  A: idx=65 price=149.45000
  B: idx=52 price=149.31000
  C: idx=43 price=149.41000
  D: idx=35 price=149.29500
  x_less_than_a: True
  Golden Line: BD | start=(47, 149.38500) -> end=(15, 149.27000)
  Signal: BUY at idx=31
  Dynamic Points: 2
    L1: idx=28 price=149.27500
    L2: idx=21 price=149.26000
  Diagnostics: 142 checks (0 failed)
```

### `dashboard` — Launch Interactive Dashboard

```bash
python -m python_implementation.main dashboard [options]
```

| Argument  | Default | Description              |
|-----------|---------|--------------------------|
| `--port`  | 8050    | Server port              |
| `--debug` | False   | Enable Dash debug mode   |

Opens at `http://localhost:8050` in your browser.

### `test` — Quick Validation

```bash
python -m python_implementation.main test
```

Runs import checks and basic type/function tests. No data file needed.

---

## Batch Files

### `detect.bat`

Quick pattern detection from the command line:

```bash
detect.bat data\USDJPY_M1.csv
detect.bat data\USDJPY_M1.csv --pattern XABCDE --buffer 0.3
```

### `dashboard.bat`

Launch the diagnostic dashboard:

```bash
dashboard.bat
dashboard.bat --port 9000
```

---

## Interactive Dashboard (`dashboard/app.py`)

### Features

1. **Candlestick Chart** — Full OHLCV chart with volume subplot
2. **Pattern Overlays** — Detected patterns drawn as connected lines
3. **Point Labels** — X, A, B, C, D, E, F labels on chart
4. **Channel Lines** — XB and A channel center lines (dotted)
5. **Golden Lines** — MN line drawn in gold (width 3)
6. **Signal Arrows** — BUY/SELL arrows at signal points
7. **Diagnostic Table** — Per-bar pass/fail for every validation rule

### Controls

| Control          | Description                                      |
|------------------|--------------------------------------------------|
| CSV File         | Path to OHLCV data file (CSV or Excel)           |
| Pattern Type     | XAB through XABCDEF                              |
| Channel Type     | Parallel, Straight, Non-Parallel, All Types      |
| Slope Buffer %   | Buffer percentage for validation rules           |
| B Min / B Max    | Bar range for B candidate search                 |
| Detect Patterns  | Run detection with current settings              |

### Diagnostic Panel

After detection, select any pattern from the dropdown to view its
complete diagnostic trail. The table shows:

| Column    | Description                                       |
|-----------|---------------------------------------------------|
| Rule      | Spec rule ID (e.g., "1.4", "Fix2", "1.15/2.15")  |
| Name      | Human-readable rule name                          |
| Segment   | Which segment was checked                         |
| Bar       | Bar index that was tested                         |
| Pass      | PASS (green) or FAIL (red)                        |
| Type      | "strict" or "buffer"                              |
| Price     | Actual candle price (HIGH or LOW)                 |
| Threshold | Slope/channel value it was compared against       |
| Details   | Tooltip with full explanation                     |

Failed checks are highlighted in red background.

### Architecture

The dashboard is built with:
- **Plotly** for interactive charts (candlestick, volume, overlays)
- **Dash** for the web application framework and callbacks
- **Dark theme** optimized for financial chart viewing

The dashboard imports from `core/` but `core/` never imports from
`dashboard/`. This means the detection engine works perfectly without
the dashboard installed.
