# CLAUDE.md — router del repositorio

Plataforma de mascotas de escritorio para [cmux](https://cmux.com). El programa
decide **cuándo** hablar; un paquete instalable decide **cómo se ve y cómo habla**.
macOS, Swift, sin dependencias.

## Antes de empezar una sesión

1. Leer `claude-progress.md` — estado verificado y próximo paso.
2. Leer `EXECUTION-PLAN.md` — qué está en vuelo y qué ya se entregó (no re-trabajar).
3. Según la tarea, leer **una** de estas y no todas:
   - toco el formato de paquete → `docs/reference/pet-pack.md` (es el contrato)
   - toco el marketplace → `docs/marketplace.md`
   - toco el dibujo o la animación → `ARCHITECTURE.md` §Vistas
   - toco eventos de cmux → `ARCHITECTURE.md` §Fuentes + `docs/reference/cmux-events.md`
   - toco los textos o la voz → `docs/adr/0002` y `docs/adr/0005`
   - decido si avisar o callar → `docs/adr/0004`
4. Al cerrar: actualizar `claude-progress.md` con la checklist del final de ese archivo.

## Comandos

```bash
make verify     # el gate: build + tests Swift + hooks de zsh + instalador + integridad
make render     # dibuja cada estado de la mascota activa a PNG en ./render
make run        # arranca en primer plano
make install    # instala en ~/.cmux-pet, con las mascotas incluidas
make log        # sigue ~/.cmux-pet/pet.log
```

Comandos de mascota (el producto, no el build):

```bash
cmux-pet list                     # instaladas, con la activa marcada
cmux-pet use <id>                 # cambiar de mascota
cmux-pet search [texto]           # buscar en el marketplace
cmux-pet install <id|url|ruta>    # instalar; --use la activa, --force reemplaza
cmux-pet new <id> [--sprites]     # crear un paquete nuevo, ya válido
cmux-pet fork <origen> <nuevo>    # copia editable de una mascota existente
cmux-pet sprite <id> <estado> <f> # ponerle imagen; --dir <carpeta>, --clear
cmux-pet validate <ruta>          # revisar un paquete y explicar cada fallo
cmux-pet voice [<id>]             # que Claude Code le escriba las frases
cmux-pet info <id>
cmux-pet uninstall <id>
```

`make verify` es el juez. Si pasa, el cambio es candidato; si no pasa, no existe.

## Límites duros

1. **Un pack nunca inventa un estado.** Los seis (`idle`, `working`, `done`,
   `error`, `attention`, `info`) son del programa: el orquestador no sabría cuándo
   usar uno nuevo. Ver `docs/adr/0005`.
2. **`PetPack.load` es la frontera del sistema.** Lo escribe un tercero: nada de
   rutas con `..`, colores sin validar ni sprites que no existan.
3. **Nunca editar un pack marcado `.bundled`.** Se reemplaza al actualizar y el
   trabajo del usuario se perdería sin aviso: primero `fork`. Todo cambio al
   manifiesto se revalida y se revierte si dejaría el paquete inválido.
4. **Las frases generadas van a `~/.cmux-pet/voices/<id>.json`, nunca dentro del
   pack.** Actualizar un pack no puede borrarlas.
5. **El prompt se compone**: personalidad del pack + contrato del programa. No
   meter personalidad en el código ni contrato en el pack.
6. **Toda mascota tiene respaldo.** `phrases.json` o las frases de `Scaffold`. La
   mascota no puede quedar muda.
7. **Nunca `boundingRect` + `draw(with:)` en la misma vista.** Divergen y cortan
   texto. Usar `layoutText(...)`. Ver `docs/adr/0003`.
8. **Nunca suprimir avisos por workspace.** Solo por pane exacto. Ver `docs/adr/0004`.
9. **Nunca llamar a un modelo en el camino de un aviso.** Ver `docs/adr/0002`.
10. **Nunca asumir que el texto de una notificación viene en el evento.** Llega
   redactado; se pide por `cmux rpc notification.list`.
11. **Nunca usar `tool_input` de los hooks.** Viene redactado. Solo hay `tool_name`.
12. **Nunca invocar el `claude` del PATH para generar la voz.** Es el envoltorio
    de cmux e inyecta hooks: la mascota se anunciaría a sí misma en bucle. Usar el
    binario real y filtrar eventos por `_ppid`.
13. **Nunca depender de launchd para el arranque.** El socket de cmux rechaza
    procesos que no descienden de cmux. Ver `docs/adr/0001`.
14. **Nunca bloquear el hilo principal con `cmuxJSON`.** Es sincrónico: va en
    `DispatchQueue.global`.
15. **Nunca escribir al disco del usuario desde el repo.** Todo el estado vive en
    `~/.cmux-pet`.
16. **Nunca dejar que un fallo sea silencioso.** Sin mascota instalada, sin socket
    o sin frases, se dice en pantalla.
17. **Nunca arte de personajes con dueño**, ni en los packs incluidos ni aceptado
    en el marketplace.
18. **Cero emojis** en código, mensajes, commits y documentación.
19. **Nunca crear carpetas de feature vacías** por simetría con la plantilla.

## Verificar en vez de recordar

Este repo se construyó depurando cuatro hipótesis falsas seguidas, y CI encontró
un archivo que el `.gitignore` excluía. La regla que salió de ahí: **una afirmación
sin comando que la respalde no entra a un documento.** Si no se pudo verificar, se
marca con ⚠️ y fecha.

Para lo visual, `make render` es la forma de verificar: escribe un PNG por estado
de la mascota activa, sin abrir ventana. No hace falta pedirle capturas al usuario.

Para un paquete, `cmux-pet validate` explica cada fallo. Úsalo antes de afirmar
que un pack está bien.

## Mapa del código

| Ruta | Qué vive ahí |
|---|---|
| `Sources/cmux-pet/main.swift` | arranque, señales, `--render`, despacho de subcomandos |
| `Sources/CmuxPetKit/Model/PetPack.swift` | el formato de paquete y su validación |
| `Sources/CmuxPetKit/Model/PetLibrary.swift` | instaladas, activa, instalar, quitar |
| `Sources/CmuxPetKit/Model/Mood.swift` | los seis estados y `PetTheme` |
| `Sources/CmuxPetKit/CLI/` | subcomandos, scaffolding y registro del marketplace |
| `Sources/CmuxPetKit/Voice/` | frases de la mascota activa y composición del prompt |
| `Sources/CmuxPetKit/Views/` | renderer vectorial, sprites, burbuja, panel de estado |
| `Sources/CmuxPetKit/Controller/` | orquestador, dividido por fuente de eventos |
| `Sources/CmuxPetKit/Support/` | rutas, puente con el CLI de cmux, formateo |
| `pets/` | mascotas incluidas: `astro` y `gatito` |
| `registry.json` | el índice del marketplace |
| `shell/pet.zsh` | hooks `preexec`/`precmd` y autoarranque |
| `docs/adr/` | decisiones durables. Insert-once: no se editan |
| `docs/reference/` | contratos: formato de paquete y eventos de cmux |

## Convenciones

- **`main` está protegido**: nada entra sin PR y sin los cuatro checks en verde.
  Ni el dueño puede empujar directo. Flujo: rama, `make verify`, `gh pr create`,
  `gh pr merge --auto --squash`.
- Commits: Conventional Commits, imperativo y minúsculas
  (`feat(packs): validar rutas de sprites`).
- Ramas: `<tipo>/<descripcion-corta-en-kebab>`.
- Comentarios: explican **por qué**, nunca qué. Si el comentario parafrasea la
  línea siguiente, se borra.
- Español en documentación, comentarios y textos de usuario; inglés en
  identificadores de código.
