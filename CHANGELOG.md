# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Versionado semántico.

## [0.2.2] — 2026-09-17

### Corregido

- `release.yml` fallaba en `check-tag.sh` con "es un tag ligero" para todo tag
  real: GitHub Actions entrega el ref del tag apuntando al commit que señala,
  no al objeto tag anotado, así que `git cat-file -t` lo veía como ligero. Se
  agrega `git fetch --tags --force origin` tras el checkout, antes de
  verificar. Encontrado publicando `v0.2.1`.

## [0.2.1] — 2026-09-17

**No se publicó.** El tag existe en GitHub, anotado y firmado, pero
`release.yml` falló antes de crear el release por el bug de arriba. La versión
efectiva es `0.2.2`; este tag se queda como está, sin borrarse
(`docs/reference/tags.md`).

### Agregado

- Reglas de los tags en `docs/reference/tags.md`, verificadas por
  `scripts/check-tag.sh` antes de empujar y por CI antes de publicar: anotado,
  firmado, con las notas del CHANGELOG en el mensaje, desde `main`, inmutable.
- `make next-version` y `make release-notes`: proponen la versión y el borrador
  de notas a partir de los commits (Conventional Commits).
- Ruleset en GitHub que impide crear, mover o borrar tags `v*` sin el rol de
  administrador.

### Cambiado

- `make tag` firma el tag con SSH y pone las notas del CHANGELOG en el mensaje.

### Documentación

- Las reglas de tags son obligatorias para cualquier agente de IA que trabaje
  en el repositorio, con sección propia en `CLAUDE.md`, no solo una mención.

## [0.2.0] — 2026-09-17

### Agregado

- **La versión es del producto.** `VERSION` en la raíz es la fuente única; el
  binario de macOS y el paquete de Python llevan una copia que
  `scripts/bump-version.sh` mantiene y que el gate de integridad compara.
- **Publicación por tag.** Empujar `vX.Y.Z` crea el GitHub Release con las notas
  de este archivo, tras verificar que tag, `VERSION` y CHANGELOG coinciden.
  `make tag` hace el paso humano desde `main`.
- **La mascota avisa cuando hay una versión nueva**, en macOS y en Windows: una
  consulta al día como máximo, fuera del hilo principal, y un solo aviso por
  versión. Se apaga con `checkUpdates: false`. Estado en `~/.cmux-pet/update.json`.
- Clase de frase `updateAvailable` con marcador `{version}`, en el contrato de
  voz y en las cuatro mascotas incluidas.
- `cmux-pet update` (macOS) reinstala la última versión publicada;
  `cmux-pet update --check` solo compara. En Windows, `python install.py --update`
  mueve el checkout al tag publicado y `python pet.py --version` dice cuál corre.
- El instalador de macOS clona la última versión publicada en vez de `main`;
  `CMUX_PET_VERSION` fija una versión o la rama.
- Comandos `sprite` para ponerle imagen a una mascota (`--dir`, `--clear`) y
  `fork` para sacar una copia editable de una incluida.
- Renderers integrados `vector:ball` y `vector:sage`, además de `vector:droid`;
  `cmux-pet renderers` los lista.
- Mascotas incluidas `cangrejo` y `llama`, con sprites propios.
- Port para Windows en `windows/`: observa Claude Code por sus hooks, reusa los
  mismos packs y el mismo contrato de voz. Sus tests entran a `make verify` y a CI.

### Cambiado

- La sección "Actualizar" del README explica el aviso y cómo actualizar en cada
  plataforma.

## [0.1.0] — 2026-07-31

Primera versión.

### Agregado

- Droide astromecánico vectorial con seis estados distinguibles, dibujado con
  Core Graphics. Sin imágenes ni dependencias.
- Sprites propios del usuario desde `~/.cmux-pet/sprites/`, con GIF animado.
- Avisos estilo terminal: monoespaciados, un párrafo, escritos letra por letra
  con cursor de bloque.
- Voz generada por Claude Code local sin API key, como plantillas validadas, con
  respaldo estático.
- Seguimiento en vivo de agentes: panel al pasar el mouse, narración periódica y
  línea de estado en el menú.
- Cuatro fuentes de eventos: stream de cmux, RPC de cmux, hooks de zsh y reloj.
- Avisos de comandos largos y fallidos, con denylist de comandos interactivos.
- Avisos de puertos que empiezan y dejan de escuchar.
- Click para saltar al workspace del aviso.
- Modo `--render`: escribe un PNG por estado sin abrir ventana, para revisar el
  dibujo desde CI o desde un agente.
- Instalador de un comando y desinstalador que conserva las preferencias.
