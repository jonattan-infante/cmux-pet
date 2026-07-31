# ADR 0004 — Silenciar por pane exacto, nunca por workspace

- **Estado:** aceptada
- **Fecha:** 2026-07-31
- **Decide:** cuándo el asistente se calla

## Contexto

Un asistente que avisa de todo se apaga el primer día. La primera versión traía
dos reglas de supresión:

1. No avisar de un comando cuyo **pane** está enfocado y cmux al frente.
2. No avisar del turno de un agente cuyo **workspace** está seleccionado y cmux
   al frente.

La regla 2 era un error de diseño. Un workspace de cmux tiene muchas pestañas: si
estás mirando cualquiera de ellas, se descartaban los avisos de **todos** los
agentes de ese workspace. En la práctica silenciaba justo lo que importa, porque
el workspace que tienes abierto es el que estás trabajando.

Síntoma reportado: "no llegan las notificaciones". Cada turno de agente en el
workspace visible se descartaba, y el log lo confirmó.

## Decisión

Solo supresión a nivel de **pane exacto**, y solo para comandos de shell, que son
los que traen `CMUX_SURFACE_ID`. Los avisos de agentes nunca se suprimen por
ubicación.

```swift
func userIsWatching(_ surfaceId: String?) -> Bool {
    guard let s = surfaceId, s == focusedSurface else { return false }
    return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.cmuxterm.app"
}
```

Configurable con `notifyWhileWatching: true` para desactivar incluso esa.

## Consecuencias

- **A favor:** el caso que el usuario quiere ver (un agente terminó mientras
  hacías otra cosa) siempre llega.
- **En contra:** si tienes dos pestañas del mismo workspace y un comando termina
  en la de al lado, te avisa aunque casi lo veas. Es el error correcto: mejor un
  aviso de más que un silencio inexplicable.
- **Regla derivada:** toda supresión nueva se decide con el identificador más
  específico disponible. Filtrar por un contenedor amplio es un anti-patrón en
  este repo.
- Los eventos de agente no traen `surface_id`, así que no hay forma de aplicar
  la regla fina; la decisión correcta es no aplicar ninguna.
