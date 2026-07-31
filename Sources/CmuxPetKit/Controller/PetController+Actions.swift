// Acciones del usuario: click, menu y sus comandos.

import AppKit
import Foundation

extension PetController {
    // MARK: acciones

    func jumpToLastAlert() {
        let ws = currentBubble?.workspaceId ?? lastAlertWorkspace
        hideBubble()
        attentionSessions.removeAll()
        refreshRestingMood()
        guard let ws = ws else { activateCmux(); return }
        cmuxFire(["select-workspace", "--workspace", ws])
        activateCmux()
    }

    func activateCmux() {
        let url = URL(fileURLWithPath: "/Applications/cmux.app")
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: cfg, completionHandler: nil)
    }

    func showMenu(_ event: NSEvent) {
        let menu = NSMenu()

        let quiet = NSMenuItem(title: config.quiet ? "Reactivar avisos" : "Silenciar avisos",
                               action: #selector(toggleQuiet), keyEquivalent: "")
        quiet.target = self
        menu.addItem(quiet)

        let ports = NSMenuItem(title: config.watchPorts ? "Dejar de vigilar puertos" : "Vigilar puertos",
                               action: #selector(togglePorts), keyEquivalent: "")
        ports.target = self
        menu.addItem(ports)

        menu.addItem(.separator())

        let jump = NSMenuItem(title: "Ir al último aviso", action: #selector(menuJump), keyEquivalent: "")
        jump.target = self
        jump.isEnabled = lastAlertWorkspace != nil
        menu.addItem(jump)

        let reset = NSMenuItem(title: "Reiniciar posición", action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let voice = NSMenuItem(title: "Reescribir sus frases", action: #selector(regenerateVoice),
                               keyEquivalent: "")
        voice.target = self
        menu.addItem(voice)

        let sprites = NSMenuItem(title: "Recargar sprites", action: #selector(reloadSprites), keyEquivalent: "")
        sprites.target = self
        menu.addItem(sprites)

        let openSprites = NSMenuItem(title: "Abrir carpeta de sprites",
                                     action: #selector(openSpriteFolder), keyEquivalent: "")
        openSprites.target = self
        menu.addItem(openSprites)

        menu.addItem(.separator())

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Salir", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        NSMenu.popUpContextMenu(menu, with: event, for: petView)
    }

    func statusLine() -> String {
        let live = activities.values.sorted { $0.startedAt < $1.startedAt }
        if live.isEmpty { return "Sin agentes activos" }
        return live.map { a in
            let ws = workspaceLabel(a.workspaceId)
            return "\(a.agent)\(ws.isEmpty ? "" : " · \(ws)") · \(a.doing) · \(a.elapsed)"
        }.joined(separator: "   |   ")
    }

    @objc func toggleQuiet() {
        config.quiet.toggle()
        config.save()
        if config.quiet { hideBubble() }
    }

    @objc func togglePorts() {
        config.watchPorts.toggle()
        config.save()
    }

    @objc func menuJump() { jumpToLastAlert() }

    @objc func reloadSprites() { petView.reloadSprites() }

    @objc func regenerateVoice() {
        show(Bubble(mood: .working,
                    text: "*whirr* Escribiendo frases nuevas con Claude Code. Tarda como un minuto.",
                    workspaceId: nil, sticky: false))
        Voice.shared.regenerate("me lo pediste") { [weak self] ok in
            guard let self = self else { return }
            self.show(Bubble(mood: ok ? .done : .error,
                             text: ok
                                ? (Voice.shared.phrase("greeting", [:]) ?? "*bip-bip* Frases nuevas cargadas.")
                                : "*bzzzt* No pude escribir frases nuevas. Sigo con las de antes; mira ~/.cmux-pet/pet.log.",
                             workspaceId: nil, sticky: false))
        }
    }

    @objc func openSpriteFolder() {
        try? fm.createDirectory(at: PetView.spriteDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(PetView.spriteDir)
    }

    @objc func resetPosition() {
        config.x = nil
        config.y = nil
        config.save()
        restoreAnchor()
        layout()
        scheduleSave()
    }

    @objc func quitApp() {
        try? fm.removeItem(at: pidURL)
        NSApp.terminate(nil)
    }
}
