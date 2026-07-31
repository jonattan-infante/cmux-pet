// Avisos: mostrar, ocultar y narrar el avance.

import AppKit
import Foundation

extension PetController {
    // MARK: burbujas y estado

    /// Estado en reposo: atender gana sobre trabajar, trabajar gana sobre descansar.
    func refreshRestingMood() {
        guard transientMoodTimer == nil else { return }
        petView.mood = restingMood()
        petView.workingCount = activities.count
    }

    func restingMood() -> Mood {
        if !attentionSessions.isEmpty { return .attention }
        if !activities.isEmpty { return .working }
        return .idle
    }

    // MARK: narracion periodica

    /// Cada tanto cuenta en que van, sin esperar a que termine nada. Se calla si
    /// no hay nadie trabajando, si estas viendo una burbuja, o si el ultimo
    /// reporte decia exactamente lo mismo.
    func startNarration() {
        let timer = Timer(timeInterval: 20, repeats: true) { [weak self] _ in
            self?.maybeNarrate()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func maybeNarrate() {
        sweepStaleActivities()
        guard config.narrateEverySeconds > 0, !config.quiet else { return }
        guard !activities.isEmpty, currentBubble == nil, !hovering else { return }
        if let last = lastNarrationAt,
           Date().timeIntervalSince(last) < config.narrateEverySeconds { return }

        let live = activities.values.sorted { $0.startedAt < $1.startedAt }
        let text: String
        if live.count == 1, let a = live[0] as AgentActivity? {
            let ws = Droid.at(workspaceLabel(a.workspaceId))
            text = Voice.shared.phrase("working", [
                "agent": a.agent, "doing": a.doing, "time": a.elapsed, "where": ws,
            ]) ?? Droid.say(.working, "\(a.agent) lleva \(a.elapsed)\(ws) \(a.doing).",
                            closer: false)
        } else {
            // Dos sesiones del mismo agente en el mismo workspace leen igual:
            // repetirlas es ruido, no informacion.
            var parts: [String] = []
            for a in live {
                let ws = workspaceLabel(a.workspaceId)
                let s = "\(a.agent)\(ws.isEmpty ? "" : " en \(ws)") \(a.doing)"
                if !parts.contains(s) { parts.append(s) }
            }
            text = Droid.say(.working, "\(live.count) unidades trabajando: "
                             + parts.prefix(3).joined(separator: ", ") + ".", closer: false)
        }

        // Si el parte es identico al anterior no aporta nada.
        guard text != lastNarrationText else { return }
        lastNarrationText = text
        lastNarrationAt = Date()
        show(Bubble(mood: .working, text: text,
                    workspaceId: live.first?.workspaceId, sticky: false))
    }

    func show(_ b: Bubble) {
        if let ws = b.workspaceId { lastAlertWorkspace = ws }

        transientMoodTimer?.invalidate()
        petView.mood = b.mood
        if !b.sticky {
            let hold: Double = b.mood == .error ? 4.5 : 3.0
            transientMoodTimer = Timer.scheduledTimer(withTimeInterval: hold, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.transientMoodTimer = nil
                self.petView.mood = self.restingMood()
            }
        } else {
            transientMoodTimer = nil
        }

        guard !config.quiet else {
            plog("silenciado: \(b.text)")
            return
        }

        plog("aviso: [\(b.mood.rawValue)] \(b.text)")
        currentBubble = b
        bubbleView.bubble = b
        layout()

        bubbleTimer?.invalidate()
        if !b.sticky {
            // El reloj arranca cuando termina de escribir, no antes: un mensaje
            // largo no puede desaparecer a medio teclear.
            let typing = Double(b.text.count) / BubbleView.charsPerSecond
            let ttl = typing + (b.mood == .error ? 9 : 6)
            bubbleTimer = Timer.scheduledTimer(withTimeInterval: ttl, repeats: false) { [weak self] _ in
                self?.hideBubble()
            }
        } else {
            // Incluso lo pegajoso caduca: un aviso de hace media hora ya no sirve.
            bubbleTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { [weak self] _ in
                self?.hideBubble()
            }
        }
    }

    func hideBubble() {
        bubbleTimer?.invalidate()
        bubbleTimer = nil
        currentBubble = nil
        bubbleView.bubble = nil
        layout()
    }

    func greet() {
        show(Bubble(mood: .info,
                    text: Voice.shared.phrase("greeting", [:])
                        ?? Droid.say(.info, "Unidad en línea y vigilando tus agentes, comandos y puertos. Un click me lleva al último aviso, click derecho abre las opciones.",
                                     closer: false),
                    workspaceId: nil, sticky: false))
    }

}
