// Fuente 1: stream de eventos de cmux (agentes, notificaciones, foco).

import AppKit
import Foundation

extension PetController {
    // MARK: fuente 1 — stream de eventos de cmux

    /// Mata streams de instancias anteriores. Sin esto cada reinicio deja un
    /// `cmux events` huerfano leyendo el socket para siempre.
    func killStaleStreams() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        p.arguments = ["-f", "cmux events --reconnect --no-heartbeat --no-ack --category agent"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    /// Cierre ordenado: launchd manda SIGTERM y el hijo debe morir con nosotros.
    public func shutdown() {
        eventProcess?.terminate()
        eventProcess = nil
        try? fm.removeItem(at: pidURL)
    }

    func startCmuxEventStream() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmuxPath)
        p.arguments = ["events", "--reconnect", "--no-heartbeat", "--no-ack",
                       "--category", "agent", "--category", "notification",
                       "--category", "surface", "--category", "workspace"]
        let pipe = Pipe()
        p.standardOutput = pipe

        // El stderr del CLI es la unica pista cuando el socket rechaza la conexion.
        let errPipe = Pipe()
        p.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let d = handle.availableData
            guard !d.isEmpty, let s = String(data: d, encoding: .utf8) else { return }
            let msg = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !msg.isEmpty else { return }
            DispatchQueue.main.async { self.noteStreamError(msg) }
        }

        let startedAt = Date()

        var buffer = Data()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty { return }
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.subdata(in: buffer.startIndex..<nl)
                buffer.removeSubrange(buffer.startIndex...nl)
                guard !lineData.isEmpty else { continue }
                guard let obj = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any]
                else {
                    plog("linea no parseable (\(lineData.count) bytes)")
                    continue
                }
                DispatchQueue.main.async {
                    self.eventCount += 1
                    if self.eventCount <= 25 {
                        plog("evento #\(self.eventCount): \(obj["name"] as? String ?? "?")")
                    }
                    self.handleCmuxEvent(obj)
                }
            }
        }

        p.terminationHandler = { [weak self] proc in
            let lived = Date().timeIntervalSince(startedAt)
            DispatchQueue.main.async {
                self?.noteStreamExit(code: proc.terminationStatus, lived: lived)
            }
            // --reconnect cubre caidas del socket; esto cubre que muera el proceso entero.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self?.startCmuxEventStream() }
        }

        do {
            try p.run()
            plog("stream de eventos conectado (pid \(p.processIdentifier))")
        } catch {
            plog("no pude iniciar cmux events: \(error)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.startCmuxEventStream()
            }
            return
        }
        eventProcess = p
    }

    /// Registra o refresca lo que esta haciendo un agente. El turno arranca en
    /// la primera senal y conserva su hora de inicio en las siguientes.
    func touchActivity(_ session: String, agent: String, wsId: String?, tool: String?) {
        if var a = activities[session] {
            if let t = tool {
                a.currentTool = t
                a.toolCount += 1
            }
            if a.workspaceId == nil { a.workspaceId = wsId }
            a.lastSeen = Date()
            activities[session] = a
        } else {
            var a = AgentActivity(agent: agent, workspaceId: wsId, startedAt: Date(),
                                  lastSeen: Date(), currentTool: tool)
            if tool != nil { a.toolCount = 1 }
            activities[session] = a
        }
    }

    /// Un Stop puede perderse (agente matado, cmux reiniciado, hook fallido). Sin
    /// esta barrida el panel acumula fantasmas que nunca se van.
    func sweepStaleActivities() {
        let cutoff = Date().addingTimeInterval(-600)
        let dead = activities.filter { $0.value.lastSeen < cutoff }.map { $0.key }
        guard !dead.isEmpty else { return }
        for k in dead {
            activities.removeValue(forKey: k)
            attentionSessions.remove(k)
        }
        plog("barrida: \(dead.count) sesión(es) sin señal por 10 min")
        refreshRestingMood()
    }

    /// Las lineas del panel de estado. Vacio si no hay nada corriendo.
    func rosterLines() -> [(String, NSColor?)] {
        let live = activities.values.sorted { $0.startedAt < $1.startedAt }
        guard !live.isEmpty else { return [] }

        let accent = Mood.working.accent
        var out: [(String, NSColor?)] = []
        out.append((live.count == 1 ? "1 unidad trabajando" : "\(live.count) unidades trabajando", accent))

        for a in live {
            out.append(("", nil))
            let ws = workspaceLabel(a.workspaceId)
            out.append(("\(a.agent)\(ws.isEmpty ? "" : " · \(ws)") · \(a.elapsed)", accent))
            out.append(("  \(a.doing)\(a.toolCount > 0 ? " · \(a.toolCount) pasos" : "")", nil))
            if let ws = a.workspaceId, let task = workspaceTasks[ws] {
                out.append(("  \u{201C}\(truncate(task, 96))\u{201D}", nil))
            }
        }
        return out
    }

    /// El CLI escribio en stderr. Si es un rechazo del socket hay que decirlo:
    /// callado, el asistente parece funcionar y no avisa de nada.
    func noteStreamError(_ msg: String) {
        plog("error del stream: \(msg)")
        let denied = msg.contains("Broken pipe") || msg.lowercased().contains("permission")
            || msg.lowercased().contains("denied") || msg.contains("errno 32")
        guard denied, !warnedAboutSocket else { return }
        warnedAboutSocket = true
        show(Bubble(mood: .error,
                    text: Wording.plain("No me deja escuchar a cmux: rechaza el control externo. Revisa socketControlMode en cmux.json."),
                    workspaceId: nil, sticky: true))
    }

    /// Un stream que muere en menos de dos segundos, dos veces seguidas, no es
    /// una caida transitoria: es acceso denegado.
    func noteStreamExit(code: Int32, lived: Double) {
        plog("stream terminado (código \(code)) tras \(String(format: "%.1f", lived)) s")
        if lived < 2 {
            fastStreamExits += 1
        } else {
            fastStreamExits = 0
        }
        guard fastStreamExits >= 2, !warnedAboutSocket else { return }
        warnedAboutSocket = true
        show(Bubble(mood: .error,
                    text: Wording.plain("El canal de eventos de cmux se me muere al arrancar. Revisa ~/.cmux-pet/pet.log."),
                    workspaceId: nil, sticky: true))
    }

    func agentLabel(_ source: String?) -> String {
        switch (source ?? "").lowercased() {
        case "claude": return "Claude"
        case "codex": return "Codex"
        case "gemini": return "Gemini"
        case "opencode": return "OpenCode"
        case "cursor": return "Cursor"
        case "amp": return "Amp"
        case "copilot": return "Copilot"
        case "": return "El agente"
        default: return (source ?? "").capitalized
        }
    }

    func handleCmuxEvent(_ e: [String: Any]) {
        guard let name = e["name"] as? String else { return }
        let payload = e["payload"] as? [String: Any] ?? [:]

        // El generador de frases ES un Claude Code que lanzamos nosotros. Sin
        // este filtro el asistente se anunciaría a sí mismo en bucle.
        if let ppid = payload["_ppid"] as? Int, ppid == Int(getpid()) { return }

        let wsId = (payload["workspace_id"] as? String) ?? (e["workspace_id"] as? String)
        let session = (payload["session_id"] as? String) ?? "anon"
        let agent = agentLabel(payload["_source"] as? String)

        switch name {
        case "agent.hook.SessionStart", "agent.hook.UserPromptSubmit":
            touchActivity(session, agent: agent, wsId: wsId, tool: nil)
            attentionSessions.remove(session)
            refreshRestingMood()

        case "agent.hook.PreToolUse":
            touchActivity(session, agent: agent, wsId: wsId,
                          tool: payload["tool_name"] as? String)
            attentionSessions.remove(session)
            refreshRestingMood()

        case "workspace.prompt.submitted":
            // El texto del prompt es lo unico que dice en QUE trabaja el agente.
            if let ws = wsId, let preview = payload["message_preview"] as? String,
               !preview.isEmpty {
                workspaceTasks[ws] = truncate(preview, 120)
            }

        case "agent.hook.Stop", "agent.hook.SessionEnd":
            let wasRunning = activities.removeValue(forKey: session) != nil
            attentionSessions.remove(session)
            refreshRestingMood()
            guard wasRunning else { break }
            // Evita dos avisos por la misma sesion si llegan Stop y SessionEnd juntos.
            if let last = lastDoneAt[session], Date().timeIntervalSince(last) < 3 { break }
            lastDoneAt[session] = Date()
            show(Bubble(mood: .done,
                        text: Voice.shared.phrase("agentDone", [
                            "agent": agent, "where": Wording.at(workspaceLabel(wsId)),
                        ]) ?? Wording.plain("\(agent) terminó su turno\(Wording.at(workspaceLabel(wsId)))."),
                        workspaceId: wsId, sticky: false))

        case "agent.hook.PermissionRequest", "agent.hook.AskUserQuestion":
            attentionSessions.insert(session)
            refreshRestingMood()
            // Cada hook llega dos veces (phase received y completed).
            if let last = lastAttentionAt[session], Date().timeIntervalSince(last) < 3 { break }
            lastAttentionAt[session] = Date()
            let tool = payload["tool_name"] as? String
            // {what} es un sustantivo: las plantillas lo enchufan tras
            // "necesita ayuda con" o "está atascado en".
            let what = (name.hasSuffix("AskUserQuestion") || tool == "AskUserQuestion")
                ? "una pregunta"
                : "un permiso" + (tool.map { " para usar \($0)" } ?? "")
            let ws = Wording.at(workspaceLabel(wsId))
            show(Bubble(mood: .attention,
                        text: Voice.shared.phrase("attention", [
                            "agent": agent, "what": what, "where": ws,
                        ]) ?? Wording.plain("\(agent) necesita \(what)\(ws)."),
                        workspaceId: wsId, sticky: true))

        case "agent.hook.Notification":
            attentionSessions.insert(session)
            refreshRestingMood()
            if let last = lastAttentionAt[session], Date().timeIntervalSince(last) < 3 { break }
            lastAttentionAt[session] = Date()
            show(Bubble(mood: .attention,
                        text: Voice.shared.phrase("attention", [
                            "agent": agent, "what": "una decisión tuya",
                            "where": Wording.at(workspaceLabel(wsId)),
                        ]) ?? Wording.plain("\(agent) dejó de trabajar\(Wording.at(workspaceLabel(wsId)))."),
                        workspaceId: wsId, sticky: true))

        case "surface.focused", "surface.selected":
            focusedSurface = (e["surface_id"] as? String) ?? (payload["surface_id"] as? String)

        case "workspace.selected":
            selectedWorkspace = (payload["workspace_id"] as? String) ?? wsId

        case "notification.created":
            // El stream trae el texto redactado; el contenido real se pide por rpc.
            guard let nid = payload["notification_id"] as? String else { break }
            fetchNotification(nid)

        default:
            break
        }
    }

    func fetchNotification(_ id: String) {
        DispatchQueue.global(qos: .utility).async {
            guard let obj = cmuxJSON(["rpc", "notification.list", "{}"]),
                  let list = obj["notifications"] as? [[String: Any]],
                  let n = list.first(where: { ($0["id"] as? String) == id })
            else { return }
            let title = (n["title"] as? String) ?? "cmux"
            let subtitle = (n["subtitle"] as? String) ?? ""
            let body = (n["body"] as? String) ?? ""
            let wsId = n["workspace_id"] as? String
            let wsTitle = (n["tab_title"] as? String) ?? ""

            DispatchQueue.main.async {
                // Los avisos de agente ya los cubre el stream de hooks: no duplicar.
                let known = ["claude code", "codex", "gemini", "opencode"]
                if known.contains(title.lowercased()) && self.currentBubble?.mood == .attention { return }
                // Todo en una frase: "cmux dice: <cuerpo> (en <workspace>)".
                let head = subtitle.isEmpty ? title : "\(title) — \(subtitle)"
                var sentence = truncate(head, 60)
                if !body.isEmpty { sentence += ": " + truncate(body, 110) }
                sentence += Wording.at(wsTitle) + "."
                self.show(Bubble(mood: .info, text: Wording.plain(sentence),
                                 workspaceId: wsId, sticky: false))
            }
        }
    }

}
