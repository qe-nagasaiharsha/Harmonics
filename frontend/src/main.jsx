import { Component } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

// Error boundary — shows crash details instead of blank page
class ErrorBoundary extends Component {
  constructor(props) {
    super(props)
    this.state = { error: null }
  }
  static getDerivedStateFromError(err) {
    return { error: err }
  }
  render() {
    if (this.state.error) {
      return (
        <div style={{
          padding: 40, color: '#ef4444', fontFamily: 'monospace',
          background: '#080b12', minHeight: '100vh', whiteSpace: 'pre-wrap',
          fontSize: 13,
        }}>
          <h2 style={{ marginBottom: 16 }}>⚠ React Error — check browser console for full stack</h2>
          <strong>{String(this.state.error)}</strong>
          <pre style={{ marginTop: 16, color: '#8b9ab5', fontSize: 11 }}>
            {this.state.error?.stack}
          </pre>
        </div>
      )
    }
    return this.props.children
  }
}

// NOTE: StrictMode intentionally removed — it double-invokes useEffect cleanup
// in development, which calls chart.remove() and leaves the lightweight-charts
// series ref pointing at a destroyed chart, causing a blank screen after Detect.
createRoot(document.getElementById('root')).render(
  <ErrorBoundary>
    <App />
  </ErrorBoundary>,
)
