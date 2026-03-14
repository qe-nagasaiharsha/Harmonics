import { useState, useMemo, useRef, useEffect, useCallback } from 'react'

// ─────────────────────────────────────────────────────────────────────────────
// Step classification: maps step_reached → pipeline stage
// ─────────────────────────────────────────────────────────────────────────────
const STEP_TO_STAGE = {
    // B-stage: finding B candidate and validating XAB triangle
    B_SEARCH:     'B',
    A_FIND:       'B',
    XB_RETRACE:   'B',
    A_WIDTH:      'B',
    A_SECONDARY:  'B',
    XB_SEGMENT:   'B',
    XB_SPAN:      'B',
    P_POINT:      'B',
    PX_SEGMENT:   'B',
    // C-stage
    C_SEARCH:     'C',
    C_POSITION:   'C',
    CASCADE:      'C',
    // D-stage
    D_CANDIDATES: 'D',
    // E-stage
    E_CANDIDATES: 'E',
    // F-stage
    F_CANDIDATES: 'F',
    // Post-detection filters
    TICK_SPEED:   'FILTER',
    DIVERGENCE:   'FILTER',
    DIRECTION:    'FILTER',
    OVERLAP:      'FILTER',
    // Success
    FINALIZE:     'SUCCESS',
}

const STAGE_ORDER = ['B', 'C', 'D', 'E', 'F', 'FILTER']
const STAGE_LABELS = { B: 'B Point', C: 'C Point', D: 'D Point', E: 'E Point', F: 'F Point', FILTER: 'Final Filters' }

// ─────────────────────────────────────────────────────────────────────────────
// Human-readable explanations for each step failure
// ─────────────────────────────────────────────────────────────────────────────
function explainStep(step, count, avgValue, thresholds) {
    const avg = avgValue != null ? avgValue.toFixed(2) : null
    const range = thresholds ? `[${thresholds.min.toFixed(1)}, ${thresholds.max.toFixed(1)}]` : null

    switch (step) {
        case 'B_SEARCH':
            return `${count} had no valid B candidate in the configured bar range`
        case 'A_FIND':
            return `${count} found B but no valid A point \u2014 no candle deviated enough from the XB slope to form a channel`
        case 'XB_RETRACE':
            return avg && range
                ? `${count} failed XB retracement check (avg ${avg}% vs allowed ${range})`
                : `${count} failed XB retracement check \u2014 ratio outside allowed range`
        case 'A_WIDTH':
            return avg
                ? `${count} failed A-width validation (A price deviation ${avg} outside dynamic width band)`
                : `${count} failed A-width validation \u2014 A point sits outside the channel width band`
        case 'A_SECONDARY':
            return `${count} failed secondary A scan \u2014 a more extreme A point pushed retracement out of range`
        case 'XB_SEGMENT':
            return `${count} failed XB strict segment check \u2014 candles between X and B breach the slope line`
        case 'XB_SPAN':
            return `${count} failed X-to-B span containment \u2014 price excursions exceed the allowed buffer`
        case 'P_POINT':
            return `${count} had insufficient bars before X to establish the P point`
        case 'PX_SEGMENT':
            return `${count} failed P-to-X segment validation \u2014 candles breach the PX slope`
        case 'C_SEARCH':
            return `${count} found no valid C \u2014 no candle after B within the configured length range lies on the A slope`
        case 'C_POSITION':
            return avg && range
                ? `${count} found C candidates but they failed position validation (avg ${avg} vs ${range})`
                : `${count} found C candidates on the A slope but highs/lows between B and C breach constraints`
        case 'CASCADE':
            return `${count} exhausted all C/D/E/F candidate combinations without finding a valid pattern`
        case 'D_CANDIDATES':
            return `${count} found valid C but no D candidate exists within the required length range in the XB channel`
        case 'E_CANDIDATES':
            return `${count} found valid D but no E candidate exists within the required length range in the A channel`
        case 'F_CANDIDATES':
            return `${count} found valid E but no F candidate exists within the required length range in the XB channel`
        case 'TICK_SPEED':
            return `${count} formed a complete pattern but failed the minimum tick speed filter`
        case 'DIVERGENCE':
            return `${count} formed a complete pattern but failed the divergence filter`
        case 'DIRECTION':
            return `${count} formed a complete pattern but were filtered by direction preference`
        case 'OVERLAP':
            return `${count} formed a complete pattern but overlap with a prior detection`
        default:
            return `${count} failed at ${step}`
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Build narrative summary for one direction (bullish or bearish)
// ─────────────────────────────────────────────────────────────────────────────
function buildDirectionSummary(attempts) {
    if (!attempts.length) return null

    const succeeded = attempts.filter(a => a.succeeded)
    const failed = attempts.filter(a => !a.succeeded)

    // Group failed attempts by pipeline stage
    const stageGroups = {}
    failed.forEach(a => {
        const step = (a.step_reached || 'B_SEARCH').toUpperCase()
        const stage = STEP_TO_STAGE[step] || 'B'
        if (!stageGroups[stage]) stageGroups[stage] = []
        stageGroups[stage].push(a)
    })

    // Build stages array
    const stages = STAGE_ORDER
        .filter(stage => stageGroups[stage]?.length > 0)
        .map(stage => {
            const stageAttempts = stageGroups[stage]

            // Sub-group by exact step_reached
            const byStep = {}
            stageAttempts.forEach(a => {
                const step = a.step_reached || 'B_SEARCH'
                if (!byStep[step]) byStep[step] = { count: 0, values: [], thresholds: null }
                byStep[step].count++
                // Extract failing step's numeric data
                const failStep = a.steps?.find(s => !s.passed)
                if (failStep?.value != null && typeof failStep.value === 'number')
                    byStep[step].values.push(failStep.value)
                if (failStep?.threshold_min != null && !byStep[step].thresholds)
                    byStep[step].thresholds = { min: failStep.threshold_min, max: failStep.threshold_max }
            })

            // Count how many attempts got past this stage
            const stageIdx = STAGE_ORDER.indexOf(stage)
            const laterStages = STAGE_ORDER.slice(stageIdx + 1)
            const progressedCount = laterStages.reduce(
                (sum, s) => sum + (stageGroups[s]?.length || 0), 0
            ) + succeeded.length

            // Generate per-step explanations
            const explanations = Object.entries(byStep)
                .sort((a, b) => b[1].count - a[1].count)
                .map(([step, info]) => {
                    const avgValue = info.values.length >= 1
                        ? info.values.reduce((a, b) => a + b, 0) / info.values.length
                        : null
                    return explainStep(step, info.count, avgValue, info.thresholds)
                })

            return {
                pointLabel: STAGE_LABELS[stage] || stage,
                total: stageAttempts.length,
                progressedCount,
                explanations,
            }
        })

    return {
        totalAttempts: attempts.length,
        succeeded: succeeded.length,
        stages,
        result: succeeded.length > 0 ? 'success' : 'no_pattern',
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// LogPanel Component
// ─────────────────────────────────────────────────────────────────────────────
export default function LogPanel({ detectionLog, hoveredBarIdx, isolationMode, candleLogs }) {
    const [filter, setFilter] = useState('all')
    const [searchBar, setSearchBar] = useState('')
    const [expandedRows, setExpandedRows] = useState(new Set())
    const scrollRef = useRef(null)

    // Determine active bar filter: isolation > hovered
    const activeBarIdx = isolationMode ? isolationMode.xIdx : hoveredBarIdx
    const activeDirection = isolationMode ? isolationMode.xIsLow : null

    useEffect(() => {
        setExpandedRows(new Set())
        if (scrollRef.current) scrollRef.current.scrollTop = 0
    }, [detectionLog])

    useEffect(() => {
        setExpandedRows(new Set())
    }, [filter, searchBar, activeBarIdx, activeDirection])

    const stats = useMemo(() => {
        if (!detectionLog?.length) return null
        const attempts = detectionLog.filter(e => e.type === 'attempt')
        return {
            total: attempts.length,
            success: attempts.filter(a => a.succeeded).length,
            fail: attempts.filter(a => !a.succeeded).length,
        }
    }, [detectionLog])

    // Filtered list for the default log view (no bar selected)
    const filtered = useMemo(() => {
        if (!detectionLog?.length) return []
        const barNum = searchBar ? parseInt(searchBar, 10) : NaN
        return detectionLog.filter(entry => {
            if (entry.type === 'channel') {
                if (activeBarIdx != null) return false
                return true
            }
            if (filter === 'success' && !entry.succeeded) return false
            if (filter === 'fail' && entry.succeeded) return false
            if (!isNaN(barNum) && entry.x_idx !== barNum) return false
            if (activeBarIdx != null && entry.x_idx !== activeBarIdx) return false
            if (activeDirection != null && entry.x_is_low !== activeDirection) return false
            return true
        })
    }, [detectionLog, filter, searchBar, activeBarIdx, activeDirection])

    // ── Narrative summary (shown when a bar is active) ──
    const narrativeSummary = useMemo(() => {
        if (activeBarIdx == null) return null

        // Prefer candleLogs (richer, pre-indexed by bar) over filtered detectionLog
        const barKey = String(activeBarIdx)
        let attempts = candleLogs?.[barKey] ?? []

        // Fallback to filtered detection_log entries
        if (!attempts.length) {
            attempts = filtered.filter(e => e.type !== 'channel')
        }

        if (!attempts.length) return null

        // Split by direction
        const bullish = attempts.filter(a => a.x_is_low === true)
        const bearish = attempts.filter(a => a.x_is_low === false)

        const directions = []
        if (activeDirection == null || activeDirection === true) {
            const summary = buildDirectionSummary(bullish)
            if (summary) directions.push({ label: 'X < B (Bullish)', isBull: true, ...summary })
        }
        if (activeDirection == null || activeDirection === false) {
            const summary = buildDirectionSummary(bearish)
            if (summary) directions.push({ label: 'X > B (Bearish)', isBull: false, ...summary })
        }

        return directions.length > 0 ? directions : null
    }, [activeBarIdx, activeDirection, candleLogs, filtered])

    const toggleRow = useCallback((i) => {
        setExpandedRows(prev => {
            const next = new Set(prev)
            if (next.has(i)) next.delete(i)
            else next.add(i)
            return next
        })
    }, [])

    // Track whether we have any data at all (streaming sends candle_logs but not detection_log)
    const hasAnyData = (detectionLog?.length > 0) || (candleLogs && Object.keys(candleLogs).length > 0)

    // ── Empty state ──
    if (!hasAnyData) {
        return (
            <aside className="log-panel">
                <div className="panel-header">Detection Log</div>
                <div className="log-empty">
                    <div className="icon">&#x27C1;</div>
                    <p>
                        Run detection to see sequential logs<br />
                        <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>
                            Every slope, channel, point &amp; validation step
                        </span>
                    </p>
                </div>
            </aside>
        )
    }

    // ── Main render ──
    return (
        <aside className="log-panel">
            {/* ── Header ── */}
            <div className="log-panel-header" style={{ flexShrink: 0 }}>
                <div className="log-panel-title">
                    Detection Log
                    {isolationMode && (
                        <span style={{ marginLeft: 8, fontSize: 10, padding: '2px 7px', borderRadius: 10, background: 'rgba(245,158,11,0.15)', color: 'var(--accent-amber)', fontWeight: 600 }}>
                            X#{isolationMode.xIdx} {isolationMode.xIsLow ? 'X<B' : 'X>B'}
                        </span>
                    )}
                    {!isolationMode && hoveredBarIdx != null && (
                        <span style={{ marginLeft: 8, fontSize: 10, padding: '2px 7px', borderRadius: 10, background: 'rgba(245,158,11,0.15)', color: 'var(--accent-amber)', fontWeight: 600 }}>
                            Bar #{hoveredBarIdx}
                        </span>
                    )}
                </div>

                {stats && (
                    <div className="log-stats-row">
                        <span className="log-stat total">{stats.total} attempts</span>
                        <span className="log-stat success">{stats.success} {'\u2713'}</span>
                        <span className="log-stat fail">{stats.fail} {'\u2717'}</span>
                    </div>
                )}

                {/* Filter controls: only shown when no bar is active (log list mode) */}
                {activeBarIdx == null && (
                    <div className="log-controls-row">
                        <div className="log-filter-row">
                            {[
                                { key: 'all', label: 'All' },
                                { key: 'success', label: '\u2713 Pass' },
                                { key: 'fail', label: '\u2717 Fail' },
                            ].map(f => (
                                <button
                                    key={f.key}
                                    className={`log-filter-btn ${filter === f.key ? 'active' : ''}`}
                                    onClick={() => setFilter(f.key)}
                                >
                                    {f.label}
                                </button>
                            ))}
                        </div>
                        <input
                            type="text"
                            className="log-bar-search"
                            placeholder="Bar #"
                            value={searchBar}
                            onChange={e => setSearchBar(e.target.value)}
                        />
                    </div>
                )}
            </div>

            {/* ── SUMMARY MODE (bar active) ── */}
            {narrativeSummary ? (
                <div className="narrative-summary" ref={scrollRef}>
                    {narrativeSummary.map((dir, di) => (
                        <div key={di} className={`narrative-direction ${dir.isBull ? 'bull' : 'bear'}`}>
                            {/* Direction header */}
                            <div className="narrative-dir-header">
                                <span className={`narrative-dir-icon ${dir.isBull ? 'bull' : 'bear'}`}>
                                    {dir.isBull ? '\u25B2' : '\u25BC'}
                                </span>
                                <span className="narrative-dir-label">{dir.label}</span>
                                <span className="narrative-dir-count">
                                    {dir.totalAttempts} attempt{dir.totalAttempts !== 1 ? 's' : ''}
                                </span>
                            </div>

                            {/* Success line */}
                            {dir.succeeded > 0 && (
                                <div className="narrative-success">
                                    {'\u2713'} {dir.succeeded} pattern{dir.succeeded !== 1 ? 's' : ''} found successfully
                                </div>
                            )}

                            {/* Stage narratives — only when NO pattern found */}
                            {dir.succeeded === 0 && dir.stages.map((stage, si) => (
                                <div key={si} className="narrative-stage">
                                    <div className="narrative-stage-header">
                                        <span className="narrative-stage-label">{stage.pointLabel}</span>
                                        <span className="narrative-stage-count">{stage.total} failed</span>
                                    </div>
                                    <div className="narrative-stage-body">
                                        {stage.explanations.map((text, ei) => (
                                            <p key={ei} className="narrative-explanation">{text}</p>
                                        ))}
                                        {stage.progressedCount > 0 && (
                                            <p className="narrative-progressed">
                                                {stage.progressedCount} attempt{stage.progressedCount !== 1 ? 's' : ''} progressed beyond this stage
                                            </p>
                                        )}
                                    </div>
                                </div>
                            ))}

                            {/* Result — only when no pattern found */}
                            {dir.succeeded === 0 && (
                                <div className="narrative-result none">
                                    {'\u2717'} No pattern found
                                </div>
                            )}
                        </div>
                    ))}

                    {/* No attempts at all for this bar */}
                    {narrativeSummary.length === 0 && (
                        <div className="log-empty" style={{ padding: '40px 20px' }}>
                            <div className="icon" style={{ fontSize: 20 }}>&#x25CB;</div>
                            <p>No detection attempts for this bar</p>
                        </div>
                    )}
                </div>
            ) : activeBarIdx != null ? (
                /* Bar active but no attempts found yet */
                <div className="narrative-summary" ref={scrollRef}>
                    <div className="log-empty" style={{ padding: '40px 20px' }}>
                        <div className="icon" style={{ fontSize: 20 }}>{'\u25CB'}</div>
                        <p>No detection attempts used this bar as X point</p>
                    </div>
                </div>
            ) : (
                /* ── LOG LIST MODE (no bar active) ── */
                <div ref={scrollRef} className="log-scroll">
                    {filtered.length > 0 ? (
                        filtered.map((entry, i) => (
                            entry.type === 'channel'
                                ? <ChannelDivider key={'ch-' + i} channel={entry.channel} />
                                : <LogRow
                                    key={entry.x_idx + '-' + entry.b_idx + '-' + i}
                                    entry={entry}
                                    isExpanded={expandedRows.has(i)}
                                    onToggle={() => toggleRow(i)}
                                />
                        ))
                    ) : hasAnyData && !detectionLog?.length ? (
                        /* Streaming mode — candle_logs loaded but no detection_log */
                        <div className="log-empty" style={{ padding: '40px 20px' }}>
                            <div className="icon" style={{ fontSize: 20 }}>{'\u25C8'}</div>
                            <p>
                                {Object.keys(candleLogs).length} bars analysed<br />
                                <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>
                                    Hover a candle or right-click to see detection analysis
                                </span>
                            </p>
                        </div>
                    ) : (
                        <div className="log-empty" style={{ padding: '40px 20px' }}>
                            <div className="icon" style={{ fontSize: 20 }}>{'\u25CB'}</div>
                            <p>No matching entries</p>
                        </div>
                    )}
                </div>
            )}
        </aside>
    )
}


// ─────────────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────────────

function ChannelDivider({ channel }) {
    return (
        <div className="channel-divider">
            <div className="channel-line" />
            <span className="channel-label">{channel.replace(/_/g, '-').toUpperCase()}</span>
            <div className="channel-line" />
        </div>
    )
}

function LogRow({ entry, isExpanded, onToggle }) {
    const bull = entry.x_is_low
    const hasB = entry.b_idx !== -1

    return (
        <div
            className={`log-row ${entry.succeeded ? 'pass' : 'fail'} ${isExpanded ? 'expanded' : ''}`}
            onClick={onToggle}
        >
            <div className="log-row-main">
                <span className={`log-dir ${bull ? 'bull' : 'bear'}`}>
                    {bull ? '\u25B2' : '\u25BC'}
                </span>
                <span className="log-xidx">#{entry.x_idx}</span>
                {hasB && <span className="log-sep">&rarr;</span>}
                {hasB && <span className="log-bidx">B#{entry.b_idx}</span>}
                <span className="log-outcome">
                    {entry.succeeded
                        ? <span className="pass-text">{'\u2713 FOUND'}</span>
                        : <span className="fail-text">{'\u2717'} {entry.step_reached}</span>
                    }
                </span>
                <span className="log-chevron">{isExpanded ? '\u25BE' : '\u25B8'}</span>
            </div>

            {isExpanded && entry.steps && (
                <div className="log-steps">
                    {entry.steps.map((s, i) => (
                        <div key={i} className={`log-step ${s.passed ? 'pass' : 'fail'}`}>
                            <span className="log-step-icon">{s.passed ? '\u2713' : '\u2717'}</span>
                            <span className="log-step-name">{s.step}</span>
                            {s.value != null && typeof s.value === 'number' && (
                                <span className="log-step-val">{s.value.toFixed(4)}</span>
                            )}
                            {!s.passed && s.value != null && typeof s.value === 'number'
                                && s.threshold_min != null && s.threshold_max != null && (
                                <span className="log-step-range">
                                    [{s.threshold_min.toFixed(3)},{s.threshold_max.toFixed(3)}]
                                    {' '}
                                    {s.value < s.threshold_min
                                        ? `\u2193${(s.threshold_min - s.value).toFixed(4)}`
                                        : `\u2191${(s.value - s.threshold_max).toFixed(4)}`
                                    }
                                </span>
                            )}
                            {!s.passed && s.detail && s.value == null && (
                                <span className="log-step-detail">{s.detail}</span>
                            )}
                        </div>
                    ))}
                    {!entry.succeeded && entry.step_reached && (
                        <div className="log-step-footer">
                            Failed at <span style={{ color: 'var(--accent-red)' }}>{entry.step_reached}</span>
                        </div>
                    )}
                </div>
            )}
        </div>
    )
}
