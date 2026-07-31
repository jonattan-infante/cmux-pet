// El droide: dibujo vectorial, animacion y captura del mouse.

import AppKit

final class PetView: NSView {
    var mood: Mood = .idle {
        didSet { if mood != oldValue { moodChangedAt = CACurrentMediaTime(); needsDisplay = true } }
    }
    var workingCount: Int = 0 { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onMenu: ((NSEvent) -> Void)?

    private var phase: Double = 0
    private var moodChangedAt: CFTimeInterval = CACurrentMediaTime()
    private var blinkUntil: CFTimeInterval = 0
    private var nextBlink: CFTimeInterval = CACurrentMediaTime() + 3

    var onHover: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?

    private var dragOrigin: CGPoint = .zero
    private var dragWindowOrigin: CGPoint = .zero
    private var dragDistance: CGFloat = 0
    private var mouseDownAt: CFTimeInterval = 0

    /// Tiempo desde que entro al estado actual. Las animaciones transitorias decaen con esto.
    private var age: Double { CACurrentMediaTime() - moodChangedAt }

    func tick(_ dt: Double) {
        phase += dt
        let now = CACurrentMediaTime()
        if now > nextBlink {
            blinkUntil = now + 0.12
            nextBlink = now + Double.random(in: 2.5...6.0)
        }
        needsDisplay = true
    }

    /// Solo el cuerpo captura el mouse; el resto de la ventana es transparente al click.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        if let r = lastSpriteRect, r.insetBy(dx: -3, dy: -3).contains(p) { return self }
        return bodyRect().insetBy(dx: -4, dy: -4).contains(p) ? self : nil
    }

    // MARK: sprites propios

    static let spriteDir = petHome.appendingPathComponent("sprites")
    private var spriteCache: [String: Sprite?] = [:]
    private var lastSpriteRect: CGRect?

    /// Vuelve a mirar la carpeta de sprites. Se llama desde el menu.
    func reloadSprites() {
        spriteCache.removeAll()
        lastSpriteRect = nil
        needsDisplay = true
    }

    /// Busca `<estado>.<ext>` y cae a `default.<ext>`.
    private func sprite(for mood: Mood) -> Sprite? {
        for key in [mood.rawValue, "default"] {
            if let cached = spriteCache[key] {
                if let s = cached { return s }
                continue
            }
            var found: Sprite? = nil
            for ext in ["gif", "png", "webp", "heic", "jpg", "jpeg", "tiff", "pdf"] {
                let url = PetView.spriteDir.appendingPathComponent("\(key).\(ext)")
                if fm.fileExists(atPath: url.path), let s = Sprite(url: url) {
                    found = s
                    break
                }
            }
            spriteCache[key] = found
            if let s = found { return s }
        }
        return nil
    }

    /// Dibuja el sprite del estado actual. Devuelve false si no hay ninguno y
    /// hay que caer al droide vectorial.
    private func drawSprite(in box: CGRect) -> Bool {
        guard let s = sprite(for: mood) else {
            lastSpriteRect = nil
            return false
        }
        // Cabe en una caja algo mayor que el vector, conservando proporcion.
        var w = box.width * 1.5, h = box.height * 1.2
        let sz = s.size
        if sz.width > 0 && sz.height > 0 {
            let k = min(w / sz.width, h / sz.height)
            w = sz.width * k
            h = sz.height * k
        }
        let rect = CGRect(x: box.midX - w / 2, y: box.minY, width: w, height: h)
        s.draw(in: rect, at: phase)
        lastSpriteRect = rect
        return true
    }

    /// Caja del droide. El resto de la vista es aire para el salto y los adornos.
    private func bodyRect() -> CGRect {
        let w: CGFloat = 50, h: CGFloat = 64
        return CGRect(x: (bounds.width - w) / 2,
                      y: (bounds.height - h) / 2 - 8,
                      width: w, height: h)
    }

    // MARK: dibujo

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Desplazamiento: flotar siempre, saltar al terminar, sacudirse al fallar.
        var dy = sin(phase * (mood == .working ? 3.2 : 1.6)) * (mood == .working ? 3 : 2)
        var dx: CGFloat = 0
        if mood == .done {
            let decay = max(0, 1 - age / 1.4)
            dy += abs(sin(age * 7)) * 15 * decay
        }
        if mood == .error {
            let decay = max(0, 1 - age / 0.9)
            dx = CGFloat(sin(age * 34) * 5 * decay)
        }

        let box = bodyRect().offsetBy(dx: dx, dy: CGFloat(dy))

        // Sombra en el piso: se achica cuando sube.
        let lift = max(0, CGFloat(dy))
        let shadowW = box.width * (0.66 - lift / 240)
        NSColor.black.withAlphaComponent(max(0, 0.24 - lift / 340)).setFill()
        NSBezierPath(ovalIn: CGRect(x: box.midX - shadowW / 2,
                                    y: bodyRect().minY - 6,
                                    width: shadowW, height: 6)).fill()

        // Sprite propio si existe; si no, el droide vectorial.
        if drawSprite(in: box) {
            drawAccessory(body: box)
            return
        }
        drawDroid(in: box, ctx: ctx)
        drawAccessory(body: box)
    }

    // MARK: el droide

    /// Cuanto gira la cupula. En reposo mira alrededor despacio; trabajando, rapido.
    private var domeSway: CGFloat {
        switch mood {
        case .working:   return CGFloat(sin(phase * 2.6)) * 6
        case .attention: return CGFloat(sin(phase * 5.0)) * 3
        case .error:     return CGFloat(sin(phase * 1.2)) * 2
        default:         return CGFloat(sin(phase * 0.7)) * 5
        }
    }

    private func drawDroid(in box: CGRect, ctx: CGContext) {
        let accent = mood.accent
        let steel = NSColor(srgbRed: 0.86, green: 0.88, blue: 0.91, alpha: 1)
        let steelDark = NSColor(srgbRed: 0.62, green: 0.65, blue: 0.70, alpha: 1)
        let ink = NSColor(srgbRed: 0.16, green: 0.18, blue: 0.22, alpha: 1)

        let domeH = box.width * 0.42
        let torso = CGRect(x: box.minX + 7, y: box.minY + 11,
                           width: box.width - 14, height: box.height - domeH - 14)

        /// Pata: caña inclinada hacia afuera y pie plano. Se dibuja antes del
        /// torso para que el torso le tape el arranque.
        func drawLeg(topX: CGFloat, botX: CGFloat, top: CGFloat, thickness: CGFloat) {
            let stem = NSBezierPath()
            stem.move(to: CGPoint(x: topX, y: top))
            stem.line(to: CGPoint(x: botX, y: box.minY + 6))
            stem.lineWidth = thickness
            stem.lineCapStyle = .round
            steelDark.setStroke()
            stem.stroke()

            // Ranura central: sin esto la caña se ve como un palo plano.
            let groove = NSBezierPath()
            groove.move(to: CGPoint(x: topX, y: top - 2))
            groove.line(to: CGPoint(x: botX, y: box.minY + 7))
            groove.lineWidth = max(1.5, thickness - 5)
            groove.lineCapStyle = .round
            ink.withAlphaComponent(0.45).setStroke()
            groove.stroke()

            let foot = CGRect(x: botX - thickness / 2 - 2.5, y: box.minY,
                              width: thickness + 5, height: 6)
            ink.withAlphaComponent(0.9).setFill()
            NSBezierPath(roundedRect: foot, xRadius: 2.5, yRadius: 2.5).fill()
            steelDark.withAlphaComponent(0.9).setFill()
            NSBezierPath(roundedRect: CGRect(x: foot.minX + 1, y: foot.maxY - 2.5,
                                             width: foot.width - 2, height: 2.5),
                         xRadius: 1, yRadius: 1).fill()
        }

        drawLeg(topX: torso.minX + 3, botX: box.minX + 4, top: torso.maxY - 5, thickness: 7)
        drawLeg(topX: torso.maxX - 3, botX: box.maxX - 4, top: torso.maxY - 5, thickness: 7)

        // --- torso ---
        let torsoPath = NSBezierPath(roundedRect: torso, xRadius: 6, yRadius: 6)
        if let g = NSGradient(colors: [steel, NSColor.white, steelDark],
                              atLocations: [0.0, 0.35, 1.0],
                              colorSpace: .sRGB) {
            g.draw(in: torsoPath, angle: 0)
        }
        ink.withAlphaComponent(0.55).setStroke()
        torsoPath.lineWidth = 1.2
        torsoPath.stroke()

        // Banda central y rejilla: lo que hace que se lea como droide y no como caja.
        ink.withAlphaComponent(0.75).setFill()
        NSBezierPath(rect: CGRect(x: torso.minX, y: torso.midY + 3,
                                  width: torso.width, height: 4)).fill()
        steelDark.withAlphaComponent(0.9).setFill()
        for i in 0..<4 {
            NSBezierPath(rect: CGRect(x: torso.minX + 4 + CGFloat(i) * 7.5,
                                      y: torso.minY + 4, width: 4, height: 5)).fill()
        }

        // Panel de color: el unico elemento del torso que cambia con el estado.
        let panel = CGRect(x: torso.minX + 4, y: torso.midY - 11, width: 12, height: 11)
        accent.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: panel, xRadius: 2, yRadius: 2).fill()
        ink.withAlphaComponent(0.5).setStroke()
        let panelPath = NSBezierPath(roundedRect: panel, xRadius: 2, yRadius: 2)
        panelPath.lineWidth = 1
        panelPath.stroke()

        // Panel gris de al lado.
        steelDark.setFill()
        NSBezierPath(roundedRect: CGRect(x: torso.maxX - 16, y: torso.midY - 10,
                                         width: 12, height: 9),
                     xRadius: 2, yRadius: 2).fill()

        // Luces de estado: parpadean en secuencia solo mientras trabaja.
        let lights: [NSColor] = [
            NSColor(srgbRed: 0.95, green: 0.35, blue: 0.35, alpha: 1),
            NSColor(srgbRed: 0.98, green: 0.78, blue: 0.30, alpha: 1),
            NSColor(srgbRed: 0.40, green: 0.80, blue: 0.95, alpha: 1),
        ]
        for (i, c) in lights.enumerated() {
            let on: CGFloat = mood == .working
                ? CGFloat(0.25 + 0.75 * (0.5 + 0.5 * sin(phase * 6 - Double(i) * 1.1)))
                : 0.5
            c.withAlphaComponent(on).setFill()
            let lx = torso.minX + 5 + CGFloat(i) * 6
            NSBezierPath(ovalIn: CGRect(x: lx, y: torso.maxY - 8, width: 3.4, height: 3.4)).fill()
        }

        // --- tercera pata, al frente y por delante del torso ---
        let centerFoot = CGRect(x: box.midX - 7, y: box.minY, width: 14, height: 6)
        steelDark.setFill()
        NSBezierPath(roundedRect: CGRect(x: box.midX - 3, y: box.minY + 3,
                                         width: 6, height: torso.minY - box.minY),
                     xRadius: 2.5, yRadius: 2.5).fill()
        ink.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: centerFoot, xRadius: 2.5, yRadius: 2.5).fill()
        steelDark.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: CGRect(x: centerFoot.minX + 1, y: centerFoot.maxY - 2.5,
                                         width: centerFoot.width - 2, height: 2.5),
                     xRadius: 1, yRadius: 1).fill()

        // --- cupula ---
        let sway = domeSway
        let domeCenter = CGPoint(x: box.midX + sway * 0.35, y: torso.maxY)
        let domeR = torso.width / 2 + 1
        let dome = NSBezierPath()
        dome.appendArc(withCenter: domeCenter, radius: domeR, startAngle: 0, endAngle: 180)
        dome.close()
        if let g = NSGradient(colors: [steel, NSColor.white, steelDark],
                              atLocations: [0.0, 0.4, 1.0],
                              colorSpace: .sRGB) {
            g.draw(in: dome, angle: 0)
        }
        ink.withAlphaComponent(0.55).setStroke()
        dome.lineWidth = 1.2
        dome.stroke()

        // Franjas de la cupula, giran con ella.
        accent.withAlphaComponent(0.7).setStroke()
        let stripe = NSBezierPath()
        stripe.appendArc(withCenter: domeCenter, radius: domeR - 5,
                         startAngle: 118 - Double(sway), endAngle: 152 - Double(sway))
        stripe.lineWidth = 3
        stripe.lineCapStyle = .round
        stripe.stroke()

        // --- lente ---
        let dim = CACurrentMediaTime() < blinkUntil
        let lens = CGPoint(x: domeCenter.x + sway, y: domeCenter.y + domeR * 0.42)
        let outerR: CGFloat = 8.5
        ink.setFill()
        NSBezierPath(ovalIn: CGRect(x: lens.x - outerR, y: lens.y - outerR,
                                    width: outerR * 2, height: outerR * 2)).fill()
        steelDark.withAlphaComponent(0.9).setStroke()
        let ring = NSBezierPath(ovalIn: CGRect(x: lens.x - outerR, y: lens.y - outerR,
                                               width: outerR * 2, height: outerR * 2))
        ring.lineWidth = 1.4
        ring.stroke()

        // El ojo late cuando hay algo que atender y se apaga al parpadear.
        var glow: CGFloat = dim ? 0.25 : 1.0
        if mood == .attention { glow *= CGFloat(0.65 + 0.35 * (0.5 + 0.5 * sin(phase * 6))) }
        if mood == .error { glow *= CGFloat(0.4 + 0.6 * (sin(phase * 14) > 0 ? 1.0 : 0.35)) }
        let innerR: CGFloat = 5
        ctx.setShadow(offset: .zero, blur: 10, color: accent.withAlphaComponent(0.9 * glow).cgColor)
        accent.withAlphaComponent(glow).setFill()
        NSBezierPath(ovalIn: CGRect(x: lens.x - innerR, y: lens.y - innerR,
                                    width: innerR * 2, height: innerR * 2)).fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        NSColor.white.withAlphaComponent(0.85 * glow).setFill()
        NSBezierPath(ovalIn: CGRect(x: lens.x - 3.2, y: lens.y + 0.6,
                                    width: 2.4, height: 2.4)).fill()

        // Tinte de estado sobre todo el droide, sutil, para que el color se lea de lejos.
        if mood == .error || mood == .attention || mood == .done {
            accent.withAlphaComponent(0.10).setFill()
            let wash = NSBezierPath(roundedRect: torso, xRadius: 6, yRadius: 6)
            wash.append(dome)
            wash.fill()
        }
    }

    /// Adorno sobre la cabeza segun el estado: puntos de "pensando", signo de admiracion.
    private func drawAccessory(body: CGRect) {
        switch mood {
        case .working:
            let y = body.maxY + 22
            for i in 0..<3 {
                let a = 0.35 + 0.65 * (0.5 + 0.5 * sin(phase * 5 - Double(i) * 0.9))
                mood.accent.withAlphaComponent(CGFloat(a)).setFill()
                let x = body.midX - 8 + CGFloat(i) * 8
                NSBezierPath(ovalIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)).fill()
            }
        case .attention:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .heavy),
                .foregroundColor: mood.accent,
            ]
            let s = NSAttributedString(string: "!", attributes: attrs)
            let sz = s.size()
            let bob = CGFloat(sin(phase * 5)) * 2
            s.draw(at: CGPoint(x: body.midX - sz.width / 2 + 9, y: body.maxY + 14 + bob))
        default:
            break
        }
    }

    // MARK: mouse

    override func mouseDown(with event: NSEvent) {
        dragOrigin = NSEvent.mouseLocation
        dragWindowOrigin = window?.frame.origin ?? .zero
        dragDistance = 0
        mouseDownAt = CACurrentMediaTime()
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        let d = CGPoint(x: now.x - dragOrigin.x, y: now.y - dragOrigin.y)
        dragDistance = max(dragDistance, abs(d.x) + abs(d.y))
        onDrag?(CGPoint(x: dragWindowOrigin.x + d.x, y: dragWindowOrigin.y + d.y))
    }

    override func mouseUp(with event: NSEvent) {
        // Un click es un click solo si casi no se movio y fue rapido.
        if dragDistance < 5 && CACurrentMediaTime() - mouseDownAt < 0.5 { onClick?() }
    }

    override func rightMouseDown(with event: NSEvent) { onMenu?(event) }

    // MARK: hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let a = hoverArea { removeTrackingArea(a) }
        let a = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(a)
        hoverArea = a
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}
