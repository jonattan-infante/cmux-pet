#!/usr/bin/env bash
# Instalador de cmux-pet.
#
#   curl -fsSL https://raw.githubusercontent.com/jonattan-infante/cmux-pet/main/install.sh | bash
#
# O desde un clon:  ./install.sh --from-source
# Para quitarlo:    ./install.sh --uninstall
set -euo pipefail

REPO_URL="https://github.com/jonattan-infante/cmux-pet.git"
PREFIX="${CMUX_PET_PREFIX:-$HOME/.cmux-pet}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SOURCE_LINE='source ~/.cmux-pet/shell/pet.zsh'
MARKER='# asistente flotante de cmux (cmux-pet)'

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
warn() { printf '  aviso: %s\n' "$1" >&2; }
die()  { printf 'error: %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- desinstalar

uninstall() {
  bold "Desinstalando cmux-pet"
  pkill -f "$PREFIX/bin/cmux-pet" 2>/dev/null || true
  info "asistente detenido"

  # El launchd agent existio en versiones tempranas; se limpia por si quedo.
  launchctl bootout "gui/$(id -u)/com.jonattan.cmuxpet" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/com.jonattan.cmuxpet.plist"

  if [[ -f "$ZSHRC" ]] && grep -qF "$SOURCE_LINE" "$ZSHRC"; then
    cp -p "$ZSHRC" "$ZSHRC.cmux-pet-backup.$(date +%Y%m%d-%H%M%S)"
    # Quita la linea y el comentario marcador que la precede.
    /usr/bin/sed -i '' "/^${MARKER//\//\\/}$/d" "$ZSHRC"
    /usr/bin/sed -i '' "\|^${SOURCE_LINE}$|d" "$ZSHRC"
    info "enganche removido de $ZSHRC (backup guardado)"
  fi

  # La configuracion y los sprites del usuario NO se borran sin pedirlo.
  rm -rf "$PREFIX/bin" "$PREFIX/shell" "$PREFIX/src"
  info "binario y shell removidos"
  bold "Listo."
  echo "  Se conservaron tus preferencias y sprites en $PREFIX"
  echo "  Para borrar todo:  rm -rf $PREFIX"
  exit 0
}

[[ "${1:-}" == "--uninstall" ]] && uninstall

# ------------------------------------------------------------------ requisitos

bold "Instalando cmux-pet"

[[ "$(uname -s)" == "Darwin" ]] || die "cmux-pet solo corre en macOS"

command -v swift >/dev/null || die "falta Swift. Instala Xcode o las Command Line Tools:
    xcode-select --install"

if ! command -v cmux >/dev/null && [[ ! -x /Applications/cmux.app/Contents/Resources/bin/cmux ]]; then
  warn "no encuentro cmux. El asistente se instala igual, pero sin cmux no recibe eventos."
  warn "cmux: https://cmux.com"
fi

# ------------------------------------------------------------------- obtener

if [[ "${1:-}" == "--from-source" ]]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  info "compilando desde $SRC"
else
  command -v git >/dev/null || die "falta git"
  SRC="$(mktemp -d)/cmux-pet"
  info "clonando $REPO_URL"
  git clone --depth 1 "$REPO_URL" "$SRC" >/dev/null 2>&1 \
    || die "no pude clonar el repositorio"
fi

# -------------------------------------------------------------------- build

cd "$SRC"
info "compilando (la primera vez tarda un minuto)"
swift build -c release >/dev/null 2>&1 || die "la compilacion falló. Corre 'swift build -c release' para ver por qué."

BUILT="$(swift build -c release --show-bin-path)/cmux-pet"
[[ -x "$BUILT" ]] || die "no encuentro el binario compilado en $BUILT"

# ------------------------------------------------------------------ instalar

mkdir -p "$PREFIX"/{bin,shell,sprites}
pkill -f "$PREFIX/bin/cmux-pet" 2>/dev/null || true
install -m 755 "$BUILT" "$PREFIX/bin/cmux-pet"
install -m 644 shell/pet.zsh "$PREFIX/shell/pet.zsh"
install -m 644 shell/sprites-README.txt "$PREFIX/sprites/LEEME.txt" 2>/dev/null || true
info "instalado en $PREFIX/bin/cmux-pet"

# ------------------------------------------------------------- enganchar zsh

# Por que en el shell y no en launchd: cmux solo acepta control de procesos
# descendientes de cmux (socketControlMode). Un proceso de launchd no lo es y el
# socket lo rechaza en silencio. Ver docs/adr/0001.
if [[ -f "$ZSHRC" ]] && grep -qF "$SOURCE_LINE" "$ZSHRC"; then
  info "el enganche ya estaba en $ZSHRC"
else
  cp -p "$ZSHRC" "$ZSHRC.cmux-pet-backup.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  printf '\n%s\n%s\n' "$MARKER" "$SOURCE_LINE" >> "$ZSHRC"
  info "enganche agregado a $ZSHRC (backup guardado)"
fi

# --------------------------------------------------------------- arrancar ya

if [[ -n "${CMUX_WORKSPACE_ID:-}" ]]; then
  # Estamos dentro de cmux: el proceso hereda el acceso al socket de control.
  ( nohup "$PREFIX/bin/cmux-pet" >> "$PREFIX/pet.log" 2>&1 < /dev/null & ) >/dev/null 2>&1
  sleep 2
  if pgrep -f "$PREFIX/bin/cmux-pet" >/dev/null; then
    info "asistente arrancado"
  else
    warn "no arrancó; mira $PREFIX/pet.log"
  fi
else
  info "abre una terminal de cmux y el asistente arranca solo"
fi

echo ""
bold "Listo."
cat <<EOF
  El droide vive en la esquina inferior derecha. Arrástralo donde quieras.

    click            ir al último aviso
    mouse encima     ver en qué van tus agentes
    click derecho    opciones

  En terminales que ya tenías abiertas:  source ~/.zshrc
  Log:                                   tail -f $PREFIX/pet.log
  Quitar:                                $PREFIX/../cmux-pet/install.sh --uninstall
EOF
