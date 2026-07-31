# FEAT-XXX — reporte de QA

> Lo llena quien implementa. La evidencia se **pega**, no se resume.

- Commit: `<sha>`
- Fecha:

## Gate

```
$ make verify
<pegar la salida completa>
```

## Casos de la spec

| # | Caso | Resultado | Evidencia |
|---|---|---|---|
| 1 | | pasa / falla | comando + salida, o imagen |

## Revisión visual

Solo si el cambio toca vistas, paleta, layout o textos.

```
$ make render
```

| Imagen | Qué se revisó |
|---|---|
| `render/todos.png` | los 6 estados se distinguen |
| `render/burbuja-*.png` | ningún texto cortado, la tarjeta no cambia de tamaño |

## Lo que quedó fuera

Qué no se cubrió y por qué. Un hueco declarado es aceptable; uno escondido, no.
