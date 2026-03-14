import { useState, useEffect, useCallback, useMemo, useRef } from 'react'
import axios from 'axios'
import ConfigPanel from './components/ConfigPanel'
import ChartContainer from './components/ChartContainer'
import LogPanel from './components/LogPanel'
import ContextMenu from './components/ContextMenu'

const DEFAULT_CFG = {
  // Pattern type
  pattern_type: 'XABCD',
  channel_type: 'parallel',
  pattern_direction: 'both',

  // Length properties
  b_min: 20,
  b_max: 100,
  max_search_bars: 0,
  px_length_percentage: 10,
  min_b_to_c_btw_x_b: 0,
  max_b_to_c_btw_x_b: 100,
  min_c_to_d_btw_x_b: 0,
  max_c_to_d_btw_x_b: 100,
  min_d_to_e_btw_x_b: 0,
  max_d_to_e_btw_x_b: 100,
  min_e_to_f_btw_x_b: 0,
  max_e_to_f_btw_x_b: 100,

  // Retracement properties
  x_to_a_b_min: -100,
  x_to_a_b_max: 100,
  min_width_percentage: 0,
  max_width_percentage: 100,

  // Dynamic height properties
  every_increasing_of_value: 5,
  width_increasing_percentage_x_to_b: 0,
  width_increasing_percentage_a_e: 0,

  // Validation
  slope_buffer_pct: 0,
  only_draw_most_recent: true,
  strict_xb_validation: false,
  min_bars_between_patterns: 10,

  // Channel width settings
  xb_upper_width_pct: 0.5,
  xb_lower_width_pct: 0.5,
  a_upper_width_pct: 0.5,
  a_lower_width_pct: 0.5,
  channel_extension_bars: 200,

  // Golden line settings
  f_percentage: 50,
  fg_increasing_percentage: 5,
  first_line_percentage: 4,
  first_line_decrease_percentage: 0.01,
  max_below_max_above_diff_percentage: 40,
  mn_buffer_percent: 0,
  mn_length_percent: 0,
  mn_extension_bars: 20,
  extension_break_close: false,

  // Dynamic tracking
  enable_dynamic_last_point: true,
  max_dynamic_iterations: 10,

  // Filters
  divergence_type: 'none',
  tick_min_speed: 500000,
}

export default function App() {
  const [dataPath, setDataPath] = useState('')
  const [uploadedFile, setUploadedFile] = useState(null)   // { name, size }
  const [maxBars, setMaxBars] = useState(500)
  const [config, setConfig] = useState(DEFAULT_CFG)
  const [loading, setLoading] = useState(false)
  const [status, setStatus] = useState({ type: 'idle', text: 'Upload a data file and click Detect' })
  const [detectionResult, setDetectionResult] = useState(null)
  const [selectedPattern, setSelectedPattern] = useState(null)

  const [hoveredBarIdx, setHoveredBarIdx] = useState(null)
  const hoverRafRef = useRef(null)

  // ---- Isolation mode (right-click → X>B / X<B) ----
  const [isolationMode, setIsolationMode] = useState(null)   // { xIdx, xIsLow } | null
  const [contextMenu, setContextMenu] = useState(null)        // { x, y, barIdx } | null

  // Load defaults from backend
  useEffect(() => {
    axios.get('/api/defaults')
      .then(r => {
        if (r.data.data_path) {
          setDataPath(r.data.data_path)
          const name = r.data.data_path.split(/[\\/]/).pop()
          setUploadedFile({ name, size: null, isDefault: true })
        }
        if (r.data.config) setConfig(c => ({ ...c, ...r.data.config }))
        setStatus({ type: 'idle', text: 'Defaults loaded. Click Detect to run.' })
      })
      .catch(() => {
        setStatus({ type: 'warn', text: 'Backend not responding — start the API server first.' })
      })
  }, [])

  const handleFileUpload = useCallback(async (file) => {
    if (!file) return
    const ext = file.name.split('.').pop().toLowerCase()
    if (!['csv', 'xlsx', 'xls'].includes(ext)) {
      setStatus({ type: 'error', text: 'Only .csv, .xlsx, and .xls files are supported.' })
      return
    }
    if (file.size > 50 * 1024 * 1024) {
      setStatus({ type: 'error', text: 'File too large (max 50 MB).' })
      return
    }
    setStatus({ type: 'running', text: `Uploading ${file.name}…` })
    try {
      const form = new FormData()
      form.append('file', file)
      const resp = await axios.post('/api/upload', form)
      setDataPath(resp.data.data_path)
      setUploadedFile({ name: resp.data.filename, size: resp.data.size })
      setStatus({ type: 'ok', text: `${resp.data.filename} uploaded. Click Detect to run.` })
    } catch (e) {
      const msg = e.response?.data?.detail || e.message
      setStatus({ type: 'error', text: `Upload failed: ${msg}` })
    }
  }, [])

  const runDetection = useCallback(async () => {
    if (!dataPath) {
      setStatus({ type: 'error', text: 'Please upload a data file first.' })
      return
    }
    setLoading(true)
    setDetectionResult(null)
    setSelectedPattern(null)
    setIsolationMode(null)
    setStatus({ type: 'running', text: 'Running detection…' })
    const t0 = performance.now()
    try {
      const resp = await axios.post('/api/detect', { data_path: dataPath, max_bars: maxBars, config }, { timeout: 300000 })
      const dt = ((performance.now() - t0) / 1000).toFixed(1)
      const d = resp.data
      setDetectionResult(d)
      const bull = d.patterns.filter(p => p.is_bullish).length
      const bear = d.patterns.length - bull
      setStatus({
        type: 'ok',
        text: `Found ${d.patterns_found} patterns (${bull}↑ ${bear}↓) in ${d.bars_scanned} bars — ${dt}s`,
        bull, bear, patterns: d.patterns_found, bars: d.bars_scanned,
      })
    } catch (e) {
      const msg = e.response?.data?.detail || e.message
      setStatus({ type: 'error', text: `Error: ${msg}` })
    } finally {
      setLoading(false)
    }
  }, [dataPath, maxBars, config])

  const handleHover = useCallback((info) => {
    if (hoverRafRef.current) cancelAnimationFrame(hoverRafRef.current)
    hoverRafRef.current = requestAnimationFrame(() => {
      setHoveredBarIdx(info?.idx ?? null)
    })
  }, [])

  // Right-click context menu handlers
  const handleContextMenu = useCallback((info) => {
    setContextMenu(info)  // { x, y, barIdx }
  }, [])

  const handleSelectCase = useCallback((xIsLow) => {
    if (!contextMenu) return
    setIsolationMode({ xIdx: contextMenu.barIdx, xIsLow })
    setContextMenu(null)
  }, [contextMenu])

  const handleExitIsolation = useCallback(() => setIsolationMode(null), [])

  const candle_logs = detectionResult?.candle_logs ?? {}

  // Client-side direction filter
  const displayedResult = useMemo(() => {
    if (!detectionResult) return null
    const dir = config.pattern_direction
    if (dir === 'both') return detectionResult
    const patterns = detectionResult.patterns.filter(p =>
      dir === 'bullish' ? p.is_bullish : !p.is_bullish
    )
    return { ...detectionResult, patterns, patterns_found: patterns.length }
  }, [detectionResult, config.pattern_direction])

  // Compute isolated attempt logs for the chart to draw partial patterns
  const isolatedAttempts = useMemo(() => {
    if (!isolationMode || !detectionResult) return []
    const logs = candle_logs[String(isolationMode.xIdx)] ?? []
    return logs.filter(a => a.x_is_low === isolationMode.xIsLow)
  }, [isolationMode, detectionResult, candle_logs])

  return (
    <div className="app-shell">
      {/* ---- Header ---- */}
      <header className="app-header">
        <div className="app-logo">&#x25C8; <span>Harmonics</span></div>
        <div className="header-divider" />
        <div className="status-bar">
          {status.type === 'running' && (
            <span><span className="spinner" style={{ display: 'inline-block', marginRight: 6, verticalAlign: 'middle' }} />{status.text}</span>
          )}
          {status.type === 'ok' && (
            <span>
              <span className="highlight">{status.patterns} patterns</span>
              {' '}({status.bull}&#x2191; {status.bear}&#x2193;) in{' '}
              <span className="highlight">{status.bars} bars</span>
              {' \u2014 '}{status.text.split('\u2014')[1]}
            </span>
          )}
          {status.type === 'error' && <span className="error">{status.text}</span>}
          {(status.type === 'idle' || status.type === 'warn') && <span>{status.text}</span>}
        </div>
        <div className="header-actions">
          <div style={{ fontSize: 11, color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            API: <span style={{ color: 'var(--accent-cyan)' }}>:8001</span>
          </div>
        </div>
      </header>

      {/* ---- Config Zone (horizontal, collapsible) ---- */}
      <ConfigPanel
        uploadedFile={uploadedFile} onFileUpload={handleFileUpload}
        maxBars={maxBars} setMaxBars={setMaxBars}
        config={config} setConfig={setConfig}
        loading={loading} onDetect={runDetection}
        patterns={displayedResult?.patterns ?? []}
        selectedPattern={selectedPattern} setSelectedPattern={setSelectedPattern}
      />

      {/* ---- Workspace: chart + log panel ---- */}
      <div className="workspace-row">
        <ChartContainer
          data={displayedResult}
          config={config}
          selectedPattern={selectedPattern}
          isolationMode={isolationMode}
          isolatedAttempts={isolatedAttempts}
          candleLogs={candle_logs}
          onHover={handleHover}
          onContextMenu={handleContextMenu}
          onExitIsolation={handleExitIsolation}
        />
        <LogPanel
          detectionLog={detectionResult?.detection_log ?? []}
          hoveredBarIdx={hoveredBarIdx}
          isolationMode={isolationMode}
          candleLogs={candle_logs}
        />
      </div>

      {/* ---- Right-click context menu ---- */}
      {contextMenu && (
        <ContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          barIdx={contextMenu.barIdx}
          onSelectCase={handleSelectCase}
          onClose={() => setContextMenu(null)}
        />
      )}
    </div>
  )
}
