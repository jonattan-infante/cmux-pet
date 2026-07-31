#!/usr/bin/env bash
# Verifica que el repositorio contenga todo lo que el build necesita.
#
# Existe por un bug real: el patron `render/` del .gitignore excluyo tambien
# `Sources/CmuxPetKit/Render/`, asi que RenderMode.swift nunca entro al repo. En
# local compilaba (el archivo estaba en disco) y en CI fallaba. Un clon limpio es
# la unica prueba honesta de que el repo esta completo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
echo "integridad del repo:"

# --- todo el codigo fuente esta versionado ---
untracked=""
while IFS= read -r f; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || untracked+="    $f"$'\n'
done < <(find Sources Tests -name '*.swift' | sort)

if [[ -z "$untracked" ]]; then
  printf '  ok   todo el codigo Swift esta versionado\n'
else
  printf '  FALLA hay codigo fuera del repo:\n%s' "$untracked"
  printf '        revisa .gitignore: un patron sin barra inicial aplica a cualquier nivel\n'
  fail=1
fi

# --- los archivos que el instalador copia existen y estan versionados ---
for f in shell/pet.zsh shell/sprites-README.txt install.sh Package.swift; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    printf '  ok   %s versionado\n' "$f"
  else
    printf '  FALLA %s falta en el repo y el instalador lo necesita\n' "$f"
    fail=1
  fi
done

# --- los documentos del harness que CLAUDE.md promete ---
for f in CLAUDE.md ARCHITECTURE.md PRODUCT.md EXECUTION-PLAN.md claude-progress.md AGENTS.md; do
  if [[ -f "$f" ]]; then
    printf '  ok   %s presente\n' "$f"
  else
    printf '  FALLA falta %s\n' "$f"
    fail=1
  fi
done

# --- CLAUDE.md tiene que seguir siendo un router, no una enciclopedia ---
lines=$(wc -l < CLAUDE.md | tr -d ' ')
if (( lines <= 200 )); then
  printf '  ok   CLAUDE.md es un router (%s lineas)\n' "$lines"
else
  printf '  FALLA CLAUDE.md tiene %s lineas; dividir en rules por ruta\n' "$lines"
  fail=1
fi

# --- cero emojis en el codigo y la documentacion ---
if LC_ALL=C grep -rlP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' \
     --include='*.swift' --include='*.md' --include='*.zsh' --include='*.sh' . 2>/dev/null \
     | grep -v '^./.build' | head -1 | grep -q .; then
  printf '  FALLA hay emojis en el repo\n'
  fail=1
else
  printf '  ok   cero emojis\n'
fi

exit $fail
