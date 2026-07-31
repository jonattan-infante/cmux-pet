# EXECUTION-PLAN.md

Plan maestro. **Un estado solo avanza con evidencia**: un comando que se pueda
correr, un archivo que se pueda abrir, o una salida pegada. Sin evidencia, el
estado es "por verificar".

Última revisión: **2026-07-31**

## P0 — Baseline

| # | Cosa | Estado | Evidencia |
|---|---|---|---|
| P0.1 | El paquete compila | verde | `swift build` → `Build complete!` |
| P0.2 | Tests de lógica pura | verde | `swift test` → 52 tests, 0 fallos |
| P0.3 | Tests de hooks de zsh | verde | `./scripts/test-shell-hooks.sh` → 8 ok, salida 0 |
| P0.3b | Tests del instalador | verde | `./scripts/test-installer.sh` → 12 ok, salida 0 |
| P0.3c | Integridad del repo | verde | `./scripts/test-repo-integrity.sh` → 13 ok, salida 0 |
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
| Formato de pet pack con validación en la frontera | 21 tests en `PetPackTests`: rutas con `..`, colores, sprites, semver, schema |
| Marketplace: índice JSON, `search` e `install` desde registro, git o ruta local | `registry.json` + 9 tests en `RegistryTests`, dos de ellos validan el registro publicado |
| Dos mascotas incluidas que solo difieren en personalidad | mismo aviso: astro dice "*bzzzt* … Algo no cuadra", gatito dice "… No fui yo" |
| Voz por mascota generada desde `persona.md` | `~/.cmux-pet/voices/gatito.json`, 64 plantillas con voz felina, sin tocar código |
| CLI de mascotas: list, use, info, install, uninstall, new, validate, voice, search | probados a mano sobre la máquina real; salida pegada en claude-progress |
| Cambio de mascota en caliente desde el menú | `switchPet` reactiva tema y voz sin reiniciar el proceso |
| Instalador y desinstalador probados de punta a punta | `./install.sh --from-source` sobre la máquina real: 1 instancia, aviso real entregado. Desinstalación cubierta por 12 casos en sandbox |

## En vuelo

| # | Cosa | Estado | Próximo paso concreto |
|---|---|---|---|
| F1 | Mascotas con arte propio | el renderer `sprites` funciona, pero ningún pack incluido lo usa | hacer un pack de ejemplo con sprites, aunque sean formas simples, para que se vea el camino |
| F2 | Más renderers integrados | solo hay `vector:droid` | un pack sin arte solo puede verse como droide; ver B10 |

## Riesgos

| # | Riesgo | Impacto | Mitigación actual |
|---|---|---|---|
| R1 | Si se cierra el pane que lanzó el asistente, el proceso queda hijo de launchd; un respawn del stream sería rechazado por el socket | pierde eventos en silencio | `--reconnect` mantiene la conexión original; `noteStreamExit` avisa en pantalla si el stream muere dos veces seguidas. **Sin verificar en la práctica** ⚠️ 2026-07-31 |
| R2 | El formato de eventos de cmux puede cambiar entre versiones | el asistente deja de reportar | `docs/reference/cmux-events.md` documenta lo verificado con fecha y versión; el fallo es visible, no silencioso |
| R3 | La generación de voz consume cuota del usuario | molestia | una llamada cada 7 días; se puede apagar borrando `voice.json` y no regenerando |
| R4 | `PetController+Events.swift` tiene 314 líneas y crece con cada tipo de evento | difícil de navegar | dividir por categoría si pasa de ~400 (B4) |
| R5 | Un pack del marketplace trae arte de un personaje con dueño | problema legal para el autor y para el índice | regla explícita en `docs/marketplace.md`, revisión en el PR, y se quita del índice al detectarlo. **Depende de revisión humana** ⚠️ 2026-07-31 |
| R6 | Un pack malicioso apunta sprites fuera de su carpeta | leer archivos del usuario | `..` prohibido en rutas, cubierto por test. Un pack no ejecuta código: solo aporta texto e imágenes |
| R7 | El registro crece y el `git clone --depth 1` por install se vuelve costoso | instalación lenta | hoy son 2 entradas; si crece, cachear o servir tarballs (B11) |

## Backlog

Ordenado por relación valor/esfuerzo, no por antojo.

| # | Cosa | Por qué | Esfuerzo |
|---|---|---|---|
| B10 | Más renderers integrados (`vector:gato`, `vector:blob`) | hoy un pack sin arte solo puede verse como droide, aunque hable como gato | medio |
| B11 | Página del marketplace con capturas de cada mascota | el índice JSON no deja ver cómo se ven; una galería sí | medio |
| B1 | Sonido opcional por estado | un aviso visual en la esquina se pierde si miras otra pantalla | bajo |
| B2 | Click derecho en el panel de estado → saltar a ese agente | el panel ya sabe el workspace de cada uno | bajo |
| B3 | Recarga en caliente de `config.json` | hoy hay que reiniciar para cambiar `narrateEverySeconds` | bajo |
| B4 | Dividir `PetController+Events.swift` por categoría | ver R4 | bajo |
| B5 | Soporte de otros shells (bash, fish) | hoy solo zsh; bash necesita `trap DEBUG` + `PROMPT_COMMAND` | medio |
| B6 | Migrar a concurrencia estricta de Swift 6 | hoy el paquete fija `swiftLanguageVersions: [.v5]` | medio |
| B7 | Avisos comentados por el modelo con los datos reales | más gracia, pero cuesta latencia; ver `docs/adr/0002` | medio |
| B8 | Fórmula de Homebrew | `brew install` es lo que espera la gente | medio |
| B9 | Empaquetar como `.app` firmada | necesario si algún día se distribuye fuera de GitHub | alto |
