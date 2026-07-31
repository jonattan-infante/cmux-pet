# ARCHITECTURE.md

Cómo está construido cmux-pet. Router, no enciclopedia: cada sección apunta al
archivo donde vive el detalle.

## Idea central

cmux ya sabe todo lo que pasa: qué agente trabaja, qué herramienta usa, qué
puerto se abrió. Lo publica en un stream de eventos y en un socket de control.
cmux-pet **no observa el sistema**: solo traduce lo que cmux ya dice a una cara y
una frase.

```
┌─────────────────────────────────────────────────────────────┐
│  cmux                                                       │
│    events (JSON line-delimited)   rpc (socket de control)   │
└───────────┬─────────────────────────────┬───────────────────┘
            │                             │
      ┌─────▼─────────────────────────────▼──────┐
      │  PetController                           │
      │    correlaciona sesiones y workspaces    │
      │    decide si avisar o callar             │
      └───┬──────────────┬───────────────┬───────┘
          │              │               │
     ┌────▼────┐   ┌─────▼─────┐   ┌─────▼──────┐
     │ PetView │   │ BubbleView│   │ RosterView │
     │ el cuerpo│  │ el aviso  │   │ el estado  │
     └─────────┘   └───────────┘   └────────────┘
                          ▲
                    ┌─────┴─────┐
                    │ Voice     │  plantillas escritas por Claude Code
                    │ Droid     │  respaldo estático
                    └───────────┘
```

## Dominios y dirección de dependencias

Las flechas solo apuntan hacia abajo. Una violación es un error de diseño, no un
detalle.

```
main.swift            (arranque, señales, --render)
     │
     ▼
Controller/           (orquesta; conoce Views, Model, Voice, Support)
     │
     ├──────────────┬──────────────┐
     ▼              ▼              ▼
Views/          Voice/          Model/
(conoce Model   (conoce         (no conoce
 y Support)      Support)        a nadie)
     │              │
     └──────┬───────┘
            ▼
        Support/      (rutas, CLI de cmux, formateo)
```

- **`Model/` no importa AppKit** salvo `Mood`, que define la paleta. Es la única
  excepción y es deliberada: el color es parte del significado del estado.
- **`Views/` nunca llama a cmux.** Si una vista necesita un dato, lo recibe.
- **`Support/CmuxCLI` es el único lugar que ejecuta `cmux`.** Todo control pasa
  por ahí.

## Las cuatro fuentes

Cada una tiene su archivo en `Controller/`.

| Fuente | Mecanismo | Qué aporta | Archivo |
|---|---|---|---|
| Eventos de cmux | subproceso `cmux events --reconnect`, lectura por líneas | agentes: arrancan, terminan, piden permiso; foco de pane; notificaciones | `PetController+Events.swift` |
| RPC de cmux | `cmux rpc <método>` sincrónico en cola de fondo | texto real de notificaciones, títulos de workspace, puertos escuchando | `PetController+Sources.swift` |
| Shell del usuario | hooks zsh que hacen append a `shell.jsonl`; la app hace tail | comandos largos y exit codes | `shell/pet.zsh` + `PetController+Sources.swift` |
| Reloj | timers | narración periódica, barrida de sesiones fantasma | `PetController+Bubbles.swift` |

Por qué un archivo plano para el shell y no un socket o un FIFO: un append nunca
bloquea el prompt del usuario. Un FIFO sin lector bloquea al abrir, y un socket
implica un servidor. El precio de la simplicidad es un poll de 400 ms, que es
gratis.

## Límites duros del diseño

1. Un solo camino de layout de texto: `layoutText(...)`. Ver `docs/adr/0003`.
2. Un solo lugar decide el tamaño y la posición del panel: `PetController.layout()`.
   Burbuja y panel de estado comparten ese hueco; el hover manda.
3. La supresión de avisos es por pane exacto. Ver `docs/adr/0004`.
4. Ninguna llamada a un modelo en el camino de un aviso. Ver `docs/adr/0002`.
5. `Voice` valida todo lo que entra. Un lote incompleto se descarta entero.
6. El respaldo estático (`Droid`) siempre existe: el asistente no puede quedar mudo.
7. El estado de agentes se barre a los 10 minutos sin señal: un `Stop` perdido no
   puede dejar fantasmas en el panel.
8. `PetView.hitTest` devuelve nil fuera del cuerpo, y `ContainerView.hitTest`
   devuelve nil en las zonas transparentes. Sin eso la ventana se comería los
   clicks de la app de abajo.
9. El panel es `NSPanel` con `canBecomeKey = false`: nunca le roba el teclado a
   la terminal.
10. Todo el estado en disco vive en `~/.cmux-pet`. El repo no escribe ahí.

## Preocupaciones transversales

| Tema | Punto de entrada |
|---|---|
| Trazas y diagnóstico | `plog(...)` en `Support/Paths.swift`; sale a `~/.cmux-pet/pet.log` |
| Ejecutar cmux | `cmuxJSON(...)` (espera respuesta) y `cmuxFire(...)` (dispara y olvida) |
| Rutas en disco | `PetPaths` |
| Textos de cara al usuario | `Voice.phrase(...)` con respaldo `Droid.say(...)` |
| Verificación visual | `renderShowcase(to:)`, expuesto como `--render` |

## Lo que NO hay, a propósito

- **Sin dependencias externas.** Solo AppKit y Foundation. Un asistente de
  escritorio que arrastra un árbol de paquetes no se instala.
- **Sin bundle .app.** Es un ejecutable que se registra como `.accessory`. No
  necesita icono, ni Info.plist, ni firma para funcionar en la máquina del dueño.
- **Sin ventana de preferencias.** `config.json` y el menú contextual alcanzan.
- **Sin base de datos.** El estado vivo es memoria; lo que persiste son dos JSON.
- **Sin telemetría.** Nada sale de la máquina salvo la llamada a Claude Code que
  el propio usuario dispara.
