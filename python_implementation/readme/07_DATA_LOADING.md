# Data Loading (`data/loader.py`)

## Overview

The data loading layer converts CSV and Excel files into the `CandleArray`
format consumed by the detection engine. It handles MetaTrader 5 export
quirks automatically.

## CandleArray

The primary data structure — vectorized candle storage using numpy arrays.

```python
@dataclass(frozen=True, slots=True)
class CandleArray:
    open: np.ndarray
    high: np.ndarray
    low: np.ndarray
    close: np.ndarray
    volume: np.ndarray
    timestamp: np.ndarray  # Unix epoch seconds
```

All arrays use MT5 bar-index convention:
- `arr[0]` = most recent bar
- `arr[N-1]` = oldest bar

### Accessor Methods

```python
candles.high_at(idx)    # HIGH price at bar index
candles.low_at(idx)     # LOW price at bar index
candles.close_at(idx)   # CLOSE price at bar index
candles.volume_at(idx)  # VOLUME at bar index
candles.time_at(idx)    # Timestamp (Unix epoch) at bar index
```

These accessors are passed to the detection engine as `PriceFn` callbacks,
maintaining the separation between data layer and core engine.

## Loading Functions

### `load_file(path, **kwargs)` — Auto-detect

Automatically detects file type by extension and delegates:
- `.xlsx` / `.xls` -> `load_excel()`
- Everything else -> `load_csv()`

```python
from python_implementation.data.loader import load_file

data = load_file("USDJPY_M1.csv")      # CSV
data = load_file("USDJPY_M1.xlsx")     # Excel
```

### `load_csv(path, date_col, date_format, reverse)`

Loads OHLCV data from a CSV file.

**Parameters:**
- `path` — Path to CSV file
- `date_col` — Column name for date/time (default: `"time"`)
- `date_format` — strptime format string (auto-detected if None)
- `reverse` — Reverse rows so index 0 = most recent (default: True)

### `load_excel(path, sheet_name, date_col, date_format, reverse)`

Loads OHLCV data from an Excel file. Same parameters as `load_csv` plus:
- `sheet_name` — Sheet name or index (default: first sheet)

Requires `openpyxl` package: `pip install openpyxl`

### `from_arrays(open_, high, low, close, volume, timestamp)`

Build a `CandleArray` from raw Python sequences (already in MT5 order).

## Column Name Normalization

The loader handles various column naming conventions automatically:

### Angle-Bracket Stripping
MT5 exports use `<DATE>`, `<TIME>`, `<OPEN>`, etc. These angle brackets
are stripped and names are lowercased:
```
<DATE> -> date
<OPEN> -> open
<TICKVOL> -> tickvol
```

### Separate DATE + TIME Merging
When separate `date` and `time` columns exist (common in MT5 CSV exports),
they are automatically merged:
```
date="2024.08.01" + time="7:09:00" -> datetime="2024.08.01 7:09:00"
```

### Column Aliases
Common variants are mapped to canonical names:

| Source Name    | Mapped To |
|---------------|-----------|
| `date`        | `time`    |
| `datetime`    | `time`    |
| `timestamp`   | `time`    |
| `o`           | `open`    |
| `h`           | `high`    |
| `l`           | `low`     |
| `c`           | `close`   |
| `vol`         | `volume`  |
| `tick_volume` | `volume`  |
| `tickvol`     | `volume`  |

## MT5 Index Convention

MetaTrader 5 uses a reverse index where `0` is the most recent bar and
higher indices go further into the past. The loader performs this reversal
by default (`reverse=True`), flipping CSV/Excel rows (which are typically
chronological, oldest first) so that `index 0 = newest bar`.

## Supported CSV Format

The sample data file uses this MT5 CSV export format:

```csv
<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<TICKVOL>,<VOL>,<SPREAD>
2024.08.01,7:09:00,149.431,149.472,149.43,149.455,46,0,2
2024.08.01,7:10:00,149.454,149.48,149.417,149.421,46,0,2
```

The loader handles this format automatically — angle brackets are stripped,
DATE and TIME columns are merged, and TICKVOL is mapped to volume.
