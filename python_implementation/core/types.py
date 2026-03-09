"""Core data types for the PXABCDEF pattern detection engine.

Every type here is a plain data container — no business logic, no imports
from other engine modules. This keeps the dependency graph acyclic and
makes serialisation trivial.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum, IntEnum
from typing import List, Optional


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class PatternType(IntEnum):
    """How many points the pattern contains (matches MQL5 ordering)."""
    XAB = 0
    XABC = 1
    XABCD = 2
    XABCDE = 3
    XABCDEF = 4


class PatternDirection(Enum):
    """User-level directional filter."""
    BULLISH = "bullish"
    BEARISH = "bearish"
    BOTH = "both"


class ChannelType(Enum):
    """A-channel slope mode."""
    PARALLEL = "parallel"
    STRAIGHT = "straight"
    NON_PARALLEL = "non_parallel"
    ALL_TYPES = "all_types"


class DivergenceType(Enum):
    """Divergence filter variants."""
    NONE = "none"
    TIME = "time"
    VOLUME = "volume"
    TIME_VOLUME = "time_volume"


class SignalType(Enum):
    """Trade signal emitted by the golden line algorithm."""
    BUY = "buy"
    SELL = "sell"


# ---------------------------------------------------------------------------
# Candle
# ---------------------------------------------------------------------------

@dataclass(frozen=True, slots=True)
class Candle:
    """Single OHLCV bar.

    ``idx`` is the MT5-style bar index (0 = most recent, increasing
    into the past).  When working with a pandas DataFrame the caller
    maps row positions to this convention.
    """
    idx: int
    open: float
    high: float
    low: float
    close: float
    volume: float
    timestamp: float  # Unix epoch seconds


# ---------------------------------------------------------------------------
# Wave (detected pattern)
# ---------------------------------------------------------------------------

@dataclass
class Wave:
    """Stores all point coordinates for one detected PXABCDEF pattern.

    Field pairs ``(x_idx, x_price)`` etc. follow the MQL5 convention
    where ``idx`` is the bar index (higher = further in the past).
    """
    p_idx: int = 0
    p_price: float = 0.0
    x_idx: int = 0
    x_price: float = 0.0
    a_idx: int = 0
    a_price: float = 0.0
    b_idx: int = 0
    b_price: float = 0.0
    c_idx: int = 0
    c_price: float = 0.0
    d_idx: int = 0
    d_price: float = 0.0
    e_idx: int = 0
    e_price: float = 0.0
    f_idx: int = 0
    f_price: float = 0.0

    is_bullish: bool = False
    x_less_than_a: bool = False

    def reset(self) -> None:
        """Zero out all fields — mirrors MQL5 ``reset_wave``."""
        for fld in (
            "p_idx", "x_idx", "a_idx", "b_idx",
            "c_idx", "d_idx", "e_idx", "f_idx",
        ):
            setattr(self, fld, 0)
        for fld in (
            "p_price", "x_price", "a_price", "b_price",
            "c_price", "d_price", "e_price", "f_price",
        ):
            setattr(self, fld, 0.0)
        self.is_bullish = False
        self.x_less_than_a = False

    def last_point(self, ptype: PatternType) -> tuple[int, float]:
        """Return (idx, price) of the terminal point for *ptype*."""
        mapping = {
            PatternType.XAB: (self.b_idx, self.b_price),
            PatternType.XABC: (self.c_idx, self.c_price),
            PatternType.XABCD: (self.d_idx, self.d_price),
            PatternType.XABCDE: (self.e_idx, self.e_price),
            PatternType.XABCDEF: (self.f_idx, self.f_price),
        }
        return mapping[ptype]

    def prev_point(self, ptype: PatternType) -> tuple[int, float]:
        """Return (idx, price) of the penultimate point for *ptype*."""
        mapping = {
            PatternType.XAB: (self.a_idx, self.a_price),
            PatternType.XABC: (self.b_idx, self.b_price),
            PatternType.XABCD: (self.c_idx, self.c_price),
            PatternType.XABCDE: (self.d_idx, self.d_price),
            PatternType.XABCDEF: (self.e_idx, self.e_price),
        }
        return mapping[ptype]

    def set_last_point(self, ptype: PatternType, idx: int, price: float) -> None:
        """Update the terminal point for *ptype*."""
        attr_map = {
            PatternType.XAB: ("b_idx", "b_price"),
            PatternType.XABC: ("c_idx", "c_price"),
            PatternType.XABCD: ("d_idx", "d_price"),
            PatternType.XABCDE: ("e_idx", "e_price"),
            PatternType.XABCDEF: ("f_idx", "f_price"),
        }
        idx_attr, price_attr = attr_map[ptype]
        setattr(self, idx_attr, idx)
        setattr(self, price_attr, price)


# ---------------------------------------------------------------------------
# Detection result
# ---------------------------------------------------------------------------

@dataclass
class PatternResult:
    """Immutable snapshot of one detected pattern plus its diagnostics."""
    wave: Wave
    pattern_type: PatternType
    channel_type: ChannelType
    is_bullish: bool
    diagnostics: List["DiagnosticRecord"] = field(default_factory=list)
    golden_line: Optional["GoldenLineResult"] = None
    dynamic_points: List["DynamicPoint"] = field(default_factory=list)


@dataclass
class GoldenLineResult:
    """Coordinates and metadata for a computed golden line."""
    mn_start_idx: int
    mn_start_price: float
    mn_end_idx: int
    mn_end_price: float
    signal: Optional[SignalType] = None
    signal_idx: Optional[int] = None
    signal_price: Optional[float] = None
    fg_start_idx: Optional[int] = None
    fg_start_price: Optional[float] = None
    fg_end_idx: Optional[int] = None
    fg_end_price: Optional[float] = None
    slope_selection: str = ""  # e.g. "XD" or "BD" — which slope was chosen


@dataclass
class DynamicPoint:
    """One dynamic last-point found during live tracking."""
    idx: int
    price: float
    iteration: int
    golden_line: Optional[GoldenLineResult] = None


# ---------------------------------------------------------------------------
# Forward-reference placeholder (defined in diagnostics.py)
# ---------------------------------------------------------------------------

# DiagnosticRecord is imported at runtime by modules that need it.
# Keeping it out of this file avoids a circular import.


# ---------------------------------------------------------------------------
# Per-candle detection tracing (for the interactive dashboard)
# ---------------------------------------------------------------------------

@dataclass
class StepLog:
    """One gate in the detection cascade for a single X→B attempt."""
    step: str           # e.g. "B_SEARCH", "XB_RETRACE", "A_WIDTH"
    passed: bool
    detail: str         # human-readable explanation
    value: float = 0.0  # primary numeric value tested
    threshold_min: float = 0.0
    threshold_max: float = 0.0


@dataclass
class XAttemptLog:
    """Full trace of one attempt to build a pattern starting from X.

    One XAttemptLog is produced per (x_idx, x_is_low, b_idx) combination
    that the detector tries.  When collect_traces=True is passed to
    PatternDetector.find_all(), these are collected into a dict keyed
    by x_idx for the interactive log panel.
    """
    x_idx: int
    x_is_low: bool      # True = X is a swing LOW candidate
    b_idx: int = -1     # B candidate tried (-1 = no B found)
    b_price: float = 0.0
    step_reached: str = "B_SEARCH"   # last step before rejection/success
    rejected_at: str = ""            # "" when pattern succeeded
    succeeded: bool = False
    steps: List[StepLog] = field(default_factory=list)

    def add_step(self, step: str, passed: bool, detail: str,
                 value: float = 0.0,
                 threshold_min: float = 0.0,
                 threshold_max: float = 0.0) -> "StepLog":
        s = StepLog(step=step, passed=passed, detail=detail,
                    value=value, threshold_min=threshold_min,
                    threshold_max=threshold_max)
        self.steps.append(s)
        self.step_reached = step
        return s

    def reject(self, step: str, reason: str,
               value: float = 0.0,
               threshold_min: float = 0.0,
               threshold_max: float = 0.0) -> None:
        self.add_step(step, False, reason, value, threshold_min, threshold_max)
        self.rejected_at = reason
        self.succeeded = False

    def succeed(self, detail: str = "Pattern confirmed") -> None:
        self.add_step("FINALIZE", True, detail)
        self.succeeded = True
        self.rejected_at = ""
