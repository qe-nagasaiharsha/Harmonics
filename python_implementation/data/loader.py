"""Data loading utilities for OHLCV candle data.

Supports CSV and Excel files exported from MetaTrader 5 or any source
with columns: ``date/time, open, high, low, close, volume``.

Handles MT5 export formats including:
  - Angle-bracket column names: ``<DATE>``, ``<TIME>``, ``<OPEN>``, etc.
  - Separate DATE + TIME columns that need merging
  - ``<TICKVOL>`` and ``<VOL>`` as volume aliases

The loader converts data into the MT5 bar-index convention where
index 0 = most recent bar and indices increase into the past.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Sequence

import numpy as np

try:
    import pandas as pd
    HAS_PANDAS = True
except ImportError:
    HAS_PANDAS = False

try:
    import openpyxl  # noqa: F401
    HAS_OPENPYXL = True
except ImportError:
    HAS_OPENPYXL = False


@dataclass(frozen=True, slots=True)
class CandleArray:
    """Vectorised candle storage for fast indexed access.

    All arrays are indexed in MT5 convention:
      ``arr[0]`` = most recent bar, ``arr[N-1]`` = oldest bar.

    This is the primary data structure consumed by the detection engine.
    """
    open: np.ndarray
    high: np.ndarray
    low: np.ndarray
    close: np.ndarray
    volume: np.ndarray
    timestamp: np.ndarray  # Unix epoch seconds

    def __len__(self) -> int:
        return len(self.high)

    def high_at(self, idx: int) -> float:
        """Return HIGH price at bar index *idx*."""
        return float(self.high[idx])

    def low_at(self, idx: int) -> float:
        """Return LOW price at bar index *idx*."""
        return float(self.low[idx])

    def close_at(self, idx: int) -> float:
        """Return CLOSE price at bar index *idx*."""
        return float(self.close[idx])

    def volume_at(self, idx: int) -> float:
        """Return VOLUME at bar index *idx*."""
        return float(self.volume[idx])

    def time_at(self, idx: int) -> float:
        """Return timestamp (Unix epoch) at bar index *idx*."""
        return float(self.timestamp[idx])


def _normalize_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Normalise column names and merge DATE+TIME if present.

    Handles MT5 export quirks:
      - Strip angle brackets: ``<DATE>`` → ``date``
      - Merge separate ``date`` + ``time`` columns into ``datetime``
      - Map common aliases to canonical names
    """
    # Strip angle brackets and whitespace, lowercase
    df.columns = [c.strip().strip("<>").strip().lower() for c in df.columns]

    # Merge separate date + time columns (MT5 CSV export format)
    if "date" in df.columns and "time" in df.columns and "datetime" not in df.columns:
        df["datetime"] = df["date"].astype(str) + " " + df["time"].astype(str)
        df.drop(columns=["date", "time"], inplace=True)

    # Prefer tickvol over vol for volume (MT5 exports both; tickvol has data)
    if "tickvol" in df.columns:
        df["volume"] = df["tickvol"]
        df.drop(columns=["tickvol"], inplace=True)
        if "vol" in df.columns:
            df.drop(columns=["vol"], inplace=True)

    # Map common column name variants to canonical names
    col_map = {
        "datetime": "time", "date": "time", "timestamp": "time",
        "o": "open", "h": "high", "l": "low", "c": "close",
        "vol": "volume", "tick_volume": "volume",
    }
    df.rename(columns={k: v for k, v in col_map.items() if k in df.columns}, inplace=True)

    return df


def load_csv(
    path: str | Path,
    date_col: str = "time",
    date_format: Optional[str] = None,
    reverse: bool = True,
) -> CandleArray:
    """Load OHLCV data from a CSV file.

    Supports MetaTrader 5 CSV export format with angle-bracket headers
    (``<DATE>,<TIME>,<OPEN>,...``) and separate DATE/TIME columns.

    Args:
        path: Path to CSV file.
        date_col: Column name for date/time (after normalization).
        date_format: strptime format string (auto-detected if None).
        reverse: If True (default), reverse rows so index 0 = most recent.

    Returns:
        A ``CandleArray`` ready for the detection engine.
    """
    if not HAS_PANDAS:
        raise ImportError("pandas is required for CSV loading: pip install pandas")

    filepath = Path(path)
    if not filepath.exists():
        raise FileNotFoundError(f"File not found: {filepath}")

    df = pd.read_csv(filepath)
    df = _normalize_dataframe(df)

    date_col_norm = date_col.lower()
    if date_col_norm in df.columns:
        df[date_col_norm] = pd.to_datetime(df[date_col_norm], format=date_format)
        timestamps = df[date_col_norm].astype("datetime64[s]").astype(np.int64)
    else:
        timestamps = np.arange(len(df), dtype=np.float64)

    if "volume" not in df.columns:
        df["volume"] = 0.0

    if reverse:
        df = df.iloc[::-1].reset_index(drop=True)
        timestamps = timestamps.values[::-1] if hasattr(timestamps, "values") else timestamps[::-1]

    return CandleArray(
        open=df["open"].values.astype(np.float64),
        high=df["high"].values.astype(np.float64),
        low=df["low"].values.astype(np.float64),
        close=df["close"].values.astype(np.float64),
        volume=df["volume"].values.astype(np.float64),
        timestamp=np.asarray(timestamps, dtype=np.float64),
    )


def load_excel(
    path: str | Path,
    sheet_name: str | int = 0,
    date_col: str = "time",
    date_format: Optional[str] = None,
    reverse: bool = True,
) -> CandleArray:
    """Load OHLCV data from an Excel (.xlsx) file.

    Handles the same column-name normalization as ``load_csv``, including
    MT5-style angle-bracket headers and separate DATE/TIME columns.

    Args:
        path: Path to Excel file.
        sheet_name: Sheet name or index (default: first sheet).
        date_col: Column name for date/time (after normalization).
        date_format: strptime format string (auto-detected if None).
        reverse: If True (default), reverse rows so index 0 = most recent.

    Returns:
        A ``CandleArray`` ready for the detection engine.
    """
    if not HAS_PANDAS:
        raise ImportError("pandas is required for Excel loading: pip install pandas")
    if not HAS_OPENPYXL:
        raise ImportError("openpyxl is required for Excel loading: pip install openpyxl")

    filepath = Path(path)
    if not filepath.exists():
        raise FileNotFoundError(f"File not found: {filepath}")

    df = pd.read_excel(filepath, sheet_name=sheet_name)
    df = _normalize_dataframe(df)

    date_col_norm = date_col.lower()
    if date_col_norm in df.columns:
        df[date_col_norm] = pd.to_datetime(df[date_col_norm], format=date_format)
        timestamps = df[date_col_norm].astype("datetime64[s]").astype(np.int64)
    else:
        timestamps = np.arange(len(df), dtype=np.float64)

    if "volume" not in df.columns:
        df["volume"] = 0.0

    if reverse:
        df = df.iloc[::-1].reset_index(drop=True)
        timestamps = timestamps.values[::-1] if hasattr(timestamps, "values") else timestamps[::-1]

    return CandleArray(
        open=df["open"].values.astype(np.float64),
        high=df["high"].values.astype(np.float64),
        low=df["low"].values.astype(np.float64),
        close=df["close"].values.astype(np.float64),
        volume=df["volume"].values.astype(np.float64),
        timestamp=np.asarray(timestamps, dtype=np.float64),
    )


def load_file(
    path: str | Path,
    **kwargs,
) -> CandleArray:
    """Auto-detect file type (CSV or Excel) and load accordingly.

    Delegates to ``load_csv`` or ``load_excel`` based on file extension.
    All keyword arguments are forwarded to the appropriate loader.
    """
    filepath = Path(path)
    ext = filepath.suffix.lower()
    if ext in (".xlsx", ".xls"):
        return load_excel(filepath, **kwargs)
    return load_csv(filepath, **kwargs)


def from_arrays(
    open_: Sequence[float],
    high: Sequence[float],
    low: Sequence[float],
    close: Sequence[float],
    volume: Optional[Sequence[float]] = None,
    timestamp: Optional[Sequence[float]] = None,
) -> CandleArray:
    """Build a ``CandleArray`` from raw sequences (already in MT5 index order).

    Index 0 must be the most recent bar.
    """
    n = len(high)
    return CandleArray(
        open=np.asarray(open_, dtype=np.float64),
        high=np.asarray(high, dtype=np.float64),
        low=np.asarray(low, dtype=np.float64),
        close=np.asarray(close, dtype=np.float64),
        volume=np.asarray(volume if volume is not None else [0.0] * n, dtype=np.float64),
        timestamp=np.asarray(timestamp if timestamp is not None else np.arange(n, dtype=np.float64)),
    )
