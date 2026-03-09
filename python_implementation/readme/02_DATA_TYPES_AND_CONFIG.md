# Data Types and Configuration

## Core Types (`core/types.py`)

### Enums

#### PatternType (IntEnum)
Controls how many points the pattern contains. Matches MQL5 ordering.

| Value | Name     | Points        | Description                |
|-------|----------|---------------|----------------------------|
| 0     | XAB      | P, X, A, B    | Three-point pattern        |
| 1     | XABC     | + C           | Four-point pattern         |
| 2     | XABCD    | + D           | Five-point (default)       |
| 3     | XABCDE   | + E           | Six-point pattern          |
| 4     | XABCDEF  | + F           | Full seven-point pattern   |

#### PatternDirection
- `BULLISH` — Only detect bullish patterns (last point < previous point)
- `BEARISH` — Only detect bearish patterns (last point > previous point)
- `BOTH` — Detect both (default)

#### ChannelType
Determines the A-channel slope relative to the XB slope:
- `PARALLEL` — A-channel slope = XB slope (parallel channels)
- `STRAIGHT` — A-channel slope = 0.0 (horizontal A-channel)
- `NON_PARALLEL` — A-channel slope = -XB slope (opposite slope)
- `ALL_TYPES` — Run detection for all three types sequentially

#### DivergenceType
- `NONE` — No divergence filter (default)
- `TIME` — Time-based divergence
- `VOLUME` — Volume-based divergence
- `TIME_VOLUME` — Combined time+volume divergence

#### SignalType
- `BUY` — Golden line generates a buy signal
- `SELL` — Golden line generates a sell signal

### Candle (frozen dataclass)
Single OHLCV bar with MT5-convention index (0 = most recent).

```python
@dataclass(frozen=True, slots=True)
class Candle:
    idx: int        # Bar index (0 = newest, N = oldest)
    open: float
    high: float
    low: float
    close: float
    volume: float
    timestamp: float  # Unix epoch seconds
```

### Wave (dataclass)
Stores all point coordinates for one detected PXABCDEF pattern.

**Fields:**
- `p_idx, p_price` — P point (backward extension of XB slope)
- `x_idx, x_price` — X point (starting anchor)
- `a_idx, a_price` — A point (max deviation from XB slope)
- `b_idx, b_price` — B point (slope partner with X)
- `c_idx, c_price` — C point (first retracement in A-channel)
- `d_idx, d_price` — D point (continuation in XB-channel)
- `e_idx, e_price` — E point (second retracement in A-channel)
- `f_idx, f_price` — F point (final continuation in XB-channel)
- `is_bullish: bool` — Last point < previous point
- `x_less_than_a: bool` — X price < A price (uptrend geometry)

**Methods:**
- `reset()` — Zero out all fields
- `last_point(ptype)` — Return (idx, price) of terminal point
- `prev_point(ptype)` — Return (idx, price) of penultimate point
- `set_last_point(ptype, idx, price)` — Update terminal point

**Critical Distinction: `x_less_than_a` vs `is_bullish`**

These are independent concepts:
- `x_less_than_a` determines channel geometry and validation rule polarity
- `is_bullish` determines pattern direction for filtering and signal type
- A pattern can have `x_less_than_a=True` with `is_bullish=False` (e.g., XABC
  where C is HIGH and B is below C)

### PatternResult
Immutable snapshot of one detected pattern plus its diagnostics.

```python
@dataclass
class PatternResult:
    wave: Wave                        # All point coordinates
    pattern_type: PatternType         # XAB through XABCDEF
    channel_type: ChannelType         # Which channel type detected it
    is_bullish: bool                  # Pattern direction
    diagnostics: List[DiagnosticRecord]  # Full validation trail
    golden_line: Optional[GoldenLineResult]  # Computed after detection
    dynamic_points: List[DynamicPoint]       # Dynamic tracking results
```

### GoldenLineResult
Coordinates and metadata for a computed golden line.

```python
@dataclass
class GoldenLineResult:
    mn_start_idx: int         # M or N point (start of golden line)
    mn_start_price: float
    mn_end_idx: int           # Extended end point
    mn_end_price: float
    signal: Optional[SignalType]     # BUY or SELL (if found)
    signal_idx: Optional[int]       # Bar where signal triggered
    signal_price: Optional[float]
    fg_start_idx: Optional[int]     # FG separator start
    fg_start_price: Optional[float]
    fg_end_idx: Optional[int]       # FG separator end
    fg_end_price: Optional[float]
    slope_selection: str     # Which slope was chosen: "XD", "BD", "AE", etc.
```

### DynamicPoint
One dynamic last-point found during live tracking.

```python
@dataclass
class DynamicPoint:
    idx: int                               # Bar index of dynamic point
    price: float                           # Price at dynamic point
    iteration: int                         # Which iteration (1, 2, 3, ...)
    golden_line: Optional[GoldenLineResult]  # Golden line from this point
```

---

## Configuration (`core/config.py`)

### DetectorConfig

All tunable knobs for the detection engine, organized into groups matching
the MQL5 input parameters.

#### Pattern Type
| Field              | Default      | Description                    |
|--------------------|-------------|--------------------------------|
| `pattern_type`     | XABCD       | Pattern depth to detect        |
| `pattern_direction`| BOTH        | Bullish, Bearish, or Both      |

#### Length Properties
| Field                  | Default | Description                         |
|------------------------|---------|-------------------------------------|
| `b_min`                | 20      | Min bars between X and B            |
| `b_max`                | 100     | Max bars between X and B            |
| `max_search_bars`      | 0       | Max bars to search (0 = all)        |
| `px_length_percentage` | 10.0    | PX length as % of XB distance      |
| `min_b_to_c_btw_x_b`  | 0.0     | Min BC distance as % of XB bars     |
| `max_b_to_c_btw_x_b`  | 100.0   | Max BC distance as % of XB bars     |
| `min_c_to_d_btw_x_b`  | 0.0     | Min CD distance as % of XB bars     |
| `max_c_to_d_btw_x_b`  | 100.0   | Max CD distance as % of XB bars     |
| `min_d_to_e_btw_x_b`  | 0.0     | Min DE distance as % of XB bars     |
| `max_d_to_e_btw_x_b`  | 100.0   | Max DE distance as % of XB bars     |
| `min_e_to_f_btw_x_b`  | 0.0     | Min EF distance as % of XB bars     |
| `max_e_to_f_btw_x_b`  | 100.0   | Max EF distance as % of XB bars     |

#### Retracement Properties
| Field                    | Default | Description                        |
|--------------------------|---------|------------------------------------|
| `max_width_percentage`   | 100.0   | Max A deviation from XB (%)        |
| `min_width_percentage`   | 0.0     | Min A deviation from XB (%)        |
| `x_to_a_b_max`           | 100.0   | Max B retracement of XA (%)        |
| `x_to_a_b_min`           | -100.0  | Min B retracement of XA (%)        |

#### Dynamic Height
| Field                              | Default | Description                 |
|------------------------------------|---------|-----------------------------|
| `every_increasing_of_value`        | 5       | Candle count step size      |
| `width_increasing_percentage_x_to_b`| 0.0    | Height increase per step    |
| `width_increasing_percentage_a_e`  | 0.0     | Vestigial (unused)          |

#### Validation
| Field                      | Default | Description                     |
|----------------------------|---------|---------------------------------|
| `strict_xb_validation`    | False   | Declared but never checked      |
| `only_draw_most_recent`   | True    | Enforce bar spacing             |
| `min_bars_between_patterns`| 10     | Min bars between pattern ends   |
| `slope_buffer_pct`        | 0.0     | Buffer % for AC/BD/CE/DF slopes |

#### Channel Settings
| Field                | Default   | Description                      |
|----------------------|-----------|----------------------------------|
| `channel_type`       | PARALLEL  | Channel slope mode               |
| `xb_upper_width_pct` | 0.5      | XB channel upper band width (%)  |
| `xb_lower_width_pct` | 0.5      | XB channel lower band width (%)  |
| `a_upper_width_pct`  | 0.5      | A channel upper band width (%)   |
| `a_lower_width_pct`  | 0.5      | A channel lower band width (%)   |
| `channel_extension_bars`| 200   | Visual extension past last point |

#### Golden Line Settings
| Field                              | Default | Description                       |
|------------------------------------|---------|-----------------------------------|
| `f_percentage`                     | 50.0    | Starting FG separator height (%)  |
| `fg_increasing_percentage`         | 5       | FG increment per iteration (%)    |
| `first_line_percentage`            | 4.0     | Initial FirstLine slope (%)       |
| `first_line_decrease_percentage`   | 0.01    | FirstLine decrement per step (%)  |
| `max_below_max_above_diff_percentage`| 40.0  | M/N equality tolerance (%)        |
| `mn_buffer_percent`                | 0.0     | MN line safety margin (%)         |
| `mn_length_percent`                | 0.0     | Min MN segment length (%)         |
| `mn_extension_bars`                | 20      | Golden line extension bars        |
| `extension_break_close`            | False   | Use CLOSE for break detection     |

#### Dynamic Tracking
| Field                      | Default | Description                 |
|----------------------------|---------|-----------------------------|
| `enable_dynamic_last_point`| True    | Enable dynamic tracking     |
| `max_dynamic_iterations`   | 10      | Max dynamic updates         |

#### Filters
| Field              | Default    | Description                       |
|--------------------|-----------|-----------------------------------|
| `divergence_type`  | NONE      | Divergence filter mode            |
| `tick_min_speed`   | 500,000   | Min tick speed threshold          |

#### Helper Methods
- `segment_range(ptype)` — Returns `(min_pct, max_pct)` for the segment
- `channel_types_to_run()` — Expands `ALL_TYPES` into three concrete types
