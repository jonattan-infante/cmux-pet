# Fuentes de eventos: el contrato `EventSource`

Contrato del producto, no de una plataforma ni de una fuente concreta. Lo
implementan `Sources/LucyGlowKit/Controller/EventSource.swift` (protocolo +
`NormalizedEvent`) del lado de macOS, y — a partir de la generalización de
`Tailer` en Windows — `windows/lucy_win/events.py` del lado de Python. Decisión
y motivos: `docs/adr/0008`.

Antes de este contrato, cada fuente (cmux, hooks de Claude Code) estaba
cableada directo al orquestador de su plataforma. Agregar una fuente nueva
(OpenCode, wmux) es agregar una clase que la implemente, no tocar el
orquestador.

## Reparto de responsabilidad

| | Le toca a la fuente (`EventSource`) | Le toca al orquestador |
|---|---|---|
| Transporte | subproceso, pipe, archivo — el que sea | nada, nunca lo ve |
| Reconexión | la política es suya (reintentos, backoff) | nada |
| Traducción | protocolo crudo → `NormalizedEvent` | nada |
| Filtros del transporte | p.ej. el anti-bucle por `_ppid` de cmux | nada |
| Mood | **nunca** | siempre — los 6 del programa |
| Texto de burbuja | **nunca** | siempre — `Voice.shared.phrase` + respaldo |
| Throttle/debounce de producto | **nunca** | siempre (los `3 s`/`600 s` ya existentes) |
| Reportar su propia falla | `onUnavailable(mensaje)`, nunca en silencio | decide si avisa (una vez por fuente) |

Una fuente que decide un mood o compone una frase rompe este contrato tan
seguro como un pack que lo haga (ver regla 1 de `CLAUDE.md` y `docs/adr/0002`
para la misma separación aplicada a la voz).

## El vocabulario normalizado

Reutiliza los nombres de hook de Claude Code que Python ya normalizaba antes
de este contrato, más lo que hoy solo aporta cmux:

| Nombre | Origen | Campos propios |
|---|---|---|
| `SessionStart`, `SessionEnd`, `UserPromptSubmit` | hook de agente | — |
| `PreToolUse` | hook de agente | `tool` |
| `PostToolUse` | hook de agente (Windows/OpenCode; cmux no lo emite hoy) | `tool`, `exitCode` |
| `Stop`, `SubagentStop` | hook de agente (`SubagentStop`: igual que `PostToolUse`) | — |
| `Notification` | cualquier fuente, enriquecido si puede | `reason: permission \| question \| generic`, `tool?` |
| `ShellCommand` | shell interactivo (solo macOS/zsh hoy) | `command`, `seconds`, `exitCode` |
| `SurfaceFocused` | solo cmux hoy | `surfaceId` |
| `WorkspaceSelected` | solo cmux hoy | `workspaceId` |
| `WorkspaceTaskSubmitted` | solo cmux hoy | `messagePreview` |
| `NotificationCreated` | solo cmux hoy (RPC de `notification.list`) | `messagePreview` (ya compuesto) |

`Notification` es deliberadamente un solo nombre con un `reason` opcional en
vez de tres: `agent.hook.PermissionRequest`/`AskUserQuestion` son categorías
propias de **cmux**, no hooks nativos de Claude Code (no están en el `KNOWN`
de `windows/lucy_win/events.py`). Windows logra la misma distinción
adivinando por texto en `state.py:_what()`. Cualquier fuente nueva que sepa
distinguir "pide permiso" de "hace una pregunta" llena `reason` con
precisión; la que no sepa, usa `generic`.

`ShellCommand` y las cuatro categorías "solo cmux hoy" son diferencias de
plataforma reales, no brechas a cerrar — se documentan así en vez de forzar
una fuente a inventar algo que no tiene.

⚠️ `PostToolUse` y `SubagentStop` no aparecen en el catálogo verificado de
`docs/reference/cmux-events.md` — `CmuxEventSource` no los emite hasta
reverificar que cmux los reenvía bajo `--category agent`.

## Esquema de campos

```
source        : string   -- "cmux" | "claude-hooks-file" | "opencode" | "wmux"
name          : uno de la tabla de arriba
sessionId     : string?  -- clave de correlación de actividad
workspaceId   : string?  -- opaco: el orquestador solo agrupa y resuelve titulo
surfaceId     : string?  -- solo si la fuente identifica el pane exacto
agent         : string?  -- lo decide la fuente ("Claude", "OpenCode", ...)
tool          : string?
exitCode      : int?
command       : string?
seconds       : double?
messagePreview: string?
reason        : permission | question | generic (default generic)
occurredAt    : fecha
```

## Reglas de fallo

1. Una fuente que no puede arrancar (binario ausente, archivo no escribible,
   pipe inexistente) llama a `onUnavailable` con un texto ya listo para
   mostrarse; el orquestador lo enseña una sola vez por fuente
   (`warnedSources`, generaliza el `warnedAboutSocket` de antes de este
   contrato).
2. Una fuente que muere después de arrancar reintenta con su propia
   política. Si revive y muere rápido dos veces seguidas, también escala a
   `onUnavailable`.
3. Ninguna fuente puede tumbar a otra ni al orquestador: un fallo en una no
   detiene a las demás.
4. Ninguna fuente bloquea el hilo principal — el trabajo de I/O va a
   background (`DispatchQueue.global` en Swift; no bloquear el tick de Tk en
   Python).
5. Si el orquestador termina con cero fuentes activas, avisa una vez
   ("No tengo ninguna fuente de eventos activa.") en vez de quedarse mudo.

## Para verificar

`Tests/LucyGlowKitTests/CmuxEventSourceTests.swift` y
`ShellHookEventSourceTests.swift` prueban `translate(_:)` de cada fuente
contra payloads literales, sin lanzar ningún proceso.
`PetControllerIngestTests.swift` prueba `ingest(_:)` con `NormalizedEvent`
sintéticos y una fuente falsa (`FakeEventSource`), incluido el caso de cero
fuentes activas y el aviso único por fuente caída.
