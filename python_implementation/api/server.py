"""FastAPI backend for the PXABCDEF pattern detection system.

Exposes two endpoints:
  GET  /api/defaults  — config.xlsx defaults + resolved data path
  POST /api/detect    — run detection + return candles/patterns/traces

Start with:
  python -m python_implementation.api.server
or:
  uvicorn python_implementation.api.server:app --reload --port 8000
"""

from __future__ import annotations

import asyncio
import json
import sys
import tempfile
import traceback
import uuid
from dataclasses import asdict
from pathlib import Path
from typing import Any, Dict, List, Optional

# Resolve project root so imports work regardless of CWD
_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_ROOT))

_DIST = _ROOT / "frontend" / "dist"

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from starlette.middleware.gzip import GZipMiddleware

from python_implementation.core.config import DetectorConfig
from python_implementation.core.types import ChannelType, DivergenceType, PatternDirection, PatternType
from python_implementation.core.detector import PatternDetector
from python_implementation.core.golden_line import compute_golden_line
from python_implementation.core.dynamic_tracking import track_dynamic_points
from python_implementation.data.loader import CandleArray, load_file
from python_implementation.inputs.loader import load_config


# ===================================================================
# App setup
# ===================================================================

app = FastAPI(title="PXABCDEF Pattern Detection API", version="2.0.0")

# Temp directory for uploaded data files
_UPLOADS = Path(tempfile.gettempdir()) / "harmonics_uploads"
_UPLOADS.mkdir(exist_ok=True)
_MAX_UPLOAD_MB = 50

app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve built frontend static assets (JS/CSS) under /assets
if _DIST.exists():
    app.mount("/assets", StaticFiles(directory=str(_DIST / "assets")), name="assets")


@app.get("/", include_in_schema=False)
@app.get("/index.html", include_in_schema=False)
async def serve_frontend():
    index = _DIST / "index.html"
    if index.exists():
        return FileResponse(str(index))
    return {"error": "Frontend not built. Run: cd frontend && npm run build"}


@app.get("/favicon.svg", include_in_schema=False)
async def serve_favicon():
    fav = _DIST / "vite.svg"
    if fav.exists():
        return FileResponse(str(fav))
    return FileResponse(str(_DIST / "favicon.ico")) if (_DIST / "favicon.ico").exists() else FileResponse(str(_DIST / "index.html"))


# ===================================================================
# Pydantic models
# ===================================================================

class ConfigInput(BaseModel):
    # Pattern type
    pattern_type: str = "XABCD"
    channel_type: str = "parallel"
    pattern_direction: str = "both"

    # Length properties
    b_min: int = 20
    b_max: int = 100
    px_length_percentage: float = 10.0
    min_b_to_c_btw_x_b: float = 0.0
    max_b_to_c_btw_x_b: float = 100.0
    min_c_to_d_btw_x_b: float = 0.0
    max_c_to_d_btw_x_b: float = 100.0
    min_d_to_e_btw_x_b: float = 0.0
    max_d_to_e_btw_x_b: float = 100.0
    min_e_to_f_btw_x_b: float = 0.0
    max_e_to_f_btw_x_b: float = 100.0

    # Retracement properties
    x_to_a_b_min: float = -100.0
    x_to_a_b_max: float = 100.0
    min_width_percentage: float = 0.0
    max_width_percentage: float = 100.0

    # Dynamic height properties
    every_increasing_of_value: int = 5
    width_increasing_percentage_x_to_b: float = 0.0
    width_increasing_percentage_a_e: float = 0.0

    # Validation
    slope_buffer_pct: float = 0.0
    only_draw_most_recent: bool = True
    min_bars_between_patterns: int = 10

    # Channel width settings
    xb_upper_width_pct: float = 0.5
    xb_lower_width_pct: float = 0.5
    a_upper_width_pct: float = 0.5
    a_lower_width_pct: float = 0.5

    # Channel extension
    channel_extension_bars: int = 200

    # Validation extras
    max_search_bars: int = 0
    strict_xb_validation: bool = False

    # Golden line settings
    f_percentage: float = 50.0
    fg_increasing_percentage: int = 5
    first_line_percentage: float = 4.0
    first_line_decrease_percentage: float = 0.01
    max_below_max_above_diff_percentage: float = 40.0
    mn_buffer_percent: float = 0.0
    mn_length_percent: float = 0.0
    mn_extension_bars: int = 20
    extension_break_close: bool = False

    # Dynamic tracking
    enable_dynamic_last_point: bool = True
    max_dynamic_iterations: int = 10

    # Filters
    divergence_type: str = "none"
    tick_min_speed: int = 500000


class DetectRequest(BaseModel):
    data_path: str
    max_bars: int = 500
    config: ConfigInput = ConfigInput()




# ===================================================================
# Serialisation helpers
# ===================================================================

def _wave_to_dict(wave, ptype) -> dict:
    d: Dict[str, Any] = {
        "p_idx": wave.p_idx, "p_price": wave.p_price,
        "x_idx": wave.x_idx, "x_price": wave.x_price,
        "a_idx": wave.a_idx, "a_price": wave.a_price,
        "b_idx": wave.b_idx, "b_price": wave.b_price,
        "x_less_than_a": wave.x_less_than_a,
    }
    if ptype >= PatternType.XABC:
        d.update({"c_idx": wave.c_idx, "c_price": wave.c_price})
    if ptype >= PatternType.XABCD:
        d.update({"d_idx": wave.d_idx, "d_price": wave.d_price})
    if ptype >= PatternType.XABCDE:
        d.update({"e_idx": wave.e_idx, "e_price": wave.e_price})
    if ptype >= PatternType.XABCDEF:
        d.update({"f_idx": wave.f_idx, "f_price": wave.f_price})
    return d


def _result_to_dict(r) -> dict:
    gl = None
    if r.golden_line:
        gl = {
            "mn_start_idx": r.golden_line.mn_start_idx,
            "mn_start_price": r.golden_line.mn_start_price,
            "mn_end_idx": r.golden_line.mn_end_idx,
            "mn_end_price": r.golden_line.mn_end_price,
            "slope_selection": r.golden_line.slope_selection,
            "signal": r.golden_line.signal.value if r.golden_line.signal else None,
            "signal_idx": r.golden_line.signal_idx,
            "signal_price": r.golden_line.signal_price,
        }
    return {
        "pattern_type": r.pattern_type.name,
        "channel_type": r.channel_type.value,
        "is_bullish": r.is_bullish,
        "wave": _wave_to_dict(r.wave, r.pattern_type),
        "golden_line": gl,
        "diagnostics": [
            {
                "rule_id": d.rule_id,
                "rule_name": d.rule_name,
                "segment": d.segment,
                "bar_idx": d.bar_idx,
                "passed": d.passed,
                "check_type": d.check_type,
                "price_checked": d.price_checked,
                "threshold": d.threshold,
                "operator": d.operator,
                "buffer_value": d.buffer_value,
                "details": d.details,
            }
            for d in r.diagnostics
        ],
    }


def _attempt_to_dict(a) -> dict:
    return {
        "x_idx": a.x_idx,
        "x_is_low": a.x_is_low,
        "b_idx": a.b_idx,
        "b_price": a.b_price,
        "step_reached": a.step_reached,
        "rejected_at": a.rejected_at,
        "succeeded": a.succeeded,
        "partial_wave": a.partial_wave,
        "steps": [
            {
                "step": s.step,
                "passed": s.passed,
                "detail": s.detail,
                "value": s.value,
                "threshold_min": s.threshold_min,
                "threshold_max": s.threshold_max,
            }
            for s in a.steps
        ],
    }


def _build_cfg(c: ConfigInput) -> DetectorConfig:
    return DetectorConfig(
        # Pattern type
        pattern_type=PatternType[c.pattern_type.upper()],
        channel_type=ChannelType(c.channel_type.lower()),
        pattern_direction=PatternDirection(c.pattern_direction.lower()),
        # Length properties
        b_min=c.b_min,
        b_max=c.b_max,
        px_length_percentage=c.px_length_percentage,
        min_b_to_c_btw_x_b=c.min_b_to_c_btw_x_b,
        max_b_to_c_btw_x_b=c.max_b_to_c_btw_x_b,
        min_c_to_d_btw_x_b=c.min_c_to_d_btw_x_b,
        max_c_to_d_btw_x_b=c.max_c_to_d_btw_x_b,
        min_d_to_e_btw_x_b=c.min_d_to_e_btw_x_b,
        max_d_to_e_btw_x_b=c.max_d_to_e_btw_x_b,
        min_e_to_f_btw_x_b=c.min_e_to_f_btw_x_b,
        max_e_to_f_btw_x_b=c.max_e_to_f_btw_x_b,
        # Retracement
        x_to_a_b_min=c.x_to_a_b_min,
        x_to_a_b_max=c.x_to_a_b_max,
        min_width_percentage=c.min_width_percentage,
        max_width_percentage=c.max_width_percentage,
        # Dynamic height
        every_increasing_of_value=c.every_increasing_of_value,
        width_increasing_percentage_x_to_b=c.width_increasing_percentage_x_to_b,
        width_increasing_percentage_a_e=c.width_increasing_percentage_a_e,
        # Validation
        slope_buffer_pct=c.slope_buffer_pct,
        only_draw_most_recent=c.only_draw_most_recent,
        min_bars_between_patterns=c.min_bars_between_patterns,
        # Channel width
        xb_upper_width_pct=c.xb_upper_width_pct,
        xb_lower_width_pct=c.xb_lower_width_pct,
        a_upper_width_pct=c.a_upper_width_pct,
        a_lower_width_pct=c.a_lower_width_pct,
        channel_extension_bars=c.channel_extension_bars,
        # Validation extras
        max_search_bars=c.max_search_bars,
        strict_xb_validation=c.strict_xb_validation,
        # Golden line
        f_percentage=c.f_percentage,
        fg_increasing_percentage=c.fg_increasing_percentage,
        first_line_percentage=c.first_line_percentage,
        first_line_decrease_percentage=c.first_line_decrease_percentage,
        max_below_max_above_diff_percentage=c.max_below_max_above_diff_percentage,
        mn_buffer_percent=c.mn_buffer_percent,
        mn_length_percent=c.mn_length_percent,
        mn_extension_bars=c.mn_extension_bars,
        extension_break_close=c.extension_break_close,
        # Dynamic tracking
        enable_dynamic_last_point=c.enable_dynamic_last_point,
        max_dynamic_iterations=c.max_dynamic_iterations,
        # Filters
        divergence_type=DivergenceType(c.divergence_type.lower()),
        tick_min_speed=c.tick_min_speed,
    )


def _serialize_attempts(attempts, max_detailed=10):
    """Serialize attempts, limiting full step detail to avoid payload bloat."""
    if len(attempts) <= max_detailed:
        return [_attempt_to_dict(a) for a in attempts]
    result = []
    for i, a in enumerate(attempts):
        if i < 5 or i >= len(attempts) - 5 or a.succeeded:
            result.append(_attempt_to_dict(a))
        else:
            result.append({
                "x_idx": a.x_idx,
                "x_is_low": a.x_is_low,
                "b_idx": a.b_idx,
                "b_price": a.b_price,
                "step_reached": a.step_reached,
                "rejected_at": a.rejected_at,
                "succeeded": a.succeeded,
                "partial_wave": None,
                "steps": [],
            })
    return result


def _compact_attempt(a) -> dict:
    """Compact attempt dict for streaming — includes ALL steps (pass and fail)
    so the narrative summary can show every metric with its actual value.
    Omits partial_wave, rejected_at, and verbose detail strings.
    """
    entry = {
        "x_idx": a.x_idx,
        "x_is_low": a.x_is_low,
        "b_idx": a.b_idx,
        "b_price": a.b_price,
        "step_reached": a.step_reached,
        "succeeded": a.succeeded,
        "steps": [
            {"step": s.step, "passed": s.passed, "value": s.value,
             "threshold_min": s.threshold_min, "threshold_max": s.threshold_max}
            for s in a.steps
        ],
    }
    # Include candidate_info if present (per-point search summaries)
    if hasattr(a, 'candidate_info') and a.candidate_info:
        entry["candidate_info"] = a.candidate_info
    return entry


def _compact_serialize_bar(attempts, max_per_bar=40) -> list:
    """Serialize a bar's attempts compactly, capping count for huge bars."""
    if len(attempts) <= max_per_bar:
        return [_compact_attempt(a) for a in attempts]
    # Keep successes + sample of failures
    successes = [a for a in attempts if a.succeeded]
    failures = [a for a in attempts if not a.succeeded]
    keep = max_per_bar - len(successes)
    if keep > 0:
        # Evenly sample failures
        step = max(1, len(failures) // keep)
        sampled = failures[::step][:keep]
    else:
        sampled = []
    return [_compact_attempt(a) for a in successes + sampled]


def _slice_data(data: CandleArray, n: int) -> CandleArray:
    """Slice to the n most-recent bars (index 0 = most recent)."""
    import numpy as np
    n = max(50, min(n, len(data)))
    return CandleArray(
        open=data.open[:n], high=data.high[:n],
        low=data.low[:n], close=data.close[:n],
        volume=data.volume[:n], timestamp=data.timestamp[:n],
    )


# ===================================================================
# Endpoints
# ===================================================================

@app.get("/api/defaults")
async def get_defaults():
    """Return defaults from config.xlsx + resolved data path."""
    try:
        cfg, data_path = load_config()
    except FileNotFoundError:
        cfg = DetectorConfig()
        data_path = ""

    # Auto-detect data file if not set in config
    if not data_path:
        data_dir = _ROOT / "python_implementation" / "data"
        files = sorted(
            [f for f in data_dir.glob("*") if f.suffix.lower() in (".csv", ".xlsx", ".xls")],
            key=lambda f: f.stat().st_mtime, reverse=True,
        )
        data_path = str(files[0]) if files else ""

    return {
        "data_path": data_path,
        "config": {
            "pattern_type": cfg.pattern_type.name,
            "channel_type": cfg.channel_type.value,
            "pattern_direction": cfg.pattern_direction.value,
            "b_min": cfg.b_min,
            "b_max": cfg.b_max,
            "px_length_percentage": cfg.px_length_percentage,
            "min_b_to_c_btw_x_b": cfg.min_b_to_c_btw_x_b,
            "max_b_to_c_btw_x_b": cfg.max_b_to_c_btw_x_b,
            "min_c_to_d_btw_x_b": cfg.min_c_to_d_btw_x_b,
            "max_c_to_d_btw_x_b": cfg.max_c_to_d_btw_x_b,
            "min_d_to_e_btw_x_b": cfg.min_d_to_e_btw_x_b,
            "max_d_to_e_btw_x_b": cfg.max_d_to_e_btw_x_b,
            "min_e_to_f_btw_x_b": cfg.min_e_to_f_btw_x_b,
            "max_e_to_f_btw_x_b": cfg.max_e_to_f_btw_x_b,
            "x_to_a_b_min": cfg.x_to_a_b_min,
            "x_to_a_b_max": cfg.x_to_a_b_max,
            "min_width_percentage": cfg.min_width_percentage,
            "max_width_percentage": cfg.max_width_percentage,
            "every_increasing_of_value": cfg.every_increasing_of_value,
            "width_increasing_percentage_x_to_b": cfg.width_increasing_percentage_x_to_b,
            "width_increasing_percentage_a_e": cfg.width_increasing_percentage_a_e,
            "slope_buffer_pct": cfg.slope_buffer_pct,
            "only_draw_most_recent": cfg.only_draw_most_recent,
            "min_bars_between_patterns": cfg.min_bars_between_patterns,
            "xb_upper_width_pct": cfg.xb_upper_width_pct,
            "xb_lower_width_pct": cfg.xb_lower_width_pct,
            "a_upper_width_pct": cfg.a_upper_width_pct,
            "a_lower_width_pct": cfg.a_lower_width_pct,
            "channel_extension_bars": cfg.channel_extension_bars,
            "max_search_bars": cfg.max_search_bars,
            "strict_xb_validation": cfg.strict_xb_validation,
            "f_percentage": cfg.f_percentage,
            "fg_increasing_percentage": cfg.fg_increasing_percentage,
            "first_line_percentage": cfg.first_line_percentage,
            "first_line_decrease_percentage": cfg.first_line_decrease_percentage,
            "max_below_max_above_diff_percentage": cfg.max_below_max_above_diff_percentage,
            "mn_buffer_percent": cfg.mn_buffer_percent,
            "mn_length_percent": cfg.mn_length_percent,
            "mn_extension_bars": cfg.mn_extension_bars,
            "extension_break_close": cfg.extension_break_close,
            "enable_dynamic_last_point": cfg.enable_dynamic_last_point,
            "max_dynamic_iterations": cfg.max_dynamic_iterations,
            "divergence_type": cfg.divergence_type.value,
            "tick_min_speed": cfg.tick_min_speed,
        },
    }


@app.post("/api/upload")
async def upload_data(file: UploadFile = File(...)):
    """Accept a CSV or Excel file upload and return a server-side path for detection."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided.")

    ext = Path(file.filename).suffix.lower()
    if ext not in (".csv", ".xlsx", ".xls"):
        raise HTTPException(status_code=400, detail="Only .csv, .xlsx, and .xls files are supported.")

    contents = await file.read()
    if len(contents) > _MAX_UPLOAD_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {_MAX_UPLOAD_MB} MB).")

    safe_name = f"{uuid.uuid4().hex[:12]}{ext}"
    dest = _UPLOADS / safe_name
    dest.write_bytes(contents)

    return {"data_path": str(dest), "filename": file.filename, "size": len(contents)}


@app.post("/api/detect")
async def detect(req: DetectRequest):
    """Run pattern detection. Returns candles, patterns, and per-candle traces."""
    try:
        raw_data = load_file(req.data_path)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Data file not found: {req.data_path}")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to load data: {e}")

    total_bars = len(raw_data)
    data = _slice_data(raw_data, req.max_bars)

    try:
        cfg = _build_cfg(req.config)
    except (KeyError, ValueError) as e:
        raise HTTPException(status_code=422, detail=f"Invalid config: {e}")

    try:
        def _run_detection():
            detector = PatternDetector(data)
            return detector.find_all(cfg, collect_traces=True)

        results, traces, detection_log = await asyncio.to_thread(_run_detection)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Detection error: {traceback.format_exc()}")

    # Add golden lines + dynamic points to results
    for r in results:
        try:
            r.golden_line = compute_golden_line(
                r.wave, r.pattern_type, cfg,
                data.high_at, data.low_at, data.close_at,
            )
        except Exception:
            pass

    # Build candle list (most-recent first, index 0)
    candles_out = [
        {
            "idx": i,
            "time": float(data.timestamp[i]),
            "open": float(data.open[i]),
            "high": float(data.high[i]),
            "low": float(data.low[i]),
            "close": float(data.close[i]),
            "volume": float(data.volume[i]),
        }
        for i in range(len(data))
    ]

    # Serialise traces: Dict[int, List[XAttemptLog]] -> JSON-safe
    # Send ALL X-candles so hover works on every bar.
    # To keep payload manageable, trim step detail for X-candles with many attempts.
    candle_logs_out = {
        str(x_idx): _serialize_attempts(attempts)
        for x_idx, attempts in traces.items()
    }

    # Trim detection_log for large runs to avoid massive payloads
    # The narrative summary in the frontend uses candle_logs (above) for per-bar
    # hover, so detection_log is only used for the default full-list view.
    raw_log = detection_log or []
    max_log = max(10000, req.max_bars * 10)  # scale with bar count
    if len(raw_log) > max_log:
        half = max_log // 2
        channels = [e for e in raw_log if e.get('type') == 'channel']
        attempts = [e for e in raw_log if e.get('type') != 'channel']
        trimmed = channels + attempts[:half] + attempts[-half:]
        # Strip verbose step arrays to reduce size
        for entry in trimmed:
            if entry.get('steps') and len(entry['steps']) > 0:
                fail_step = next((s for s in entry['steps'] if not s.get('passed')), None)
                entry['steps'] = [fail_step] if fail_step else []
        detection_log_out = trimmed
    else:
        detection_log_out = raw_log

    return {
        "total_bars_in_file": total_bars,
        "bars_scanned": len(data),
        "patterns_found": len(results),
        "candles": candles_out,
        "patterns": [_result_to_dict(r) for r in results],
        "candle_logs": candle_logs_out,
        "detection_log": detection_log_out,
    }


@app.post("/api/detect_stream")
async def detect_stream(req: DetectRequest):
    """Progressive detection with NDJSON streaming.

    Processes detection in chunks of ~500 bars, streaming results as each
    chunk completes.  The first line includes OHLC candle data so the chart
    renders immediately.  Subsequent lines carry incremental patterns and
    full per-candle trace data.
    """
    try:
        raw_data = load_file(req.data_path)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Data file not found: {req.data_path}")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to load data: {e}")

    total_bars_in_file = len(raw_data)
    data = _slice_data(raw_data, req.max_bars)

    try:
        cfg = _build_cfg(req.config)
    except (KeyError, ValueError) as e:
        raise HTTPException(status_code=422, detail=f"Invalid config: {e}")

    detector = PatternDetector(data)

    # Pre-build OHLC candle list (sent with first chunk)
    candles_out = [
        {
            "idx": i,
            "time": float(data.timestamp[i]),
            "open": float(data.open[i]),
            "high": float(data.high[i]),
            "low": float(data.low[i]),
            "close": float(data.close[i]),
            "volume": float(data.volume[i]),
        }
        for i in range(len(data))
    ]

    async def event_generator():
        gen = detector.find_all_progressive(cfg, chunk_size=500)
        is_first = True
        patterns_found = 0

        try:
            while True:
                chunk = await asyncio.to_thread(next, gen, None)
                if chunk is None:
                    break

                # Compute golden lines for this chunk's patterns
                for r in chunk['patterns']:
                    try:
                        r.golden_line = compute_golden_line(
                            r.wave, r.pattern_type, cfg,
                            data.high_at, data.low_at, data.close_at,
                        )
                    except Exception:
                        pass

                patterns_found += len(chunk['patterns'])

                payload = {
                    'patterns': [_result_to_dict(r) for r in chunk['patterns']],
                    'candle_logs': {
                        str(x_idx): _compact_serialize_bar(attempts)
                        for x_idx, attempts in chunk['traces'].items()
                    },
                    'bars_scanned': chunk['bars_scanned'],
                    'total_bars': chunk['total_bars'],
                    'patterns_found': patterns_found,
                    'done': chunk['done'],
                }

                if is_first:
                    payload['candles'] = candles_out
                    payload['total_bars_in_file'] = total_bars_in_file
                    payload['bars_loaded'] = len(data)
                    is_first = False

                yield json.dumps(payload) + "\n"

        except Exception as e:
            yield json.dumps({'error': str(e), 'done': True}) + "\n"

    return StreamingResponse(
        event_generator(),
        media_type="application/x-ndjson",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


# ===================================================================
# Entry point
# ===================================================================

def main():
    import uvicorn
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    print(f"\n{'='*50}")
    print(f"  Harmonics Dashboard")
    print(f"  Local:   http://localhost:8001")
    print(f"  Network: http://{local_ip}:8001")
    print(f"{'='*50}\n")
    uvicorn.run("python_implementation.api.server:app", host="0.0.0.0", port=8001, reload=False, timeout_keep_alive=120)


if __name__ == "__main__":
    main()
