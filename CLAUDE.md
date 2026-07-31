# CLAUDE.md — router del repositorio

Asistente flotante para [cmux](https://cmux.com): un droide que vive sobre la
pantalla y avisa qué hacen tus agentes y comandos. macOS, Swift, sin dependencias.

## Antes de empezar una sesión

1. Leer `claude-progress.md` — estado verificado y próximo paso.
2. Leer `EXECUTION-PLAN.md` — qué está en vuelo y qué ya se entregó (no re-trabajar).
3. Según la tarea, leer **una** de estas y no todas:
   - toco el dibujo o la animación → `ARCHITECTURE.md` §Vistas
   - toco eventos de cmux → `ARCHITECTURE.md` §Fuentes + `docs/reference/cmux-events.md`
   - toco los textos → `docs/adr/0002`
   - decido si avisar o callar → `docs/adr/0004`
4. Al cerrar: actualizar `claude-progress.md` con la checklist del final de ese archivo.

## Comandos

```bash
make verify     # el gate: build + tests Swift + tests de hooks de zsh
make render     # dibuja cada estado a PNG en ./render para revisarlo a ojo
make run        # arranca en primer plano
make install    # instala en ~/.cmux-pet y engancha el shell
make log        # sigue ~/.cmux-pet/pet.log
```

`make verify` es el juez. Si pasa, el cambio es candidato; si no pasa, no existe.

## Límites duros

1. **Nunca `boundingRect` + `draw(with:)` en la misma vista.** Divergen y cortan
   texto. Usar `layoutText(...)`. Ver `docs/adr/0003`.
2. **Nunca suprimir avisos por workspace.** Solo por pane exacto. Ver `docs/adr/0004`.
3. **Nunca llamar a un modelo en el camino de un aviso.** La voz son plantillas
   pregeneradas. Ver `docs/adr/0002`.
4. **Nunca asumir que el texto de una notificación viene en el evento.** Llega
   redactado; se pide por `cmux rpc notification.list`.
5. **Nunca usar `tool_input` de los hooks.** Viene redactado. Solo hay `tool_name`.
6. **Nunca invocar el `claude` del PATH para generar la voz.** Es el envoltorio de
   cmux e inyecta hooks: el droide se anunciaría a sí mismo en bucle. Usar el
   binario real y filtrar eventos por `_ppid`.
7. **Nunca depender de launchd para el arranque.** El socket de cmux rechaza
   procesos que no descienden de cmux. Ver `docs/adr/0001`.
8. **Nunca bloquear el hilo principal con `cmuxJSON`.** Es sincrónico: va en
   `DispatchQueue.global`.
9. **Nunca escribir al disco del usuario desde el repo.** Todo el estado vive en
   `~/.cmux-pet`, que crea el instalador.
10. **Nunca dejar que un fallo sea silencioso.** Si el socket rechaza o el stream
    muere, el droide lo dice en pantalla. Un asistente mudo parece funcionar.
11. **Cero emojis** en código, mensajes, commits y documentación.
12. **Nunca crear carpetas de feature vacías** por simetría con la plantilla.

## Verificar en vez de recordar

Este repo se construyó depurando cuatro hipótesis falsas seguidas. La regla que
salió de ahí: **una afirmación sin comando que la respalde no entra a un
documento.** Si no se pudo verificar, se marca con ⚠️ y fecha.

Para lo visual, `make render` es la forma de verificar: escribe un PNG por estado
sin abrir ventana, y se puede mirar. No hace falta pedirle capturas al usuario.

## Mapa del código

| Ruta | Qué vive ahí |
|---|---|
| `Sources/cmux-pet/main.swift` | arranque, señales, modo `--render`. Delgado a propósito |
| `Sources/CmuxPetKit/Support/` | rutas, puente con el CLI de cmux, formateo |
| `Sources/CmuxPetKit/Model/` | `Mood`, `Bubble`, `AgentActivity`, `PetConfig` |
| `Sources/CmuxPetKit/Voice/` | `Droid` (estática) y `Voice` (generada) |
| `Sources/CmuxPetKit/Views/` | droide, burbuja, panel de estado, sprites |
| `Sources/CmuxPetKit/Controller/` | orquestador, dividido por fuente de eventos |
| `shell/pet.zsh` | hooks `preexec`/`precmd` y autoarranque |
| `docs/adr/` | decisiones durables. Insert-once: no se editan |
| `docs/features/` | una carpeta por feature en curso |

## Convenciones

- Commits: Conventional Commits, imperativo y minúsculas
  (`feat(voice): validar marcadores de plantillas`).
- Ramas: `<tipo>/<descripcion-corta-en-kebab>`.
- Comentarios: explican **por qué**, nunca qué. Si el comentario parafrasea la
  línea siguiente, se borra.
- Español en documentación y comentarios; inglés en identificadores de código.
