# FEAT-XXX — <título>

> Plantilla. Copiar la carpeta a `docs/features/FEAT-XXX/` y crear **solo** los
> archivos que van a tener contenido. Carpetas vacías por simetría son deuda.

## Problema

Qué le pasa hoy al usuario. En términos de lo que ve, no de lo que falta en el
código.

## Fuera de alcance

Lo que explícitamente no se hace en esta feature. Esta sección evita que crezca
sola.

## Casos verificables

Cada caso tiene que poder fallar. Si no se puede escribir cómo comprobarlo, no es
un caso: es un deseo.

| # | Dado | Cuando | Entonces | Cómo se comprueba |
|---|---|---|---|---|
| 1 | | | | `swift test` / `make render` / comando concreto |
| 2 | | | | |

## Terminado cuando

- [ ] Todos los casos verificables pasan
- [ ] `make verify` verde
- [ ] Si es visual: `make render` revisado a ojo, con la imagen que lo demuestra
- [ ] `EXECUTION-PLAN.md` actualizado con evidencia
- [ ] `claude-progress.md` actualizado

## Notas

Decisiones tomadas al vuelo. Si alguna es durable, va a un ADR en `docs/adr/`, no
se queda aquí.
