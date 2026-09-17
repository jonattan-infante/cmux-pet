#!/usr/bin/env bash
# Borrador de la seccion del CHANGELOG para la proxima version, a partir de los
# commits desde el ultimo tag. Conventional Commits -> Keep a Changelog
# (docs/reference/tags.md). Es un borrador: se pega y se reescribe para quien
# usa el programa.
#
#   ./scripts/release-notes.sh [X.Y.Z]     sin argumento, usa next-version.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:-$("$ROOT/scripts/next-version.sh" 2>/dev/null || echo "X.Y.Z")}"

last="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)"
range="${last:+$last..HEAD}"
range="${range:-HEAD}"

# Quita el prefijo del commit y la referencia al PR; pone mayuscula y punto,
# porque una nota es una oracion y un commit no.
section() {
  local title="$1" re="$2" lines
  lines="$(git log --format='%s' "$range" | grep -E "$re" \
    | sed -E 's/^[a-z]+(\([^)]*\))?!?: //; s/ \(#[0-9]+\)$//' \
    | awk '{ print "- " toupper(substr($0, 1, 1)) substr($0, 2) "." }' || true)"
  [[ -n "$lines" ]] || return 0
  printf '### %s\n\n%s\n\n' "$title" "$lines"
}

printf '## [%s] — %s\n\n' "$version" "$(date +%Y-%m-%d)"
section "Incompatible"  '^[a-z]+(\([^)]*\))?!:'
section "Agregado"      '^feat(\([^)]*\))?:'
section "Cambiado"      '^(refactor|perf|revert)(\([^)]*\))?:'
section "Corregido"     '^fix(\([^)]*\))?:'
section "Documentación" '^docs(\([^)]*\))?:'
