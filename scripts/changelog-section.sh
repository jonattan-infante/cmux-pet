#!/usr/bin/env bash
# Imprime el cuerpo de la seccion `## [X.Y.Z]` del CHANGELOG, sin el titulo.
# Es lo que va en el mensaje del tag y en las notas del release: una sola
# fuente para los dos.
#
#   ./scripts/changelog-section.sh 0.2.0 [CHANGELOG.md]
set -euo pipefail

version="${1:-}"
file="${2:-CHANGELOG.md}"
[[ -n "$version" ]] || { echo "uso: $0 X.Y.Z [archivo]" >&2; exit 2; }

notes="$(awk -v v="$version" '
  $0 ~ "^## \\[" v "\\]" { on = 1; next }
  on && /^## \[/ { exit }
  on { print }
' "$file")"

# Sin lineas en blanco al principio ni al final: el mensaje del tag empieza
# justo despues de la primera linea y su blanco obligatorio.
notes="$(printf '%s\n' "$notes" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | awk 'NF || started { started = 1; print }')"
[[ -n "$notes" ]] || { echo "CHANGELOG no tiene la seccion [$version] o esta vacia" >&2; exit 1; }
printf '%s\n' "$notes"
