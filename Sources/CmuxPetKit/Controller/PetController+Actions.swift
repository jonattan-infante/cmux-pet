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

        menu.addItem(.separator())

        // Cambiar de mascota sin salir a la terminal: es la accion central del
        // producto ahora que hay un marketplace.
        let installed = PetLibrary.installed()
        let activeID = PetTheme.shared.pack?.id
        if installed.count > 1 {
            let switcher = NSMenuItem(title: "Cambiar de mascota", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for p in installed {
                let item = NSMenuItem(title: "\(p.name)  (\(p.id))",
                                      action: #selector(switchPet(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = p.id
                item.state = p.id == activeID ? .on : .off
                sub.addItem(item)
            }
            switcher.submenu = sub
            menu.addItem(switcher)
        }

        let voice = NSMenuItem(title: "Reescribir sus frases", action: #selector(regenerateVoice),
                               keyEquivalent: "")
        voice.target = self
        menu.addItem(voice)

        let reload = NSMenuItem(title: "Recargar la mascota", action: #selector(reloadPet),
                                keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)

        let openFolder = NSMenuItem(title: "Abrir su carpeta",
                                    action: #selector(openPetFolder), keyEquivalent: "")
        openFolder.target = self
        menu.addItem(openFolder)

        menu.addItem(.separator())

        let petLine = NSMenuItem(title: PetTheme.shared.pack.map { "\($0.name) v\($0.version)" }
                                    ?? "sin mascota instalada",
                                 action: nil, keyEquivalent: "")
        petLine.isEnabled = false
        menu.addItem(petLine)

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

    /// Relee el paquete de la mascota activa desde el disco: sirve mientras
    /// alguien esta creando la suya y quiere ver los cambios sin reiniciar.
    @objc func reloadPet() {
        activateConfiguredPet()
        layout()
        show(Bubble(mood: .info,
                    text: Voice.shared.phrase("greeting", [:])
                        ?? "\(PetTheme.shared.name) recargada.",
                    workspaceId: nil, sticky: false))
    }

    /// Cambia de mascota en caliente, sin reiniciar el proceso.
    @objc func switchPet(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        config.activePet = id
        config.save()
        activateConfiguredPet()
        layout()
        show(Bubble(mood: .info,
                    text: Voice.shared.phrase("greeting", [:])
                        ?? "Ahora soy \(PetTheme.shared.name).",
                    workspaceId: nil, sticky: false))
    }

    @objc func regenerateVoice() {
        show(Bubble(mood: .working,
                    text: "Escribiendo frases nuevas con Claude Code. Tarda como un minuto.",
                    workspaceId: nil, sticky: false))
        Voice.shared.regenerate("me lo pediste") { [weak self] ok, detail in
            guard let self = self else { return }
            self.show(Bubble(mood: ok ? .done : .error,
                             text: ok
                                ? (Voice.shared.phrase("greeting", [:]) ?? "Frases nuevas cargadas.")
                                : "No pude escribir frases nuevas: \(detail). Sigo con las de antes.",
                             workspaceId: nil, sticky: false))
        }
    }

    /// Abre la carpeta del paquete de la mascota activa, que es donde estan sus
    /// sprites y su personalidad.
    @objc func openPetFolder() {
        guard let pack = PetTheme.shared.pack else {
            NSWorkspace.shared.open(PetLibrary.petsDir)
            return
        }
        NSWorkspace.shared.open(pack.root)
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
