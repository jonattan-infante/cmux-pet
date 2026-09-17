// Rutas del asistente y utilidades base.

import Foundation

public let lucyGlowVersion = "0.3.0"

let fm = FileManager.default
let homeURL = fm.homeDirectoryForCurrentUser

/// Todo el estado en disco vive bajo ~/.lucy. El repo nunca escribe ahi:
/// el instalador lo crea y la app lo mantiene.
public enum PetPaths {
    public static let home = FileManager.default
        .homeDirectoryForCurrentUser.appendingPathComponent(".lucy")

    public static var config: URL { home.appendingPathComponent("config.json") }
    public static var voice: URL { home.appendingPathComponent("voice.json") }
    public static var shellLog: URL { home.appendingPathComponent("shell.jsonl") }
    public static var pid: URL { home.appendingPathComponent("pet.pid") }
    public static var sprites: URL { home.appendingPathComponent("sprites") }
    /// Misma forma en macOS y Windows: ver docs/reference/versioning.md.
    public static var update: URL { home.appendingPathComponent("update.json") }

    /// El nombre viejo del producto (cmux-pet) escribia aqui. Migrar en vez de
    /// empezar de cero: nadie deberia perder su configuracion, sus mascotas o
    /// sus frases generadas solo porque el producto cambio de nombre.
    static var legacyHome: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cmux-pet")
    }

    public static func ensureHome() {
        if !FileManager.default.fileExists(atPath: home.path),
           FileManager.default.fileExists(atPath: legacyHome.path) {
            try? FileManager.default.moveItem(at: legacyHome, to: home)
            plog("migrado ~/.cmux-pet -> ~/.lucy (cmux-pet ahora se llama LucyGlow)")
        }
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }
}

let petHome = PetPaths.home
let configURL = PetPaths.config
let shellLogURL = PetPaths.shellLog
let pidURL = PetPaths.pid

/// Traza a stderr. Bajo el arranque normal termina en ~/.lucy/pet.log y es
/// el primer lugar donde mirar cuando un aviso no llega.
func plog(_ s: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    if let d = "[\(stamp)] \(s)\n".data(using: .utf8) {
        FileHandle.standardError.write(d)
    }
}

/// Instancia unica: si habia otra corriendo, se le pide que salga y tomamos el relevo.
public func takeOverPidFile() {
    if let s = try? String(contentsOf: PetPaths.pid, encoding: .utf8),
       let old = Int32(s.trimmingCharacters(in: .whitespacesAndNewlines)),
       old != getpid(), kill(old, 0) == 0 {
        kill(old, SIGTERM)
        usleep(400_000)
    }
    try? "\(getpid())".write(to: PetPaths.pid, atomically: true, encoding: .utf8)
}
