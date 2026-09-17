# claude-progress.md

**Leer esto primero.** El agente olvida entre sesiones; el repo no.

---

## Estado verificado

Fecha: **2026-09-17**

El proyecto es una **plataforma de mascotas con dos runtimes**: macOS en Swift y
Windows en Python (`windows/`). Desde esta sesión la **versión es del producto**
(`VERSION` = `0.2.0`) y **la mascota avisa una vez cuando hay una versión publicada
más nueva**, con el mismo contrato en las dos plataformas
(`docs/reference/versioning.md`, `docs/adr/0006`).

Baseline verde, verificado con comandos en la rama
`feat/versiones-y-aviso-de-actualizacion`:

```
make verify                          -> compila + 84 tests Swift + 8 hooks + 12 instalador
                                        + 15 integridad + 11 mascotas + 51 tests Python
./.build/debug/cmux-pet --version    -> cmux-pet 0.2.0
python3 windows/pet.py --version     -> cmux-pet 0.2.0
./.build/debug/cmux-pet update --check -> "sin versiones publicadas todavía", salida 0
actionlint release.yml               -> limpio
```

Guarda de versión probada en negativo: con `__init__.py` en `0.1.0`,
`test-repo-integrity.sh` dice
`FALLA la version diverge: VERSION=0.2.0 swift=0.2.0 python=0.1.0 changelog=0.2.0`.

El aviso, de punta a punta en la máquina real, con
`CMUX_PET_UPDATE_URL=file://…/latest.json` (`{"tag_name":"v9.9.9"}`):

```
[14:12:23Z] aviso: [info] *dwoo-weep* Reactivada. A vigilar tus procesos.
[14:12:53Z] actualizaciones: hay 9.9.9, corre 0.2.0
[14:12:53Z] aviso: [info] Hay una versión nueva de cmux-pet: 9.9.9. Corre: cmux-pet update
~/.cmux-pet/update.json -> { "announced": "9.9.9", "checkedAt": "2026-09-17T14:12:53Z", "latest": "9.9.9" }
segundo arranque                -> 0 avisos de actualización (ver abajo)
```

Ese primer aviso salió con el texto neutro del programa porque el pack instalado
en `~/.cmux-pet/pets/` era la copia anterior, sin la clase `updateAvailable`.
Tras `./install.sh --from-source` (binario y packs en 0.2.0, máquina del autor),
la misma prueba lo dijo con la voz de la mascota activa:

```
[14:14:53Z] mascota activa: Astro (astro) v1.1.0, renderer vector:droid
[14:15:23Z] actualizaciones: hay 9.9.9, corre 0.2.0
[14:15:23Z] aviso: [info] *bip-bip* Hay una versión nueva de cmux-pet: 9.9.9. Solicito actualización de firmware.
```

La máquina del autor quedó con `cmux-pet 0.2.0` instalado desde esta rama y sin
`update.json` (se borró al terminar la prueba para que la primera consulta real
ocurra sola).

**`v0.2.0` está publicado.** `make tag` empujó el tag y `release.yml` corrió por
primera vez en verde (run 35236336097): release con el tarball de macOS y su
sha256. `cmux-pet update --check` contra GitHub real:

```
cmux-pet 0.2.0
Estás en la última versión publicada.
```

Desde entonces hay **reglas de tags** (`docs/reference/tags.md`): anotado, firmado
con SSH, notas del CHANGELOG en el mensaje, desde `main`, inmutable. Las verifica
`scripts/check-tag.sh` (19 casos en `test-release-tooling.sh`, dentro del gate),
`make tag` antes de empujar y `release.yml` antes de publicar. Un ruleset en GitHub
(`tags de version`, id 23606182) impide crear, mover o borrar `v*` sin rol de
administrador. La firma SSH está configurada solo en este repo
(`git config gpg.format ssh`, llave `~/.ssh/id_ed25519_github.pub`) y probada con
un tag local que se borró sin empujar.

`v0.2.0` es anterior a las reglas (sin notas ni firma) y por inmutabilidad se
queda así.

## Próximo paso

**Que el primer `make tag` bajo las reglas sea `v0.3.0`** (F4): probará la firma,
las notas en el mensaje, `check-tag.sh` en CI y el bypass del ruleset. Antes,
registrar la llave como signing key en GitHub (B14) para que aparezca "Verified":

```
gh auth refresh -h github.com -s admin:ssh_signing_key
gh ssh-key add ~/.ssh/id_ed25519_github.pub --type signing --title "firma de tags"
```

Después: probar `python pet.py --selftest` con `CMUX_PET_UPDATE_URL` en una máquina
Windows real (R9), y marcar el job `port de Windows` como check obligatorio (B13).

## Historial

| Fecha | Qué pasó |
|---|---|
| 2026-07-31 | Prototipo: droide vectorial, burbuja de terminal, cuatro fuentes de eventos, voz generada, seguimiento en vivo. Todo en un archivo de 2195 líneas |
| 2026-07-31 | Diagnóstico de "no llegan las notificaciones": tres causas, la principal el socket de cmux rechazando procesos de launchd (`docs/adr/0001`) |
| 2026-07-31 | Empaquetado: SPM librería + ejecutable, 20 archivos, tests, instalador, harness. CI encontró un archivo que el `.gitignore` excluía |
| 2026-07-31 | Pivote a plataforma: pet packs, marketplace, CLI de mascotas, voz por personalidad (`docs/adr/0005`) |
| 2026-08-02 | Comandos `sprite` y `fork`; renderers `vector:ball` y `vector:sage`; port de Windows en Python (PRs #2, #3, #4) |
| 2026-09-17 | La versión es del producto: `VERSION`, guarda de integridad, release por tag, instalador al último release, y aviso de versión nueva con el mismo contrato en macOS y Windows (`docs/adr/0006`) |
| 2026-09-17 | Primer release: `v0.2.0`. README reescrito. Reglas de tags con `check-tag.sh`, `next-version`, `release-notes`, firma SSH y ruleset en GitHub (`docs/reference/tags.md`) |

## Trampas que ya costaron tiempo

No volver a caer en estas. Todas están documentadas con evidencia en
`docs/reference/` y en los ADR.

1. **Un fallo silencioso parece éxito.** El asistente arrancaba y dibujaba, pero
   no recibía nada. Tres hipótesis falsas antes de encontrar el rechazo del socket.
   Ahora el rechazo, y la falta de mascota, se muestran en pantalla.
2. **Medir con `boundingRect` y dibujar con `draw(with:)`** corta la última línea.
   Ver `docs/adr/0003`.
3. **Un patrón de `.gitignore` sin barra inicial aplica a cualquier nivel.**
   `render/` excluyó `Sources/CmuxPetKit/Render/`. Lo cubre
   `scripts/test-repo-integrity.sh`.
4. **`pkill -f <patrón>` mata el propio shell** si el patrón aparece en su línea de
   comandos. Pasó dos veces.
5. **Un test que depende del entorno pasa en local y falla en CI.** `pgrep` sin
   coincidencias devuelve 1 y con `pipefail` mata el script.
6. **`#"..."#` se cierra en el `"#"` de un color hex.** Para JSON con colores en un
   test, hace falta `##"..."##`.
7. **Los hooks de cmux llegan duplicados** (`received` y `completed`).
8. **El texto de las notificaciones y de `tool_input` viene redactado.**
9. **`NSImageView` como subvista no aparece en `cacheDisplay`**, así que
   `--render` salía vacío con sprites. Se cambió a dibujo directo, que además
   permitió animar GIF con el mismo reloj.
10. **Una funcionalidad que solo existe en un runtime no es del producto.** El
    aviso de actualización se pidió "global, sin depender de la plataforma": el
    contrato va en `docs/reference/` y cada runtime lo implementa con los mismos
    casos de prueba. Y el gate tiene que cubrir los dos: hasta esta sesión los
    tests de Windows no corrían ni en `make verify` ni en CI.
11. **`Config` de Windows descarta claves desconocidas.** Una preferencia nueva que
    no esté en `DEFAULTS` se pierde en el siguiente `save()`.
12. **El remote no tenía refspec de fetch** (`remote.origin.fetch` vacío), así que
    `origin/main` no existía en local y `git fetch` solo movía `FETCH_HEAD`. Se
    arregló con `git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'`.
    `make tag` depende de `origin/main`.
13. **`git branch -d` no borra una rama mergeada por squash**: para git no está
    "fully merged". Es `-D`, tras comprobar que el PR entró.

## Checklist de fin de sesión

Antes de cerrar, sin excepciones:

- [ ] `make verify` verde
- [ ] Si cambió algo visual: `make render` y **mirar** los PNG
- [ ] Si cambió el formato de pack: actualizar `docs/reference/pet-pack.md`, que es
      el contrato, y revisar que las dos mascotas incluidas sigan validando
- [ ] Si cambió una decisión durable: ADR nuevo en `docs/adr/` (insert-once)
- [ ] Si cambió el comportamiento de cara al usuario: README y `PRODUCT.md`
- [ ] Si cambió un contrato de `docs/reference/`: los dos runtimes y sus dos tests
- [ ] `EXECUTION-PLAN.md`: mover lo terminado a "Entregado" **con evidencia**
- [ ] Actualizar "Estado verificado" y "Próximo paso" de este archivo
- [ ] Working tree limpio o el pendiente anotado arriba
