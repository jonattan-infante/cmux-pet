// Fuentes 2 y 3: comandos de shell, puertos y titulos de workspace.

import AppKit
import Foundation

extension PetController {
    // MARK: fuente 2 — comandos de shell

    func startShellLogTail() {
        if !fm.fileExists(atPath: shellLogURL.path) {
            fm.createFile(atPath: shellLogURL.path, contents: nil)
        }
        // Arrancar al final: no reproducir el historial al abrir.
        let attrs = try? fm.attributesOfItem(atPath: shellLogURL.path)
        shellOffset = (attrs?[.size] as? UInt64) ?? 0

        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.drainShellLog()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func drainShellLog() {
        guard let attrs = try? fm.attributesOfItem(atPath: shellLogURL.path),
              let size = attrs[.size] as? UInt64 else { return }
        if size == shellOffset { return }
        if size < shellOffset { shellOffset = 0 }   // el archivo rotó

        guard let fh = try? FileHandle(forReadingFrom: shellLogURL) else { return }
        defer { try? fh.close() }
        try? fh.seek(toOffset: shellOffset)
        let data = fh.readDataToEndOfFile()
        shellOffset = size

        for line in data.split(separator: 0x0A) {
            guard let obj = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any]
            else { continue }
            handleShellEvent(obj)
        }
    }

    /// Estas mirando ese pane exacto ahora mismo: no tiene sentido avisarte de lo
    /// que ya ves. Deliberadamente es a nivel de pane y no de workspace: un
    /// workspace tiene muchas pestañas y silenciarlo entero se traga casi todo.
    func userIsWatching(_ surfaceId: String?) -> Bool {
        guard let s = surfaceId, s == focusedSurface else { return false }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.cmuxterm.app"
    }

    func handleShellEvent(_ e: [String: Any]) {
        guard (e["kind"] as? String) == "command" else { return }
        if !config.notifyWhileWatching && userIsWatching(e["surface"] as? String) {
            plog("suprimido (mirando el pane): \((e["command"] as? String) ?? "")")
            return
        }
        let status = (e["status"] as? Int) ?? 0
        let seconds = (e["seconds"] as? Double) ?? 0
        let command = truncate((e["command"] as? String) ?? "", 56)
        let wsId = e["workspace"] as? String
        let ws = Wording.at(workspaceLabel(wsId))

        if status != 0 {
            show(Bubble(mood: .error,
                        text: Voice.shared.phrase("commandError", [
                            "cmd": command, "code": "\(status)", "where": ws,
                        ]) ?? Wording.plain("\(command) falló con código \(status)\(ws)."),
                        workspaceId: wsId, sticky: false))
        } else {
            show(Bubble(mood: .done,
                        text: Voice.shared.phrase("commandDone", [
                            "cmd": command, "time": humanDuration(seconds), "where": ws,
                        ]) ?? Wording.plain("\(command) terminó en \(humanDuration(seconds))\(ws)."),
                        workspaceId: wsId, sticky: false))
        }
    }

    // MARK: fuente 3 — puertos y titulos de workspace

    func startPolling() {
        refreshWorkspaces()
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            self?.refreshWorkspaces()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func refreshWorkspaces() {
        DispatchQueue.global(qos: .utility).async {
            guard let obj = cmuxJSON(["rpc", "workspace.list", "{}"]),
                  let list = obj["workspaces"] as? [[String: Any]] else { return }

            var titles: [String: String] = [:]
            var ports: [String: Set<Int>] = [:]
            for w in list {
                guard let id = w["id"] as? String else { continue }
                if let t = w["title"] as? String, !t.isEmpty {
                    titles[id] = t
                } else if let t = w["custom_title"] as? String, !t.isEmpty {
                    titles[id] = t
                } else if let d = w["current_directory"] as? String {
                    titles[id] = (d as NSString).lastPathComponent
                }
                let raw = (w["listening_ports"] as? [Any]) ?? []
                var set = Set<Int>()
                for item in raw {
                    if let n = item as? Int { set.insert(n) }
                    else if let d = item as? [String: Any], let n = d["port"] as? Int { set.insert(n) }
                }
                ports[id] = set
            }

            DispatchQueue.main.async {
                self.workspaceTitles = titles
                self.diffPorts(ports)
            }
        }
    }

    func diffPorts(_ fresh: [String: Set<Int>]) {
        defer { knownPorts = fresh }
        guard config.watchPorts else { return }
        guard portsBaselineDone else { portsBaselineDone = true; return }

        for (ws, now) in fresh {
            let before = knownPorts[ws] ?? []
            let label = Wording.at(workspaceLabel(ws))
            for p in now.subtracting(before).sorted() {
                show(Bubble(mood: .info,
                            text: Voice.shared.phrase("portUp", ["port": "\(p)", "where": label])
                                ?? Wording.plain("El puerto \(p) está escuchando\(label)."),
                            workspaceId: ws, sticky: false))
            }
            for p in before.subtracting(now).sorted() {
                show(Bubble(mood: .info,
                            text: Voice.shared.phrase("portDown", ["port": "\(p)", "where": label])
                                ?? Wording.plain("El puerto \(p) se cerró\(label)."),
                            workspaceId: ws, sticky: false))
            }
        }
    }

    func workspaceLabel(_ id: String?) -> String {
        guard let id = id else { return "" }
        return PetController.cleanTitle(workspaceTitles[id] ?? "")
    }

    /// cmux le pone un spinner braille o un asterisco al titulo cuando el
    /// workspace esta activo. Dentro de una frase eso es basura.
    static func cleanTitle(_ t: String) -> String {
        var s = Substring(t)
        while let f = s.unicodeScalars.first {
            let v = f.value
            let isSpinner = (v >= 0x2800 && v <= 0x28FF)   // braille
                || v == 0x2733 || v == 0x2731 || v == 0x002A   // asteriscos
                || f == " "
            if isSpinner { s = s.dropFirst() } else { break }
        }
        return String(s).trimmingCharacters(in: .whitespaces)
    }

}
