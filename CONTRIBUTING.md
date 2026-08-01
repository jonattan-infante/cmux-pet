# Contribuir

## Empezar

```bash
git clone https://github.com/jonattan-infante/cmux-pet.git
cd cmux-pet
make verify      # debe pasar antes de que toques nada
make run         # arranca en primer plano, Ctrl-C para salir
```

## El gate

`make verify` es el juez: compila, corre los tests de Swift, los de los hooks de
zsh, los del instalador, la integridad del repo y la validación de las mascotas.
Es exactamente lo que corre CI. Si pasa, tu cambio es candidato; si no pasa, no
existe.

En GitHub son cuatro jobs, para que se lea de un vistazo qué falló:

| Job | Qué cubre |
|---|---|
| `build y tests` | compila y tests de lógica, en macOS 14 y 15 |
| `shell e instalador` | hooks de zsh, instalación y desinstalación, integridad del repo |
| `mascotas y marketplace` | valida cada pet pack y el índice, clonando incluso los de terceros |
| `vista previa` | dibuja los estados y los sube como artefacto; no bloquea |

```bash
make verify
```

Si tocaste algo visual, además:

```bash
make render && open render/todos.png
```

Y **míralo**. La última línea cortada de una burbuja no la detecta ningún test;
se detectó mirando un PNG.

## Qué se espera de un cambio

- **Tests para la lógica pura.** Parseo, validación, formateo: todo eso es
  testeable y va con test. Lo que depende de pantalla se verifica con `make render`.
- **Comentarios que expliquen por qué**, nunca qué. Si el comentario parafrasea la
  línea de abajo, bórralo.
- **Una decisión durable va a un ADR** en `docs/adr/`. Son insert-once: se agregan,
  no se editan.
- **Cero emojis**, en código, mensajes, commits y documentación.
- Español en documentación y comentarios; inglés en identificadores.

## Límites del diseño

Están en [`CLAUDE.md`](CLAUDE.md) como una lista de doce. Los tres que más se
violan por accidente:

1. Nunca `boundingRect` para medir y `draw(with:)` para dibujar en la misma vista.
   Divergen y cortan texto. Usa `layoutText(...)`.
2. Nunca suprimas avisos por workspace, solo por pane exacto.
3. Nunca llames a un modelo en el camino de un aviso.

Cada uno tiene su ADR con la evidencia de por qué.

## Commits y ramas

Conventional Commits, imperativo y minúsculas:

```
feat(voice): validar marcadores de plantillas
fix(bubble): medir y dibujar con el mismo layout manager
docs(adr): registrar el rechazo del socket bajo launchd
```

Ramas: `<tipo>/<descripcion-corta-en-kebab>`.

## Reportar un problema

Incluye siempre:

- salida de `~/.cmux-pet/pet.log` (registra cada aviso, cada supresión y cada
  caída del stream)
- versión de macOS y de cmux
- `cmux capabilities | grep access_mode`

Ese último dato resuelve la mitad de los reportes de "no me llegan avisos": si no
dice `cmuxOnly`, alguien cambió la configuración del socket.
