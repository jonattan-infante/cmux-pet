# PRODUCT.md

## Por qué existe

Cuando trabajas con varios agentes de IA en paralelo en cmux, pierdes el hilo de
quién está haciendo qué. Los agentes terminan en workspaces que no estás mirando,
piden permiso y se quedan esperando, los builds terminan sin que te enteres. La
información existe — cmux la publica toda — pero está repartida en el sidebar, el
Feed y las notificaciones del sistema, y ninguna de esas cosas está mirándote a la
cara.

cmux-pet pone un droide sobre la pantalla que te lo dice.

## Para quién

Desarrolladores que usan cmux en macOS con uno o más agentes de IA a la vez.
El caso que lo justifica: **3 o más agentes trabajando en workspaces distintos.**
Con un solo agente en una sola pestaña, el sidebar de cmux ya alcanza.

## Qué hace

| Necesidad | Cómo la cubre |
|---|---|
| "¿ya terminó?" | avisa en cuanto un agente cierra su turno, con el workspace |
| "¿está esperándome?" | cara de alerta persistente cuando pide permiso o pregunta |
| "¿en qué van?" | panel al pasar el mouse, más narración periódica |
| "¿pasó el build?" | avisa comandos de más de 20 s y cualquier fallo |
| "¿levantó el server?" | avisa puertos que empiezan y dejan de escuchar |
| "llévame ahí" | un click salta al workspace del aviso y trae cmux al frente |

## Qué NO es

- **No es un panel de control de cmux.** No crea workspaces ni maneja paneles.
  Para eso está cmux.
- **No es un monitor del sistema.** No mira CPU, memoria ni red.
- **No es un cliente de IA.** No habla con agentes ni les manda prompts. Solo
  reporta. La única llamada a un modelo es para escribir sus propias frases.
- **No es multiplataforma.** AppKit y el socket de cmux son de macOS.
- **No reemplaza las notificaciones de cmux.** Es un canal distinto: cmux te
  notifica al sistema, el droide está siempre visible.

## Criterios de éxito

1. **No se apaga.** Si a la semana el usuario lo silencia, el producto falló. Se
   mide con la cantidad de avisos por hora: más de ~6 es ruido.
2. **Cero fallos silenciosos.** Si no puede escuchar a cmux, lo dice en pantalla.
   Un asistente mudo que parece funcionar es peor que uno ausente.
3. **Se instala en un comando** y no pide cambiar la configuración de seguridad
   de cmux.
4. **No estorba.** No roba el foco del teclado, deja pasar los clicks en sus
   zonas transparentes, y no dispara redibujados cuando no pasa nada.

## Vocabulario

Estos términos se pisan entre cmux, Claude Code y este repo. Aquí valen estas
definiciones:

| Término | Aquí significa | Ojo con |
|---|---|---|
| **workspace** | un workspace de cmux: un grupo de paneles con nombre en el sidebar | no es un workspace de VS Code ni un directorio |
| **surface** | una pestaña dentro de un panel de cmux (`CMUX_SURFACE_ID`) | cmux también dice "tab"; en el código es surface |
| **pane / panel** | la división visual que contiene surfaces | en el payload de cmux aparece como `panel` |
| **sesión** | una sesión de agente (`session_id` de los hooks) | varias sesiones pueden vivir en un mismo workspace |
| **actividad** | lo que el agente hace ahora, derivado de `tool_name` | no es el contenido: `tool_input` viene redactado |
| **tarea** | el texto del prompt que el humano escribió (`message_preview`) | es por workspace, no por sesión |
| **aviso / burbuja** | la tarjeta de terminal que aparece al lado del droide | no es una notificación de macOS |
| **panel de estado** | la tarjeta del hover con el detalle de los agentes | en el código es `RosterView` |
| **estado / mood** | idle, working, done, error, attention, info | no es el `workspace status` de cmux (todo/working/done) |
| **voz** | las plantillas de frases en `voice.json` | no es voz sintetizada; no hay audio |

## Decisiones de producto que ya se tomaron

- **El personaje es un droide astromecánico genérico, dibujado con Core Graphics.**
  No se usa arte de Star Wars: R2-D2 es propiedad de Lucasfilm y este repo es
  público. Quien quiera otro personaje pone sus imágenes en `~/.cmux-pet/sprites/`.
- **Habla español.** El autor programa en español y el droide tiene más carácter
  así. Cambiar el idioma es editar `Voice.prompt` y regenerar; el respaldo
  estático en `Droid` también está en español.
- **El texto es de terminal, no de UI.** Monoespaciado, fondo oscuro, se escribe
  letra por letra. Encaja con lo que el usuario está mirando todo el día.
