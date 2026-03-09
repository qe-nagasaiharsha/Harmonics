"""Interactive diagnostic dashboard for PXABCDEF pattern detection.

Built with Plotly + Dash for real-time visual debugging.
Renders detected patterns, channels, golden lines, and per-bar
diagnostic overlays so the operator can understand exactly WHY
a pattern was found or rejected.

Launch with: ``python -m python_implementation.dashboard.app``
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import List, Optional

try:
    import dash
    from dash import dcc, html, Input, Output, State, callback_context
    import plotly.graph_objects as go
    from plotly.subplots import make_subplots
except ImportError:
    print("Dashboard requires: pip install dash plotly")
    sys.exit(1)

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from python_implementation.core.types import (
    ChannelType, PatternDirection, PatternResult, PatternType, Wave,
)
from python_implementation.core.config import DetectorConfig
from python_implementation.core.detector import PatternDetector
from python_implementation.core.golden_line import compute_golden_line
from python_implementation.core.dynamic_tracking import track_dynamic_points
from python_implementation.core.diagnostics import DiagnosticRecord
from python_implementation.data.loader import CandleArray, load_file
from python_implementation.inputs.loader import load_config


# ===================================================================
# Helper: load defaults from Excel config
# ===================================================================

def _load_excel_defaults() -> tuple:
    """Try to load defaults from config.xlsx. Returns (cfg, data_path) or defaults."""
    try:
        cfg, data_path = load_config()
        return cfg, data_path
    except FileNotFoundError:
        return DetectorConfig(), ""


# ===================================================================
# Chart rendering
# ===================================================================

def build_candlestick_figure(
    candles: CandleArray,
    results: List[PatternResult],
    cfg: DetectorConfig,
) -> go.Figure:
    """Build the main interactive candlestick chart with overlays."""
    import numpy as np
    from datetime import datetime

    n = len(candles)
    # Build x-axis as bar indices (MT5 convention: 0=newest)
    x_axis = list(range(n))

    fig = make_subplots(
        rows=2, cols=1,
        shared_xaxes=True,
        vertical_spacing=0.03,
        row_heights=[0.85, 0.15],
    )

    # Candlestick
    fig.add_trace(go.Candlestick(
        x=x_axis,
        open=candles.open,
        high=candles.high,
        low=candles.low,
        close=candles.close,
        name="Price",
        increasing_line_color="#26a69a",
        decreasing_line_color="#ef5350",
    ), row=1, col=1)

    # Volume
    colors = ["#26a69a" if candles.close[i] >= candles.open[i] else "#ef5350"
              for i in range(n)]
    fig.add_trace(go.Bar(
        x=x_axis,
        y=candles.volume,
        name="Volume",
        marker_color=colors,
        opacity=0.5,
    ), row=2, col=1)

    # Overlay detected patterns
    for idx, result in enumerate(results):
        _add_pattern_overlay(fig, result, idx, candles, cfg)

    fig.update_layout(
        title="PXABCDEF Pattern Detection — Diagnostic Dashboard",
        template="plotly_dark",
        xaxis_rangeslider_visible=False,
        height=900,
        showlegend=True,
        legend=dict(x=0, y=1, bgcolor="rgba(0,0,0,0.5)"),
    )

    # Reverse x-axis so newest is on right (matching MT5 visual)
    fig.update_xaxes(autorange="reversed", row=1, col=1)
    fig.update_xaxes(autorange="reversed", row=2, col=1)

    return fig


def _add_pattern_overlay(
    fig: go.Figure,
    result: PatternResult,
    pattern_idx: int,
    candles: CandleArray,
    cfg: DetectorConfig,
) -> None:
    """Add pattern lines, channels, labels, and golden line to figure."""
    w = result.wave
    ptype = result.pattern_type
    prefix = f"P{pattern_idx}"
    direction = "Bull" if result.is_bullish else "Bear"

    # Pattern connecting lines
    points = [("P", w.p_idx, w.p_price), ("X", w.x_idx, w.x_price),
              ("A", w.a_idx, w.a_price), ("B", w.b_idx, w.b_price)]
    if ptype >= PatternType.XABC:
        points.append(("C", w.c_idx, w.c_price))
    if ptype >= PatternType.XABCD:
        points.append(("D", w.d_idx, w.d_price))
    if ptype >= PatternType.XABCDE:
        points.append(("E", w.e_idx, w.e_price))
    if ptype >= PatternType.XABCDEF:
        points.append(("F", w.f_idx, w.f_price))

    x_coords = [p[1] for p in points]
    y_coords = [p[2] for p in points]

    # Pattern line
    fig.add_trace(go.Scatter(
        x=x_coords, y=y_coords,
        mode="lines+markers",
        name=f"{prefix} {ptype.name} [{direction}]",
        line=dict(color="white" if result.is_bullish else "red", width=2),
        marker=dict(size=8),
        hoverinfo="text",
        text=[f"{p[0]}: idx={p[1]} price={p[2]:.5f}" for p in points],
    ), row=1, col=1)

    # Labels
    for label, idx, price in points:
        fig.add_annotation(
            x=idx, y=price,
            text=label,
            showarrow=False,
            font=dict(color="yellow", size=12),
            yshift=15 if w.x_less_than_a == (label in ("X", "B", "D", "F")) else -15,
            row=1, col=1,
        )

    # Channel lines (simplified — center lines only)
    bars_x_b = w.x_idx - w.b_idx
    if bars_x_b > 0:
        xb_slope = (w.b_price - w.x_price) / bars_x_b
        last_idx = w.last_point(ptype)[0]
        ext = last_idx - cfg.channel_extension_bars

        # XB channel center
        xb_x = [w.x_idx, ext]
        xb_y = [w.x_price, w.x_price + (w.x_idx - ext) * xb_slope]
        fig.add_trace(go.Scatter(
            x=xb_x, y=xb_y,
            mode="lines",
            name=f"{prefix} XB-ch",
            line=dict(color="cyan", width=1, dash="dot"),
            showlegend=False,
        ), row=1, col=1)

    # Golden line
    if result.golden_line:
        gl = result.golden_line
        fig.add_trace(go.Scatter(
            x=[gl.mn_start_idx, gl.mn_end_idx],
            y=[gl.mn_start_price, gl.mn_end_price],
            mode="lines",
            name=f"{prefix} Golden ({gl.slope_selection})",
            line=dict(color="gold", width=3),
        ), row=1, col=1)

        # Signal arrow
        if gl.signal and gl.signal_idx is not None:
            fig.add_annotation(
                x=gl.signal_idx,
                y=gl.signal_price,
                text=f"{'▲ BUY' if gl.signal.value == 'buy' else '▼ SELL'}",
                showarrow=True,
                arrowhead=2,
                arrowcolor="lime" if gl.signal.value == "buy" else "red",
                font=dict(color="lime" if gl.signal.value == "buy" else "red", size=14),
                row=1, col=1,
            )


# ===================================================================
# Diagnostic panel
# ===================================================================

def build_diagnostic_table(records: List[DiagnosticRecord]) -> html.Div:
    """Build an HTML table from diagnostic records."""
    if not records:
        return html.Div("No diagnostics available", style={"color": "#888"})

    header = html.Tr([
        html.Th("Rule"), html.Th("Name"), html.Th("Segment"),
        html.Th("Bar"), html.Th("Pass"), html.Th("Type"),
        html.Th("Price"), html.Th("Threshold"), html.Th("Details"),
    ])

    rows = []
    for r in records:
        color = "#26a69a" if r.passed else "#ef5350"
        rows.append(html.Tr([
            html.Td(r.rule_id),
            html.Td(r.rule_name),
            html.Td(r.segment),
            html.Td(str(r.bar_idx)),
            html.Td("PASS" if r.passed else "FAIL", style={"color": color, "fontWeight": "bold"}),
            html.Td(r.check_type),
            html.Td(f"{r.price_checked:.5f}"),
            html.Td(f"{r.threshold:.5f}"),
            html.Td(r.details, style={"fontSize": "11px"}),
        ], style={"backgroundColor": "rgba(239,83,80,0.1)" if not r.passed else "transparent"}))

    return html.Table(
        [html.Thead(header), html.Tbody(rows)],
        style={
            "width": "100%",
            "borderCollapse": "collapse",
            "fontSize": "12px",
            "color": "#ddd",
        },
    )


# ===================================================================
# Dash App
# ===================================================================

def _auto_detect_data_path() -> str:
    """Auto-detect the most recent data file in python_implementation/data/."""
    data_dir = Path(__file__).resolve().parent.parent / "data"
    data_files = sorted(
        [f for f in data_dir.glob("*") if f.suffix.lower() in (".csv", ".xlsx", ".xls")],
        key=lambda f: f.stat().st_mtime,
        reverse=True,
    )
    return str(data_files[0]) if data_files else ""


def create_app(candles: Optional[CandleArray] = None) -> dash.Dash:
    """Create and configure the Dash application."""
    # Load defaults from Excel config
    excel_cfg, excel_data_path = _load_excel_defaults()

    # Resolve data path: Excel config > auto-detect (path resolution only, no detection here)
    resolved_data_path = excel_data_path
    if not resolved_data_path:
        resolved_data_path = _auto_detect_data_path()
        if resolved_data_path:
            print(f"Auto-detected data file: {resolved_data_path}")

    # Server starts immediately with empty chart.
    # dcc.Interval below fires once after 1s to auto-run detection in the browser.
    init_fig = go.Figure(layout=dict(template="plotly_dark", height=900))
    init_status = "Loading patterns..." if resolved_data_path else "No data file found. Place a CSV in python_implementation/data/ and refresh."
    init_options = []
    init_results = None

    app = dash.Dash(
        __name__,
        title="PXABCDEF Diagnostic Dashboard",
    )

    app.layout = html.Div([
        html.H1("Golden Line PXABCDEF — Diagnostic Dashboard",
                style={"textAlign": "center", "color": "#e0e0e0"}),

        # Controls
        html.Div([
            html.Div([
                html.Label("Data File:", style={"color": "#aaa"}),
                dcc.Input(id="csv-path", type="text", value=resolved_data_path,
                         placeholder="Path to OHLCV data file (CSV or Excel)",
                         style={"width": "400px"}),
            ], style={"display": "inline-block", "marginRight": "20px"}),

            html.Div([
                html.Label("Pattern Type:", style={"color": "#aaa"}),
                dcc.Dropdown(
                    id="pattern-type",
                    options=[{"label": pt.name, "value": pt.value} for pt in PatternType],
                    value=excel_cfg.pattern_type.value,
                    style={"width": "150px", "color": "#000"},
                ),
            ], style={"display": "inline-block", "marginRight": "20px"}),

            html.Div([
                html.Label("Channel Type:", style={"color": "#aaa"}),
                dcc.Dropdown(
                    id="channel-type",
                    options=[{"label": ct.value, "value": ct.value} for ct in ChannelType],
                    value=excel_cfg.channel_type.value,
                    style={"width": "150px", "color": "#000"},
                ),
            ], style={"display": "inline-block", "marginRight": "20px"}),

            html.Div([
                html.Label("Slope Buffer %:", style={"color": "#aaa"}),
                dcc.Input(id="slope-buffer", type="number", value=excel_cfg.slope_buffer_pct, step=0.1,
                         style={"width": "80px"}),
            ], style={"display": "inline-block", "marginRight": "20px"}),

            html.Div([
                html.Label("B Min:", style={"color": "#aaa"}),
                dcc.Input(id="b-min", type="number", value=excel_cfg.b_min, style={"width": "60px"}),
            ], style={"display": "inline-block", "marginRight": "10px"}),

            html.Div([
                html.Label("B Max:", style={"color": "#aaa"}),
                dcc.Input(id="b-max", type="number", value=excel_cfg.b_max, style={"width": "60px"}),
            ], style={"display": "inline-block", "marginRight": "20px"}),

            html.Div([
                html.Label("Max Bars:", style={"color": "#aaa"}),
                dcc.Input(id="max-bars", type="number", value=500, min=50, step=100,
                         style={"width": "80px"}),
            ], style={"display": "inline-block", "marginRight": "20px"}),

            html.Button("Detect Patterns", id="detect-btn",
                       style={"backgroundColor": "#26a69a", "color": "white",
                              "border": "none", "padding": "10px 20px",
                              "cursor": "pointer", "fontSize": "14px"}),
        ], style={"padding": "10px", "backgroundColor": "#1e1e1e",
                  "borderRadius": "5px", "marginBottom": "10px"}),

        # Status
        html.Div(id="status-bar", children=init_status,
                style={"padding": "5px", "color": "#aaa"}),

        # Main chart
        dcc.Graph(id="main-chart", figure=init_fig, style={"height": "900px"}),

        # Pattern selector
        html.Div([
            html.Label("Select Pattern for Diagnostics:", style={"color": "#aaa"}),
            dcc.Dropdown(id="pattern-selector", options=init_options,
                        style={"color": "#000"}),
        ], style={"padding": "10px"}),

        # Diagnostic panel
        html.Div(id="diagnostic-panel",
                style={"padding": "10px", "maxHeight": "400px",
                       "overflowY": "auto", "backgroundColor": "#1a1a1a"}),

        # Hidden store for results
        dcc.Store(id="results-store", data=init_results),

    ], style={"backgroundColor": "#121212", "minHeight": "100vh",
              "fontFamily": "monospace", "padding": "10px"})

    # -- Callbacks --

    @app.callback(
        [Output("main-chart", "figure"),
         Output("status-bar", "children"),
         Output("pattern-selector", "options"),
         Output("results-store", "data")],
        [Input("detect-btn", "n_clicks")],
        [State("csv-path", "value"),
         State("pattern-type", "value"),
         State("channel-type", "value"),
         State("slope-buffer", "value"),
         State("b-min", "value"),
         State("b-max", "value"),
         State("max-bars", "value")],
        prevent_initial_call=True,
    )
    def run_detection(n_clicks, csv_path, ptype, ctype, sbuf, bmin, bmax, max_bars_val):
        try:
            if not csv_path:
                return go.Figure(), "ERROR: Please provide a CSV file path.", [], None

            data = load_file(csv_path)
            total_bars = len(data)

            # Slice to max_bars most-recent bars (index 0 = most recent)
            n = int(max_bars_val or 500)
            n = max(50, min(n, total_bars))
            if n < total_bars:
                from python_implementation.data.loader import CandleArray
                import numpy as np
                data = CandleArray(
                    open=data.open[:n], high=data.high[:n],
                    low=data.low[:n], close=data.close[:n],
                    volume=data.volume[:n], timestamp=data.timestamp[:n],
                )

            cfg = DetectorConfig(
                pattern_type=PatternType(ptype),
                channel_type=ChannelType(ctype),
                slope_buffer_pct=float(sbuf or 0),
                b_min=int(bmin or 20),
                b_max=int(bmax or 100),
            )

            detector = PatternDetector(data)
            results = detector.find_all(cfg)

            # Compute golden lines and dynamic points
            for r in results:
                r.golden_line = compute_golden_line(
                    r.wave, r.pattern_type, cfg,
                    data.high_at, data.low_at, data.close_at,
                )
                r.dynamic_points = track_dynamic_points(
                    r.wave, r.pattern_type, cfg,
                    data.high_at, data.low_at, data.close_at,
                )

            fig = build_candlestick_figure(data, results, cfg)
            status = (
                f"Found {len(results)} pattern(s) in {len(data)} bars "
                f"(of {total_bars} total). "
                f"Increase Max Bars to search further back."
            )

            options = [
                {"label": f"#{i}: {r.pattern_type.name} [{'Bull' if r.is_bullish else 'Bear'}] X={r.wave.x_idx}",
                 "value": i}
                for i, r in enumerate(results)
            ]

            result_data = {
                "count": len(results),
                "diagnostics": {
                    str(i): [
                        {"rule_id": d.rule_id, "rule_name": d.rule_name,
                         "segment": d.segment, "bar_idx": d.bar_idx,
                         "passed": d.passed, "check_type": d.check_type,
                         "price_checked": d.price_checked, "threshold": d.threshold,
                         "details": d.details}
                        for d in r.diagnostics
                    ]
                    for i, r in enumerate(results)
                },
            }

            return fig, status, options, result_data

        except Exception as exc:
            import traceback
            err = traceback.format_exc()
            print(f"[Dashboard ERROR]\n{err}")
            return go.Figure(), f"ERROR: {exc}", [], None

    @app.callback(
        Output("diagnostic-panel", "children"),
        Input("pattern-selector", "value"),
        State("results-store", "data"),
        prevent_initial_call=True,
    )
    def show_diagnostics(selected, store):
        if selected is None or store is None:
            return html.Div("Select a pattern to view diagnostics", style={"color": "#888"})

        diag_data = store.get("diagnostics", {}).get(str(selected), [])
        records = [
            DiagnosticRecord(
                rule_id=d["rule_id"], rule_name=d["rule_name"],
                segment=d["segment"], bar_idx=d["bar_idx"],
                passed=d["passed"], check_type=d["check_type"],
                price_checked=d["price_checked"], threshold=d["threshold"],
                details=d["details"],
            )
            for d in diag_data
        ]
        return build_diagnostic_table(records)

    return app


# ===================================================================
# CLI entry point
# ===================================================================

def main():
    """Launch the dashboard server."""
    import argparse

    parser = argparse.ArgumentParser(description="PXABCDEF Diagnostic Dashboard")
    parser.add_argument("--port", type=int, default=8050, help="Server port")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode")
    args = parser.parse_args()

    app = create_app()
    print(f"Starting dashboard on http://localhost:{args.port}")
    app.run(debug=args.debug, port=args.port)


if __name__ == "__main__":
    main()
