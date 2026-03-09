# PXABCDEF Pattern Detection Engine — Python Implementation

## What This Is

A production-grade Python port of the MetaTrader 5 (MQL5) Expert Advisor
"Golden Line PXABCDEF Channels V3". This engine detects geometric harmonic
wave patterns (PXABCDEF) in candlestick price data, validates them through
a dual-channel system with strict slope rules, computes a proprietary
"Golden Line" trading signal, and tracks dynamic continuation points.

## Architecture

```
detect.bat                   # Run pattern detection (auto-detects data file)
dashboard.bat                # Launch diagnostic dashboard (auto-loads last run)

python_implementation/
    __init__.py              # Package root
    __main__.py              # python -m python_implementation entry
    main.py                  # CLI: detect / dashboard / test commands

    inputs/                  # Configuration layer
        config.xlsx          # Excel config file (edit here to change parameters)
        loader.py            # Reads config.xlsx into DetectorConfig
        create_template.py   # Regenerates config.xlsx with dropdowns/validation

    core/                    # Detection engine (100% independent from UI)
        __init__.py
        types.py             # Data types: Wave, PatternType, Candle, etc.
        config.py            # DetectorConfig — all tunable parameters
        diagnostics.py       # DiagnosticRecord + DiagnosticLog
        channels.py          # Dual-channel geometry (XB + A channels)
        validators.py        # All 24+ slope validation rules
        candidates.py        # C/D/E/F candidate collection and sorting
        detector.py          # Main PatternDetector orchestrator
        golden_line.py       # Golden Line signal algorithm
        dynamic_tracking.py  # Dynamic last point tracking
        filters.py           # Tick speed + divergence filters

    data/                    # Data files + loading layer
        __init__.py
        loader.py            # CSV/Excel loader with MT5 format support
        Data.csv             # Drop any MT5-exported OHLCV file here

    dashboard/               # Interactive diagnostic UI
        __init__.py
        app.py               # Plotly/Dash dashboard (auto-loads on start)

    readme/                  # This documentation
```

## Design Principles

### 1. Separation of Concerns

The `core/` package is 100% independent from `dashboard/` and `data/`.
It never imports from either — it receives data through callback functions
(`PriceFn = Callable[[int], float]`) rather than direct data access.
This means the detection engine can be used:
- With CSV files, Excel files, or live data feeds
- With the Dash dashboard or any other visualization
- In batch processing or real-time trading systems

### 2. Diagnostic-First Architecture

The engine's primary output is not "patterns found" — it is a complete
trail of every validation decision. Every single bar check emits a
`DiagnosticRecord` containing:
- Rule ID and human-readable name
- Which bar was checked and which segment
- The actual price and the threshold it was compared against
- Whether it passed or failed, and the exact operator used
- The buffer amount (if applicable)

This makes the system fully explainable: you can understand exactly
WHY any candle passed or failed any rule.

### 3. Exact MQL5 Parity

Every function, every operator, every edge case mirrors the original
MQL5 source code. The same patterns detected in MetaTrader should be
detected here. Key nuances preserved:
- `x_less_than_a` vs `is_bullish` are independent concepts
- Channel width swapping for X>A patterns
- Secondary A extreme scan between A and B
- Re-validation fixes (1-4) when later points reveal true slopes
- Candidate sorting: `take_extreme_high = !point_is_low`
- Alternating strict/buffer operator pattern across segments

## Quick Start

### Step 1 — Install dependencies
```bash
pip install numpy pandas plotly dash openpyxl
```

### Step 2 — Configure (optional)
Open `python_implementation/inputs/config.xlsx` and adjust parameters.
Key settings: Pattern Type, Channel Type, Slope Buffer %, B Min/Max.
All cells have dropdown validation where applicable.

### Step 3 — Drop your data file
Export an OHLCV CSV from MetaTrader 5 and place it in:
```
python_implementation/data/
```
The engine always picks the **most recently modified** file automatically.

### Step 4 — Run from project root

**Detect patterns:**
```
detect.bat
```
Reads config from `inputs/config.xlsx`, auto-finds the data file, prints all
detected patterns with golden line signals to the console.

**Launch dashboard:**
```
dashboard.bat
```
Opens `http://localhost:8050` — patterns are already rendered on load.
No clicks required. Use the "Detect Patterns" button to re-run with
changed settings.

### Advanced: CLI overrides
```bash
# Override specific settings (all others still come from config.xlsx)
python -m python_implementation.main detect --pattern XABCD --channel EQ --buffer 2.5

# Explicit data file
python -m python_implementation.main detect path/to/data.csv

# Run tests
python -m python_implementation.main test
```

## Dependencies

| Package    | Purpose                                    | Required |
|------------|--------------------------------------------|----------|
| numpy      | Vectorized candle storage and math         | Yes      |
| pandas     | CSV and Excel file loading                 | Yes      |
| plotly     | Interactive chart rendering                | Dashboard only |
| dash       | Web-based diagnostic dashboard             | Dashboard only |
| openpyxl   | Excel (.xlsx) file support                 | Excel only |
