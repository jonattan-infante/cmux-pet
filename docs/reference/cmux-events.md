# Referencia — eventos de cmux que usa el asistente

Catálogo **verificado el 2026-07-31** contra cmux instalado en
`/Applications/cmux.app` (build de 2026-05-23), leyendo
`~/.cmuxterm/events.jsonl` y el stream de `cmux events`.

Si esto diverge de la realidad, gana cmux: reverificar con los comandos de abajo
y actualizar este archivo con la fecha nueva.

## Cómo reverificar

```bash
# catálogo de nombres y cuántas veces aparece cada uno
cat ~/.cmuxterm/events.jsonl | python3 -c "
import sys,json,collections
c=collections.Counter()
for l in sys.stdin:
    try: e=json.loads(l)
    except: continue
    c[(e.get('category'),e.get('name'))]+=1
for k,v in c.most_common(): print(v,k)"

# el payload real de un evento concreto
cmux events --reconnect --no-heartbeat --category agent | head -3

# los métodos del socket
cmux capabilities | grep notification
```

## Suscripción que usa el asistente

```
cmux events --reconnect --no-heartbeat --no-ack \
  --category agent --category notification --category surface --category workspace
```

`--reconnect` es obligatorio: sin eso una caída del socket deja al asistente
sordo para siempre.

## Eventos que se consumen

| Evento | Qué se saca | Ojo |
|---|---|---|
| `agent.hook.SessionStart` | arranca una sesión | |
| `agent.hook.UserPromptSubmit` | la sesión está activa | llega dos veces: `phase: received` y `phase: completed` |
| `agent.hook.PreToolUse` | **`tool_name`** → qué hace el agente | el más frecuente con diferencia (miles por sesión) |
| `agent.hook.Stop` | terminó el turno | también duplicado por `phase` |
| `agent.hook.SessionEnd` | murió la sesión | |
| `agent.hook.PermissionRequest` | pide permiso, con `tool_name` | duplicado por `phase` |
| `agent.hook.AskUserQuestion` | hace una pregunta | |
| `agent.hook.Notification` | dejó de trabajar y espera | |
| `workspace.prompt.submitted` | **`message_preview`** → el texto de la tarea | es por workspace, no por sesión |
| `workspace.selected` | qué workspace está visible | |
| `surface.focused` / `surface.selected` | qué pane mira el usuario | base de la supresión de avisos |
| `notification.created` | que hay una notificación nueva | **el texto viene redactado**, ver abajo |

## Campos de un evento

```json
{
  "seq": 97372,
  "boot_id": "545BC4B8-…",
  "name": "agent.hook.Stop",
  "category": "agent",
  "source": "claude",
  "occurred_at": "2026-07-31T05:10:21.867Z",
  "workspace_id": "CB8D0565-…",
  "surface_id": null,
  "payload": { }
}
```

Del payload de los hooks de agente se usan:

| Campo | Para qué |
|---|---|
| `session_id` | clave del seguimiento de actividad |
| `_source` | nombre del agente: `claude`, `codex`, `gemini`, `opencode` |
| `_ppid` | **filtro anti-bucle**: si es el pid del asistente, el evento es de su propio generador de voz |
| `tool_name` | el verbo que se muestra |
| `workspace_id` | para resolver el título y para el click |
| `phase` | `received` y `completed`: por eso hay que deduplicar |

## Trampas confirmadas

1. **Las notificaciones vienen redactadas.** En `notification.created`, los campos
   `title`, `subtitle` y `body` llegan en `null`, con `redacted_fields` listando
   qué se ocultó. El texto real se pide aparte:

   ```bash
   cmux rpc notification.list '{}'
   ```

2. **`tool_input` también viene redactado.** Solo hay `tool_name` y
   `tool_input_length`. Por eso el asistente puede decir "editando archivos" pero
   no "editando `Loan.java`".

3. **Cada hook llega dos veces**, con `phase: received` y `phase: completed`. Sin
   deduplicar, cada aviso sale doble.

4. **Los eventos de agente no traen `surface_id`.** Solo `workspace_id`. Por eso
   la supresión por pane no se puede aplicar a agentes (ver `docs/adr/0004`).

5. **El socket rechaza procesos que no descienden de cmux** cuando
   `automation.socketControlMode` es `cmuxOnly`, que es el valor por defecto. El
   error es `Broken pipe, errno 32`. Ver `docs/adr/0001`.

6. **`cmux reload-config` no reinicia el servidor del socket.** Cambiar
   `socketControlMode` requiere reiniciar cmux.app; `cmux capabilities` sigue
   reportando el modo viejo hasta entonces.

7. **Los títulos de workspace traen un spinner** cuando están activos: un carácter
   braille (`U+2800`–`U+28FF`) o un asterisco al principio. Hay que limpiarlos
   antes de meterlos en una frase (`PetController.cleanTitle`).

## Métodos RPC que se usan

| Método | Para qué |
|---|---|
| `notification.list` | el texto real de una notificación |
| `workspace.list` | títulos de workspace y `listening_ports` |

Y por CLI: `cmux select-workspace --workspace <uuid>` para saltar al workspace de
un aviso. Acepta UUID además de refs tipo `workspace:2`.
