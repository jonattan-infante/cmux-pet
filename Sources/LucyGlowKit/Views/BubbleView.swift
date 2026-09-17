// Burbuja estilo terminal con texto que se escribe letra por letra.

import AppKit

final class BubbleView: NSView {
    var bubble: Bubble? {
        didSet {
            revealStart = CACurrentMediaTime()
            needsDisplay = true
        }
    }
    var onClick: (() -> Void)?

    static let width: CGFloat = 272
    static let padding: CGFloat = 12
    static let charsPerSecond: Double = 45
    private static let prompt = "› "
    private static let cursor = "\u{2588}"

    private var revealStart: CFTimeInterval = 0
    /// Solo para el modo --render: congela el avance de la escritura.
    var debugReveal: Double?

    private static func font() -> NSFont {
        NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
    }

    private static func inkAttrs() -> [NSAttributedString.Key: Any] {
        [.font: font(),
         .foregroundColor: NSColor(srgbRed: 0.87, green: 0.90, blue: 0.94, alpha: 1)]
    }

    /// Vista volteada: el motor de layout dibuja de arriba hacia abajo, y asi
    /// medir y dibujar usan exactamente el mismo sistema de coordenadas.
    override var isFlipped: Bool { true }

    /// Un unico camino de layout para medir Y para dibujar. Medir con
    /// `boundingRect` y dibujar con `draw(with:)` daba envoltura distinta y
    /// recortaba la ultima linea.
    private static func layoutText(_ s: NSAttributedString, width w: CGFloat)
        -> (NSTextStorage, NSLayoutManager, NSTextContainer, CGFloat) {
        let storage = NSTextStorage(attributedString: s)
        let container = NSTextContainer(size: CGSize(width: w, height: 100_000))
        container.lineFragmentPadding = 0
        let layout = NSLayoutManager()
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        return (storage, layout, container, ceil(layout.usedRect(for: container).height))
    }

    static func textHeight(_ s: NSAttributedString, width w: CGFloat) -> CGFloat {
        layoutText(s, width: w).3
    }

    /// La caja se mide con el texto COMPLETO. Si se midiera con lo revelado,
    /// la tarjeta crecería mientras escribe y saltaría en pantalla.
    static func size(for b: Bubble) -> CGSize {
        let inner = width - padding * 2
        let s = NSAttributedString(string: prompt + b.text + cursor, attributes: inkAttrs())
        return CGSize(width: width, height: textHeight(s, width: inner) + padding * 2)
    }

    /// Cuantos caracteres se ven ya.
    private func revealed(_ b: Bubble) -> Int {
        if let f = debugReveal { return Int(Double(b.text.count) * f) }
        let elapsed = CACurrentMediaTime() - revealStart
        return min(b.text.count, max(0, Int(elapsed * BubbleView.charsPerSecond)))
    }

    var isTyping: Bool {
        guard let b = bubble else { return false }
        return revealed(b) < b.text.count
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bubble != nil else { return nil }
        let p = convert(point, from: superview)
        return bounds.contains(p) ? self : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let b = bubble, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let box = bounds.insetBy(dx: 0.5, dy: 0.5)

        // Tarjeta oscura: es una terminal, se queda oscura en tema claro tambien.
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 12,
                      color: NSColor.black.withAlphaComponent(0.42).cgColor)
        let path = NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8)
        NSColor(srgbRed: 0.075, green: 0.085, blue: 0.11, alpha: 0.97).setFill()
        path.fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        b.mood.accent.withAlphaComponent(0.5).setStroke()
        path.lineWidth = 1
        path.stroke()

        // Un solo parrafo: prompt en color de estado, texto en gris claro,
        // cursor de bloque al final.
        let n = revealed(b)
        let shown = String(b.text.prefix(n))
        let line = NSMutableAttributedString(string: BubbleView.prompt,
                                             attributes: [.font: BubbleView.font(),
                                                          .foregroundColor: b.mood.accent])
        line.append(NSAttributedString(string: shown, attributes: BubbleView.inkAttrs()))

        // Mientras escribe el cursor esta fijo; al terminar, parpadea.
        let typing = n < b.text.count
        let blink = CACurrentMediaTime().truncatingRemainder(dividingBy: 1.0) < 0.55
        if typing || blink {
            line.append(NSAttributedString(
                string: BubbleView.cursor,
                attributes: [.font: BubbleView.font(),
                             .foregroundColor: b.mood.accent.withAlphaComponent(0.9)]))
        }

        let inner = BubbleView.width - BubbleView.padding * 2
        let (storage, layout, container, _) = BubbleView.layoutText(line, width: inner)
        layout.drawGlyphs(forGlyphRange: layout.glyphRange(for: container),
                          at: CGPoint(x: box.minX + BubbleView.padding,
                                      y: box.minY + BubbleView.padding))
        _ = storage   // el layout manager no retiene el storage
    }

    override func mouseUp(with event: NSEvent) { onClick?() }
}
