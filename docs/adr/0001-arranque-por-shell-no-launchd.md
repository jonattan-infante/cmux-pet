# ADR 0001 — El asistente arranca desde el shell, no desde launchd

- **Estado:** aceptada
- **Fecha:** 2026-07-31
- **Decide:** cómo se mantiene vivo el proceso entre sesiones

## Contexto

La primera versión se instalaba como LaunchAgent (`com.jonattan.cmuxpet`) con
`RunAtLoad`. Arrancaba, dibujaba el droide correctamente, y **no mostraba un solo
aviso**. El fallo era silencioso: ni un error en el log.

## Investigación

Se descartaron tres hipótesis antes de llegar a la causa:

1. *Buffering del CLI*: se midió `cmux events | while read` con un hook disparado
   en medio. Las líneas llegaron en menos de 1 s. **Descartada.**
2. *Bug en el lector del pipe*: se aisló el patrón exacto (`Process` + `Pipe` +
   `readabilityHandler`) en un programa mínimo. Recibió los eventos. **Descartada.**
3. *Entorno sin variables `CMUX_*`*: se corrió el CLI con `env -i HOME=...`.
   Funcionó. **Descartada.**

La causa se aisló corriendo el binario a mano (funcionaba) y luego bajo launchd
mediante un LaunchAgent de prueba:

```
--- entorno ---
HOME=/Users/jonattan PPID=1 ancestro=/sbin/launchd
--- rpc ---
Error: Failed to write to socket (Broken pipe, errno 32)
--- events ---
Error: Failed to write stream request (Broken pipe, errno 32)
```

cmux trae `automation.socketControlMode = "cmuxOnly"` por defecto: **solo acepta
control de procesos descendientes de cmux**. Bajo launchd el ancestro es
`/sbin/launchd`, así que el socket cierra la conexión.

## Decisión

El asistente arranca desde `shell/pet.zsh`, que lo levanta si no está corriendo.
Toda terminal de cmux es hija de cmux, así que el proceso hereda el acceso.

```zsh
if ! pgrep -f 'cmux-pet/bin/cmux-pet' >/dev/null 2>&1; then
  ( nohup "$HOME/.cmux-pet/bin/cmux-pet" >> "$HOME/.cmux-pet/pet.log" 2>&1 & )
fi
```

## Consecuencias

- **A favor:** cero cambios en la configuración de seguridad de cmux. Funciona
  con los valores por defecto, que es lo que tendrá cualquiera que lo instale.
- **En contra:** el asistente no existe hasta que se abre la primera terminal.
  Aceptable: sin cmux abierto tampoco hay nada que reportar.
- **En contra:** si la terminal que lo lanzó se cierra, el proceso queda
  reparentado a launchd. La conexión viva sigue, pero un `cmux events` que se
  respawnee después sería rechazado. Mitigación parcial: `--reconnect` mantiene la
  conexión original. Ver riesgo R1 en EXECUTION-PLAN.
- Se descartó `socketControlMode: "allowAll"` porque abre el control de cmux a
  cualquier proceso local (leer paneles, enviar teclas) y no se puede pedir eso a
  quien instala una mascota.
- Se descartó `"password"` por ahora: requiere reiniciar cmux.app para tomar
  efecto (`cmux reload-config` no reinicia el servidor del socket, verificado) y
  añade un secreto que gestionar.
