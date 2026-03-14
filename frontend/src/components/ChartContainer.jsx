import { useEffect, useRef, useState, useCallback } from 'react'
import { createChart } from 'lightweight-charts'

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Sort ascending by time and drop duplicate timestamps (lightweight-charts requirement). */
function dedup(arr) {
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
// ─────────────────────────────────────────────────────────────────────────────

function buildChannelLines(pattern, idxToTime, config) {
    const w = pattern.wave
    const channelType = pattern.channel_type || 'parallel'

    const span = w.b_idx - w.x_idx
    if (span === 0) return []
    const xb_slope = (w.b_price - w.x_price) / span

    let a_slope
    if (channelType === 'straight') a_slope = 0
    else if (channelType === 'non_parallel') a_slope = -xb_slope
    else a_slope = xb_slope

    const x_less_than_a = w.x_less_than_a

    const xb_up_pct = x_less_than_a ? (config?.xb_upper_width_pct ?? 0.5) : (config?.xb_lower_width_pct ?? 0.5)
    const xb_lo_pct = x_less_than_a ? (config?.xb_lower_width_pct ?? 0.5) : (config?.xb_upper_width_pct ?? 0.5)
    const a_up_pct = x_less_than_a ? (config?.a_upper_width_pct ?? 0.5) : (config?.a_lower_width_pct ?? 0.5)
    const a_lo_pct = x_less_than_a ? (config?.a_lower_width_pct ?? 0.5) : (config?.a_upper_width_pct ?? 0.5)

    const xbAt = (i) => w.x_price + xb_slope * (i - w.x_idx)
    const aAt  = (i) => w.a_price + a_slope  * (i - w.a_idx)

    const xbUpOff = Math.abs(w.x_price) * xb_up_pct * 0.01
    const xbLoOff = Math.abs(w.x_price) * xb_lo_pct * 0.01
    const aUpOff  = Math.abs(w.a_price) * a_up_pct  * 0.01
    const aLoOff  = Math.abs(w.a_price) * a_lo_pct  * 0.01

    const waveIdxs = [
        w.p_idx, w.x_idx, w.a_idx, w.b_idx,
        w.c_idx, w.d_idx, w.e_idx, w.f_idx,
    ].filter(i => i != null && i > 0 && idxToTime[i] != null)

    if (waveIdxs.length < 2) return []

    const mostRecentIdx = Math.min(...waveIdxs)
    const extBars = Math.max(0, config?.channel_extension_bars ?? 200)
    const extIdx  = Math.max(0, mostRecentIdx - extBars)
    if (idxToTime[extIdx] != null) waveIdxs.push(extIdx)

    const sortedIdxs = [...new Set(waveIdxs)].sort((a, b) => b - a)

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

function buildGoldenLine(pattern, idxToTime) {
    const gl = pattern.golden_line
    if (!gl) return null
    const t1 = idxToTime[gl.mn_start_idx]
    const t2 = idxToTime[gl.mn_end_idx]
    if (!t1 || !t2) return null
    return [
        { time: t1, value: gl.mn_start_price },
        { time: t2, value: gl.mn_end_price },
    ].sort((a, b) => a.time - b.time)
}

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
// Partial pattern helpers (for isolation mode)
// ─────────────────────────────────────────────────────────────────────────────

const WAVE_LABELS = ['p', 'x', 'a', 'b', 'c', 'd', 'e', 'f']

/** Build zigzag line data from a partial_wave dict */
function buildPartialZigzag(partialWave, idxToTime) {
    if (!partialWave) return []
    const pts = []
    for (const label of WAVE_LABELS) {
        const idx = partialWave[`${label}_idx`]
        const price = partialWave[`${label}_price`]
        if (idx != null && idx > 0 && price != null && price !== 0) {
            const time = idxToTime[idx]
            if (time != null) pts.push({ time, value: price, _label: label.toUpperCase() })
        }
    }
    return dedup(pts) || []
}

/** Build markers for partial wave points */
function buildPartialMarkers(partialWave, idxToTime, isFail) {
    if (!partialWave) return { markers: [], lastPoint: null }
    const markers = []
    let lastPoint = null
    for (const label of WAVE_LABELS) {
        const idx = partialWave[`${label}_idx`]
        const price = partialWave[`${label}_price`]
        if (idx != null && idx > 0 && price != null && price !== 0) {
            const time = idxToTime[idx]
            if (time != null) {
                lastPoint = { label: label.toUpperCase(), time, price }
                markers.push({
                    time,
                    position: ['X', 'B', 'D', 'F'].includes(label.toUpperCase()) ? 'belowBar' : 'aboveBar',
                    color: '#f59e0b',
                    shape: 'circle',
                    text: label.toUpperCase(),
                    size: 0.5,
                })
            }
        }
    }
    return { markers: markers.sort((a, b) => a.time - b.time), lastPoint }
}

// ─────────────────────────────────────────────────────────────────────────────
// On-chart log overlay content builder (left-click — detailed trace view)
// ─────────────────────────────────────────────────────────────────────────────

function buildOverlayHTML(barIdx, attempts, isPinned) {
    if (!attempts || !attempts.length) {
        return `<div class="ov-header">
            <span class="ov-bar">\u2630 Bar #${barIdx}</span>
            <span class="ov-stat">No detection traces at this bar</span>
        </div>
        <div class="ov-empty-hint">Right-click a candle for pattern isolation</div>`
    }
    const passed = attempts.filter(a => a.succeeded).length
    const failed = attempts.length - passed
    let html = `<div class="ov-header">
        <span class="ov-bar">\u2630 Bar #${barIdx} \u2014 Detection Log</span>
        <div class="ov-summary">
            <span class="ov-stat">${attempts.length} traces</span>
            ${passed ? `<span class="ov-stat ov-pass-stat">\u2713 ${passed} found</span>` : ''}
            ${failed ? `<span class="ov-stat ov-fail-stat">\u2717 ${failed} rejected</span>` : ''}
        </div>
        ${isPinned ? '<span class="ov-pin">\uD83D\uDD12 pinned</span>' : '<span class="ov-pin-hint">click again to unpin</span>'}
    </div><div class="ov-trace-list">`

    attempts.forEach((a, i) => {
        const dir = a.x_is_low ? 'LOW' : 'HIGH'
        const dirCls = a.x_is_low ? 'bull' : 'bear'
        const arrow = a.x_is_low ? '\u25B2' : '\u25BC'
        const bInfo = a.b_idx !== -1 ? `\u2192 B#${a.b_idx} (${a.b_price?.toFixed(2) ?? '?'})` : '\u2192 no B found'

        if (a.succeeded) {
            html += `<div class="ov-trace success">
                <div class="ov-trace-head">
                    <span class="ov-trace-dir ${dirCls}">${arrow} X=${dir}</span>
                    <span class="ov-trace-result pass">\u2713 PATTERN FOUND</span>
                </div>
                <div class="ov-trace-route">${bInfo}</div>
            </div>`
        } else {
            // Show the failure step prominently with detail from steps
            const failStep = a.steps?.find(s => !s.passed)
            const failDetail = failStep?.detail || a.rejected_at || a.step_reached || 'unknown'
            const failStepName = failStep?.step || a.step_reached || '?'

            html += `<div class="ov-trace failed">
                <div class="ov-trace-head">
                    <span class="ov-trace-dir ${dirCls}">${arrow} X=${dir}</span>
                    <span class="ov-trace-result fail">\u2717 ${failStepName}</span>
                </div>
                <div class="ov-trace-route">${bInfo}</div>
                <div class="ov-trace-reason">${failDetail}</div>
                ${failStep?.value != null ? `<div class="ov-trace-vals">val=${typeof failStep.value === 'number' ? failStep.value.toFixed(4) : failStep.value}${failStep.threshold_min != null ? ` range=[${failStep.threshold_min?.toFixed(2)}, ${failStep.threshold_max?.toFixed(2)}]` : ''}</div>` : ''}
            </div>`
        }
    })

    html += '</div>'
    return html
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

const LS_SOLID  = 0
const LS_DOTTED = 1

// ─────────────────────────────────────────────────────────────────────────────
// Component
// ─────────────────────────────────────────────────────────────────────────────

export default function ChartContainer({
    data, config, selectedPattern, pinnedBar,
    isolationMode, isolatedAttempts, candleLogs,
    onHover, onBarClick, onContextMenu, onExitIsolation,
}) {
    const containerRef    = useRef(null)
    const chartRef        = useRef(null)
    const candleSeriesRef = useRef(null)
    const patternSeriesRef = useRef([])
    const rawCandlesRef   = useRef(null)
    const onHoverRef      = useRef(onHover)
    const onBarClickRef   = useRef(onBarClick)
    const onContextMenuRef = useRef(onContextMenu)
    const crosshairBoxRef = useRef(null)
    const isMountedRef    = useRef(false)
    const [chartError, setChartError] = useState(null)

    onHoverRef.current     = onHover
    onBarClickRef.current  = onBarClick
    onContextMenuRef.current = onContextMenu

    // ---- Find candle by click coordinates ----
    const findCandleAtX = useCallback((clientX) => {
        const candles = rawCandlesRef.current
        if (!candles || !chartRef.current || !containerRef.current) return null
        const rect = containerRef.current.getBoundingClientRect()
        const x = clientX - rect.left
        const ts = chartRef.current.timeScale().coordinateToTime(x)
        if (!ts) return null
        for (const c of candles) {
            if (Math.floor(c.time) === ts) return c
        }
        return null
    }, [])

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

            // Crosshair hover
            chart.subscribeCrosshairMove(param => {
                if (!param || !param.time) {
                    onHoverRef.current({ idx: null, time: null })
                    return
                }
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

            // Left-click → pin bar (logs shown in right panel)
            container.addEventListener('click', (e) => {
                if (e.button !== 0) return
                const found = findCandleAtX(e.clientX)
                if (found) {
                    const ohlcv = { open: found.open, high: found.high, low: found.low, close: found.close }
                    onBarClickRef.current({ idx: found.idx, time: Math.floor(found.time), ...ohlcv })
                }
            })

            // Right-click → context menu (capture phase to beat lightweight-charts)
            container.addEventListener('contextmenu', (e) => {
                e.preventDefault()
                e.stopPropagation()
                const found = findCandleAtX(e.clientX)
                if (found && onContextMenuRef.current) {
                    onContextMenuRef.current({
                        x: e.clientX,
                        y: e.clientY,
                        barIdx: found.idx,
                    })
                }
            }, true)

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
    }, [findCandleAtX])

    // ---- Helper: remove all pattern series ----
    const clearPatternSeries = () => {
        patternSeriesRef.current.forEach(group => {
            if (group.zigzag) try { chartRef.current.removeSeries(group.zigzag) } catch (_) { }
            if (group.channels) {
                group.channels.forEach(s => {
                    if (s) try { chartRef.current.removeSeries(s) } catch (_) { }
                })
            }
            if (group.golden) try { chartRef.current.removeSeries(group.golden) } catch (_) { }
        })
        patternSeriesRef.current = []
    }

    // ---- Render a single complete pattern and return its series group ----
    const renderPattern = useCallback((pattern, idxToTime, config, highlight) => {
        const bull      = pattern.is_bullish
        const xbColor   = bull ? '#22c55e' : '#f87171'
        const aColor    = bull ? '#86efac' : '#fca5a5'
        const baseColor = highlight ? (bull ? '#34d399' : '#f87171') : (bull ? '#10b981' : '#ef4444')

        const zigzagData = dedup(buildZigzag(pattern, idxToTime))
        const zigzag = chartRef.current.addLineSeries({
            color: baseColor, lineWidth: highlight ? 2 : 1, lineStyle: highlight ? LS_SOLID : 2,
            crosshairMarkerVisible: false, priceLineVisible: false, lastValueVisible: false,
        })
        if (zigzagData.length >= 2) {
            zigzag.setData(zigzagData)
            const markers = buildMarkers(pattern, idxToTime)
            if (markers.length) zigzag.setMarkers(markers)
        }

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

        const glData = dedup(buildGoldenLine(pattern, idxToTime))
        let goldenSeries = null
        if (glData && glData.length >= 2) {
            goldenSeries = chartRef.current.addLineSeries({
                color: '#facc15', lineWidth: 2, lineStyle: LS_SOLID,
                crosshairMarkerVisible: true, priceLineVisible: false, lastValueVisible: false,
            })
            goldenSeries.setData(glData)
        }

        return { zigzag, channels: channelSeries, channelDescs, golden: goldenSeries, bull }
    }, [])

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

        // Load candles
        try {
            const chartData = toChartCandles(data.candles)
            candleSeriesRef.current.setData(chartData)
            rawCandlesRef.current = data.candles
        } catch (err) {
            console.error('Candle data error:', err)
            setChartError(`Candle render error: ${err.message}\n\nSee F12 \u2192 Console.`)
            return
        }

        const idxToTime = buildIdxToTime(data.candles)

        if (isolationMode) {
            // === ISOLATION MODE ===
            // 1. Draw completed patterns from this X candle (highlighted)
            const matchedPatterns = (data.patterns || []).filter(p =>
                p.wave.x_idx === isolationMode.xIdx
            )
            matchedPatterns.forEach(pattern => {
                try {
                    const group = renderPattern(pattern, idxToTime, config, true)
                    patternSeriesRef.current.push(group)
                } catch (err) {
                    console.warn('Isolation pattern error:', err)
                }
            })

            // 2. Draw partial patterns from failed attempts
            const attempts = isolatedAttempts || []
            attempts.forEach((attempt, ai) => {
                if (attempt.succeeded) return  // already drawn above via matched patterns
                if (!attempt.partial_wave) return

                try {
                    const zigzagData = buildPartialZigzag(attempt.partial_wave, idxToTime)
                    if (zigzagData.length < 1) return

                    // Partial zigzag: amber dashed line
                    const zigzag = chartRef.current.addLineSeries({
                        color: '#f59e0b', lineWidth: 1, lineStyle: 2,
                        crosshairMarkerVisible: false, priceLineVisible: false, lastValueVisible: false,
                    })
                    if (zigzagData.length >= 2) {
                        zigzag.setData(zigzagData)
                    }

                    // Markers for partial wave points + failure marker at last point
                    const { markers, lastPoint } = buildPartialMarkers(attempt.partial_wave, idxToTime, true)
                    if (lastPoint && !attempt.succeeded) {
                        // Add a red failure marker at the last discovered point
                        markers.push({
                            time: lastPoint.time,
                            position: 'aboveBar',
                            color: '#ef4444',
                            shape: 'arrowDown',
                            text: attempt.step_reached,
                            size: 0.8,
                        })
                        markers.sort((a, b) => a.time - b.time)
                    }
                    if (markers.length && zigzagData.length >= 2) {
                        zigzag.setMarkers(markers)
                    }

                    patternSeriesRef.current.push({
                        zigzag,
                        channels: [],
                        channelDescs: [],
                        golden: null,
                        bull: attempt.x_is_low,
                        isPartial: true,
                    })
                } catch (err) {
                    console.warn(`Partial pattern #${ai} error:`, err)
                }
            })
        } else {
            // === NORMAL MODE ===
            ;(data.patterns || []).forEach((pattern, pi) => {
                try {
                    const group = renderPattern(pattern, idxToTime, config, false)
                    patternSeriesRef.current.push(group)
                } catch (err) {
                    console.warn(`Pattern #${pi} overlay error:`, err)
                }
            })
        }

        chartRef.current.timeScale().fitContent()
    }, [data, config, isolationMode, isolatedAttempts, renderPattern])

    // ---- Highlight selected pattern (normal mode only) ----
    useEffect(() => {
        if (!data?.patterns || isolationMode) return
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
    }, [selectedPattern, data, isolationMode])

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
                                pinned #{pinnedBar.idx}
                            </span>
                        )}
                        {isolationMode && (
                            <span className="isolation-badge" onClick={onExitIsolation} title="Click to exit isolation mode">
                                ISOLATION: X#{isolationMode.xIdx} {isolationMode.xIsLow ? 'LOW (X<B)' : 'HIGH (X>B)'}
                                &nbsp;&mdash; click to exit
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
                        <div className="icon">&#x1F4C8;</div>
                        <p>Configure parameters and click <strong>&#x25B6; Detect Patterns</strong></p>
                        <p style={{ fontSize: 11, marginTop: 8, color: 'var(--text-muted)' }}>
                            Left-click candle to see logs &middot; Right-click for pattern isolation
                        </p>
                    </div>
                )}
                {chartError && (
                    <div className="chart-empty" style={{ color: '#ef4444', padding: 24 }}>
                        <div className="icon">&#x26A0;</div>
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
                        <span>Right-click candle for</span>
                        <span className="val" style={{ color: 'var(--accent-amber)' }}>pattern isolation</span>
                    </div>
                </div>
            )}
        </div>
    )
}
