// Voz estatica de respaldo: siempre disponible, sin depender de nada.

import Foundation

enum Droid {
    static func beep(_ mood: Mood) -> String {
        switch mood {
        case .done:      return "bip-bip"
        case .error:     return "bzzzt"
        case .attention: return "bip! bip!"
        case .working:   return "whirr"
        case .info:      return "blip"
        case .idle:      return "bip"
        }
    }

    private static let closers: [Mood: [String]] = [
        .done: ["Todo en orden.", "Sin novedades.", "Listo para lo que sigue.", "Trabajo completado."],
        .error: ["Algo no cuadra.", "Revisa eso.", "No salió como esperabas.", "Necesita tu atención."],
        .attention: ["Te está esperando.", "No avanza sin ti.", "Requiere tu confirmación."],
        .info: [],
        .working: [],
        .idle: [],
    ]

    /// Arma la frase completa. `closer` en falso para mensajes que ya se explican solos.
    static func say(_ mood: Mood, _ body: String, closer: Bool = true) -> String {
        var s = "*\(beep(mood))* " + body
        if closer, let opts = closers[mood], !opts.isEmpty, let c = opts.randomElement() {
            s += " " + c
        }
        return s
    }

    /// " en Fineract" o cadena vacia si no sabemos donde.
    static func at(_ workspace: String) -> String {
        workspace.isEmpty ? "" : " en \(workspace)"
    }

    /// Traduce la herramienta a lo que el agente esta haciendo de verdad.
    /// `tool_input` viene redactado en los eventos, asi que el nombre de la
    /// herramienta es todo lo que hay: sirve para el verbo, no para el detalle.
    static func activity(_ tool: String?) -> String {
        switch tool ?? "" {
        case "Bash", "BashOutput", "KillShell":        return "corriendo comandos"
        case "Edit", "Write", "MultiEdit", "NotebookEdit": return "editando archivos"
        case "Read":                                    return "leyendo código"
        case "Grep", "Glob":                            return "buscando en el código"
        case "WebFetch", "WebSearch":                   return "consultando la web"
        case "Task", "Agent":                           return "delegando a subagentes"
        case "Skill":                                   return "usando una skill"
        case "AskUserQuestion":                         return "esperando tu respuesta"
        case "TodoWrite", "TaskCreate", "TaskUpdate":   return "organizando el plan"
        case "Artifact":                                return "publicando un artifact"
        case "":                                        return "arrancando"
        default:                                        return "usando \(tool ?? "")"
        }
    }
}
