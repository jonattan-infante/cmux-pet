# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Versionado semántico.

## [0.1.0] — 2026-07-31

Primera versión.

### Agregado

- Droide astromecánico vectorial con seis estados distinguibles, dibujado con
  Core Graphics. Sin imágenes ni dependencias.
- Sprites propios del usuario desde `~/.cmux-pet/sprites/`, con GIF animado.
- Avisos estilo terminal: monoespaciados, un párrafo, escritos letra por letra
  con cursor de bloque.
- Voz generada por Claude Code local sin API key, como plantillas validadas, con
  respaldo estático.
- Seguimiento en vivo de agentes: panel al pasar el mouse, narración periódica y
  línea de estado en el menú.
- Cuatro fuentes de eventos: stream de cmux, RPC de cmux, hooks de zsh y reloj.
- Avisos de comandos largos y fallidos, con denylist de comandos interactivos.
- Avisos de puertos que empiezan y dejan de escuchar.
- Click para saltar al workspace del aviso.
- Modo `--render`: escribe un PNG por estado sin abrir ventana, para revisar el
  dibujo desde CI o desde un agente.
- Instalador de un comando y desinstalador que conserva las preferencias.
