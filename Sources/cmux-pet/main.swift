// Punto de entrada. Deliberadamente delgado: solo arranque, modo --render y
// manejo de senales. Toda la logica vive en CmuxPetKit para que sea testeable.

import AppKit
import CmuxPetKit
import Foundation

// Los DispatchSource de senales mueren si nadie los retiene.
var signalSources: [DispatchSourceSignal] = []

PetPaths.ensureHome()

// `cmux-pet --render <dir>` escribe un PNG por estado sin abrir ventana.
// Es la forma de revisar el dibujo en CI o desde un agente.
if let i = CommandLine.arguments.firstIndex(of: "--render") {
    _ = NSApplication.shared
    let out = i + 1 < CommandLine.arguments.count
        ? URL(fileURLWithPath: CommandLine.arguments[i + 1])
        : PetPaths.home.appendingPathComponent("render")
    renderShowcase(to: out)
    exit(0)
}

if CommandLine.arguments.contains("--version") {
    print("cmux-pet \(cmuxPetVersion)")
    exit(0)
}

takeOverPidFile()

let app = NSApplication.shared
let controller = PetController()
app.delegate = controller

// launchd o un reinicio manual mandan SIGTERM: hay que llevarse al hijo por delante.
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler {
        controller.shutdown()
        exit(0)
    }
    src.resume()
    signalSources.append(src)
}

app.run()
