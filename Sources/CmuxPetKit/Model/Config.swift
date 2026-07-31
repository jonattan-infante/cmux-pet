// Preferencias persistentes en ~/.cmux-pet/config.json

import Foundation

struct PetConfig: Codable {
    var x: Double? = nil
    var y: Double? = nil
    var quiet: Bool = false
    var watchPorts: Bool = true
    var scale: Double = 1.0
    /// Avisar de comandos del pane que estas mirando en este momento. Por defecto no: seria ruido.
    var notifyWhileWatching: Bool = false
    /// Cada cuanto cuenta en que van los agentes mientras trabajan. 0 lo apaga.
    var narrateEverySeconds: Double = 150

    static func load() -> PetConfig {
        guard let d = try? Data(contentsOf: configURL),
              let c = try? JSONDecoder().decode(PetConfig.self, from: d)
        else { return PetConfig() }
        return c
    }

    func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? enc.encode(self).write(to: configURL, options: .atomic)
    }
}
