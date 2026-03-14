import { useState, useMemo, useRef, useEffect, useCallback } from 'react'

// ─────────────────────────────────────────────────────────────────────────────
// Constants: B-stage step order, labels, candidate check names
// ─────────────────────────────────────────────────────────────────────────────
const B_STEPS = [
    'B_SEARCH', 'A_FIND', 'XB_RETRACE', 'A_WIDTH', 'A_SECONDARY',
    'XB_SEGMENT', 'XB_SPAN', 'P_POINT', 'PX_SEGMENT',
]

const FILTER_STEPS = ['TICK_SPEED', 'DIVERGENCE', 'DIRECTION', 'OVERLAP']

const STEP_LABELS = {
    B_SEARCH:     'B Distance',
    A_FIND:       'A Point Found',
    XB_RETRACE:   'XB Retracement',
    A_WIDTH:      'A Width Band',
    A_SECONDARY:  'Secondary A Scan',
    XB_SEGMENT:   'XB Segment Check',
    XB_SPAN:      'XB Span Containment',
    P_POINT:      'P Point Available',
    PX_SEGMENT:   'PX Segment Check',
    C_SEARCH:     'C Candidates',
    CASCADE:      'Cascade Search',
    TICK_SPEED:   'Tick Speed',
    DIVERGENCE:   'Divergence',
    DIRECTION:    'Direction Filter',
    OVERLAP:      'Overlap Filter',
    FINALIZE:     'Pattern Confirmed',
    POINTS:       'Final Points',
}

const CANDIDATE_CHECK_LABELS = ['Channel', 'Extremum', 'Fix Reval', 'Segment', 'Span']

// ─────────────────────────────────────────────────────────────────────────────
// Human-readable value descriptions for B-stage steps
// ─────────────────────────────────────────────────────────────────────────────
function stepValueDesc(step, avgValue, thresholds, passed, checked) {
    const avg = avgValue != null ? avgValue.toFixed(2) : null
    const range = thresholds
        ? `[${thresholds.min.toFixed(1)}, ${thresholds.max.toFixed(1)}]`
        : null

    switch (step) {
        case 'B_SEARCH':
            return avg ? `avg ${avg} bars from X` : 'B candidate found in range'
        case 'A_FIND':
            return avg ? `max slope deviation avg ${avg}` : 'max deviation from XB slope'
        case 'XB_RETRACE':
            if (avg && range) {
                return passed === checked
                    ? `avg ${avg}% within ${range}`
                    : `avg ${avg}% — allowed ${range}`
            }
            return 'XB retracement ratio check'
        case 'A_WIDTH':
            if (avg && range) {
                return passed === checked
                    ? `A price avg ${avg} within band ${range}`
                    : `A price avg ${avg} — band ${range}`
            }
            return 'A price within dynamic width band'
        case 'A_SECONDARY':
            return avg && passed < checked
                ? `secondary A shifted retrace to avg ${avg}%`
                : 'no more extreme A found'
        case 'XB_SEGMENT':
            return passed === checked
                ? 'all bars between X and B respect slope'
                : 'bars between X and B breach slope line'
        case 'XB_SPAN':
            return passed === checked
                ? 'all bars within span buffer'
                : 'price excursions exceed span buffer'
        case 'P_POINT':
            return passed === checked
                ? 'enough bars before X for P'
                : 'insufficient bars before X'
        case 'PX_SEGMENT':
            return passed === checked
                ? 'all PX bars respect slope'
                : 'bars between P and X breach slope'
        default:
            return ''
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Build elaborate narrative for one direction (bullish or bearish)
// ─────────────────────────────────────────────────────────────────────────────
function buildDirectionSummary(attempts) {
    if (!attempts.length) return null

    const succeeded = attempts.filter(a => a.succeeded)
    const total = attempts.length

    // ── B-Stage: aggregate ALL steps across all attempts ──
    const stepStats = {}
    attempts.forEach(a => {
        (a.steps || []).forEach(s => {
            if (!stepStats[s.step]) {
                stepStats[s.step] = { checked: 0, passed: 0, failed: 0, values: [], thresholds: null }
            }
            const stat = stepStats[s.step]
            stat.checked++
            if (s.passed) stat.passed++
            else stat.failed++
            if (s.value != null && typeof s.value === 'number' && s.value !== 0) {
                stat.values.push(s.value)
            }
            if (s.threshold_min != null && s.threshold_max != null
                && (s.threshold_min !== 0 || s.threshold_max !== 0)
                && !stat.thresholds) {
                stat.thresholds = { min: s.threshold_min, max: s.threshold_max }
            }
        })
    })

    // Build B-stage rows
    const bStageRows = B_STEPS.filter(step => stepStats[step]).map(step => {
        const stat = stepStats[step]
        const allPass = stat.passed === stat.checked
        const avgValue = stat.values.length > 0
            ? stat.values.reduce((a, b) => a + b, 0) / stat.values.length
            : null
        return {
            step,
            label: STEP_LABELS[step] || step,
            checked: stat.checked,
            passed: stat.passed,
            failed: stat.failed,
            allPass,
            avgValue,
            thresholds: stat.thresholds,
            desc: stepValueDesc(step, avgValue, stat.thresholds, stat.passed, stat.checked),
        }
    })

    // ── Candidate stages: aggregate candidate_info from all attempts ──
    const candidateInfoMap = {}
    attempts.forEach(a => {
        if (a.candidate_info) {
            Object.entries(a.candidate_info).forEach(([point, info]) => {
                if (!candidateInfoMap[point]) candidateInfoMap[point] = []
                candidateInfoMap[point].push(info)
            })
        }
    })

    // Also check if C_SEARCH step exists to count attempts that reached C
    const cSearchStat = stepStats['C_SEARCH']
    const cascadeStat = stepStats['CASCADE']

    const candidateStages = ['C', 'D', 'E', 'F']
        .filter(pt => candidateInfoMap[pt]?.length > 0)
        .map(pt => {
            const infos = candidateInfoMap[pt]
            const totalScanned = infos.reduce((s, i) => s + (i.total_scanned || 0), 0)
            const totalValid = infos.reduce((s, i) => s + (i.valid_count || 0), 0)
            const channelName = infos[0]?.channel_name || ''

            // Merge funnel counts
            const mergedFunnel = [0, 0, 0, 0, 0]
            infos.forEach(i => {
                (i.funnel || []).forEach((v, idx) => { mergedFunnel[idx] += v })
            })

            // Find best rejected across all infos
            let bestRej = null
            infos.forEach(i => {
                if (i.best_rejected && (!bestRej || i.best_rejected.checks_passed > bestRej.checks_passed)) {
                    bestRej = i.best_rejected
                }
            })

            return {
                point: pt,
                channelName,
                totalScanned,
                totalValid,
                funnel: mergedFunnel,
                bestRejected: bestRej,
                attemptCount: infos.length,
            }
        })

    // ── Filter steps (post-detection) ──
    const filterRows = FILTER_STEPS.filter(step => stepStats[step]).map(step => {
        const stat = stepStats[step]
        return {
            step,
            label: STEP_LABELS[step] || step,
            checked: stat.checked,
            passed: stat.passed,
            failed: stat.failed,
            allPass: stat.passed === stat.checked,
        }
    })

    // ── C-search summary row (how many attempts found C vs not) ──
    const cSearchInfo = cSearchStat ? {
        checked: cSearchStat.checked,
        passed: cSearchStat.passed,
        failed: cSearchStat.failed,
    } : null

    const cascadeInfo = cascadeStat ? {
        count: cascadeStat.checked,
    } : null

    return {
        totalAttempts: total,
        succeeded: succeeded.length,
        bStageRows,
        candidateStages,
        filterRows,
        cSearchInfo,
        cascadeInfo,
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

    // Track whether we have any data at all
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

            {/* ── NARRATIVE SUMMARY MODE (bar active) ── */}
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

                            {/* ━━ B Point Validation ━━ */}
                            {dir.bStageRows.length > 0 && (
                                <div className="narrative-stage">
                                    <div className="narrative-stage-header">
                                        <span className="narrative-stage-label">B Point Validation</span>
                                        <span className="narrative-stage-count">{dir.totalAttempts} attempts</span>
                                    </div>
                                    <div className="narrative-stage-body">
                                        {dir.bStageRows.map((row, ri) => (
                                            <div key={ri} className={`narr-metric-row ${row.allPass ? 'pass' : 'fail'}`}>
                                                <span className="narr-metric-icon">
                                                    {row.allPass ? '\u2713' : '\u2717'}
                                                </span>
                                                <span className="narr-metric-label">{row.label}</span>
                                                <span className="narr-metric-ratio">
                                                    {row.passed}/{row.checked}
                                                </span>
                                                <span className="narr-metric-desc">{row.desc}</span>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* ━━ C Search summary ━━ */}
                            {dir.cSearchInfo && (
                                <div className="narrative-stage">
                                    <div className="narrative-stage-header">
                                        <span className="narrative-stage-label">C Point Search</span>
                                        <span className="narrative-stage-count">
                                            {dir.cSearchInfo.passed} found / {dir.cSearchInfo.checked} checked
                                        </span>
                                    </div>
                                    <div className="narrative-stage-body">
                                        {dir.cSearchInfo.passed > 0 && (
                                            <div className="narr-metric-row pass">
                                                <span className="narr-metric-icon">{'\u2713'}</span>
                                                <span className="narr-metric-label">Valid C found</span>
                                                <span className="narr-metric-ratio">{dir.cSearchInfo.passed}/{dir.cSearchInfo.checked}</span>
                                                <span className="narr-metric-desc">
                                                    {dir.cSearchInfo.passed} attempt{dir.cSearchInfo.passed !== 1 ? 's' : ''} found C candidates on the A-channel
                                                </span>
                                            </div>
                                        )}
                                        {dir.cSearchInfo.failed > 0 && (
                                            <div className="narr-metric-row fail">
                                                <span className="narr-metric-icon">{'\u2717'}</span>
                                                <span className="narr-metric-label">No valid C</span>
                                                <span className="narr-metric-ratio">{dir.cSearchInfo.failed}/{dir.cSearchInfo.checked}</span>
                                                <span className="narr-metric-desc">
                                                    {dir.cSearchInfo.failed} attempt{dir.cSearchInfo.failed !== 1 ? 's' : ''} found no valid C in search range
                                                </span>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}

                            {/* ━━ Candidate point stages (C, D, E, F funnel) ━━ */}
                            {dir.candidateStages.map((cs, ci) => (
                                <div key={ci} className="narrative-stage">
                                    <div className="narrative-stage-header">
                                        <span className="narrative-stage-label">
                                            {cs.point} Point Candidates
                                        </span>
                                        <span className="narrative-stage-count">
                                            {cs.channelName}-channel
                                        </span>
                                    </div>
                                    <div className="narrative-stage-body">
                                        <p className="narr-scan-line">
                                            Scanned {cs.totalScanned} bar{cs.totalScanned !== 1 ? 's' : ''} across {cs.attemptCount} attempt{cs.attemptCount !== 1 ? 's' : ''}
                                        </p>

                                        {/* Funnel visualization */}
                                        <div className="narr-funnel">
                                            {CANDIDATE_CHECK_LABELS.map((name, fi) => (
                                                <div key={fi} className={`narr-funnel-step ${cs.funnel[fi] > 0 ? 'active' : 'empty'}`}>
                                                    <span className="narr-funnel-count">{cs.funnel[fi]}</span>
                                                    <span className="narr-funnel-label">{name}</span>
                                                </div>
                                            ))}
                                            <div className={`narr-funnel-step result ${cs.totalValid > 0 ? 'active' : 'empty'}`}>
                                                <span className="narr-funnel-count">{cs.totalValid}</span>
                                                <span className="narr-funnel-label">Valid</span>
                                            </div>
                                        </div>

                                        {/* Best rejected candidate */}
                                        {cs.bestRejected && (
                                            <div className="narr-best-rejected">
                                                <div className="narr-best-rej-header">
                                                    Best rejected: bar #{cs.bestRejected.bar_idx}
                                                    <span className="narr-best-rej-score">
                                                        {cs.bestRejected.checks_passed}/5 checks passed
                                                    </span>
                                                </div>
                                                <div className="narr-best-rej-checks">
                                                    {CANDIDATE_CHECK_LABELS.map((name, fi) => {
                                                        const passed = fi < cs.bestRejected.checks_passed
                                                        const isFail = fi === cs.bestRejected.checks_passed
                                                            && cs.bestRejected.failed_at === ['channel', 'extremum', 'fix_reval', 'segment', 'span'][fi]
                                                        const notChecked = fi > cs.bestRejected.checks_passed
                                                        return (
                                                            <span key={fi} className={`narr-rej-check ${passed ? 'pass' : isFail ? 'fail' : 'skip'}`}>
                                                                {passed ? '\u2713' : isFail ? '\u2717' : '\u2500'}{' '}{name}
                                                            </span>
                                                        )
                                                    })}
                                                </div>
                                                {cs.bestRejected.checks_passed === 0 && cs.bestRejected.channel_center > 0 && (
                                                    <p className="narr-rej-detail">
                                                        Price {cs.bestRejected.channel_value?.toFixed(2)} outside channel center {cs.bestRejected.channel_center?.toFixed(2)} {'\u00B1'} [{cs.bestRejected.channel_lower?.toFixed(1)}%, {cs.bestRejected.channel_upper?.toFixed(1)}%]
                                                    </p>
                                                )}
                                            </div>
                                        )}
                                    </div>
                                </div>
                            ))}

                            {/* ━━ Post-detection filters ━━ */}
                            {dir.filterRows.length > 0 && (
                                <div className="narrative-stage">
                                    <div className="narrative-stage-header">
                                        <span className="narrative-stage-label">Post-Detection Filters</span>
                                    </div>
                                    <div className="narrative-stage-body">
                                        {dir.filterRows.map((row, ri) => (
                                            <div key={ri} className={`narr-metric-row ${row.allPass ? 'pass' : 'fail'}`}>
                                                <span className="narr-metric-icon">
                                                    {row.allPass ? '\u2713' : '\u2717'}
                                                </span>
                                                <span className="narr-metric-label">{row.label}</span>
                                                <span className="narr-metric-ratio">{row.passed}/{row.checked}</span>
                                                <span className="narr-metric-desc">
                                                    {row.failed > 0
                                                        ? `${row.failed} pattern${row.failed !== 1 ? 's' : ''} rejected`
                                                        : 'all passed'}
                                                </span>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* ━━ Cascade exhaustion ━━ */}
                            {dir.cascadeInfo && dir.succeeded === 0 && (
                                <div className="narrative-stage">
                                    <div className="narrative-stage-body">
                                        <div className="narr-metric-row fail">
                                            <span className="narr-metric-icon">{'\u2717'}</span>
                                            <span className="narr-metric-label">Cascade Exhausted</span>
                                            <span className="narr-metric-ratio">{dir.cascadeInfo.count}</span>
                                            <span className="narr-metric-desc">
                                                All C/D/E/F candidate combinations tried without forming a valid pattern
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            )}

                            {/* ━━ Final result ━━ */}
                            <div className={`narrative-result ${dir.succeeded > 0 ? 'found' : 'none'}`}>
                                {dir.succeeded > 0
                                    ? `\u2713 ${dir.succeeded} pattern${dir.succeeded !== 1 ? 's' : ''} confirmed`
                                    : '\u2717 No pattern found'
                                }
                            </div>
                        </div>
                    ))}

                    {narrativeSummary.length === 0 && (
                        <div className="log-empty" style={{ padding: '40px 20px' }}>
                            <div className="icon" style={{ fontSize: 20 }}>&#x25CB;</div>
                            <p>No detection attempts for this bar</p>
                        </div>
                    )}
                </div>

            ) : activeBarIdx != null ? (
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
                            {s.value != null && typeof s.value === 'number'
                                && s.threshold_min != null && s.threshold_max != null
                                && (s.threshold_min !== 0 || s.threshold_max !== 0) && (
                                <span className="log-step-range">
                                    [{s.threshold_min.toFixed(3)},{s.threshold_max.toFixed(3)}]
                                    {!s.passed && (
                                        <>
                                            {' '}
                                            {s.value < s.threshold_min
                                                ? `\u2193${(s.threshold_min - s.value).toFixed(4)}`
                                                : `\u2191${(s.value - s.threshold_max).toFixed(4)}`
                                            }
                                        </>
                                    )}
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
