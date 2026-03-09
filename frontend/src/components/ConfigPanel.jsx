import { useState, useRef, useCallback } from 'react'

const PATTERN_TYPES = ['XAB', 'XABC', 'XABCD', 'XABCDE', 'XABCDEF']
const CHANNEL_TYPES = ['parallel', 'straight', 'non_parallel', 'all_types']
const DIRECTION_TYPES = ['both', 'bullish', 'bearish']
const DIVERGENCE_TYPES = ['none', 'time', 'volume', 'time_volume']

/* ------------------------------------------------------------------ */
/*  Small reusable field helpers                                        */
/* ------------------------------------------------------------------ */

function SF({ label, children }) {
    return (
        <div className="sf">
            <label>{label}</label>
            {children}
        </div>
    )
}

function PairRow({ children }) {
    return <div className="pair-row">{children}</div>
}

function Num({ value, onChange, min, max, step = 1, placeholder }) {
    return (
        <input
            type="number"
            value={value}
            onChange={onChange}
            min={min} max={max} step={step}
            placeholder={placeholder}
        />
    )
}

function Check({ id, checked, onChange, label }) {
    return (
        <label className="check-field" htmlFor={id}>
            <input id={id} type="checkbox" checked={checked} onChange={onChange} />
            <span>{label}</span>
        </label>
    )
}

/* ------------------------------------------------------------------ */
/*  Section content renderers                                           */
/* ------------------------------------------------------------------ */

function LengthSection({ config, set }) {
    return (
        <div className="sg">
            <SF label="B Range (min / max)">
                <PairRow>
                    <Num value={config.b_min} onChange={set('b_min')} min={1} max={500} placeholder="min" />
                    <Num value={config.b_max} onChange={set('b_max')} min={1} max={2000} placeholder="max" />
                </PairRow>
            </SF>
            <SF label="Max Search Bars (0=all)">
                <Num value={config.max_search_bars} onChange={set('max_search_bars')} min={0} max={100000} step={100} />
            </SF>
            <SF label="P-X Length % of XB">
                <Num value={config.px_length_percentage} onChange={set('px_length_percentage')} min={0} max={200} step={1} />
            </SF>
            <SF label="BC Length % (min / max)">
                <PairRow>
                    <Num value={config.min_b_to_c_btw_x_b} onChange={set('min_b_to_c_btw_x_b')} min={0} max={500} placeholder="min" />
                    <Num value={config.max_b_to_c_btw_x_b} onChange={set('max_b_to_c_btw_x_b')} min={0} max={500} placeholder="max" />
                </PairRow>
            </SF>
            <SF label="CD Length % (min / max)">
                <PairRow>
                    <Num value={config.min_c_to_d_btw_x_b} onChange={set('min_c_to_d_btw_x_b')} min={0} max={500} placeholder="min" />
                    <Num value={config.max_c_to_d_btw_x_b} onChange={set('max_c_to_d_btw_x_b')} min={0} max={500} placeholder="max" />
                </PairRow>
            </SF>
            <SF label="DE Length % (min / max)">
                <PairRow>
                    <Num value={config.min_d_to_e_btw_x_b} onChange={set('min_d_to_e_btw_x_b')} min={0} max={500} placeholder="min" />
                    <Num value={config.max_d_to_e_btw_x_b} onChange={set('max_d_to_e_btw_x_b')} min={0} max={500} placeholder="max" />
                </PairRow>
            </SF>
            <SF label="EF Length % (min / max)">
                <PairRow>
                    <Num value={config.min_e_to_f_btw_x_b} onChange={set('min_e_to_f_btw_x_b')} min={0} max={500} placeholder="min" />
                    <Num value={config.max_e_to_f_btw_x_b} onChange={set('max_e_to_f_btw_x_b')} min={0} max={500} placeholder="max" />
                </PairRow>
            </SF>
        </div>
    )
}

function RetraceSection({ config, set }) {
    return (
        <div className="sg">
            <SF label="½ Max A retrace % from X">
                <Num value={config.max_width_percentage} onChange={set('max_width_percentage')} min={0} max={10000} step={0.1} />
            </SF>
            <SF label="½ Min A retrace % from X">
                <Num value={config.min_width_percentage} onChange={set('min_width_percentage')} min={0} max={10000} step={0.1} />
            </SF>
            <SF label="B Retrace % from XA (min / max)">
                <PairRow>
                    <Num value={config.x_to_a_b_min} onChange={set('x_to_a_b_min')} step={1} placeholder="min" />
                    <Num value={config.x_to_a_b_max} onChange={set('x_to_a_b_max')} step={1} placeholder="max" />
                </PairRow>
            </SF>
        </div>
    )
}

function DynamicSection({ config, set }) {
    return (
        <div className="sg">
            <SF label="Every Candle Count Increase">
                <Num value={config.every_increasing_of_value} onChange={set('every_increasing_of_value')} min={1} max={200} step={1} />
            </SF>
            <SF label="A Retrace Increase % per Step">
                <Num value={config.width_increasing_percentage_x_to_b} onChange={set('width_increasing_percentage_x_to_b')} min={0} max={100} step={0.1} />
            </SF>
            <SF label="A/E Price Buffer % (AC/BD/CE)">
                <Num value={config.width_increasing_percentage_a_e} onChange={set('width_increasing_percentage_a_e')} min={0} max={100} step={0.1} />
            </SF>
        </div>
    )
}

function ChannelsSection({ config, set }) {
    return (
        <div className="sg">
            <SF label="XB Upper Width %">
                <Num value={config.xb_upper_width_pct} onChange={set('xb_upper_width_pct')} min={0} max={50} step={0.05} />
            </SF>
            <SF label="XB Lower Width %">
                <Num value={config.xb_lower_width_pct} onChange={set('xb_lower_width_pct')} min={0} max={50} step={0.05} />
            </SF>
            <SF label="A Upper Width %">
                <Num value={config.a_upper_width_pct} onChange={set('a_upper_width_pct')} min={0} max={50} step={0.05} />
            </SF>
            <SF label="A Lower Width %">
                <Num value={config.a_lower_width_pct} onChange={set('a_lower_width_pct')} min={0} max={50} step={0.05} />
            </SF>
            <SF label="Extension Bars">
                <Num value={config.channel_extension_bars} onChange={set('channel_extension_bars')} min={0} max={2000} step={10} />
            </SF>
        </div>
    )
}

function GoldenSection({ config, set }) {
    return (
        <div className="sg">
            <SF label="Separator Height % (F)">
                <Num value={config.f_percentage} onChange={set('f_percentage')} min={0} max={100} step={0.5} />
            </SF>
            <SF label="FG Increment % per Iter">
                <Num value={config.fg_increasing_percentage} onChange={set('fg_increasing_percentage')} min={1} max={50} step={1} />
            </SF>
            <SF label="First Line Slope %">
                <Num value={config.first_line_percentage} onChange={set('first_line_percentage')} min={0} max={50} step={0.1} />
            </SF>
            <SF label="First Line Decrease % / Step">
                <Num value={config.first_line_decrease_percentage} onChange={set('first_line_decrease_percentage')} min={0} max={10} step={0.001} />
            </SF>
            <SF label="M/N Equality Tolerance %">
                <Num value={config.max_below_max_above_diff_percentage} onChange={set('max_below_max_above_diff_percentage')} min={0} max={100} step={0.5} />
            </SF>
            <SF label="MN Buffer %">
                <Num value={config.mn_buffer_percent} onChange={set('mn_buffer_percent')} min={0} max={10} step={0.01} />
            </SF>
            <SF label="MN Min Length %">
                <Num value={config.mn_length_percent} onChange={set('mn_length_percent')} min={0} max={50} step={0.1} />
            </SF>
            <SF label="MN Extension Bars">
                <Num value={config.mn_extension_bars} onChange={set('mn_extension_bars')} min={0} max={500} step={5} />
            </SF>
            <SF label=" ">
                <Check
                    id="ext-break-close"
                    checked={config.extension_break_close}
                    onChange={set('extension_break_close')}
                    label="Use Close for Break Detection"
                />
            </SF>
        </div>
    )
}

function ValidationSection({ config, set }) {
    return (
        <div className="sg">
            <SF label="Slope Buffer %">
                <Num value={config.slope_buffer_pct} onChange={set('slope_buffer_pct')} min={0} max={100} step={0.1} />
            </SF>
            <SF label="Min Bars Between Patterns">
                <Num value={config.min_bars_between_patterns} onChange={set('min_bars_between_patterns')} min={0} max={500} step={1} />
            </SF>
            <SF label="Max Dynamic Iterations">
                <Num value={config.max_dynamic_iterations} onChange={set('max_dynamic_iterations')} min={1} max={100} step={1} />
            </SF>
            <SF label=" ">
                <Check
                    id="strict-xb"
                    checked={config.strict_xb_validation}
                    onChange={set('strict_xb_validation')}
                    label="Strict XB Validation"
                />
            </SF>
            <SF label=" ">
                <Check
                    id="only-recent"
                    checked={config.only_draw_most_recent}
                    onChange={set('only_draw_most_recent')}
                    label="Only Most Recent Pattern"
                />
            </SF>
            <SF label=" ">
                <Check
                    id="dynamic-point"
                    checked={config.enable_dynamic_last_point}
                    onChange={set('enable_dynamic_last_point')}
                    label="Enable Dynamic Last Point"
                />
            </SF>
        </div>
    )
}

function FiltersSection({ config, set }) {
    return (
        <div className="sg">
            <SF label="Divergence Filter">
                <select value={config.divergence_type} onChange={set('divergence_type')}>
                    {DIVERGENCE_TYPES.map(t => <option key={t}>{t}</option>)}
                </select>
            </SF>
            <SF label="Tick Min Speed">
                <Num value={config.tick_min_speed} onChange={set('tick_min_speed')} min={0} max={10000000} step={50000} />
            </SF>
        </div>
    )
}

function PatternListSection({ patterns, selectedPattern, setSelectedPattern }) {
    if (patterns.length === 0) {
        return (
            <div style={{ color: 'var(--text-muted)', fontSize: 12, padding: '8px 0' }}>
                No patterns detected yet. Click "Detect Patterns" to run.
            </div>
        )
    }
    return (
        <div className="pattern-list-inline">
            {patterns.map((p, i) => {
                const active = selectedPattern === i
                const color = p.is_bullish ? 'var(--bull-color)' : 'var(--bear-color)'
                return (
                    <div
                        key={i}
                        className={`pattern-entry-inline ${active ? 'active' : ''}`}
                        onClick={() => setSelectedPattern(active ? null : i)}
                        style={{ borderColor: active ? color : undefined }}
                    >
                        <div className="pattern-direction-dot" style={{ background: color }} />
                        <div className="pattern-info">
                            <div className="pattern-name" style={{ color }}>
                                {p.pattern_type} {p.is_bullish ? '▲' : '▼'}
                            </div>
                            <div className="pattern-meta">X:{p.wave.x_idx}  B:{p.wave.b_idx}</div>
                        </div>
                        <div className="pattern-type-badge">{p.channel_type}</div>
                    </div>
                )
            })}
        </div>
    )
}

/* ------------------------------------------------------------------ */
/*  Main ConfigPanel                                                    */
/* ------------------------------------------------------------------ */

const SECTIONS = [
    { id: 'length',     label: 'Length' },
    { id: 'retrace',    label: 'Retracement' },
    { id: 'dynamic',    label: 'Dynamic Height' },
    { id: 'channels',   label: 'Channel Width' },
    { id: 'golden',     label: 'Golden Line' },
    { id: 'validation', label: 'Validation' },
    { id: 'filters',    label: 'Filters' },
    { id: 'patterns',   label: null },   // label built dynamically
]

export default function ConfigPanel({
    uploadedFile, onFileUpload, maxBars, setMaxBars,
    config, setConfig, loading, onDetect,
    patterns, selectedPattern, setSelectedPattern,
}) {
    const [activeSection, setActiveSection] = useState(null)
    const [dragOver, setDragOver] = useState(false)
    const fileInputRef = useRef(null)

    const set = (key) => (e) => {
        const val = e.target.type === 'checkbox' ? e.target.checked
            : e.target.type === 'number' ? Number(e.target.value)
                : e.target.value
        setConfig(c => ({ ...c, [key]: val }))
    }

    const toggle = (id) => setActiveSection(prev => prev === id ? null : id)

    const renderContent = (id) => {
        switch (id) {
            case 'length':     return <LengthSection config={config} set={set} />
            case 'retrace':    return <RetraceSection config={config} set={set} />
            case 'dynamic':    return <DynamicSection config={config} set={set} />
            case 'channels':   return <ChannelsSection config={config} set={set} />
            case 'golden':     return <GoldenSection config={config} set={set} />
            case 'validation': return <ValidationSection config={config} set={set} />
            case 'filters':    return <FiltersSection config={config} set={set} />
            case 'patterns':   return (
                <PatternListSection
                    patterns={patterns}
                    selectedPattern={selectedPattern}
                    setSelectedPattern={setSelectedPattern}
                />
            )
            default: return null
        }
    }

    return (
        <div className="config-zone">
            {/* ---- Always-visible top bar ---- */}
            <div className="config-topbar">
                <div
                    className={`topbar-upload${dragOver ? ' drag-over' : ''}${uploadedFile ? ' has-file' : ''}`}
                    onClick={() => fileInputRef.current?.click()}
                    onDragOver={e => { e.preventDefault(); setDragOver(true) }}
                    onDragLeave={() => setDragOver(false)}
                    onDrop={e => {
                        e.preventDefault()
                        setDragOver(false)
                        const f = e.dataTransfer.files?.[0]
                        if (f) onFileUpload(f)
                    }}
                >
                    <input
                        ref={fileInputRef}
                        type="file"
                        accept=".csv,.xlsx,.xls"
                        style={{ display: 'none' }}
                        onChange={e => {
                            const f = e.target.files?.[0]
                            if (f) onFileUpload(f)
                            e.target.value = ''
                        }}
                    />
                    {uploadedFile ? (
                        <span className="upload-filename">{uploadedFile.name}</span>
                    ) : (
                        <span className="upload-placeholder">Drop CSV / Excel here or click to browse</span>
                    )}
                </div>

                <div className="topbar-field">
                    <span className="topbar-label">Bars</span>
                    <input
                        className="topbar-num"
                        type="number" min={50} max={50000} step={50}
                        value={maxBars}
                        onChange={e => setMaxBars(Number(e.target.value))}
                    />
                </div>

                <div className="topbar-field">
                    <span className="topbar-label">Pattern</span>
                    <select
                        className="topbar-select"
                        value={config.pattern_type}
                        onChange={set('pattern_type')}
                    >
                        {PATTERN_TYPES.map(t => <option key={t}>{t}</option>)}
                    </select>
                </div>

                <div className="topbar-field">
                    <span className="topbar-label">Channel</span>
                    <select
                        className="topbar-select"
                        value={config.channel_type}
                        onChange={set('channel_type')}
                    >
                        {CHANNEL_TYPES.map(t => <option key={t}>{t}</option>)}
                    </select>
                </div>

                <div className="topbar-field">
                    <span className="topbar-label">Direction</span>
                    <select
                        className="topbar-select"
                        value={config.pattern_direction}
                        onChange={set('pattern_direction')}
                    >
                        {DIRECTION_TYPES.map(t => <option key={t}>{t}</option>)}
                    </select>
                </div>

                <button
                    className={`topbar-detect-btn ${loading ? 'running' : ''}`}
                    onClick={onDetect}
                    disabled={loading}
                >
                    {loading ? (
                        <><span className="spinner" /> Detecting…</>
                    ) : (
                        '▶  Detect'
                    )}
                </button>
            </div>

            {/* ---- Section tabs ---- */}
            <div className="section-tabs-row">
                {SECTIONS.map(s => {
                    const label = s.id === 'patterns'
                        ? `Patterns${patterns.length > 0 ? ` (${patterns.length})` : ''}`
                        : s.label
                    return (
                        <button
                            key={s.id}
                            className={`section-tab ${activeSection === s.id ? 'active' : ''}`}
                            onClick={() => toggle(s.id)}
                        >
                            {label}
                            <span className="tab-arrow">{activeSection === s.id ? ' ▲' : ' ▼'}</span>
                        </button>
                    )
                })}
            </div>

            {/* ---- Expanded section panel ---- */}
            {activeSection && (
                <div className="section-panel">
                    {renderContent(activeSection)}
                </div>
            )}
        </div>
    )
}
