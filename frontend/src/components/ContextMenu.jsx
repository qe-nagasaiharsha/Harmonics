import { useEffect, useRef } from 'react'

export default function ContextMenu({ x, y, barIdx, onSelectCase, onClose }) {
    const ref = useRef(null)

    // Clamp to viewport so the menu doesn't overflow
    useEffect(() => {
        if (!ref.current) return
        const rect = ref.current.getBoundingClientRect()
        const el = ref.current
        if (rect.right > window.innerWidth) el.style.left = `${x - rect.width}px`
        if (rect.bottom > window.innerHeight) el.style.top = `${y - rect.height}px`
    }, [x, y])

    // Click-away dismiss
    useEffect(() => {
        const dismiss = (e) => {
            if (ref.current && !ref.current.contains(e.target)) onClose()
        }
        window.addEventListener('mousedown', dismiss)
        return () => window.removeEventListener('mousedown', dismiss)
    }, [onClose])

    return (
        <div ref={ref} className="ctx-menu" style={{ position: 'fixed', left: x, top: y, zIndex: 100 }}>
            <div className="ctx-title">Bar #{barIdx} — Pattern Traces</div>
            <button className="ctx-item" onClick={() => onSelectCase(false)}>
                <span className="ctx-icon bear">&#x25BC;</span>
                <span>Draw X &gt; B patterns<span className="ctx-hint">X = HIGH</span></span>
            </button>
            <button className="ctx-item" onClick={() => onSelectCase(true)}>
                <span className="ctx-icon bull">&#x25B2;</span>
                <span>Draw X &lt; B patterns<span className="ctx-hint">X = LOW</span></span>
            </button>
        </div>
    )
}
