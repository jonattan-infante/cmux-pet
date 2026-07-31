# EXECUTION-PLAN.md

Plan maestro. **Un estado solo avanza con evidencia**: un comando que se pueda
correr, un archivo que se pueda abrir, o una salida pegada. Sin evidencia, el
estado es "por verificar".

Última revisión: **2026-07-31**

## P0 — Baseline

| # | Cosa | Estado | Evidencia |
|---|---|---|---|
| P0.1 | El paquete compila | verde | `swift build` → `Build complete!` |
| P0.2 | Tests de lógica pura | verde | `swift test` → 18 tests, 0 fallos |
| P0.3 | Tests de hooks de zsh | verde | `./scripts/test-shell-hooks.sh` → 8 ok, salida 0 |
| P0.3b | Tests del instalador | verde | `./scripts/test-installer.sh` → 12 ok, salida 0 |
| P0.4 | El binario arranca y responde | verde | `./.build/debug/cmux-pet --version` → `cmux-pet 0.1.0` |
| P0.5 | El dibujo se puede revisar sin pantalla | verde | `make render` → 6 PNG de estado + `todos.png` + `panel.png` |
| P0.6 | Working tree limpio | verde | repo recién creado, primer commit |

## Entregado — no re-trabajar

| Cosa | Evidencia |
|---|---|
| Droide vectorial con 6 estados distinguibles | `make render`, revisado a ojo en `render/todos.png` |
| Sprites propios del usuario, con GIF animado | probado sustituyendo `default.png`: el vector desaparece y escala bien |
| Burbuja estilo terminal con escritura letra por letra | `render/burbuja-*.png` en dos avances de escritura |
| Voz generada por Claude Code local, sin API key | `~/.cmux-pet/voice.json`, 64 plantillas, log: `voz cargada: agentDone=8 …` |
| Respaldo estático cuando no hay `voice.json` | primera narración del log usó `Droid`, antes de que terminara la generación |
| Seguimiento en vivo: panel al hover, narración, línea de menú | log: `aviso: [working] *whirr* 3 unidades trabajando: …` |
| Comandos de shell largos y fallos | log: `*bzzzt* npm run build falló con código 1 en Fineract` |
| Puertos que suben y bajan | diff contra `listening_ports` de `cmux rpc workspace.list` |
| Texto real de notificaciones vía RPC | probado con `cmux notify`: la burbuja mostró título y cuerpo |
| Click salta al workspace del aviso | `cmux select-workspace --workspace <uuid>` → `OK workspace:2` |
| Arranque por shell con acceso al socket | ver `docs/adr/0001`; probado: 1 instancia tras abrir dos shells |
| Fallos de socket visibles en pantalla | `noteStreamError` / `noteStreamExit` con burbuja pegajosa |
| Deduplicación de hooks duplicados (`received` + `completed`) | log antes: 2 avisos por evento; después: 1 |
| Barrida de sesiones fantasma a los 10 min | `sweepStaleActivities()`, traza `barrida: N sesión(es) sin señal` |
| Instalador y desinstalador probados de punta a punta | `./install.sh --from-source` sobre la máquina real: 1 instancia, aviso real entregado. Desinstalación cubierta por 12 casos en sandbox |

## En vuelo

| # | Cosa | Estado | Próximo paso concreto |
|---|---|---|---|
| F1 | Publicar el repo | listo local, sin publicar | el dueño decide si lo sube; ya hay `install.sh` apuntando a la URL final |
| F2 | CI en GitHub Actions | escrito, sin ejecutar ⚠️ 2026-07-31 | correrá en el primer push; `make render` queda fuera del gate (requiere sesión gráfica) |

## Riesgos

| # | Riesgo | Impacto | Mitigación actual |
|---|---|---|---|
| R1 | Si se cierra el pane que lanzó el asistente, el proceso queda hijo de launchd; un respawn del stream sería rechazado por el socket | pierde eventos en silencio | `--reconnect` mantiene la conexión original; `noteStreamExit` avisa en pantalla si el stream muere dos veces seguidas. **Sin verificar en la práctica** ⚠️ 2026-07-31 |
| R2 | El formato de eventos de cmux puede cambiar entre versiones | el asistente deja de reportar | `docs/reference/cmux-events.md` documenta lo verificado con fecha y versión; el fallo es visible, no silencioso |
| R3 | La generación de voz consume cuota del usuario | molestia | una llamada cada 7 días; se puede apagar borrando `voice.json` y no regenerando |
| R4 | `PetController+Events.swift` tiene 314 líneas y crece con cada tipo de evento | difícil de navegar | dividir por categoría si pasa de ~400 (B4) |

## Backlog

Ordenado por relación valor/esfuerzo, no por antojo.

| # | Cosa | Por qué | Esfuerzo |
|---|---|---|---|
| B1 | Sonido opcional por estado | un aviso visual en la esquina se pierde si miras otra pantalla | bajo |
| B2 | Click derecho en el panel de estado → saltar a ese agente | el panel ya sabe el workspace de cada uno | bajo |
| B3 | Recarga en caliente de `config.json` | hoy hay que reiniciar para cambiar `narrateEverySeconds` | bajo |
| B4 | Dividir `PetController+Events.swift` por categoría | ver R4 | bajo |
| B5 | Soporte de otros shells (bash, fish) | hoy solo zsh; bash necesita `trap DEBUG` + `PROMPT_COMMAND` | medio |
| B6 | Migrar a concurrencia estricta de Swift 6 | hoy el paquete fija `swiftLanguageVersions: [.v5]` | medio |
| B7 | Avisos comentados por el modelo con los datos reales | más gracia, pero cuesta latencia; ver `docs/adr/0002` | medio |
| B8 | Fórmula de Homebrew | `brew install` es lo que espera la gente | medio |
| B9 | Empaquetar como `.app` firmada | necesario si algún día se distribuye fuera de GitHub | alto |
