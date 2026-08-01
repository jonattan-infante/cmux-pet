# claude-progress.md

**Leer esto primero.** El agente olvida entre sesiones; el repo no.

---

## Estado verificado

Fecha: **2026-07-31**

El proyecto ya no es "un droide": es una **plataforma de mascotas**. El programa
decide cuándo hablar y en qué estado está; un paquete instalable decide cómo se ve
y cómo habla. El marketplace es un JSON en el repo, sin servidor.

Baseline verde, verificado con comandos:

```
make verify                       -> compila + 52 tests + 8 hooks + 12 instalador + 13 integridad + 7 mascotas
./.build/debug/cmux-pet --version -> cmux-pet 0.1.0
make render                       -> 15 PNG en ./render
./install.sh --from-source        -> instalado y corriendo en la maquina del autor
CI                                -> 5 jobs verdes, incluida la validacion del marketplace
```

El asistente que corre en la máquina del autor es **el binario que produce este
repo**, con `gatito` como mascota activa.

La prueba de que la plataforma es genérica, del log real:

```
mascota activa: Gatito (gatito) v1.0.0, renderer vector:droid
aviso: [info]  Mrrp. Estoy aquí, supongo que vigilando.
aviso: [error] npm run build se rompió, código 1 en Fineract. No fui yo.
```

Y `cmux-pet voice gatito` produjo 64 frases con voz felina desde `persona.md`, sin
tocar una línea de Swift:

```
{cmd} explotó{where}, código {code}, fffs. Vuelvo a mi caja.
{agent} lleva {time} {doing}{where}. Yo llevo el mismo tiempo sin moverme del sol.
```

## Próximo paso

**Un pack de ejemplo con sprites reales** (F1 en el plan). Hoy el renderer
`sprites` está implementado y probado con un test, pero ninguna de las dos
mascotas incluidas lo usa, así que nadie ve el camino completo. Bastan seis
imágenes simples, incluso formas geométricas, con licencia clara.

Después, en orden de valor/esfuerzo: B10 (más renderers vectoriales, porque hoy un
pack sin arte solo puede verse como droide aunque hable como gato) y B11 (galería
del marketplace con capturas).

Pendiente que no bloquea: falta un GIF o captura en el README. `make render`
genera los PNG de los estados, pero capturar la ventana real necesita permiso de
Grabación de Pantalla que un proceso automatizado no tiene.

## Historial

| Fecha | Qué pasó |
|---|---|
| 2026-07-31 | Prototipo: droide vectorial, burbuja de terminal, cuatro fuentes de eventos, voz generada, seguimiento en vivo. Todo en un archivo de 2195 líneas |
| 2026-07-31 | Diagnóstico de "no llegan las notificaciones": tres causas, la principal el socket de cmux rechazando procesos de launchd (`docs/adr/0001`) |
| 2026-07-31 | Empaquetado: SPM librería + ejecutable, 20 archivos, tests, instalador, harness. CI encontró un archivo que el `.gitignore` excluía |
| 2026-07-31 | Pivote a plataforma: pet packs, marketplace, CLI de mascotas, voz por personalidad (`docs/adr/0005`) |

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

## Checklist de fin de sesión

Antes de cerrar, sin excepciones:

- [ ] `make verify` verde
- [ ] Si cambió algo visual: `make render` y **mirar** los PNG
- [ ] Si cambió el formato de pack: actualizar `docs/reference/pet-pack.md`, que es
      el contrato, y revisar que las dos mascotas incluidas sigan validando
- [ ] Si cambió una decisión durable: ADR nuevo en `docs/adr/` (insert-once)
- [ ] Si cambió el comportamiento de cara al usuario: README y `PRODUCT.md`
- [ ] `EXECUTION-PLAN.md`: mover lo terminado a "Entregado" **con evidencia**
- [ ] Actualizar "Estado verificado" y "Próximo paso" de este archivo
- [ ] Working tree limpio o el pendiente anotado arriba
