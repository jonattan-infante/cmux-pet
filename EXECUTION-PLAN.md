# EXECUTION-PLAN.md

Plan maestro. **Un estado solo avanza con evidencia**: un comando que se pueda
correr, un archivo que se pueda abrir, o una salida pegada. Sin evidencia, el
estado es "por verificar".

Última revisión: **2026-09-17**

## P0 — Baseline

| # | Cosa | Estado | Evidencia |
|---|---|---|---|
| P0.1 | El paquete compila | verde | `swift build` → `Build complete!` |
| P0.2 | Tests de lógica pura | verde | `swift test` → 52 tests, 0 fallos |
| P0.3 | Tests de hooks de zsh | verde | `./scripts/test-shell-hooks.sh` → 8 ok, salida 0 |
| P0.3b | Tests del instalador | verde | `./scripts/test-installer.sh` → 12 ok, salida 0 |
| P0.3c | Integridad del repo | verde | `./scripts/test-repo-integrity.sh` → 13 ok, salida 0 |
| P0.3d | Mascotas y marketplace | verde | `./scripts/test-pet-packs.sh` → 11 ok, salida 0. Probado que detecta: pack roto, versión desincronizada e id duplicado |
| P0.3e | Port de Windows | verde | `make test-windows` → 51 tests, 0 fallos (2026-09-17); job `port de Windows` en CI, en `windows-latest` |
| P0.3f | La versión es una sola | verde | `./scripts/test-repo-integrity.sh` → `ok version 0.2.0 en VERSION, Paths.swift, __init__.py y CHANGELOG`; probado en negativo: con `__init__.py` en 0.1.0 dice `FALLA la version diverge` |
| P0.8 | `main` protegido | verde | push directo → `remote rejected (protected branch hook declined)`, verificado con `enforce_admins: true` |
| P0.7 | CI en GitHub Actions | verde | 5 jobs en verde el 2026-07-31: build en macos-14 y macos-15, shell, mascotas, vista previa |
| P0.4 | El binario arranca y responde | verde | `./.build/debug/cmux-pet --version` → `cmux-pet 0.2.0`; `python3 windows/pet.py --version` → `cmux-pet 0.2.0` |
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
| Versión del producto con fuente única y guarda | `VERSION` + `scripts/bump-version.sh`; la integridad compara cuatro sitios y falla en negativo (P0.3f) |
| Aviso de versión nueva, mismo contrato en macOS y Windows | `docs/reference/versioning.md`; 14 tests en `UpdateTests.swift` y 17 en `test_update.py` con los mismos casos; punta a punta con `CMUX_PET_UPDATE_URL=file://…` en la máquina real: `aviso: [info] … 9.9.9` una sola vez, `update.json` con `announced` (ver claude-progress) |
| `cmux-pet update [--check]` y `python install.py --update` | `update --check` contra GitHub real → `sin versiones publicadas todavía`, salida 0. `--update` en Windows solo probado por lectura ⚠️ 2026-09-17 |
| Instalador de macOS clona el último release | `install.sh`: resuelve `tag_name` de `releases/latest`, cae a `main` y lo dice; `bash -n` ok. **Sin release publicado aún, la rama `main` es lo que instala** ⚠️ 2026-09-17 |

## En vuelo

| # | Cosa | Estado | Próximo paso concreto |
|---|---|---|---|
| F1 | Mascotas con arte propio | el renderer `sprites` funciona, pero ningún pack incluido lo usa | hacer un pack de ejemplo con sprites, aunque sean formas simples, para que se vea el camino |
| F2 | Más renderers integrados | hay `vector:droid`, `vector:ball` y `vector:sage` | portar `ball` y `sage` al Canvas de Windows |
| F3 | Primer release publicado | `release.yml` escrito y pasado por `actionlint`, **nunca ejercido** ⚠️ 2026-09-17 | con `main` al día: `make tag` para `v0.2.0`, mirar el job, y comprobar que `cmux-pet update --check` dice `Estás en la última versión publicada` |


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
| R8 | `release.yml` falla en el primer tag (permisos, `gh`, awk de las notas) | no hay release y nadie recibe el aviso; el instalador sigue en `main` | el fallo es visible en Actions; se corrige y se vuelve a etiquetar. **Por verificar con `v0.2.0`** ⚠️ 2026-09-17 |
| R9 | La burbuja de actualización en Tk (Windows) no se ha visto en una máquina Windows real | el aviso podría no mostrarse aunque la lógica esté probada | la lógica pura tiene 17 tests y `Checker` está probado con `file://`; falta `--selftest` con `CMUX_PET_UPDATE_URL` en Windows ⚠️ 2026-09-17 |

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
| B8 | Fórmula de Homebrew | `brew install` es lo que espera la gente; el release ya adjunta el tarball con su sha256 | medio |
| B12 | Que el instalador de macOS use el tarball del release en vez de compilar | instalar sin Xcode; depende de firmar (B9) | medio |
| B13 | Marcar el job `port de Windows` como check obligatorio en `main` | hoy son cuatro checks obligatorios; se cambia en Settings > Branches | bajo |
| B9 | Empaquetar como `.app` firmada | necesario si algún día se distribuye fuera de GitHub | alto |
