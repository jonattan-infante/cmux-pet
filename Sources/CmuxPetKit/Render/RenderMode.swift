// Modo --render: dibuja cada estado a PNG sin abrir ventana.

import AppKit

public func renderShowcase(to dir: URL) {
    let moods: [Mood] = [.idle, .working, .done, .error, .attention, .info]
    let size = CGSize(width: 96, height: 108)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

    var frames: [NSImage] = []
    for m in moods {
        let view = PetView(frame: CGRect(origin: .zero, size: size))
        view.mood = m
        view.tick(m == .done ? 0.22 : 0.9)   // avanza a un instante representativo

        let canvas = NSImage(size: size)
        canvas.lockFocus()
        NSColor(srgbRed: 0.13, green: 0.14, blue: 0.17, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            rep.draw(in: CGRect(origin: .zero, size: size))
        }
        canvas.unlockFocus()
        frames.append(canvas)

        if let tiff = canvas.tiffRepresentation,
           let bmp = NSBitmapImageRep(data: tiff),
           let png = bmp.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("\(m.rawValue).png"))
        }
    }

    // Tira horizontal con los seis estados, para compararlos de un vistazo.
    let stripSize = CGSize(width: size.width * CGFloat(frames.count), height: size.height)
    let strip = NSImage(size: stripSize)
    strip.lockFocus()
    for (i, f) in frames.enumerated() {
        f.draw(at: CGPoint(x: CGFloat(i) * size.width, y: 0),
               from: .zero, operation: .sourceOver, fraction: 1)
    }
    strip.unlockFocus()
    if let tiff = strip.tiffRepresentation,
       let bmp = NSBitmapImageRep(data: tiff),
       let png = bmp.representation(using: .png, properties: [:]) {
        try? png.write(to: dir.appendingPathComponent("todos.png"))
    }
    // Burbujas de terminal a distintos avances de escritura.
    let samples: [(Mood, String)] = [
        (.done, Droid.say(.done, "./gradlew build terminó en 1 min 34 s en Fineract.")),
        (.error, Droid.say(.error, "npm run test:e2e falló con código 1 en Backend.")),
        (.attention, Droid.say(.attention, "Claude pide permiso para usar Bash en DB Connect.")),
        (.info, Droid.say(.info, "Unidad en línea y vigilando tus agentes, comandos y puertos. Un click me lleva al último aviso, click derecho abre las opciones.", closer: false)),
    ]
    for (i, sample) in samples.enumerated() {
        let b = Bubble(mood: sample.0, text: sample.1, workspaceId: nil, sticky: false)
        let bs = BubbleView.size(for: b)
        for (j, frac) in [0.35, 1.0].enumerated() {
            let view = BubbleView(frame: CGRect(origin: .zero, size: bs))
            view.bubble = b
            view.debugReveal = frac
            let canvas = NSImage(size: CGSize(width: bs.width + 20, height: bs.height + 20))
            canvas.lockFocus()
            NSColor(srgbRed: 0.30, green: 0.32, blue: 0.36, alpha: 1).setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: canvas.size)).fill()
            if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                rep.draw(in: CGRect(x: 10, y: 10, width: bs.width, height: bs.height))
            }
            canvas.unlockFocus()
            if let tiff = canvas.tiffRepresentation,
               let bmp = NSBitmapImageRep(data: tiff),
               let png = bmp.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("burbuja-\(i)-\(j).png"))
            }
        }
    }

    // Panel de estado en vivo.
    let accent = Mood.working.accent
    let rosterLines: [(String, NSColor?)] = [
        ("2 unidades trabajando", accent),
        ("", nil),
        ("Claude · Fineract · 4 min", accent),
        ("  corriendo comandos · 23 pasos", nil),
        ("  \u{201C}repetir los movimientos del corte 23\u{201D}", nil),
        ("", nil),
        ("Codex · Backend · 40 s", accent),
        ("  editando archivos · 3 pasos", nil),
        ("  \u{201C}arreglar el null pointer del score\u{201D}", nil),
    ]
    let rh = RosterView.height(for: rosterLines)
    let rv = RosterView(frame: CGRect(x: 0, y: 0, width: RosterView.width, height: rh))
    rv.lines = rosterLines
    rv.accent = accent
    let rcanvas = NSImage(size: CGSize(width: RosterView.width + 20, height: rh + 20))
    rcanvas.lockFocus()
    NSColor(srgbRed: 0.30, green: 0.32, blue: 0.36, alpha: 1).setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: rcanvas.size)).fill()
    if let rep = rv.bitmapImageRepForCachingDisplay(in: rv.bounds) {
        rv.cacheDisplay(in: rv.bounds, to: rep)
        rep.draw(in: CGRect(x: 10, y: 10, width: RosterView.width, height: rh))
    }
    rcanvas.unlockFocus()
    if let tiff = rcanvas.tiffRepresentation,
       let bmp = NSBitmapImageRep(data: tiff),
       let png = bmp.representation(using: .png, properties: [:]) {
        try? png.write(to: dir.appendingPathComponent("panel.png"))
    }

    print("render en \(dir.path)")
}
