import { useState } from 'react'

export default function LogPanel({ activeBar, logs, matchedPattern, isPinned, onUnpin }) {
    if (!activeBar) {
        return (
            <aside className="log-panel">
                <div className="panel-header">Detection Trace</div>
                <div className="log-empty">
                    <div className="icon">⟁</div>
                    <p>
                        Hover a candle to see detection traces<br />
                        <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>
                            Click any candle to <strong>lock</strong> the trace panel so you can read it freely
                        </span>
                    </p>
                </div>
            </aside>
        )
    }

    const time = new Date(activeBar.time * 1000).toLocaleString('en-GB', {
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit',
    })

    return (
        <aside className="log-panel">
            {/* flex-shrink:0 ensures header never squeezes the scrollable list below */}
            <div className="log-panel-header" style={{ flexShrink: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    <div className="log-panel-title">Detection Trace</div>
                    <div className="bar-badge">Bar #{activeBar.idx}</div>
                    {isPinned ? (
                        <button
                            className="pin-badge pinned"
                            onClick={onUnpin}
                            title="Click to unpin and return to hover mode"
                        >
                            📌 Pinned — click to unlock
                        </button>
                    ) : (
                        <div className="pin-hint">click candle to lock ↗</div>
                    )}
                </div>
                <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 3 }}>{time}</div>
                {matchedPattern && (
                    <div className="matched-pattern-tag">
                        <span className={`dot ${matchedPattern.is_bullish ? 'bull' : 'bear'}`} />
                        X-origin of {matchedPattern.pattern_type} {matchedPattern.is_bullish ? '▲ Bullish' : '▼ Bearish'}
                    </div>
                )}
            </div>

            {logs.length === 0 ? (
                <div className="log-empty">
                    <div className="icon">○</div>
                    <p>No detection attempts started at this bar</p>
                </div>
            ) : (
                <div className="attempts-list">
                    {logs.map((attempt, i) => (
                        <AttemptCard key={i} attempt={attempt} index={i} />
                    ))}
                </div>
            )}
        </aside>
    )
}

function AttemptCard({ attempt, index }) {
    const [open, setOpen] = useState(attempt.succeeded || index === 0)
    const bull = attempt.x_is_low

    const successColor = 'var(--bull-color)'
    const failColor = 'var(--bear-color)'
    const accentColor = attempt.succeeded ? successColor : failColor

    return (
        <div
            className={`attempt-card ${attempt.succeeded ? 'success' : 'failed'}`}
            id={`attempt-card-${attempt.x_idx}-${index}`}
        >
            <div className="attempt-header" onClick={() => setOpen(o => !o)}>
                <div className={`attempt-badge ${bull ? 'bull' : 'bear'}`}>{bull ? '▲' : '▼'}</div>
                <div className="attempt-label">
                    <div className="headline">
                        X={bull ? 'LOW' : 'HIGH'} → B#{attempt.b_idx !== -1 ? attempt.b_idx : '?'}
                    </div>
                    <div className="subline">
                        {attempt.b_idx !== -1
                            ? `B price: ${attempt.b_price?.toFixed(5) ?? '?'}`
                            : 'No B candidate found'}
                    </div>
                </div>
                <div className={`outcome-badge ${attempt.succeeded ? 'pass' : 'fail'}`}>
                    {attempt.succeeded ? '✓ FOUND' : `✗ ${attempt.step_reached}`}
                </div>
                <span className={`chevron ${open ? 'open' : ''}`}>▾</span>
            </div>

            {open && (
                <div className="step-timeline">
                    {attempt.steps.map((s, si) => (
                        <StepItem key={si} step={s} isLast={si === attempt.steps.length - 1} />
                    ))}
                    {!attempt.succeeded && attempt.rejected_at && (
                        <div className="rejection-footer">
                            Stopped at: <span style={{ color: failColor, fontWeight: 600 }}>{attempt.rejected_at}</span>
                        </div>
                    )}
                </div>
            )}
        </div>
    )
}

function StepItem({ step, isLast }) {
    const cls = step.passed ? 'pass' : 'fail'
    return (
        <div className={`step-item ${cls} ${isLast ? 'last' : ''}`}>
            <div className="step-track">
                <div className={`step-dot ${cls}`} />
                {!isLast && <div className="step-line" />}
            </div>
            <div className="step-content">
                <div className="step-name">{step.step}</div>
                <div className={`step-detail ${step.passed ? '' : 'fail-text'}`}>{step.detail}</div>
                {step.value != null && (
                    <div className="step-values">
                        val=<span>{typeof step.value === 'number' ? step.value.toFixed(4) : step.value}</span>
                        {step.threshold_min != null && (
                            <span className="threshold">
                                {' '}range=[{step.threshold_min?.toFixed(2)}, {step.threshold_max?.toFixed(2)}]
                            </span>
                        )}
                    </div>
                )}
            </div>
        </div>
    )
}
