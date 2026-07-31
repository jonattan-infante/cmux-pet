# claude-progress.md

**Leer esto primero.** El agente olvida entre sesiones; el repo no.

---

## Estado verificado

Fecha: **2026-07-31**

El asistente funciona de punta a punta y está instalado en la máquina del autor.
El repositorio se acaba de crear a partir del prototipo que vivía en
`~/.cmux-pet/src/main.swift` (un solo archivo de 2195 líneas), dividido en 20
archivos con tests.

Baseline verde, verificado con comandos:

```
swift build                    -> Build complete!
swift test                     -> 18 tests, 0 fallos
./scripts/test-shell-hooks.sh  -> 8 ok, salida 0
./.build/debug/cmux-pet --version -> cmux-pet 0.1.0
make render                    -> 8 PNG en ./render
```

## Próximo paso

**Decidir si se publica el repo.** Todo está listo para eso:

- `install.sh` ya apunta a `https://github.com/jonattan-infante/cmux-pet.git`.
  Si el nombre o el dueño cambian, hay que actualizar `REPO_URL` ahí y las URLs
  del README.
- El workflow de CI está escrito pero **nunca ha corrido** (marcado ⚠️ en el
  plan). Correrá en el primer push; si falla, lo más probable es la versión de
  macOS del runner.
- Falta un GIF o captura en `assets/` para el README. Se puede generar con
  `make render`, pero una captura de la ventana real necesita permiso de Grabación
  de Pantalla, que el proceso automatizado no tiene.

Después de eso, el backlog está ordenado por valor/esfuerzo en `EXECUTION-PLAN.md`.
Los tres primeros (B1 sonido, B2 click en el panel, B3 recarga de config) son de
esfuerzo bajo.

## Historial

| Fecha | Qué pasó |
|---|---|
| 2026-07-31 | Prototipo: droide vectorial, burbuja de terminal, cuatro fuentes de eventos, voz generada, seguimiento en vivo. Todo en un archivo |
| 2026-07-31 | Diagnóstico del fallo "no llegan las notificaciones": tres causas, la principal fue el socket de cmux rechazando procesos de launchd (`docs/adr/0001`) |
| 2026-07-31 | Empaquetado: SPM con librería + ejecutable, 20 archivos, 18 tests, 8 tests de shell, instalador, harness |

## Trampas que ya costaron tiempo

No volver a caer en estas. Todas están documentadas con evidencia en
`docs/reference/cmux-events.md` y en los ADR.

1. **Un fallo silencioso parece éxito.** El asistente arrancaba y dibujaba, pero
   no recibía nada. Se perdió tiempo en tres hipótesis falsas (buffering del CLI,
   bug del pipe, variables de entorno) antes de encontrar el rechazo del socket.
   Ahora el rechazo se muestra en pantalla.
2. **Medir con `boundingRect` y dibujar con `draw(with:)`** corta la última línea.
   Ver `docs/adr/0003`.
3. **`pkill -f <patrón>` mata el propio shell** si el patrón aparece en su línea de
   comandos. Pasó dos veces durante el desarrollo.
4. **Los hooks de cmux llegan duplicados** (`received` y `completed`).
5. **El texto de las notificaciones y de `tool_input` viene redactado.**
6. **`NSImageView` como subvista no aparece en `cacheDisplay`**, así que el modo
   `--render` salía vacío con sprites. Se cambió a dibujo directo, que además
   permitió animar GIF con el mismo reloj.

## Checklist de fin de sesión

Antes de cerrar, sin excepciones:

- [ ] `make verify` verde
- [ ] Si cambió algo visual: `make render` y **mirar** los PNG
- [ ] Si cambió una decisión durable: ADR nuevo en `docs/adr/` (insert-once, no se
      editan los existentes)
- [ ] Si cambió el comportamiento de cara al usuario: README y `PRODUCT.md`
- [ ] `EXECUTION-PLAN.md`: mover lo terminado a "Entregado" **con evidencia**
- [ ] Actualizar "Estado verificado" y "Próximo paso" de este archivo
- [ ] Working tree limpio o el pendiente anotado arriba
