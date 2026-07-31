# ADR 0002 — La voz se genera como plantillas, no como mensajes finales

- **Estado:** aceptada
- **Fecha:** 2026-07-31
- **Decide:** cómo se consigue que los avisos no suenen siempre igual

## Contexto

Los avisos con texto fijo se vuelven invisibles: a la tercera vez que lees
"Claude terminó" dejas de leerlo. Se quería variedad real, generada por Claude
Code con la sesión local del usuario (sin API key ni costo aparte).

## Opciones

**A. Una llamada por aviso.** Máxima creatividad: el modelo ve los datos reales
y escribe la frase. Se midió la latencia del CLI local en headless:

| Modelo | Latencia medida |
|---|---|
| haiku | ~3.8 s |
| sonnet | ~47 s |

Un aviso que llega 4 s tarde ya no es un aviso, y consume cuota del usuario en
cada build que termina.

**B. Un lote de plantillas con marcadores.** Una llamada cada tanto produce 64
plantillas; rellenarlas es sustitución de cadenas, o sea instantáneo y gratis.

## Decisión

Opción B. `Voice` pide a Claude Code un JSON de plantillas por clase de aviso,
las valida, y las guarda en `~/.cmux-pet/voice.json`.

```json
"commandError": [
  "*bzzzt* {cmd} explotó con código {code}{where}, alguien debe mirar esto.",
  "*brrrp* {cmd} se rompió, salida {code}{where}."
]
```

Se regenera la primera vez, cuando las frases pasan de 7 días, o a pedido desde
el menú.

## Consecuencias

- **A favor:** latencia cero en el camino del aviso. La generación corre en
  segundo plano y si tarda o falla no se nota.
- **A favor:** una llamada da variedad para semanas. El costo en cuota es
  despreciable.
- **En contra:** el modelo no ve los datos reales, así que no puede comentar
  sobre el contenido ("ese test falla siempre"). Se cambia gracia por
  inmediatez. Documentado como idea futura en EXECUTION-PLAN, no como falta.
- **Obligatorio:** validar cada plantilla. Un marcador faltante o inventado
  dejaría `{time}` literal en pantalla. Cubierto por `VoiceTests`.
- **Obligatorio:** respaldo estático (`enum Droid`). Sin `voice.json` el
  asistente habla igual, con menos variedad. Nunca se queda mudo.
