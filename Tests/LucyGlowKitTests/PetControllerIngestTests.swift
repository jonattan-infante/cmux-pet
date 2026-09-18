// PetController.ingest(_:) alimentado con NormalizedEvent sinteticos: nunca
// lanza cmux real. Cierra la brecha de cobertura que tenia el orquestador
// antes de este refactor (docs/reference/event-source.md, docs/adr/0008).

import XCTest
@testable import LucyGlowKit

/// Fuente de prueba: no toca disco ni procesos, solo registra si arranco/paro
/// y deja disparar eventos a mano.
final class FakeEventSource: EventSource {
    let id: String
    private(set) var started = false
    private(set) var stopped = false
    private var onEvent: ((NormalizedEvent) -> Void)?
    private var onUnavailable: ((String) -> Void)?

    init(id: String) { self.id = id }

    func start(onEvent: @escaping (NormalizedEvent) -> Void,
               onUnavailable: @escaping (String) -> Void) {
        started = true
        self.onEvent = onEvent
        self.onUnavailable = onUnavailable
    }

    func stop() { stopped = true }

    func fire(_ e: NormalizedEvent) { onEvent?(e) }
    func fail(_ msg: String) { onUnavailable?(msg) }
}

final class PetControllerIngestTests: XCTestCase {
    /// Config limpia, sin depender de lo que haya en ~/.lucy/config.json de
    /// quien corra los tests.
    func makeController() -> PetController {
        let pc = PetController()
        pc.config = PetConfig()
        return pc
    }

    // MARK: arranque de fuentes

    func testStartEventSourcesArrancaCadaUna() {
        let pc = makeController()
        let a = FakeEventSource(id: "a")
        let b = FakeEventSource(id: "b")
        pc.startEventSources([a, b])
        XCTAssertTrue(a.started)
        XCTAssertTrue(b.started)
    }

    func testCeroFuentesAvisaUnaVez() {
        let pc = makeController()
        pc.startEventSources([])
        XCTAssertEqual(pc.currentBubble?.mood, .error)
    }

    func testShutdownParaTodasLasFuentes() {
        let pc = makeController()
        let a = FakeEventSource(id: "a")
        pc.startEventSources([a])
        pc.shutdown()
        XCTAssertTrue(a.stopped)
    }

    func testUnaFuenteCaidaAvisaUnaSolaVez() {
        let pc = makeController()
        pc.noteSourceUnavailable("cmux", "boom")
        XCTAssertNotNil(pc.currentBubble)
        pc.hideBubble()
        pc.noteSourceUnavailable("cmux", "boom")
        XCTAssertNil(pc.currentBubble, "ya habia avisado de esta fuente: no debe repetirse")
    }

    // MARK: sesiones — arranca, hace algo, termina

    func testSessionStartCreaActividad() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .sessionStart, sessionId: "s1", agent: "Claude"))
        XCTAssertEqual(pc.activities["s1"]?.agent, "Claude")
    }

    func testPreToolUseActualizaLaHerramientaActual() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .sessionStart, sessionId: "s1", agent: "Claude"))
        pc.ingest(NormalizedEvent(source: "t", name: .preToolUse, sessionId: "s1", agent: "Claude", tool: "Edit"))
        XCTAssertEqual(pc.activities["s1"]?.currentTool, "Edit")
        XCTAssertEqual(pc.activities["s1"]?.toolCount, 1)
    }

    func testStopMuestraBurbujaDoneYQuitaLaActividad() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .sessionStart, sessionId: "s1", agent: "Claude"))
        pc.ingest(NormalizedEvent(source: "t", name: .stop, sessionId: "s1", agent: "Claude"))
        XCTAssertEqual(pc.currentBubble?.mood, .done)
        XCTAssertNil(pc.activities["s1"])
    }

    func testStopSinActividadPreviaNoAvisaNada() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .stop, sessionId: "fantasma", agent: "Claude"))
        XCTAssertNil(pc.currentBubble)
    }

    // MARK: atencion

    func testNotificationMuestraAtencionYSeRecuerdaLaSesion() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .notification, sessionId: "s1",
                                  agent: "Claude", reason: .generic))
        XCTAssertEqual(pc.currentBubble?.mood, .attention)
        XCTAssertTrue(pc.attentionSessions.contains("s1"))
    }

    func testNotificationNoSeRepiteAntesDeTresSegundos() {
        let pc = makeController()
        let ev = NormalizedEvent(source: "t", name: .notification, sessionId: "s1",
                                 agent: "Claude", reason: .generic)
        pc.ingest(ev)
        pc.hideBubble()
        pc.ingest(ev)
        XCTAssertNil(pc.currentBubble, "el segundo aviso llega antes de 3s: no debe repetirse")
    }

    // MARK: permiso/pregunta pendientes

    func testNotificationDePermisoConRequestIdQuedaPendiente() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .notification, sessionId: "s1", agent: "Claude",
                                  tool: "Bash", requestId: "req-1", reason: .permission))
        XCTAssertEqual(pc.pendingRequests["req-1"]?.kind, .permission)
        XCTAssertEqual(pc.pendingRequests["req-1"]?.sessionId, "s1")
        XCTAssertEqual(pc.pendingRequests["req-1"]?.tool, "Bash")
    }

    func testNotificationDePreguntaConRequestIdQuedaPendiente() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .notification, sessionId: "s1", agent: "Claude",
                                  requestId: "req-2", reason: .question))
        XCTAssertEqual(pc.pendingRequests["req-2"]?.kind, .question)
    }

    func testNotificationGenericaNoQuedaPendienteAunqueTraigaRequestId() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .notification, sessionId: "s1", agent: "Claude",
                                  requestId: "req-3", reason: .generic))
        XCTAssertTrue(pc.pendingRequests.isEmpty)
    }

    func testSweepExpiredRequestsQuitaLoViejo() {
        let pc = makeController()
        pc.pendingRequests["viejo"] = PendingRequest(requestId: "viejo", kind: .permission,
                                                      sessionId: "s1", workspaceId: nil, tool: nil,
                                                      createdAt: Date().addingTimeInterval(-200))
        pc.pendingRequests["nuevo"] = PendingRequest(requestId: "nuevo", kind: .permission,
                                                      sessionId: "s1", workspaceId: nil, tool: nil)
        pc.sweepExpiredRequests()
        XCTAssertNil(pc.pendingRequests["viejo"])
        XCTAssertNotNil(pc.pendingRequests["nuevo"])
    }

    // MARK: shell — supresion por pane

    func testComandoDeShellSeSuprimeSiMirasElPaneExacto() {
        let pc = makeController()
        pc.focusedSurface = "surf1"
        pc.isCmuxFrontmost = { true }
        pc.ingest(NormalizedEvent(source: "t", name: .shellCommand, workspaceId: nil,
                                  surfaceId: "surf1", exitCode: 0, command: "ls", seconds: 0.1))
        XCTAssertNil(pc.currentBubble)
    }

    func testComandoDeShellAvisaSiNoEstasMirandoEsePane() {
        let pc = makeController()
        pc.focusedSurface = "otro-pane"
        pc.ingest(NormalizedEvent(source: "t", name: .shellCommand, workspaceId: nil,
                                  surfaceId: "surf1", exitCode: 0, command: "ls", seconds: 0.1))
        XCTAssertEqual(pc.currentBubble?.mood, .done)
    }

    func testComandoDeShellQueFallaAvisaError() {
        let pc = makeController()
        pc.ingest(NormalizedEvent(source: "t", name: .shellCommand, exitCode: 1, command: "make", seconds: 2))
        XCTAssertEqual(pc.currentBubble?.mood, .error)
    }

    // MARK: barrida de sesiones fantasma

    func testSweepStaleActivitiesQuitaLoQueLlevaDiezMinutosSinSenal() {
        let pc = makeController()
        pc.activities["viejo"] = AgentActivity(agent: "Claude", workspaceId: nil,
                                               startedAt: Date().addingTimeInterval(-1000),
                                               lastSeen: Date().addingTimeInterval(-1000),
                                               currentTool: nil)
        pc.sweepStaleActivities()
        XCTAssertNil(pc.activities["viejo"])
    }
}
