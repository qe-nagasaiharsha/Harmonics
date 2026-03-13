import { useState, useMemo, useRef, useEffect, useCallback } from 'react'
import { useVirtualizer } from '@tanstack/react-virtual'

export default function LogPanel({ detectionLog }) {
    const [filter, setFilter] = useState('all')
    const [searchBar, setSearchBar] = useState('')
    const [expandedRows, setExpandedRows] = useState(new Set())
    const parentRef = useRef(null)

    useEffect(() => {
        setExpandedRows(new Set())
        if (parentRef.current) parentRef.current.scrollTop = 0
    }, [detectionLog])

    useEffect(() => {
        setExpandedRows(new Set())
    }, [filter, searchBar])

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
            if (entry.type === 'channel') return true
            if (filter === 'success' && !entry.succeeded) return false
            if (filter === 'fail' && entry.succeeded) return false
            if (!isNaN(barNum) && entry.x_idx !== barNum) return false
            return true
        })
    }, [detectionLog, filter, searchBar])

    const toggleRow = useCallback((i) => {
        setExpandedRows(prev => {
            const next = new Set(prev)
            if (next.has(i)) next.delete(i)
            else next.add(i)
            return next
        })
    }, [])

    const virtualizer = useVirtualizer({
        count: filtered.length,
        getScrollElement: () => parentRef.current,
        estimateSize: () => 30,
        overscan: 10,
        measureElement: el => el?.getBoundingClientRect().height ?? 30,
    })

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
                <div className="log-panel-title">Detection Log</div>

                {stats && (
                    <div className="log-stats-row">
                        <span className="log-stat total">{stats.total} attempts</span>
                        <span className="log-stat success">{stats.success} {'✓'}</span>
                        <span className="log-stat fail">{stats.fail} {'✗'}</span>
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

            <div ref={parentRef} className="log-scroll">
                <div style={{ height: virtualizer.getTotalSize(), position: 'relative' }}>
                    {virtualizer.getVirtualItems().map(vItem => {
                        const entry = filtered[vItem.index]
                        const isExpanded = expandedRows.has(vItem.index)
                        return (
                            <div
                                key={vItem.key}
                                data-index={vItem.index}
                                ref={virtualizer.measureElement}
                                style={{
                                    position: 'absolute',
                                    top: 0,
                                    left: 0,
                                    width: '100%',
                                    transform: `translateY(${vItem.start}px)`,
                                }}
                            >
                                {entry.type === 'channel'
                                    ? <ChannelDivider channel={entry.channel} />
                                    : <LogRow
                                        entry={entry}
                                        isExpanded={isExpanded}
                                        onToggle={() => toggleRow(vItem.index)}
                                    />
                                }
                            </div>
                        )
                    })}
                </div>

                {filtered.length === 0 && (
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
