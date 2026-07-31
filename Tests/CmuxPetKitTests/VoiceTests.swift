// La validacion de plantillas es la defensa contra un lote malo de Claude Code.
// Si esto se rompe, el droide puede acabar mostrando "{time}" en pantalla.

import XCTest
@testable import CmuxPetKit

final class VoiceTests: XCTestCase {
    /// Una plantilla que usa todos sus marcadores obligatorios sobrevive.
    func testAceptaPlantillaCompleta() {
        let raw: [String: Any] = [
            "commandError": ["*bzzzt* {cmd} falló con código {code}{where}."],
        ]
        let out = Voice.validate(raw)
        XCTAssertEqual(out["commandError"]?.count, 1)
    }

    /// Le falta {code}: rellenarla dejaria un aviso incompleto.
    func testRechazaMarcadorFaltante() {
        let raw: [String: Any] = [
            "commandError": ["*bzzzt* {cmd} falló{where}."],
        ]
        XCTAssertNil(Voice.validate(raw)["commandError"])
    }

    /// {usuario} no existe: quedaria literal en pantalla.
    func testRechazaMarcadorInventado() {
        let raw: [String: Any] = [
            "commandError": ["*bzzzt* {cmd} falló con {code}{where}, {usuario}."],
        ]
        XCTAssertNil(Voice.validate(raw)["commandError"])
    }

    /// La burbuja es de un solo parrafo: un salto de linea rompe el layout.
    func testRechazaSaltoDeLinea() {
        let raw: [String: Any] = [
            "greeting": ["*bip*\nhola"],
        ]
        XCTAssertNil(Voice.validate(raw)["greeting"])
    }

    /// Un lote mezclado conserva solo lo bueno en vez de descartar todo.
    func testConservaLasBuenasYDescartaLasMalas() {
        let raw: [String: Any] = [
            "portUp": [
                "*blip* puerto {port} escuchando{where}.",
                "*blip* un puerto se abrió.",                 // sin marcadores
                "*whirr* {port} en línea{where}, listo.",
            ],
        ]
        XCTAssertEqual(Voice.validate(raw)["portUp"]?.count, 2)
    }

    /// greeting no lleva marcadores: no debe exigirse ninguno.
    func testGreetingSinMarcadores() {
        let raw: [String: Any] = ["greeting": ["*bip-bip* aquí estoy."]]
        XCTAssertEqual(Voice.validate(raw)["greeting"]?.count, 1)
    }

    /// Toda clase declarada debe tener sus marcadores dentro del conjunto permitido,
    /// o el prompt y el validador estarian desalineados.
    func testMarcadoresDeclaradosSonCoherentes() {
        let permitidos = Set(Voice.kinds.values.flatMap { $0 })
        for (kind, required) in Voice.kinds {
            for r in required {
                XCTAssertTrue(permitidos.contains(r), "\(kind) exige {\(r)} desconocido")
            }
        }
    }

    /// El prompt que se le manda a Claude Code debe nombrar todas las clases;
    /// si se agrega una clase y no se actualiza el prompt, nunca llegan plantillas.
    func testElPromptCubreTodasLasClases() {
        for kind in Voice.kinds.keys {
            XCTAssertTrue(Voice.prompt.contains("\"\(kind)\""),
                          "el prompt no menciona la clase \(kind)")
        }
    }
}
