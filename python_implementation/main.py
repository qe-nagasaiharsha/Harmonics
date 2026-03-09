"""Main entry point for the PXABCDEF Pattern Detection Engine.

Usage:
    # Run detection on a CSV file:
    python -m python_implementation.main detect data.csv --pattern XABCD

    # Launch the interactive dashboard:
    python -m python_implementation.main dashboard --port 8050

    # Quick validation test:
    python -m python_implementation.main test
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def cmd_detect(args: argparse.Namespace) -> None:
    """Run pattern detection on a data file.

    Reads configuration from inputs/config.xlsx by default.
    CLI arguments override Excel values when provided.
    If a data file is passed as positional arg, it overrides the Excel path.
    """
    from python_implementation.core.types import PatternType, ChannelType
    from python_implementation.core.config import DetectorConfig
    from python_implementation.core.detector import PatternDetector
    from python_implementation.core.golden_line import compute_golden_line
    from python_implementation.core.dynamic_tracking import track_dynamic_points
    from python_implementation.data.loader import load_file
    from python_implementation.inputs.loader import load_config, print_config

    # Load base config from Excel
    try:
        cfg, excel_data_path = load_config(args.config)
        print_config(cfg, excel_data_path)
        print()
    except FileNotFoundError:
        cfg = DetectorConfig()
        excel_data_path = ""

    # Determine which CLI args were explicitly provided by the user
    # (vs left at their argparse defaults).  We inspect sys.argv so
    # that e.g. "--pattern XABCD" is treated as an explicit override
    # even when the value matches the argparse default.
    _cli_words = set(sys.argv)
    _explicit = {
        "pattern": "--pattern" in _cli_words,
        "channel": "--channel" in _cli_words,
        "buffer":  "--buffer" in _cli_words,
        "b_min":   "--b-min" in _cli_words,
        "b_max":   "--b-max" in _cli_words,
        "max_bars": "--max-bars" in _cli_words,
    }

    # Data file: CLI positional arg > Excel path > auto-detect in data folder
    if args.csv:
        data_path = args.csv
    elif excel_data_path:
        data_path = excel_data_path
    else:
        # Auto-detect: look for CSV/Excel files in the data folder
        data_dir = Path(__file__).resolve().parent / "data"
        data_files = sorted(
            [f for f in data_dir.glob("*") if f.suffix.lower() in (".csv", ".xlsx", ".xls")],
            key=lambda f: f.stat().st_mtime,
            reverse=True,
        )
        if data_files:
            data_path = str(data_files[0])
            print(f"Auto-detected data file: {data_path}")
        else:
            print("Error: No data file found.")
            print("  Place a CSV or Excel file in python_implementation/data/")
            print("  or set 'data_file_path' in inputs/config.xlsx")
            print("  or pass a file path: detect <data_file>")
            sys.exit(1)

    # CLI overrides (only when explicitly passed on the command line)
    if _explicit["pattern"]:
        cfg.pattern_type = PatternType[args.pattern.upper()]
    if _explicit["channel"]:
        cfg.channel_type = ChannelType(args.channel.lower())
    if _explicit["buffer"]:
        cfg.slope_buffer_pct = args.buffer
    if _explicit["b_min"]:
        cfg.b_min = args.b_min
    if _explicit["b_max"]:
        cfg.b_max = args.b_max
    if _explicit["max_bars"]:
        cfg.max_search_bars = args.max_bars

    print(f"Loading data from: {data_path}")
    candles = load_file(data_path)
    print(f"Loaded {len(candles)} bars")

    detector = PatternDetector(candles)
    results = detector.find_all(cfg)

    print(f"\nFound {len(results)} pattern(s)\n")

    for i, r in enumerate(results):
        w = r.wave
        direction = "BULLISH" if r.is_bullish else "BEARISH"
        print(f"--- Pattern #{i} [{r.pattern_type.name}] [{direction}] ---")
        print(f"  Channel: {r.channel_type.value}")
        print(f"  P: idx={w.p_idx} price={w.p_price:.5f}")
        print(f"  X: idx={w.x_idx} price={w.x_price:.5f}")
        print(f"  A: idx={w.a_idx} price={w.a_price:.5f}")
        print(f"  B: idx={w.b_idx} price={w.b_price:.5f}")
        if r.pattern_type >= PatternType.XABC:
            print(f"  C: idx={w.c_idx} price={w.c_price:.5f}")
        if r.pattern_type >= PatternType.XABCD:
            print(f"  D: idx={w.d_idx} price={w.d_price:.5f}")
        if r.pattern_type >= PatternType.XABCDE:
            print(f"  E: idx={w.e_idx} price={w.e_price:.5f}")
        if r.pattern_type >= PatternType.XABCDEF:
            print(f"  F: idx={w.f_idx} price={w.f_price:.5f}")
        print(f"  x_less_than_a: {w.x_less_than_a}")

        # Golden line
        gl = compute_golden_line(w, r.pattern_type, cfg,
                                 candles.high_at, candles.low_at, candles.close_at)
        if gl:
            print(f"  Golden Line: {gl.slope_selection} | "
                  f"start=({gl.mn_start_idx}, {gl.mn_start_price:.5f}) -> "
                  f"end=({gl.mn_end_idx}, {gl.mn_end_price:.5f})")
            if gl.signal:
                print(f"  Signal: {gl.signal.value.upper()} at idx={gl.signal_idx}")
        else:
            print("  Golden Line: not found")

        # Dynamic points
        dyn = track_dynamic_points(w, r.pattern_type, cfg,
                                   candles.high_at, candles.low_at, candles.close_at)
        if dyn:
            print(f"  Dynamic Points: {len(dyn)}")
            for dp in dyn:
                print(f"    L{dp.iteration}: idx={dp.idx} price={dp.price:.5f}")

        # Diagnostics summary
        n_diag = len(r.diagnostics)
        n_fail = sum(1 for d in r.diagnostics if not d.passed)
        print(f"  Diagnostics: {n_diag} checks ({n_fail} failed)")
        print()

    if args.json_output:
        output = {
            "patterns_found": len(results),
            "patterns": [
                {
                    "type": r.pattern_type.name,
                    "direction": "bullish" if r.is_bullish else "bearish",
                    "channel": r.channel_type.value,
                    "x_less_than_a": r.wave.x_less_than_a,
                    "points": {
                        "P": {"idx": r.wave.p_idx, "price": r.wave.p_price},
                        "X": {"idx": r.wave.x_idx, "price": r.wave.x_price},
                        "A": {"idx": r.wave.a_idx, "price": r.wave.a_price},
                        "B": {"idx": r.wave.b_idx, "price": r.wave.b_price},
                        **({"C": {"idx": r.wave.c_idx, "price": r.wave.c_price}}
                           if r.pattern_type >= PatternType.XABC else {}),
                        **({"D": {"idx": r.wave.d_idx, "price": r.wave.d_price}}
                           if r.pattern_type >= PatternType.XABCD else {}),
                        **({"E": {"idx": r.wave.e_idx, "price": r.wave.e_price}}
                           if r.pattern_type >= PatternType.XABCDE else {}),
                        **({"F": {"idx": r.wave.f_idx, "price": r.wave.f_price}}
                           if r.pattern_type >= PatternType.XABCDEF else {}),
                    },
                    "diagnostics_count": len(r.diagnostics),
                }
                for r in results
            ],
        }
        out_path = Path(args.json_output)
        out_path.write_text(json.dumps(output, indent=2))
        print(f"JSON output written to: {out_path}")


def cmd_dashboard(args: argparse.Namespace) -> None:
    """Launch the interactive Dash dashboard."""
    from python_implementation.dashboard.app import create_app

    app = create_app()
    print(f"Starting dashboard on http://localhost:{args.port}")
    app.run(debug=args.debug, port=args.port)


def cmd_test(args: argparse.Namespace) -> None:
    """Run a quick import and instantiation test."""
    print("Testing imports...")

    from python_implementation.core.types import Wave, PatternType, ChannelType
    from python_implementation.core.config import DetectorConfig
    from python_implementation.core.diagnostics import DiagnosticLog, DiagnosticRecord
    from python_implementation.core.channels import (
        get_a_channel_slope, is_in_channel, channel_widths_for_xb,
    )
    from python_implementation.core import validators
    from python_implementation.core import candidates
    from python_implementation.core.detector import PatternDetector
    from python_implementation.core.golden_line import compute_golden_line
    from python_implementation.core.dynamic_tracking import track_dynamic_points
    from python_implementation.core.filters import tick_speed_filter, divergence_filter
    from python_implementation.data.loader import CandleArray, from_arrays, load_file

    print("All imports successful.")

    # Test basic types
    w = Wave()
    w.reset()
    assert w.x_price == 0.0

    cfg = DetectorConfig()
    assert cfg.pattern_type == PatternType.XABCD
    assert cfg.channel_types_to_run() == [ChannelType.PARALLEL]

    cfg2 = DetectorConfig(channel_type=ChannelType.ALL_TYPES)
    assert len(cfg2.channel_types_to_run()) == 3

    # Test channels
    assert get_a_channel_slope(0.5, ChannelType.PARALLEL) == 0.5
    assert get_a_channel_slope(0.5, ChannelType.STRAIGHT) == 0.0
    assert get_a_channel_slope(0.5, ChannelType.NON_PARALLEL) == -0.5

    assert is_in_channel(100.0, 100.0, 1.0, 1.0) is True
    assert is_in_channel(200.0, 100.0, 1.0, 1.0) is False

    # Test diagnostics
    diag = DiagnosticLog()
    diag.record_pass("1.2", "test", "X→B", 50, "strict", 1.0, 0.9)
    diag.record_fail("1.3", "test", "A→B", 45, "buffer", 1.1, 1.0)
    assert len(diag) == 2
    assert len(diag.failures) == 1
    assert not diag.all_passed

    # Test candle array
    data = from_arrays(
        open_=[1.0, 1.1, 1.2],
        high=[1.5, 1.6, 1.7],
        low=[0.9, 0.8, 0.7],
        close=[1.2, 1.3, 1.4],
    )
    assert len(data) == 3
    assert data.high_at(0) == 1.5

    print("\nAll tests passed! The engine is ready.")
    print("\nUsage:")
    print("  python -m python_implementation.main detect <csv_file> --pattern XABCD")
    print("  python -m python_implementation.main dashboard --port 8050")


def main():
    parser = argparse.ArgumentParser(
        description="PXABCDEF Pattern Detection Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # detect
    p_detect = subparsers.add_parser("detect", help="Run pattern detection on data file")
    p_detect.add_argument("csv", nargs="?", default="",
                         help="Path to OHLCV data file (CSV or Excel). If omitted, uses config.xlsx")
    p_detect.add_argument("--config", default=None,
                         help="Path to config Excel file (default: inputs/config.xlsx)")
    p_detect.add_argument("--pattern", default="XABCD",
                         choices=["XAB", "XABC", "XABCD", "XABCDE", "XABCDEF"])
    p_detect.add_argument("--channel", default="parallel",
                         choices=["parallel", "straight", "non_parallel", "all_types"])
    p_detect.add_argument("--buffer", type=float, default=0.0, help="Slope buffer %%")
    p_detect.add_argument("--b-min", type=int, default=20)
    p_detect.add_argument("--b-max", type=int, default=100)
    p_detect.add_argument("--max-bars", type=int, default=0, help="Max bars to search (0=all)")
    p_detect.add_argument("--json-output", type=str, default="", help="Write JSON results to file")

    # dashboard
    p_dash = subparsers.add_parser("dashboard", help="Launch diagnostic dashboard")
    p_dash.add_argument("--port", type=int, default=8050)
    p_dash.add_argument("--debug", action="store_true")

    # test
    subparsers.add_parser("test", help="Run quick validation test")

    args = parser.parse_args()

    if args.command == "detect":
        cmd_detect(args)
    elif args.command == "dashboard":
        cmd_dashboard(args)
    elif args.command == "test":
        cmd_test(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
