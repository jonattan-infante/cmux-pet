# ADR 0009 — Responder un permiso o una pregunta desde la burbuja

- **Estado:** aceptada
- **Fecha:** 2026-09-17
- **Decide:** cómo el orquestador escribe de vuelta a cmux para responder un
  permiso o una pregunta que Claude dejó pendiente, sin ir a la terminal

## Contexto

El pedido: que la mascota deje de ser pasiva — que se le pueda escribir, que
si pregunta algo se le responda ahí mismo, y que eso llegue de verdad al
agente. Hasta ahora `EventSource` (`docs/adr/0008`) es de una sola vía: la
fuente informa, el orquestador nunca escribe de vuelta.

Investigación de esta sesión, con comandos reales contra el cmux instalado:

1. **`cmux capabilities` confirma un RPC de escritura** que no estaba en uso:
   `feed.permission.reply`, `feed.question.reply`, `feed.exit_plan.reply`,
   `workspace.prompt_submit`, `surface.send_text`/`send_key`. Ninguno
   documentado en `docs/cli-contract.md` ni en `cmux feed --help`.
2. **El esquema exacto de los dos primeros se pudo verificar sin tocar
   ningún permiso/pregunta real**: `cmux rpc feed.permission.reply '{}'` (o
   con un `request_id` inventado) devuelve `invalid_params` listando los
   campos que exige — un `request_id` que no existe no afecta ninguna sesión
   de trabajo. Resultado: `feed.permission.reply` pide `request_id` +
   `mode: once|always|all|bypass|deny`; `feed.question.reply` pide
   `request_id` + `selections: [string]`. Ver `docs/reference/agent-reply.md`
   para la transcripción completa.
3. **El id de correlación ya viaja en el stream de hooks**, sin necesidad de
   inventar nada: `agent.hook.PermissionRequest`/`AskUserQuestion` traen un
   campo `_opencode_request_id` (mal nombrado — aparece igual con
   `_source: claude`) cuyo valor es idéntico al `request_id` de
   `feed.list`. `tool_input`/`context` siguen redactados en ese mismo
   payload (regla 11 de `CLAUDE.md` intacta).
4. **El contenido real (comando, opciones de pregunta) solo está en
   `feed.list`**, que no redacta nada y devuelve *todos* los workstreams
   activos de cmux, no solo los de esta mascota — leerlo trae de refilón
   trabajo de otros proyectos abiertos en la misma máquina.
5. **`BubbleView` no tiene ningún control interactivo hoy** (confirmado por
   grep: cero `NSButton`/`NSTextField` en todo el árbol de vistas) y
   `PetPanel` fija `canBecomeKey = false` / `canBecomeMain = false`
   (`Chrome.swift`) — no puede tomar foco de teclado tal como está armado.

## Decisión sobre el alcance

Por el hallazgo 5, esta fase se limita a **responder con clics** (permiso:
botones tipo Sí/No sobre `mode`; pregunta: una opción de
`question_options`). Texto libre y `workspace.prompt_submit` (reenviar un
mensaje nuevo) quedan fuera: requieren resolver antes cómo `PetPanel`
aceptaría foco de teclado sin romper que la mascota nunca interrumpe al
usuario — un problema de UI aparte, más grande.

## Decisión sobre privacidad

Por el hallazgo 4, el contrato exige explícitamente (ver
`docs/reference/agent-reply.md`): descartar de `feed.list` todo ítem que no
matchee el `requestId` pendiente apenas se filtra, y nunca loguear ni
persistir ese contenido (ni `pet.log` ni `~/.lucy`). No es una excepción a
la regla 11 — esa regla sigue rigiendo el stream de hooks, que sigue
redactado; `feed.list` es un canal nuevo y distinto, con su propia
disciplina.

## Decisión sobre fallos

`replyPermission`/`replyQuestion` usan `cmuxJSON` (que devuelve algo
verificable), nunca `cmuxFire` (fire-and-forget): responder un permiso es de
mayor riesgo que saltar a un workspace (`jumpToLastAlert`) — si falla en
silencio, Claude se queda esperando indefinidamente y parece que la mascota
funciona. Regla 16 de `CLAUDE.md`.

## Alternativas descartadas

**Adivinar el esquema de los RPC de respuesta** contra un permiso/pregunta
real para no "perder tiempo" con la verificación segura. Descartada:
`cmux rpc <método> '{}'` ya revela el esquema exacto vía su propio error de
validación, sin ningún riesgo — no había necesidad de tocar una sesión de
trabajo real para conseguir la misma información.

**Mostrar el contenido redactado (solo "Claude pide permiso", sin el
comando)**, más simple y sin tensión con la regla 11. Descartada por pedido
explícito del autor: quiere ver el contenido real antes de responder.

**Resolver ya mismo el foco de teclado del panel** para entregar texto libre
en la misma fase. Descartada: es un cambio de comportamiento de ventana más
grande y no probado (`canBecomeKey`/`canBecomeMain` existen por una razón no
documentada en el código — cambiarlos a ciegas puede romper que la mascota
nunca robe foco). Se decide aparte, con su propia investigación.

## Consecuencias

- **A favor:** el usuario puede responder un permiso o una pregunta sin
  soltar el mouse para ir a la terminal.
- **A favor:** el esquema de los RPC quedó verificado con evidencia
  reproducible (`docs/reference/agent-reply.md`), no adivinado.
- **En contra:** queda una verificación pendiente y marcada con ⚠️: que
  `{"delivered": true}` contra un `request_id` real efectivamente mueva al
  agente, no solo que el JSON sea válido. No se cierra la fase 1 sin esa
  prueba.
- **Regla derivada:** un canal de escritura hacia cmux usa `cmuxJSON`, nunca
  `cmuxFire`, cuando el fallo tiene costo de producto (el usuario cree que
  respondió y no pasó nada).
