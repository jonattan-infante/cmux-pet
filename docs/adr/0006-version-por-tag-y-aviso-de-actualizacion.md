# ADR 0006 — La versión es del producto: tag = release, y la mascota avisa una vez

- **Estado:** aceptada
- **Fecha:** 2026-09-17
- **Decide:** qué es "una versión" de lucy y cómo se entera el usuario de que hay otra

## Contexto

Hasta 0.1.0 la versión era un string copiado a mano en dos sitios: el binario de
macOS y el paquete de Python del port de Windows. No había tags ni releases; el
instalador de macOS compilaba `main` cada vez y el de Windows corría desde el
checkout. Nada comparaba las copias, y ningún runtime sabía si existía una versión
más nueva. El pedido fue explícito: **la funcionalidad tiene que ser global, sin
depender de la plataforma.**

## Opciones

**A. Versión por plataforma.** Cada runtime con su número y su ciclo. Descartada:
un mismo `~/.lucy` puede ser leído por los dos (el estado y los packs son
compartidos), y "lucy 0.3.0" tiene que significar lo mismo en las dos.

**B. `VERSION` como fuente única, con copias verificadas.** Ni Swift ni Python leen
un archivo al compilar sin plugins; se aceptan las copias y se verifica que no
diverjan. Elegida.

**C. Leer `VERSION` en tiempo de ejecución.** El binario de macOS instalado no
tiene el repo al lado; la copia compilada es la única honesta.

Para "cuándo existe una versión":

**D. La versión existe cuando cambia `VERSION` en `main`.** Descartada: `main`
avanza con cada PR y el usuario recibiría avisos por cambios que nadie decidió
publicar.

**E. La versión existe cuando hay un tag y CI publica el release.** Elegida. El
tag es una decisión humana; el release lo fabrica CI solo si tag, `VERSION` y
CHANGELOG coinciden. Un tag sin release no cuenta.

Para "cómo se entera el usuario":

**F. La mascota consulta el último release.** Una consulta por día, en segundo
plano, y un solo aviso por versión. Elegida. Es la única pieza del producto que
está en pantalla todo el día, y avisar es su trabajo.

**G. Avisar en cada `lucy` de la terminal.** Se descartó como único canal: en
Windows no existe CLI de la mascota, y la mitad de los usuarios de macOS no vuelve
a escribir `lucy` después de instalar.

## Decisión

- `VERSION` en la raíz es la fuente única. `scripts/bump-version.sh` propaga a
  Swift y Python; `scripts/test-repo-integrity.sh` falla si las copias o el
  CHANGELOG divergen.
- Empujar `vX.Y.Z` dispara `release.yml`, que verifica y crea el GitHub Release.
  `make tag` es el paso humano, solo desde `main` al día.
- El instalador de macOS clona el último release, no `main`. El de Windows mueve el
  checkout al tag del último release con `--update`.
- El contrato del aviso vive en `docs/reference/versioning.md` y lo implementan
  `Model/Update.swift` y `lucy_win/update.py`, con los mismos casos de prueba
  en `UpdateTests.swift` y `test_update.py`. La clase de frase `updateAvailable`
  entra al vocabulario de voz para que la mascota lo diga con su personalidad.

## Consecuencias

- **A favor:** "hay versión nueva" significa lo mismo en macOS y Windows, sale del
  mismo endpoint y se guarda en el mismo archivo. Portar a una tercera plataforma es
  implementar un documento, no adivinar.
- **A favor:** publicar es un tag. Nada se publica por accidente y nada se publica
  con las notas desincronizadas.
- **A favor:** el aviso respeta las reglas de la casa: sin modelo en el camino, fuera
  del hilo principal, un fallo de red se registra y no molesta.
- **En contra:** hay tres copias del número. Se acepta porque la guarda corre en
  cada `make verify` y en CI, y cambiar de número sin el script es visible.
- **En contra:** el instalador de macOS sigue compilando desde fuente aunque el
  release adjunte un tarball. Firmar y notarizar (B9) y Homebrew (B8) siguen en el
  backlog; el tarball existe para cuando lleguen.
- **En contra:** una consulta de red diaria a GitHub desde la mascota. Es
  desactivable (`checkUpdates: false`), no manda nada del usuario más que el
  `User-Agent` con la versión, y a 60 consultas por hora por IP el límite sin
  autenticar nunca se toca.
- **Regla derivada:** una funcionalidad del producto se define una vez en
  `docs/reference/` y se implementa en cada runtime con los mismos casos de prueba.
  Lo que solo existe en un runtime es una diferencia de plataforma, y se documenta
  como tal en `windows/README.md`.
