# cmux-pet

[![verify](https://github.com/jonattan-infante/cmux-pet/actions/workflows/ci.yml/badge.svg)](https://github.com/jonattan-infante/cmux-pet/actions/workflows/ci.yml)

Una mascota flotante que te cuenta qué están haciendo tus agentes de IA en
[cmux](https://cmux.com). **Elige la tuya, o hazla.**

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

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/jonattan-infante/cmux-pet/main/install.sh | bash
```

Necesitas macOS 13 o más, cmux, y Swift (viene con Xcode o con
`xcode-select --install`). Abre una terminal de cmux y la mascota aparece en la
esquina inferior derecha.

## Elegir mascota

El programa es uno; las mascotas son muchas. Vienen dos instaladas:

| id | Mascota | Cómo habla |
|---|---|---|
| `astro` | Astro | droide de servicio: *bip-bip*, seco, con carácter |
| `gatito` | Gatito | indiferencia felina: te avisa, pero tenía otros planes |

```bash
cmux-pet list                  # las instaladas, con la activa marcada
cmux-pet use gatito            # cambiar, en caliente
cmux-pet search                # ver el marketplace
cmux-pet install <id> --use    # instalar y activar
```

La misma alerta, dos personalidades:

```
astro   › *bzzzt* npm run build falló con código 1 en Backend. Algo no cuadra.
gatito  › npm run build se rompió, código 1 en Backend. No fui yo.
```

## Hacer la tuya

**No hace falta programar.** Una mascota es una carpeta con un archivo que
describe cómo habla.

```bash
cmux-pet new mi-mascota        # crea un paquete que ya funciona
# edita mi-mascota/persona.md  <- lo único imprescindible
cmux-pet validate ./mi-mascota
cmux-pet install ./mi-mascota --use
cmux-pet voice mi-mascota      # Claude Code le escribe sus frases
```

`persona.md` es prosa, no configuración:

```markdown
Eres Gatito, un gato que vive flotando sobre la pantalla de un programador.

Tu tono es de indiferencia felina cortés: informas lo que pasó, pero dejas claro
que tú tenías otros planes. Nunca eres grosero.

Usas sonidos de gato con moderación: "mrrp", "miau", "prrr". No en todas las
frases, y nunca más de uno por frase.
```

Con eso, `cmux-pet voice` produjo 64 frases como estas:

```
{cmd} explotó{where}, código {code}, fffs. Vuelvo a mi caja.
{agent} lleva {time} {doing}{where}. Yo llevo el mismo tiempo sin moverme del sol.
```

Usa tu sesión local de Claude Code: **sin API key**. Y si no tienes Claude Code, la
mascota habla igual con las frases de respaldo del paquete.

### Con tu propio arte

```bash
cmux-pet sprite mi-mascota idle gato.png       # una imagen a un estado
cmux-pet sprite mi-mascota --dir ./mis-dibujos # varias, por nombre de archivo
cmux-pet sprite mi-mascota --clear             # volver al dibujo vectorial
```

El comando copia la imagen al paquete, actualiza el manifiesto y recarga la
mascota. No hace falta editar JSON.

Con `--dir` toma los archivos que se llamen como un estado: `idle.png`,
`working.gif`, `done.png`, `error.png`, `attention.png`, `info.png`, o
`default.png` como comodín. Los GIF se animan solos.

La imagen reemplaza el cuerpo entero. El programa sigue dibujando alrededor: la
sombra del piso, los puntos de "trabajando", el signo de admiración cuando te
necesita, y el salto al terminar.

**Para partir de una mascota que ya viene incluida**, saca tu copia primero: las
de fábrica se reemplazan al actualizar.

```bash
cmux-pet fork gatito mi-gato --name "Mi Gato"
cmux-pet sprite mi-gato --dir ./mis-dibujos
cmux-pet use mi-gato
```

### Sin arte propio

Hay tres dibujos integrados que se tiñen con tus colores. No pesan nada y no
involucran arte de nadie:

| `renderer` | Qué dibuja |
|---|---|
| `vector:droid` | droide astromecánico: cúpula con lente, torso, tres patas |
| `vector:ball` | droide esférico: cuerpo bola que rueda, cúpula y antena |
| `vector:sage` | figura encapuchada: túnica, ojos en la sombra, bastón |

```bash
cmux-pet renderers    # verlos con su descripción
```

El formato completo está en [`docs/reference/pet-pack.md`](docs/reference/pet-pack.md).

## Publicar en el marketplace

El marketplace es un JSON en este repositorio. **No hay servidor, ni cuentas, ni
pagos.** Cada entrada apunta al repositorio del autor, así que tu arte se queda
donde tú quieras.

1. Sube tu paquete a un repositorio público tuyo.
2. Abre un PR que agregue una entrada a `registry.json`.
3. Al mergearse: `cmux-pet install tu-id` funciona para todo el mundo.

Detalles y qué se revisa: [`docs/marketplace.md`](docs/marketplace.md).

Una regla que no se negocia: **nada de arte de personajes con dueño.** R2-D2,
Pikachu, Clippy y compañía son marcas registradas.

## Qué hace

- **Avisa cuando un agente termina** su turno, y en qué workspace.
- **Se pone en alerta** cuando un agente pide permiso o hace una pregunta, y se
  queda así hasta que le hagas caso.
- **Te dice en qué van**: pasa el mouse por encima y ves cada agente, qué
  herramienta usa, cuántos pasos lleva y con qué prompt arrancó.
- **Avisa de comandos largos** (más de 20 s) y de cualquier comando que falle.
- **Avisa de puertos** que empiezan y dejan de escuchar.
- **Un click te lleva** al workspace del aviso y trae cmux al frente.

| Acción | Qué pasa |
|---|---|
| Click | salta al workspace del último aviso |
| Arrastrar | la mueves; recuerda la posición |
| Mouse encima | panel con el estado de cada agente |
| Click derecho | cambiar de mascota, silenciar, reescribir frases, salir |

## Los seis estados

Toda mascota tiene que poder expresar estos seis. Es el vocabulario del sistema.

| Estado | Cuándo |
|---|---|
| en reposo | nada en curso |
| trabajando | hay agentes activos |
| listo | terminó bien |
| falló | exit code distinto de cero |
| te necesita | pide permiso o pregunta |
| info | notificación o puerto |

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
  "activePet": "gatito",
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
export CMUX_PET_REGISTRY=<url>        # usar otro marketplace
```

## Cómo funciona

```
cmux events ──┐
cmux rpc    ──┼──► PetController ──► estado (uno de seis) ──► pet pack
zsh hooks   ──┤                                               arte + voz
reloj       ──┘
```

Cuatro fuentes, un orquestador, un paquete que decide cómo se ve y cómo suena. El
detalle está en [`ARCHITECTURE.md`](ARCHITECTURE.md), y las decisiones con su
evidencia en [`docs/adr/`](docs/adr/).

Una cosa que sorprende a todo el mundo: **cmux solo acepta control de procesos que
descienden de cmux**, así que el asistente no puede arrancar desde launchd — el
socket lo rechaza en silencio. Por eso arranca desde tu shell. Está contado en
[`docs/adr/0001`](docs/adr/0001-arranque-por-shell-no-launchd.md).

## Contribuir

```bash
make verify        # el gate completo: lo mismo que corre CI
make packs         # solo validar las mascotas y el índice
make render        # revisar el dibujo a ojo
```

Lee [`CONTRIBUTING.md`](CONTRIBUTING.md). Si vas a trabajar con un agente de IA,
[`CLAUDE.md`](CLAUDE.md) es el router del repo.

## Licencia

MIT. Ver [`LICENSE`](LICENSE). Cada mascota del marketplace declara la suya.

cmux-pet no está afiliado a cmux ni a Lucasfilm.
