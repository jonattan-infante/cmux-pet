# ADR 0005 — La mascota es un paquete instalable, no código

- **Estado:** aceptada
- **Fecha:** 2026-07-31
- **Decide:** dónde vive lo que hace única a una mascota

## Contexto

La primera versión traía un droide y nada más. Su dibujo estaba en `PetView`, su
personalidad en una constante de `Voice.prompt`, y sus sprites en una carpeta fija
`~/.cmux-pet/sprites/`. Cambiar de mascota era editar Swift y recompilar.

Eso pone un techo bajo: la parte divertida del producto — inventarle carácter a
una mascota — quedaba reservada a quien sabe Swift y tiene el repo clonado.

## Decisión

Todo lo que hace única a una mascota se mueve a un **pet pack**: una carpeta con
manifiesto, personalidad y arte. El programa queda genérico.

```
mi-mascota/
├── pet.json      identidad, renderer, colores
├── persona.md    cómo habla, en prosa
├── phrases.json  frases de respaldo
└── sprites/      arte, si tiene
```

Reparto de responsabilidades:

| Lo pone | Qué |
|---|---|
| El pack | nombre, arte, colores, personalidad, frases de respaldo, idioma |
| El programa | los seis estados, los marcadores, el contrato del prompt, cuándo avisar |

El vocabulario de estados (`idle`, `working`, `done`, `error`, `attention`, `info`)
y los marcadores (`{agent}`, `{cmd}`, `{where}`…) **son del programa**. Un pack no
puede inventar un estado nuevo, porque el orquestador no sabría cuándo usarlo.

## Consecuencias

- **A favor:** crear una mascota es escribir un archivo de texto. `cmux-pet new`
  genera un paquete válido y `persona.md` es el único archivo que hay que editar
  para que suene distinta.
- **A favor:** el marketplace existe casi gratis. Un pack es una carpeta en un
  repositorio; el índice solo guarda punteros. Ver `docs/marketplace.md`.
- **A favor:** el mismo binario sirve para todas. Cambiar de mascota es cambiar
  una línea en `config.json`, y se puede hacer en caliente desde el menú.
- **En contra:** hay una frontera nueva que validar. Un pack lo escribe un
  tercero, así que `PetPack.load` es código defensivo: rutas que no se escapen del
  paquete, colores bien escritos, sprites que existan. Cubierto por 21 tests.
- **En contra:** una mascota puede quedar muda si no trae `phrases.json` y falla
  la generación. Por eso `cmux-pet new` escribe frases de respaldo genéricas y
  `validate` avisa cuando faltan.
- **En contra:** el renderer vectorial sigue siendo un droide. Un pack sin arte se
  ve como un droide con otros colores. Es honesto, pero limitado; más renderers
  integrados están en el backlog.

## Detalles que costaron pensarlos

**Las frases generadas viven fuera del pack**, en `~/.cmux-pet/voices/<id>.json`.
Dos razones: actualizar o reinstalar un pack no debe borrar lo que Claude Code ya
escribió, y un pack instalado desde el registro se trata como de solo lectura.

**El prompt se compone**: la personalidad la pone el pack, el contrato mecánico
(clases, marcadores, longitud, prohibición de emojis) lo pone el programa. Así el
autor de una mascota no tiene que saber nada del formato de salida, y una regla
nueva del contrato aplica a todas las mascotas existentes sin tocarlas.

**Un renderer desconocido no es fatal**: cae al vectorial y lo dice en el log. Un
pack hecho para una versión futura sigue siendo usable. Pero un campo obligatorio
que falta sí es fatal, porque adivinar un id o una versión es peor que rechazar.

## Alternativas descartadas

- **Un pack como archivo único** (`.petpack` comprimido). Más limpio para
  distribuir, pero peor para crear: no se puede editar `persona.md` con el editor
  ni versionar el arte en git. Una carpeta gana.
- **La personalidad en `pet.json`** como campo de texto. JSON es mal formato para
  párrafos: sin saltos de línea reales y con comillas escapadas. Un `.md` aparte
  se edita sin dolor.
- **Un servidor de marketplace.** Cuesta dinero, se cae, y necesita cuentas. Un
  JSON en el repo servido por raw.github cubre el caso completo.
