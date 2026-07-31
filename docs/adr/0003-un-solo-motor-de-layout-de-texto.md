# ADR 0003 — Medir y dibujar texto con el mismo NSLayoutManager

- **Estado:** aceptada
- **Fecha:** 2026-07-31
- **Decide:** cómo se calcula el tamaño de la burbuja

## Contexto

La burbuja es una tarjeta de terminal con texto que se escribe letra por letra.
El alto se calcula antes de mostrarla y no puede cambiar después: si creciera
mientras escribe, la tarjeta saltaría en pantalla.

La primera versión medía con `NSAttributedString.boundingRect(with:options:)` y
dibujaba con `NSAttributedString.draw(with:options:)`. Con mensajes de más de
tres líneas, **la última línea salía cortada** — verificado a ojo en un render:

```
› *blip* Unidad en línea y
vigilando tus agentes, comandos y
puertos. Un click me lleva al
último aviso, click derecho abre
las opciones.            <- recortada a media altura
```

Cambiar la medición a `NSLayoutManager` no alcanzó: seguía cortando. La causa es
que `draw(with:)` usa su propio contenedor de texto, con un
`lineFragmentPadding` distinto del que se usó al medir, así que **envuelve en
puntos diferentes** y produce más líneas de las contadas.

## Decisión

Un solo camino de layout para medir y para dibujar: `NSTextStorage` +
`NSTextContainer(lineFragmentPadding: 0)` + `NSLayoutManager`. El alto sale de
`usedRect(for:)` y el dibujo de `drawGlyphs(forGlyphRange:at:)`.

Como `drawGlyphs` asume coordenadas hacia abajo, `BubbleView` y `RosterView`
declaran `isFlipped = true`.

## Consecuencias

- **A favor:** medida y dibujo no pueden divergir, porque son el mismo cálculo.
- **En contra:** hay que retener el `NSTextStorage` explícitamente durante el
  dibujo; el layout manager no lo hace. Está comentado en el código.
- **En contra:** `isFlipped` invierte el eje Y en esas vistas. Es una diferencia
  con `PetView`, que no está volteada porque su dibujo vectorial es más natural
  con el origen abajo.
- **Regla derivada:** cualquier vista nueva que mida texto usa `layoutText(...)`.
  Nunca mezclar `boundingRect` con `draw(with:)`.
