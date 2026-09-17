# ADR 0008 — Las fuentes de eventos se agregan por adapter, no por plataforma

- **Estado:** aceptada
- **Fecha:** 2026-09-17
- **Decide:** cómo se agrega una fuente de eventos nueva sin tocar el
  orquestador de cada plataforma

## Contexto

`PetController.swift` decía "consume las cuatro fuentes de eventos" pero no
existía ninguna interfaz que las modelara: `startCmuxEventStream()` y
`startShellLogTail()` estaban cableadas directo dentro del controller, y en
Windows `app.py` mezclaba `Tailer` (hooks de Claude Code), `nowplaying.Poller`
(Spotify) y `updatemod.Checker` (red) como tres mecanismos heterogéneos sin
protocolo compartido.

El pedido: soportar fuentes nuevas — **OpenCode** (agente de código con
sistema de plugins propio) y **wmux** (fork de cmux para Windows, con su
propio protocolo) — sin fusionar Swift y Python en un solo runtime.

Tres hallazgos de la exploración cambiaron el diseño final:

1. **Swift no normalizaba; Python sí.** `handleCmuxEvent`/`handleShellEvent`
   operaban directo sobre el `[String:Any]` crudo de cmux, mientras
   `events.normalize()` en Python ya producía un esquema común.
2. **`agent.hook.PermissionRequest`/`AskUserQuestion` son categorías propias
   de cmux** (`docs/reference/cmux-events.md`), no hooks nativos de Claude
   Code (no están en el `KNOWN` de `windows/lucy_win/events.py`). Windows
   lograba la misma distinción adivinando por texto en `state.py:_what()`.
3. **`agent.hook.PostToolUse` y `agent.hook.SubagentStop` no están
   documentados como categorías que cmux reenvíe** bajo `--category agent`.

Sin cobertura: `PetController`, `+Events`, `+Sources`, `AgentActivity` y
`CmuxCLI` no tenían ningún test antes de este cambio.

## Opciones para el vocabulario

**A. Nombres neutros nuevos**, ajenos a cualquier fuente concreta. Descartada:
duplica el trabajo de traducción que Python ya tenía resuelto para los 8
hooks de Claude Code, sin ganar nada a cambio.

**B. Reusar el vocabulario de hooks de Claude Code que Python ya normaliza**,
y sumar lo que solo cmux aporta (`SurfaceFocused`, `WorkspaceSelected`,
`WorkspaceTaskSubmitted`, `NotificationCreated`) como categorías extra.
Elegida: ya está probada en producción del lado de Python, y evita inventar
un vocabulario paralelo.

## Opciones para wmux

**C. Implementar contra la documentación pública de wmux.org**, que confirma
un fork de cmux con named pipe `\\.\pipe\wmux` (JSON-RPC v2) y hooks de
Claude Code auto-registrados, pero no documenta métodos RPC, categorías de
evento ni forma de payload. Descartada: viola la sección "Verificar en vez de
recordar" de `CLAUDE.md` — implementar a ciegas dejaría un adapter que nadie
puede afirmar que funciona.

**D. Skeleton explícito, no registrado por defecto, hasta verificar el
protocolo real** contra `wmux --help` o `github.com/amirlehmam/wmux`.
Elegida: `WmuxEventSource.start()` llama `onUnavailable` y nunca `onEvent`; un
test fija ese contrato en código en vez de dejarlo como comentario que se
puede desincronizar. No hay entorno Windows real en el que verificarlo hoy.

## Decisión

Protocolo `EventSource` (Swift) / mismo contrato por duck-typing (`read_new()`
en Python) que traduce el transporte de cada fuente a un
`NormalizedEvent` común, documentado en `docs/reference/event-source.md`. El
orquestador de cada plataforma pasa de "llamar directo a cmux/al tailer" a
"sostener una lista de fuentes activas e ingerir eventos normalizados";
sigue siendo el único que decide mood, texto y throttle.

Se entrega en PRs separados: (1) contrato + refactor de Swift (cmux y shell)
sin cambio de comportamiento observable, con los tests que faltaban; (2)
generalización de Python (`Tailer` con parser inyectable, campo `agent`); (3)
OpenCode, vía un plugin-puente que LucyGlow instala y que escribe a un
archivo, tanto en macOS como en Windows; (4) wmux, como skeleton.

## Consecuencias

- **A favor:** agregar una fuente es una clase nueva que implementa
  `EventSource`, no un fork del orquestador de cada plataforma.
- **A favor:** el refactor de PR1 agrega la cobertura de test que
  `PetController`/`+Events`/`+Sources` no tenían, en vez de solo mover código.
- **En contra:** el PR1 es grande (mueve casi 500 líneas) aunque de riesgo
  bajo, porque no cambia ningún comportamiento observable.
- **Regla derivada:** una fuente de eventos nunca decide mood ni compone
  texto — eso es siempre del orquestador, sin excepción. Es la misma
  separación que `docs/adr/0002` ya aplica entre "cuándo avisar" y "qué
  dice la voz".
