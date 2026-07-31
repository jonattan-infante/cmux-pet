# cmux-pet

Un droide flotante que te cuenta qué están haciendo tus agentes de IA en
[cmux](https://cmux.com).

Cuando trabajas con varios agentes en paralelo pierdes el hilo: terminan en
workspaces que no estás mirando, se quedan esperando permiso, los builds pasan sin
que te enteres. cmux ya publica todo eso; cmux-pet lo pone donde lo veas.

```
                                    ┌──────────────────────────────────────┐
      ___                           │ › *bip-bip* ./gradlew build terminó  │
     /o o\                          │ en 1 min 34 s en Fineract. Todo en   │
    | ___ |                         │ orden.█                              │
    |[###]|  ◄───────────────────── └──────────────────────────────────────┘
    /|   |\
   ▄▄▀   ▀▄▄
```

macOS · Swift · sin dependencias · un binario de 800 KB

## Qué hace

- **Avisa cuando un agente termina** su turno, y en qué workspace.
- **Se pone en alerta** cuando un agente pide permiso o hace una pregunta, y se
  queda así hasta que le hagas caso.
- **Te dice en qué van**: pasa el mouse por encima y ves cada agente, qué
  herramienta usa, cuántos pasos lleva y con qué prompt arrancó.
- **Avisa de comandos largos** (más de 20 s) y de cualquier comando que falle.
- **Avisa de puertos** que empiezan y dejan de escuchar.
- **Un click te lleva** al workspace del aviso y trae cmux al frente.
- **Sus frases las escribe Claude Code** con tu sesión local, así que no suenan
  siempre igual. Sin API key.

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/jonattan-infante/cmux-pet/main/install.sh | bash
```

Necesitas macOS 13 o más, cmux, y Swift (viene con Xcode o con
`xcode-select --install`).

El instalador compila, deja el binario en `~/.cmux-pet/bin/`, y agrega una línea a
tu `.zshrc` (con backup). Abre una terminal de cmux y el droide aparece en la
esquina inferior derecha.

Desde un clon:

```bash
git clone https://github.com/jonattan-infante/cmux-pet.git
cd cmux-pet && make install
```

Para quitarlo: `./install.sh --uninstall`. Conserva tus preferencias y sprites.

## Usarlo

| Acción | Qué pasa |
|---|---|
| Click | salta al workspace del último aviso |
| Arrastrar | lo mueves; recuerda la posición |
| Mouse encima | panel con el estado de cada agente |
| Click derecho | silenciar, vigilar puertos, reescribir sus frases, sprites, salir |

## Los estados

| Estado | Cómo se ve | Cuándo |
|---|---|---|
| en reposo | lente azul, cúpula mirando alrededor | nada en curso |
| trabajando | lente ámbar, cúpula girando, luces en secuencia | hay agentes activos |
| listo | lente verde, salta | terminó bien |
| falló | lente roja parpadeando, se sacude | exit code distinto de cero |
| te necesita | lente naranja latiendo, signo de admiración | pide permiso o pregunta |

Para verlos sin instalar nada:

```bash
make render && open render/todos.png
```

## Que no sea molesto

Un asistente que avisa de todo se apaga el primer día. Tres reglas:

1. **No avisa de lo que ya estás viendo.** Si el pane del evento está enfocado y
   cmux al frente, se calla.
2. **Denylist de comandos interactivos**: `vim`, `ssh`, `btop`, `claude`, `psql`,
   `tail`… nunca reportan aunque duren horas.
3. **Ctrl-C no es un fallo.**

Y si aun así molesta: click derecho, **Silenciar avisos**.

## Configurar

`~/.cmux-pet/config.json`:

```json
{
  "quiet": false,
  "watchPorts": true,
  "notifyWhileWatching": false,
  "narrateEverySeconds": 150
}
```

En `~/.zshrc`, antes del `source`:

```zsh
export CMUX_PET_MIN_SECONDS=20        # umbral de "comando largo"
export CMUX_PET_IGNORE="vim ssh ..."  # denylist
export CMUX_PET_NO_AUTOSTART=1        # no arrancar solo
```

## Tu propio personaje

El droide está dibujado con Core Graphics, no es una imagen. **No se usa arte de
Star Wars**: R2-D2 es propiedad de Lucasfilm. Si quieres otro personaje, suelta
imágenes en `~/.cmux-pet/sprites/`:

```
idle.png  working.gif  done.png  error.png  attention.png  info.png  default.png
```

Los GIF se animan solos. Después: click derecho, **Recargar sprites**.

## Cómo funciona

```
cmux events ──┐
cmux rpc    ──┼──► PetController ──► droide + burbuja + panel
zsh hooks   ──┤
reloj       ──┘
```

Cuatro fuentes, un orquestador, tres vistas. El detalle está en
[`ARCHITECTURE.md`](ARCHITECTURE.md), y las decisiones con su evidencia en
[`docs/adr/`](docs/adr/).

Una cosa que sorprende a todo el mundo: **cmux solo acepta control de procesos
que descienden de cmux**, así que el asistente no puede arrancar desde launchd —
el socket lo rechaza en silencio. Por eso arranca desde tu shell. Está contado en
[`docs/adr/0001`](docs/adr/0001-arranque-por-shell-no-launchd.md).

## Contribuir

```bash
make verify     # build + tests Swift + tests de hooks de zsh
make render     # revisar el dibujo a ojo
```

Lee [`CONTRIBUTING.md`](CONTRIBUTING.md). Si vas a trabajar con un agente de IA,
[`CLAUDE.md`](CLAUDE.md) es el router del repo.

## Licencia

MIT. Ver [`LICENSE`](LICENSE).

cmux-pet no está afiliado a cmux ni a Lucasfilm.
