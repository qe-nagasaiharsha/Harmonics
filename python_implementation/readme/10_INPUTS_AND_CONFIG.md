# Inputs and Configuration (`inputs/`)

## Overview

All detection parameters are stored in an Excel workbook so they can be
edited without touching Python code. The `inputs/` folder contains:

```
inputs/
    config.xlsx          # The active configuration file (edit this)
    loader.py            # Reads config.xlsx -> DetectorConfig + data path
    create_template.py   # Regenerates config.xlsx with fresh defaults
```

---

## config.xlsx

The workbook has a single sheet with two columns:

| Column A (Parameter) | Column B (Value)  |
|----------------------|-------------------|
| pattern_type         | XABCD             |
| channel_type         | parallel          |
| slope_buffer_pct     | 0.0               |
| ...                  | ...               |
| data_file_path       | (path or blank)   |

### Enum fields — dropdowns

Cells for enum parameters have Excel Data Validation dropdowns so you
can only pick valid values:

| Parameter          | Valid Values                                     |
|--------------------|--------------------------------------------------|
| `pattern_type`     | XAB, XABC, XABCD, XABCDE, XABCDEF              |
| `channel_type`     | parallel, straight, non_parallel, all_types      |
| `pattern_direction`| bullish, bearish, both                           |
| `divergence_type`  | none, time, volume, time_volume                  |

### Number fields — editable cells

All numeric parameters (integers, floats, booleans stored as 0/1) are
free-form editable cells with their default value pre-filled.

### `data_file_path`

Optional. If set, `detect.bat` and the dashboard will use this file
instead of auto-detecting. Leave blank to let the engine pick the most
recently modified file in `data/`.

---

## Config Priority

The three-tier priority applies throughout the system:

```
CLI argument (explicit flag)
    |
    v
config.xlsx value
    |
    v
DetectorConfig Python default
```

In the **dashboard**, the priority is:

```
UI control value (after clicking Detect)
    |
    v
config.xlsx value (base for ALL other parameters)
    |
    v
DetectorConfig Python default
```

This means: change `xb_upper_width_pct` in Excel to affect channel widths;
the dashboard will pick it up on the next "Detect Patterns" click.

---

## Full Parameter Reference

### Pattern Type
| Parameter           | Default | Type       | Description                          |
|---------------------|---------|------------|--------------------------------------|
| `pattern_type`      | XABCD   | enum       | Pattern depth: XAB through XABCDEF  |
| `pattern_direction` | both    | enum       | bullish, bearish, or both            |

### Length Properties
| Parameter                    | Default | Type  | Description                           |
|------------------------------|---------|-------|---------------------------------------|
| `b_min`                      | 20      | int   | Min bars between X and B              |
| `b_max`                      | 100     | int   | Max bars between X and B              |
| `max_search_bars`            | 0       | int   | Search depth (0 = all history)        |
| `px_length_percentage`       | 10.0    | float | PX extension as % of XB bars          |
| `min_b_to_c_btw_x_b`        | 0.0     | float | Min B->C length as % of XB bars       |
| `max_b_to_c_btw_x_b`        | 100.0   | float | Max B->C length as % of XB bars       |
| `min_c_to_d_btw_x_b`        | 0.0     | float | Min C->D length as % of XB bars       |
| `max_c_to_d_btw_x_b`        | 100.0   | float | Max C->D length as % of XB bars       |
| `min_d_to_e_btw_x_b`        | 0.0     | float | Min D->E length as % of XB bars       |
| `max_d_to_e_btw_x_b`        | 100.0   | float | Max D->E length as % of XB bars       |
| `min_e_to_f_btw_x_b`        | 0.0     | float | Min E->F length as % of XB bars       |
| `max_e_to_f_btw_x_b`        | 100.0   | float | Max E->F length as % of XB bars       |

### Retracement Properties
| Parameter             | Default  | Type  | Description                        |
|-----------------------|----------|-------|------------------------------------|
| `max_width_percentage`| 100.0    | float | Max A deviation from XB line (%)   |
| `min_width_percentage`| 0.0      | float | Min A deviation from XB line (%)   |
| `x_to_a_b_max`        | 100.0    | float | Max B retracement of XA range (%)  |
| `x_to_a_b_min`        | -100.0   | float | Min B retracement of XA range (%)  |

### Dynamic Height
| Parameter                          | Default | Type  | Description                    |
|------------------------------------|---------|-------|--------------------------------|
| `every_increasing_of_value`        | 5       | int   | Step size in candles           |
| `width_increasing_percentage_x_to_b`| 0.0   | float | Width increase per step        |
| `width_increasing_percentage_a_e`  | 0.0     | float | AE width increase per step     |

### Validation
| Parameter                   | Default | Type  | Description                          |
|-----------------------------|---------|-------|--------------------------------------|
| `strict_xb_validation`      | False   | bool  | Stricter XB slope check              |
| `only_draw_most_recent`     | True    | bool  | Enforce minimum bar spacing          |
| `min_bars_between_patterns` | 10      | int   | Min bars gap between pattern ends    |
| `slope_buffer_pct`          | 0.0     | float | Buffer % for all slope rules         |

### Channel Settings
| Parameter              | Default  | Type  | Description                         |
|------------------------|----------|-------|-------------------------------------|
| `channel_type`         | parallel | enum  | parallel / straight / non_parallel / all_types |
| `xb_upper_width_pct`   | 0.5      | float | XB channel upper band width (%)    |
| `xb_lower_width_pct`   | 0.5      | float | XB channel lower band width (%)    |
| `a_upper_width_pct`    | 0.5      | float | A channel upper band width (%)     |
| `a_lower_width_pct`    | 0.5      | float | A channel lower band width (%)     |
| `channel_extension_bars`| 200     | int   | Visual extension past last point   |

The channel widths are mirrored (upper<->lower swapped) for X>A patterns
so that "upper" always means "away from price action" regardless of orientation.

### Golden Line Settings
| Parameter                              | Default | Type  | Description                        |
|----------------------------------------|---------|-------|------------------------------------|
| `f_percentage`                         | 50.0    | float | Starting FG separator height (%)   |
| `fg_increasing_percentage`             | 5       | int   | FG increment per iteration (%)     |
| `first_line_percentage`                | 4.0     | float | Initial FirstLine slope (%)        |
| `first_line_decrease_percentage`       | 0.01    | float | FirstLine decrement per step (%)   |
| `max_below_max_above_diff_percentage`  | 40.0    | float | M/N equality tolerance (%)         |
| `mn_buffer_percent`                    | 0.0     | float | MN line safety margin (%)          |
| `mn_length_percent`                    | 0.0     | float | Min MN segment length (%)          |
| `mn_extension_bars`                    | 20      | int   | Golden line extension bars         |
| `extension_break_close`                | False   | bool  | Use CLOSE price for break check    |

### Dynamic Tracking
| Parameter                   | Default | Type | Description                     |
|-----------------------------|---------|------|---------------------------------|
| `enable_dynamic_last_point` | True    | bool | Enable live dynamic tracking    |
| `max_dynamic_iterations`    | 10      | int  | Max dynamic tracking iterations |

### Filters
| Parameter          | Default   | Type | Description                       |
|--------------------|-----------|------|-----------------------------------|
| `divergence_type`  | none      | enum | none / time / volume / time_volume|
| `tick_min_speed`   | 500000    | int  | Minimum tick speed threshold      |

### Data
| Parameter        | Default | Type   | Description                               |
|------------------|---------|--------|-------------------------------------------|
| `data_file_path` | (blank) | string | Explicit data file path (or leave blank)  |

---

## Regenerating config.xlsx

If you add new parameters to `DetectorConfig` and want them in the Excel file:

```bash
python -m python_implementation.inputs.create_template
```

This overwrites `config.xlsx` with a fresh template containing all current
parameters and their defaults. Any custom values will be lost, so note them first.

---

## Loading Config in Python

```python
from python_implementation.inputs.loader import load_config, print_config

cfg, data_path = load_config()          # loads inputs/config.xlsx
print_config(cfg, data_path)            # prints formatted summary

# Or load a custom config file:
cfg, data_path = load_config("path/to/custom_config.xlsx")
```

`load_config()` returns `(DetectorConfig, str)` where the string is the
`data_file_path` value (empty string if not set).
