// Voz generada por Claude Code local.

import Foundation

final class Voice {
    static let shared = Voice()

    /// Marcadores obligatorios de cada clase de aviso.
    static let kinds: [String: Set<String>] = [
        "agentDone":    ["agent", "where"],
        "commandDone":  ["cmd", "time", "where"],
        "commandError": ["cmd", "code", "where"],
        "attention":    ["agent", "what", "where"],
        "working":      ["agent", "doing", "time", "where"],
        "portUp":       ["port", "where"],
        "portDown":     ["port", "where"],
        "greeting":     [],
    ]

    private var templates: [String: [String]] = [:]
    private var lastPick: [String: Int] = [:]
    private var generating = false
    private let url = petHome.appendingPathComponent("voice.json")

    var isLoaded: Bool { !templates.isEmpty }

    var ageInDays: Double? {
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let d = attrs[.modificationDate] as? Date else { return nil }
        return Date().timeIntervalSince(d) / 86400
    }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return }
        templates = Voice.validate(raw)
        plog("voz cargada: \(templates.map { "\($0.key)=\($0.value.count)" }.sorted().joined(separator: " "))")
    }

    /// Rellena una plantilla al azar. Devuelve nil si no hay ninguna usable, y
    /// entonces manda la voz estatica de `Droid`.
    func phrase(_ kind: String, _ vars: [String: String]) -> String? {
        guard let options = templates[kind], !options.isEmpty else { return nil }
        var i = Int.random(in: 0..<options.count)
        // No repetir la misma frase dos veces seguidas.
        if options.count > 1, let last = lastPick[kind], last == i {
            i = (i + 1) % options.count
        }
        lastPick[kind] = i
        var s = options[i]
        for (k, v) in vars {
            s = s.replacingOccurrences(of: "{\(k)}", with: v)
        }
        // Un marcador sin dato deja hueco: mejor limpiarlo que mostrar "{time}".
        return s.replacingOccurrences(of: "  ", with: " ")
    }

    /// Solo sobreviven las plantillas que usan todos sus marcadores y ninguno inventado.
    static func validate(_ raw: [String: Any]) -> [String: [String]] {
        var out: [String: [String]] = [:]
        let allowed = Set(kinds.values.flatMap { $0 })
        for (kind, required) in kinds {
            guard let list = raw[kind] as? [String] else { continue }
            let good = list.filter { t in
                guard t.count <= 220, !t.contains("\n") else { return false }
                for r in required where !t.contains("{\(r)}") { return false }
                // Marcadores inventados: cualquier {x} que no conozcamos.
                var scan = Substring(t)
                while let open = scan.firstIndex(of: "{") {
                    guard let close = scan[open...].firstIndex(of: "}") else { break }
                    let name = String(scan[scan.index(after: open)..<close])
                    if !allowed.contains(name) { return false }
                    scan = scan[scan.index(after: close)...]
                }
                return true
            }
            if !good.isEmpty { out[kind] = good }
        }
        return out
    }

    /// El binario real de Claude Code, no el envoltorio de cmux: el envoltorio
    /// inyecta hooks y el asistente terminaria anunciando a su propio generador.
    private static func claudeBinary() -> String? {
        let candidates = [
            homeURL.appendingPathComponent(".local/bin/claude").path,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/Applications/cmux.app/Contents/Resources/bin/claude",
        ]
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    /// Pide un lote nuevo. Corre en segundo plano; si falla, no pasa nada:
    /// se sigue usando lo que haya.
    func regenerate(_ reason: String, done: ((Bool) -> Void)? = nil) {
        guard !generating else { return }
        guard let bin = Voice.claudeBinary() else {
            plog("voz: no encuentro el binario de claude")
            done?(false)
            return
        }
        generating = true
        plog("voz: generando frases nuevas (\(reason)) con \(bin)")

        DispatchQueue.global(qos: .background).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: bin)
            p.arguments = ["-p", "--model", "sonnet", "--output-format", "text", Voice.prompt]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            p.standardInput = FileHandle.nullDevice   // sin esto espera stdin y avisa

            var ok = false
            do {
                try p.run()
                // Perro guardian: una generacion no puede colgarse para siempre.
                let deadline = DispatchTime.now() + 240
                let q = DispatchQueue.global(qos: .background)
                q.asyncAfter(deadline: deadline) { if p.isRunning { p.terminate() } }

                let data = out.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()

                if let text = String(data: data, encoding: .utf8),
                   let i = text.firstIndex(of: "{"), let j = text.lastIndex(of: "}"), i < j,
                   let obj = (try? JSONSerialization.jsonObject(
                        with: Data(text[i...j].utf8))) as? [String: Any] {
                    let valid = Voice.validate(obj)
                    // Exigir cobertura: media voz es peor que ninguna.
                    if valid.count == Voice.kinds.count,
                       valid.values.allSatisfy({ $0.count >= 3 }) {
                        try? JSONSerialization
                            .data(withJSONObject: obj, options: [.prettyPrinted])
                            .write(to: self.url, options: .atomic)
                        DispatchQueue.main.async { self.templates = valid }
                        plog("voz: \(valid.values.reduce(0) { $0 + $1.count }) plantillas nuevas")
                        ok = true
                    } else {
                        plog("voz: lote incompleto (\(valid.count)/\(Voice.kinds.count) clases), lo descarto")
                    }
                } else {
                    plog("voz: la respuesta no traia JSON usable")
                }
            } catch {
                plog("voz: no pude ejecutar claude: \(error)")
            }

            DispatchQueue.main.async {
                self.generating = false
                done?(ok)
            }
        }
    }

    /// El guion. Vive aqui dentro para que el binario no dependa de archivos externos.
    static let prompt = """
    Eres el guionista de un asistente de escritorio con forma de droide \
    astromecánico que vive flotando sobre la pantalla de un programador. \
    Habla español neutro.

    Genera plantillas de frases para sus avisos. Devuelve SOLO un objeto JSON, \
    sin texto alrededor y sin bloque de código.

    Claves obligatorias y sus marcadores permitidos (escríbelos EXACTAMENTE así):

    - "agentDone":    {agent} {where}          el agente terminó su turno
    - "commandDone":  {cmd} {time} {where}     un comando largo terminó bien
    - "commandError": {cmd} {code} {where}     un comando falló
    - "attention":    {agent} {what} {where}   el agente necesita al humano
    - "working":      {agent} {doing} {time} {where}   reporte de avance
    - "portUp":       {port} {where}           un puerto empezó a escuchar
    - "portDown":     {port} {where}           un puerto se cerró
    - "greeting":     (ninguno)                saludo al arrancar

    Cada clave debe tener un arreglo de 8 plantillas distintas entre sí.

    Qué contiene cada marcador:
    - {agent} nombre propio: "Claude", "Codex".
    - {cmd} un comando de shell: "./gradlew build".
    - {time} una duración ya formateada: "1 min 34 s".
    - {code} un número de exit code: "1".
    - {port} un número de puerto: "3000".
    - {doing} una frase con gerundio: "corriendo comandos", "editando archivos".
    - {what} un sustantivo: "un permiso para usar Bash", "una pregunta".
    - {where} YA TRAE la preposición incluida (" en Fineract") o viene vacío.

    Reglas estrictas:
    1. Cada plantilla empieza con una onomatopeya de droide entre asteriscos, \
    variada: *bip-bip*, *whirr*, *bzzzt*, *blip*, *dwoo-weep*, *clic-clic*, \
    *brrrp*, *skreee*. Que combine con el tono: alegre al terminar, chirriante \
    al fallar.
    2. Una sola oración, o dos muy cortas. Máximo 110 caracteres sin contar marcadores.
    3. Un solo párrafo. Sin saltos de línea. Sin listas.
    4. CERO emojis. Solo texto.
    5. Usa TODOS los marcadores de su clave, cada uno al menos una vez, tal cual.
    6. No inventes marcadores nuevos.
    7. Pega {where} directo después de una palabra, nunca escribas "en {where}".
    8. Tono: servicial, seco, con carácter. Nunca sonar como un log de sistema. \
    Humor leve de droide, sin chistes largos.
    """
}

/// Lo que sabemos de un agente vivo. Se arma con los hooks: el turno arranca con
