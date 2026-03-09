"""Quick end-to-end smoke test for the Harmonics API."""
import requests, time, glob, sys

files = glob.glob("python_implementation/data/*.csv")
data_path = files[0] if files else ""
if not data_path:
    print("NO DATA FILE FOUND - put a CSV in python_implementation/data/")
    sys.exit(1)
print("Data:", data_path)

# Defaults
r = requests.get("http://localhost:8000/api/defaults", timeout=5)
print(f"GET /api/defaults: {r.status_code}")
defaults = r.json()
print("  config keys:", sorted(defaults["config"].keys()))

# Detection
t0 = time.time()
r2 = requests.post("http://localhost:8000/api/detect", json={
    "data_path": data_path,
    "max_bars": 200,
    "config": defaults["config"],
}, timeout=60)
dt = time.time() - t0
print(f"POST /api/detect: {r2.status_code} in {dt:.2f}s")
d = r2.json()
print(f"  bars_scanned={d['bars_scanned']}  patterns={d['patterns_found']}")
print(f"  candles={len(d['candles'])}  candle_log_bars={len(d['candle_logs'])}")

if d["candle_logs"]:
    k = next(iter(d["candle_logs"]))
    atmp = d["candle_logs"][k][0]
    steps = atmp["steps"]
    print(f"  bar #{k}: {len(steps)} steps, step_reached={atmp['step_reached']}, succeeded={atmp['succeeded']}")
    for s in steps[:3]:
        icon = "✓" if s["passed"] else "✗"
        print(f"    {icon} {s['step']}: {s['detail']}")

if d["patterns"]:
    p = d["patterns"][0]
    w = p["wave"]
    print(f"  pattern: {p['pattern_type']} {'BULL' if p['is_bullish'] else 'BEAR'} via {p['channel_type']}")
    print(f"  X={w['x_idx']} A={w['a_idx']} B={w['b_idx']}")

assert r.status_code == 200
assert r2.status_code == 200
assert "candles" in d and "patterns" in d and "candle_logs" in d
print("\nALL ASSERTIONS PASSED ✓")
