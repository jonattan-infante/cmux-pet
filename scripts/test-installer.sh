#!/usr/bin/env bash
# Verifica el instalador sin tocar la maquina real: prefijo y ZDOTDIR apuntan a
# un directorio temporal.
#
# Se prueba sobre todo la desinstalacion, porque edita el .zshrc del usuario. Un
# sed mal escrito ahi le rompe el shell a alguien.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  ok   %s\n' "$desc"
  else
    printf '  FALLA %s (esperaba %s, obtuve %s)\n' "$desc" "$expected" "$actual"
    fail=1
  fi
}

echo "instalador:"

# --- sintaxis ---
bash -n "$ROOT/install.sh"
check "sintaxis de install.sh" 0 $?

# --- desinstalacion sobre un zshrc con contenido alrededor ---
PREFIX="$WORK/prefix"
mkdir -p "$PREFIX/bin" "$PREFIX/shell" "$PREFIX/sprites"
touch "$PREFIX/bin/cmux-pet" "$PREFIX/shell/pet.zsh"
echo 'mi-droide' > "$PREFIX/sprites/mi-droide.png"
echo '{"quiet":false}' > "$PREFIX/config.json"

cat > "$WORK/.zshrc" <<'EOF'
export PATH=/opt/homebrew/bin:$PATH
alias ll='ls -la'

# asistente flotante de cmux (cmux-pet)
source ~/.cmux-pet/shell/pet.zsh

export EDITOR=vim
EOF

ZDOTDIR="$WORK" CMUX_PET_PREFIX="$PREFIX" "$ROOT/install.sh" --uninstall >/dev/null 2>&1

check "quita la linea del source" 0 "$(grep -c 'pet.zsh' "$WORK/.zshrc" || true)"
check "quita el comentario marcador" 0 "$(grep -c 'cmux-pet' "$WORK/.zshrc" || true)"
check "conserva el PATH del usuario" 1 "$(grep -c 'homebrew' "$WORK/.zshrc" || true)"
check "conserva los alias" 1 "$(grep -c "alias ll" "$WORK/.zshrc" || true)"
check "conserva lo que venia despues" 1 "$(grep -c 'EDITOR=vim' "$WORK/.zshrc" || true)"
check "deja backup del zshrc" 1 "$(ls "$WORK"/.zshrc.cmux-pet-backup.* 2>/dev/null | wc -l | tr -d ' ')"
check "borra el binario" 0 "$(ls "$PREFIX/bin" 2>/dev/null | wc -l | tr -d ' ')"
check "conserva los sprites del usuario" 1 "$(ls "$PREFIX/sprites" 2>/dev/null | wc -l | tr -d ' ')"
check "conserva la configuracion" 1 "$(ls "$PREFIX/config.json" 2>/dev/null | wc -l | tr -d ' ')"

# --- desinstalar dos veces no debe explotar ni corromper ---
before="$(md5 -q "$WORK/.zshrc")"
ZDOTDIR="$WORK" CMUX_PET_PREFIX="$PREFIX" "$ROOT/install.sh" --uninstall >/dev/null 2>&1
check "desinstalar dos veces es idempotente" "$before" "$(md5 -q "$WORK/.zshrc")"

# --- un zshrc sin el enganche no se toca ---
echo 'export FOO=bar' > "$WORK/.zshrc"
untouched="$(md5 -q "$WORK/.zshrc")"
ZDOTDIR="$WORK" CMUX_PET_PREFIX="$PREFIX" "$ROOT/install.sh" --uninstall >/dev/null 2>&1
check "no toca un zshrc ajeno" "$untouched" "$(md5 -q "$WORK/.zshrc")"

exit $fail
