import { useEffect, useRef, useState } from 'react'
import { createChart } from 'lightweight-charts'

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Sort ascending by time and drop duplicate timestamps (lightweight-charts requirement). */
function dedup(arr, valueKey) {
    if (!arr || !arr.length) return arr
    const sorted = [...arr].sort((a, b) => a.time - b.time)
    return sorted.filter((p, i) => i === 0 || p.time !== sorted[i - 1].time)
}

function toChartCandles(candles) {
    if (!candles || !candles.length) return []
    return dedup(candles.map(c => ({
        time: Math.floor(c.time),
        open: c.open, high: c.high, low: c.low, close: c.close,
    })))
}

/** Build idxToTime map from candle array (idx 0 = most recent) */
function buildIdxToTime(candles) {
    const m = {}
    if (candles) candles.forEach(c => { m[c.idx] = Math.floor(c.time) })
    return m
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel computation
//
// MT5 bar index 0 = most recent → largest timestamp.
// idx increases as we go further back in time (smaller timestamp).
//
// XB slope in "price per idx-unit":
//   slope = (b_price - x_price) / (b_idx - x_idx)
//   b_idx < x_idx  →  denominator is negative for an upward XB move
//
// A-channel slope depends on channel type:
//   parallel:     a_slope = xb_slope
//   straight:     a_slope = 0
//   non_parallel: a_slope = -xb_slope
//
// Price at idx i on XB baseline:  xbAt(i) = x_price + xb_slope * (i - x_idx)
// Price at idx i on A centerline: aAt(i)  = a_price + a_slope  * (i - a_idx)
//
// Channel boundary offsets use the anchor price to compute absolute width:
//   upper = center(i) + |anchor_price| * width_pct / 100
//   lower = center(i) - |anchor_price| * width_pct / 100
//
// For X < A (x_less_than_a=true):  upper_pct = xb_upper_width_pct, lower_pct = xb_lower_width_pct
// For X > A (x_less_than_a=false): upper and lower swap so user-facing "upper" semantics stay consistent
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Build six line data series for a pattern's dual-channel system:
 *   XB center (solid), XB upper (dotted), XB lower (dotted)
 *   A  center (solid), A  upper (dotted), A  lower (dotted)
 *
 * Returns an array of channel descriptor objects.
 */
function buildChannelLines(pattern, idxToTime, config) {
    const w = pattern.wave
    const channelType = pattern.channel_type || 'parallel'

    const span = w.b_idx - w.x_idx  // negative (b is newer = lower idx)
    if (span === 0) return []
    const xb_slope = (w.b_price - w.x_price) / span

    // A-channel slope based on channel type
    let a_slope
    if (channelType === 'straight') {
        a_slope = 0
    } else if (channelType === 'non_parallel') {
        a_slope = -xb_slope
    } else {
        a_slope = xb_slope  // parallel (default)
    }

    const x_less_than_a = w.x_less_than_a

    // Width percentages — swap upper/lower for X>A
    const xb_up_pct = x_less_than_a
        ? (config?.xb_upper_width_pct ?? 0.5)
        : (config?.xb_lower_width_pct ?? 0.5)
    const xb_lo_pct = x_less_than_a
        ? (config?.xb_lower_width_pct ?? 0.5)
        : (config?.xb_upper_width_pct ?? 0.5)
    const a_up_pct = x_less_than_a
        ? (config?.a_upper_width_pct ?? 0.5)
        : (config?.a_lower_width_pct ?? 0.5)
    const a_lo_pct = x_less_than_a
        ? (config?.a_lower_width_pct ?? 0.5)
        : (config?.a_upper_width_pct ?? 0.5)

    // Center-line price at a given bar index
    const xbAt = (i) => w.x_price + xb_slope * (i - w.x_idx)
    const aAt  = (i) => w.a_price + a_slope  * (i - w.a_idx)

    // Absolute width offsets (computed from anchor price)
    const xbUpOff = Math.abs(w.x_price) * xb_up_pct * 0.01
    const xbLoOff = Math.abs(w.x_price) * xb_lo_pct * 0.01
    const aUpOff  = Math.abs(w.a_price) * a_up_pct  * 0.01
    const aLoOff  = Math.abs(w.a_price) * a_lo_pct  * 0.01

    // Collect all wave-point idx values that have a known timestamp
    const waveIdxs = [
        w.p_idx, w.x_idx, w.a_idx, w.b_idx,
        w.c_idx, w.d_idx, w.e_idx, w.f_idx,
    ].filter(i => i != null && i > 0 && idxToTime[i] != null)

    if (waveIdxs.length < 2) return []

    // Add extension beyond the most-recent (lowest-idx) pattern point
    const mostRecentIdx = Math.min(...waveIdxs)
    const extBars = Math.max(0, config?.channel_extension_bars ?? 200)
    const extIdx  = Math.max(0, mostRecentIdx - extBars)
    if (idxToTime[extIdx] != null) waveIdxs.push(extIdx)

    // Sort descending by idx so that time is ascending (chart requirement)
    const sortedIdxs = [...new Set(waveIdxs)].sort((a, b) => b - a)

    /** Build a deduplicated { time, value }[] series for one price function. */
    const makeSeries = (priceFn) => {
        const pts = sortedIdxs
            .filter(i => idxToTime[i] != null)
            .map(i => ({ time: idxToTime[i], value: priceFn(i) }))
        return pts.filter((p, i) => i === 0 || p.time !== pts[i - 1].time)
    }

    return [
        { series: makeSeries(i => xbAt(i)),             isXB: true,  solid: true,  tag: 'xb_c' },
        { series: makeSeries(i => xbAt(i) + xbUpOff),   isXB: true,  solid: false, tag: 'xb_u' },
        { series: makeSeries(i => xbAt(i) - xbLoOff),   isXB: true,  solid: false, tag: 'xb_l' },
        { series: makeSeries(i => aAt(i)),               isXB: false, solid: true,  tag: 'a_c'  },
        { series: makeSeries(i => aAt(i) + aUpOff),      isXB: false, solid: false, tag: 'a_u'  },
        { series: makeSeries(i => aAt(i) - aLoOff),      isXB: false, solid: false, tag: 'a_l'  },
    ].filter(ch => ch.series.length >= 2)
}

/** Build golden line series in yellow */
function buildGoldenLine(pattern, idxToTime) {
    const gl = pattern.golden_line
    if (!gl) return null
    const t1 = idxToTime[gl.mn_start_idx]
    const t2 = idxToTime[gl.mn_end_idx]
    if (!t1 || !t2) return null
    const pts = [
        { time: t1, value: gl.mn_start_price },
        { time: t2, value: gl.mn_end_price },
    ].sort((a, b) => a.time - b.time)
    return pts
}

/** Build zigzag wave line P→X→A→B→... */
function buildZigzag(pattern, idxToTime) {
    const w = pattern.wave
    const pts = [
        [w.p_idx, w.p_price],
        [w.x_idx, w.x_price],
        [w.a_idx, w.a_price],
        [w.b_idx, w.b_price],
    ]
    if (['XABC', 'XABCD', 'XABCDE', 'XABCDEF'].includes(pattern.pattern_type))
        pts.push([w.c_idx, w.c_price])
    if (['XABCD', 'XABCDE', 'XABCDEF'].includes(pattern.pattern_type))
        pts.push([w.d_idx, w.d_price])
    if (['XABCDE', 'XABCDEF'].includes(pattern.pattern_type))
        pts.push([w.e_idx, w.e_price])
    if (pattern.pattern_type === 'XABCDEF')
        pts.push([w.f_idx, w.f_price])

    return pts
        .map(([idx, price]) => ({ time: idxToTime[idx], value: price }))
        .filter(p => p.time != null)
        .sort((a, b) => a.time - b.time)
        .filter((p, i, arr) => i === 0 || p.time !== arr[i - 1].time)
}

/** Build markers for wave labels */
function buildMarkers(pattern, idxToTime) {
    const w = pattern.wave
    const color = pattern.is_bullish ? '#10b981' : '#ef4444'
    const pts = [
        [w.p_idx, 'P'], [w.x_idx, 'X'], [w.a_idx, 'A'], [w.b_idx, 'B'],
    ]
    if (['XABC', 'XABCD', 'XABCDE', 'XABCDEF'].includes(pattern.pattern_type))
        pts.push([w.c_idx, 'C'])
    if (['XABCD', 'XABCDE', 'XABCDEF'].includes(pattern.pattern_type))
        pts.push([w.d_idx, 'D'])
    if (['XABCDE', 'XABCDEF'].includes(pattern.pattern_type))
        pts.push([w.e_idx, 'E'])
    if (pattern.pattern_type === 'XABCDEF')
        pts.push([w.f_idx, 'F'])

    return pts
        .map(([idx, label]) => {
            const t = idxToTime[idx]
            if (!t) return null
            const below = ['X', 'B', 'D', 'F'].includes(label)
            return { time: t, position: below ? 'belowBar' : 'aboveBar', color, shape: 'circle', text: label, size: 0.8 }
        })
        .filter(Boolean)
        .sort((a, b) => a.time - b.time)
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart options
// ─────────────────────────────────────────────────────────────────────────────

const CHART_OPTS = {
    layout: {
        background: { color: '#080b12' },
        textColor: '#8b9ab5',
        fontFamily: "'Inter', system-ui, sans-serif",
        fontSize: 11,
    },
    grid: {
        vertLines: { color: '#1c2740' },
        horzLines: { color: '#1c2740' },
    },
    crosshair: {
        mode: 1,
        vertLine: { color: '#3b82f6', width: 1, style: 1, labelBackgroundColor: '#3b82f6' },
        horzLine: { color: '#3b82f6', width: 1, style: 1, labelBackgroundColor: '#3b82f6' },
    },
    rightPriceScale: { borderColor: '#253050' },
    timeScale: { borderColor: '#253050', timeVisible: true, secondsVisible: false },
}

// lightweight-charts line styles: 0=Solid, 1=Dotted, 2=Dashed, 3=LargeDashed, 4=SparseDotted
const LS_SOLID  = 0
const LS_DOTTED = 1

// ─────────────────────────────────────────────────────────────────────────────
// Component
// ─────────────────────────────────────────────────────────────────────────────

export default function ChartContainer({ data, config, selectedPattern, pinnedBar, onHover, onBarClick }) {
    const containerRef   = useRef(null)
    const chartRef       = useRef(null)
    const candleSeriesRef = useRef(null)
    /**
     * patternSeriesRef stores per-pattern series groups:
     *   { zigzag, channels: [lineSeries,...], golden }
     */
    const patternSeriesRef = useRef([])
    const rawCandlesRef  = useRef(null)
    const onHoverRef     = useRef(onHover)
    const onBarClickRef  = useRef(onBarClick)
    const crosshairBoxRef = useRef(null)
    const isMountedRef   = useRef(false)
    const [chartError, setChartError] = useState(null)

    onHoverRef.current    = onHover
    onBarClickRef.current = onBarClick

    // ---- Init chart once ----
    useEffect(() => {
        const container = containerRef.current
        if (!container || isMountedRef.current) return
        isMountedRef.current = true

        try {
            const chart = createChart(container, {
                ...CHART_OPTS,
                width:  container.clientWidth  || 800,
                height: container.clientHeight || 500,
            })
            chartRef.current = chart

            const cs = chart.addCandlestickSeries({
                upColor:        '#10b981', downColor:        '#ef4444',
                borderUpColor:  '#10b981', borderDownColor:  '#ef4444',
                wickUpColor:    '#10b981', wickDownColor:    '#ef4444',
            })
            candleSeriesRef.current = cs

            // Crosshair hover → propagate to LogPanel
            chart.subscribeCrosshairMove(param => {
                if (!param || !param.time) return
                const candles = rawCandlesRef.current
                if (!candles) return
                const ohlcv = param.seriesData ? param.seriesData.get(cs) : null
                let barIdx = null
                for (const c of candles) {
                    if (Math.floor(c.time) === param.time) { barIdx = c.idx; break }
                }
                if (barIdx !== null) {
                    onHoverRef.current({ idx: barIdx, time: param.time, ...(ohlcv || {}) })
                    if (crosshairBoxRef.current && ohlcv) {
                        crosshairBoxRef.current.innerHTML =
                            `<span class="price-item"><span class="label">O</span><span class="val">${ohlcv.open?.toFixed(5)}</span></span>` +
                            `<span class="price-item"><span class="label">H</span><span class="val" style="color:var(--bull-color)">${ohlcv.high?.toFixed(5)}</span></span>` +
                            `<span class="price-item"><span class="label">L</span><span class="val" style="color:var(--bear-color)">${ohlcv.low?.toFixed(5)}</span></span>` +
                            `<span class="price-item"><span class="label">C</span><span class="val">${ohlcv.close?.toFixed(5)}</span></span>`
                    }
                }
            })

            // Click → pin bar in LogPanel
            container.addEventListener('click', (e) => {
                const candles = rawCandlesRef.current
                if (!candles || !chartRef.current) return
                const rect = container.getBoundingClientRect()
                const x = e.clientX - rect.left
                const ts = chart.timeScale().coordinateToTime(x)
                if (!ts) return
                let found = null
                for (const c of candles) {
                    if (Math.floor(c.time) === ts) { found = c; break }
                }
                if (found) {
                    const ohlcv = { open: found.open, high: found.high, low: found.low, close: found.close }
                    onBarClickRef.current({ idx: found.idx, time: Math.floor(found.time), ...ohlcv })
                }
            })

            // Resize observer
            const ro = new ResizeObserver(() => {
                if (container && chartRef.current) {
                    chartRef.current.resize(container.clientWidth, container.clientHeight)
                }
            })
            ro.observe(container)

            return () => { ro.disconnect() }
        } catch (err) {
            setChartError(`Chart init error: ${err.message}`)
        }
    }, [])

    // ---- Helper: remove all pattern series ----
    const clearPatternSeries = () => {
        patternSeriesRef.current.forEach(group => {
            // Remove zigzag
            if (group.zigzag) try { chartRef.current.removeSeries(group.zigzag) } catch (_) { }
            // Remove all channel lines
            if (group.channels) {
                group.channels.forEach(s => {
                    if (s) try { chartRef.current.removeSeries(s) } catch (_) { }
                })
            }
            // Remove golden line
            if (group.golden) try { chartRef.current.removeSeries(group.golden) } catch (_) { }
        })
        patternSeriesRef.current = []
    }

    // ---- Rebuild chart data + overlays ----
    useEffect(() => {
        if (!chartRef.current || !candleSeriesRef.current) return
        setChartError(null)
        clearPatternSeries()

        if (!data?.candles?.length) {
            try { candleSeriesRef.current.setData([]) } catch (_) { }
            rawCandlesRef.current = null
            return
        }

        // 1. Load candles (must succeed for chart to show anything)
        try {
            const chartData = toChartCandles(data.candles)
            candleSeriesRef.current.setData(chartData)
            rawCandlesRef.current = data.candles
        } catch (err) {
            console.error('Candle data error:', err)
            setChartError(`Candle render error: ${err.message}\n\nSee F12 → Console.`)
            return
        }

        // 2. Load pattern overlays (each pattern wrapped individually so one bad pattern can't break the chart)
        const idxToTime = buildIdxToTime(data.candles)
        ;(data.patterns || []).forEach((pattern, pi) => {
            try {
                const bull      = pattern.is_bullish
                const xbColor   = bull ? '#22c55e' : '#f87171'
                const aColor    = bull ? '#86efac' : '#fca5a5'
                const baseColor = bull ? '#10b981' : '#ef4444'

                // Zigzag wave line
                const zigzagData = dedup(buildZigzag(pattern, idxToTime))
                const zigzag = chartRef.current.addLineSeries({
                    color: baseColor, lineWidth: 1, lineStyle: 2,
                    crosshairMarkerVisible: false, priceLineVisible: false, lastValueVisible: false,
                })
                if (zigzagData.length >= 2) {
                    zigzag.setData(zigzagData)
                    const markers = buildMarkers(pattern, idxToTime)
                    if (markers.length) zigzag.setMarkers(markers)
                }

                // Dual channel lines: 3 XB + 3 A = 6 lines total
                const channelDescs = buildChannelLines(pattern, idxToTime, config)
                const channelSeries = channelDescs.map(ch => {
                    const color = ch.isXB ? xbColor : aColor
                    const s = chartRef.current.addLineSeries({
                        color,
                        lineWidth: ch.solid ? 2 : 1,
                        lineStyle: ch.solid ? LS_SOLID : LS_DOTTED,
                        crosshairMarkerVisible: false,
                        priceLineVisible: false,
                        lastValueVisible: false,
                    })
                    if (ch.series.length >= 2) s.setData(dedup(ch.series))
                    return s
                })

                // Golden line in yellow
                const glData = dedup(buildGoldenLine(pattern, idxToTime))
                let goldenSeries = null
                if (glData && glData.length >= 2) {
                    goldenSeries = chartRef.current.addLineSeries({
                        color: '#facc15',
                        lineWidth: 2,
                        lineStyle: LS_SOLID,
                        crosshairMarkerVisible: true,
                        priceLineVisible: false,
                        lastValueVisible: false,
                    })
                    goldenSeries.setData(glData)
                }

                patternSeriesRef.current.push({
                    zigzag,
                    channels: channelSeries,
                    channelDescs,
                    golden: goldenSeries,
                    bull,
                })
            } catch (err) {
                console.warn(`Pattern #${pi} overlay error:`, err)
            }
        })

        chartRef.current.timeScale().fitContent()
    }, [data, config])

    // ---- Highlight selected pattern ----
    useEffect(() => {
        if (!data?.patterns) return
        patternSeriesRef.current.forEach((group, i) => {
            const p = data.patterns[i]
            if (!p) return
            const bull      = group.bull
            const isSelected = selectedPattern === i
            const base      = bull ? '#10b981' : '#ef4444'
            const sel       = bull ? '#34d399' : '#f87171'
            const xbBase    = bull ? '#22c55e' : '#f87171'
            const aBase     = bull ? '#86efac' : '#fca5a5'

            if (group.zigzag) {
                group.zigzag.applyOptions({
                    color:     isSelected ? sel  : base,
                    lineWidth: isSelected ? 2    : 1,
                    lineStyle: isSelected ? LS_SOLID : 2,
                })
            }

            if (group.channels) {
                group.channels.forEach((s, ci) => {
                    const desc = group.channelDescs?.[ci]
                    if (!s || !desc) return
                    const baseClr = desc.isXB ? xbBase : aBase
                    s.applyOptions({
                        color:     isSelected ? sel : baseClr,
                        lineWidth: (isSelected && desc.solid) ? 2 : (desc.solid ? 2 : 1),
                    })
                })
            }
        })
    }, [selectedPattern, data])

    const isEmpty = !data?.candles?.length

    return (
        <div className="chart-area">
            {/* Toolbar */}
            <div className="chart-toolbar">
                <span className="symbol">HARMONICS</span>
                <div className="header-divider" style={{ height: 16, width: 1, background: 'var(--border)', margin: '0 8px' }} />
                {data ? (
                    <>
                        <span>{data.bars_scanned} bars</span>
                        {pinnedBar && (
                            <span style={{ background: 'var(--accent-blue)', color: '#fff', fontSize: 10, padding: '2px 7px', borderRadius: 10, marginLeft: 8 }}>
                                📌 Pinned bar #{pinnedBar.idx}
                            </span>
                        )}
                        <span style={{ marginLeft: 'auto', color: 'var(--accent-cyan)' }}>
                            {data.patterns_found} patterns
                        </span>
                    </>
                ) : (
                    <span style={{ color: 'var(--text-muted)' }}>No data loaded</span>
                )}
            </div>

            {/* Chart canvas */}
            <div className="chart-wrap" ref={containerRef} style={{ cursor: 'crosshair' }}>
                {isEmpty && !chartError && (
                    <div className="chart-empty">
                        <div className="icon">📈</div>
                        <p>Configure parameters and click <strong>▶ Detect Patterns</strong></p>
                        <p style={{ fontSize: 11, marginTop: 8, color: 'var(--text-muted)' }}>
                            Click any candle after detection to lock the trace panel
                        </p>
                    </div>
                )}
                {chartError && (
                    <div className="chart-empty" style={{ color: '#ef4444', padding: 24 }}>
                        <div className="icon">⚠</div>
                        <pre style={{ margin: '12px auto', textAlign: 'left', fontSize: 11, maxWidth: 600, whiteSpace: 'pre-wrap' }}>
                            {chartError}
                        </pre>
                    </div>
                )}
                <div ref={crosshairBoxRef} className="crosshair-info" style={{ display: isEmpty ? 'none' : undefined }} />
            </div>

            {/* Stats strip */}
            {data && (
                <div className="pattern-strip">
                    <div className="stat-chip"><span>Total:</span><span className="val">{data.patterns_found}</span></div>
                    <div className="stat-chip"><span>Bull:</span><span className="val bull">{data.patterns.filter(p => p.is_bullish).length}</span></div>
                    <div className="stat-chip"><span>Bear:</span><span className="val bear">{data.patterns.filter(p => !p.is_bullish).length}</span></div>
                    <div className="stat-chip"><span>Bars:</span><span className="val">{data.bars_scanned} / {data.total_bars_in_file}</span></div>
                    <div className="stat-chip" style={{ marginLeft: 'auto' }}>
                        <span>Click candle to</span>
                        <span className="val" style={{ color: 'var(--accent-blue)' }}>📌 lock trace</span>
                    </div>
                </div>
            )}
        </div>
    )
}
