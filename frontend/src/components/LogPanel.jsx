import { useState, useMemo, useRef, useEffect, useCallback } from 'react'

export default function LogPanel({ detectionLog, hoveredBarIdx, pinnedBar, isolationMode, candleLogs }) {
    const [filter, setFilter] = useState('all')
    const [searchBar, setSearchBar] = useState('')
    const [expandedRows, setExpandedRows] = useState(new Set())
    const scrollRef = useRef(null)

    // Determine active bar filter: isolation > pinned > hovered
    const activeBarIdx = isolationMode ? isolationMode.xIdx : pinnedBar ? pinnedBar.idx : hoveredBarIdx
    const activeDirection = isolationMode ? isolationMode.xIsLow : null // null = both directions

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


    // Concise failure summary grouped by point type
    const failureSummary = useMemo(() => {
        const attempts = filtered.filter(e => e.type !== 'channel')
        if (!attempts.length) return null

        const succeeded = attempts.filter(a => a.succeeded).length
        const failed = attempts.filter(a => !a.succeeded)
        if (!failed.length) return { succeeded, failed: 0, groups: [] }

        // Classify by point type based on step_reached
        const buckets = { 'B Point': [], 'C Point': [], 'D Point': [], 'E Point': [], 'F Point': [], 'Other': [] }
        failed.forEach(a => {
            const step = (a.step_reached || '').toUpperCase()
            if (step.startsWith('B_') || step.startsWith('XB_') || step.startsWith('PX_') || step === 'P_POINT' || step === 'A_FIND' || step === 'A_WIDTH' || step === 'A_SECONDARY' || step === 'FIND_B')
                buckets['B Point'].push(a)
            else if (step.startsWith('C_') || step === 'CASCADE' || step === 'FIND_C')
                buckets['C Point'].push(a)
            else if (step.startsWith('D_') || step === 'FIND_D')
                buckets['D Point'].push(a)
            else if (step.startsWith('E_') || step === 'FIND_E')
                buckets['E Point'].push(a)
            else if (step.startsWith('F_') || step === 'FIND_F')
                buckets['F Point'].push(a)
            else
                buckets['Other'].push(a)
        })

        const groups = Object.entries(buckets)
            .filter(([, list]) => list.length > 0)
            .map(([label, list]) => {
                // Sub-group by step_reached
                const byStep = {}
                list.forEach(a => {
                    const step = a.step_reached || 'UNKNOWN'
                    if (!byStep[step]) byStep[step] = { count: 0, values: [], thresholds: null }
                    byStep[step].count++
                    const failStep = a.steps?.find(s => !s.passed)
                    if (failStep?.value != null && typeof failStep.value === 'number')
                        byStep[step].values.push(failStep.value)
                    if (failStep?.threshold_min != null && !byStep[step].thresholds)
                        byStep[step].thresholds = { min: failStep.threshold_min, max: failStep.threshold_max }
                })

                const parts = Object.entries(byStep)
                    .sort((a, b) => b[1].count - a[1].count)
                    .map(([step, info]) => {
                        let detail = `${info.count} at ${step}`
                        if (info.values.length >= 2 && info.thresholds) {
                            const avg = info.values.reduce((a, b) => a + b, 0) / info.values.length
                            detail += ` (avg ${avg.toFixed(2)} vs [${info.thresholds.min.toFixed(1)}, ${info.thresholds.max.toFixed(1)}])`
                        }
                        return detail
                    })

                return { label, total: list.length, parts }
            })

        return { succeeded, failed: failed.length, groups }
    }, [filtered])

    const toggleRow = useCallback((i) => {
        setExpandedRows(prev => {
            const next = new Set(prev)
            if (next.has(i)) next.delete(i)
            else next.add(i)
            return next
        })
    }, [])

    if (!detectionLog?.length) {
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

    return (
        <aside className="log-panel">
            <div className="log-panel-header" style={{ flexShrink: 0 }}>
                <div className="log-panel-title">
                    Detection Log
                    {isolationMode && (
                        <span style={{ marginLeft: 8, fontSize: 10, padding: '2px 7px', borderRadius: 10, background: 'rgba(245,158,11,0.15)', color: 'var(--accent-amber)', fontWeight: 600 }}>
                            X#{isolationMode.xIdx} {isolationMode.xIsLow ? 'X<B' : 'X>B'}
                        </span>
                    )}
                    {!isolationMode && pinnedBar && (
                        <span style={{ marginLeft: 8, fontSize: 10, padding: '2px 7px', borderRadius: 10, background: 'rgba(59,130,246,0.2)', color: 'var(--accent-blue)', fontWeight: 600 }}>
                            Pinned #{pinnedBar.idx}
                        </span>
                    )}
                    {!isolationMode && !pinnedBar && hoveredBarIdx != null && (
                        <span style={{ marginLeft: 8, fontSize: 10, padding: '2px 7px', borderRadius: 10, background: 'rgba(245,158,11,0.15)', color: 'var(--accent-amber)', fontWeight: 600 }}>
                            Bar #{hoveredBarIdx}
                        </span>
                    )}
                </div>

                {stats && (
                    <div className="log-stats-row">
                        <span className="log-stat total">{stats.total} attempts</span>
                        <span className="log-stat success">{stats.success} {'✓'}</span>
                        <span className="log-stat fail">{stats.fail} {'✗'}</span>
                        <span className="log-stat total" style={{ marginLeft: 'auto', color: 'var(--accent-cyan)' }}>
                            {filtered.length} shown
                        </span>
                    </div>
                )}

                <div className="log-controls-row">
                    <div className="log-filter-row">
                        {[
                            { key: 'all', label: 'All' },
                            { key: 'success', label: '✓ Pass' },
                            { key: 'fail', label: '✗ Fail' },
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
            </div>

            {failureSummary && failureSummary.groups?.length > 0 && (activeBarIdx != null || searchBar) && (
                <div className="failure-summary">
                    {failureSummary.succeeded > 0 && (
                        <div className="summary-point-group">
                            <span className="summary-point-label" style={{ color: 'var(--accent-green)' }}>Passed:</span>{' '}
                            <span style={{ color: 'var(--accent-green)' }}>{failureSummary.succeeded} succeeded</span>
                        </div>
                    )}
                    {failureSummary.groups.map(g => (
                        <div key={g.label} className="summary-point-group">
                            <span className="summary-point-label">{g.label}:</span>{' '}
                            <span className="summary-point-count">{g.total} failed</span>{' '}
                            <span className="summary-point-detail">{'\u2014'} {g.parts.join(', ')}</span>
                        </div>
                    ))}
                </div>
            )}

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
                ) : (
                    <div className="log-empty" style={{ padding: '40px 20px' }}>
                        <div className="icon" style={{ fontSize: 20 }}>&#x25CB;</div>
                        <p>No matching entries</p>
                    </div>
                )}
            </div>
        </aside>
    )
}

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
                        ? <span className="pass-text">{'✓ FOUND'}</span>
                        : <span className="fail-text">{'✗'} {entry.step_reached}</span>
                    }
                </span>
                <span className="log-chevron">{isExpanded ? '\u25BE' : '\u25B8'}</span>
            </div>

            {isExpanded && entry.steps && (
                <div className="log-steps">
                    {entry.steps.map((s, i) => (
                        <div key={i} className={`log-step ${s.passed ? 'pass' : 'fail'}`}>
                            <span className="log-step-icon">{s.passed ? '✓' : '✗'}</span>
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
