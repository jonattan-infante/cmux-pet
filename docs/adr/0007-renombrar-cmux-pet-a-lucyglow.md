# ADR 0007 — El producto se renombra de cmux-pet a LucyGlow

- **Estado:** aceptada
- **Fecha:** 2026-09-17
- **Decide:** cómo se llama el producto, el binario, el paquete de Windows y el
  directorio de estado en disco

## Contexto

El nombre `cmux-pet` describía bien el prototipo original: un droide que
observaba [cmux](https://cmux.com). Pero desde el port de Windows (`docs/adr/`
del port, `windows/README.md`) el producto observa **Claude Code** directamente
cuando no hay cmux disponible. El nombre seguía sugiriendo, con razón, que la
mascota solo servía dentro de cmux. Pedido explícito: un nombre que no dependa
de una sola plataforma.

## Búsqueda

Se evaluaron más de treinta candidatos: sinónimos de "vigilante" y "guardián" en
español, inglés y latín (`Vigía`, `Centinela`, `Herald`, `Warden`, `Custos`,
`Scribe`, `Witness`, `Sentinel`), nombres de la literatura clásica (`Virgilio`,
`Sancho`, `Passepartout`, `Jeeves`, `Puck`), figuras de compañía leal (`Lucy`,
`Toto`, `Hachiko`, `Fido`) y modismos regionales (`Parce`, `Pana`).

Casi todos chocaban con algo ya existente: el nicho de "mascota de escritorio
que observa agentes de IA" se pobló de decenas de proyectos casi idénticos
durante 2026 (`agent-pet`, `agentpet`, `codepet`, `devpet`, `CoPet`, `OpenPets`,
entre otros), y cada sinónimo obvio de "vigilar" en cualquiera de los tres
idiomas ya tenía una herramienta de agentes de IA encima. `Virgilio` en
particular resultó ser una marca activa: el portal web más antiguo de Italia,
con el mismo origen (el guía de Dante) que motivó la propuesta.

## Decisión

`LucyGlow`, con `lucy` como comando de terminal. `Lucy` viene del latín *lux*
(luz) y el compuesto encaja con algo real del producto: la mascota cambia de
color según el estado (`idle`, `working`, `done`, `error`, `attention`, `info`).
Verificado sin colisión en el espacio de agentes de IA de escritorio.

Consecuencias técnicas de este PR:

- Repositorio de GitHub: `cmux-pet` → `lucyglow` (GitHub redirige la URL vieja).
- Binario y target ejecutable de Swift: `cmux-pet` → `lucy`.
- Librería Swift: `CmuxPetKit` → `LucyGlowKit`.
- Paquete de Windows: `cmux_pet_win` → `lucy_win`; hook `cmux-pet-hook.ps1` →
  `lucy-hook.ps1`.
- Variables de entorno: todo `CMUX_PET_*` → `LUCY_*`.
- Directorio de estado: `~/.cmux-pet` → `~/.lucy`, con **migración automática**
  en el primer arranque (macOS y Windows) para no perder configuración,
  mascotas ni frases generadas de una instalación anterior.

## Consecuencias

- **A favor:** el nombre ya no promete una integración que no existe en
  Windows. La marca (`LucyGlow`) y el comando (`lucy`) pueden convivir sin que
  el segundo suene raro en una frase.
- **A favor:** la migración automática del directorio de estado significa que
  nadie pierde trabajo por el cambio de nombre, ni en macOS ni en Windows.
- **En contra:** rompe cualquier script o alias que alguien tuviera apuntando a
  `cmux-pet` o a las variables `CMUX_PET_*`. Dado que el proyecto tiene un solo
  usuario activo hasta ahora, el costo es bajo; de crecer el marketplace, un
  cambio así de nombre se pagaría más caro.
- **Regla derivada:** un nombre de producto no se seguirá porque ya haya código
  escrito con él. Renombrar temprano, con migración, cuesta un PR; renombrar
  tarde, con usuarios y un marketplace externo dependiendo de la URL, no sería
  tan barato.
