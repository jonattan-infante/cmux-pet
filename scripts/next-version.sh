#!/usr/bin/env bash
# Propone la proxima version a partir de los commits desde el ultimo tag, con
# Conventional Commits (docs/reference/tags.md):
#
#   tipo!: o BREAKING CHANGE  -> major   (mientras la version sea 0.x, minor)
#   feat:                     -> minor
#   lo demas                  -> patch
#   sin commits               -> nada que publicar, salida 1
#
# Imprime X.Y.Z por stdout y la razon por stderr, para que un script use lo uno
# y una persona lea lo otro.
set -euo pipefail

last="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)"
if [[ -n "$last" ]]; then
  base="${last#v}"
  range="$last..HEAD"
else
  base="0.0.0"
  range="HEAD"
fi
IFS=. read -r major minor patch <<< "$base"

subjects="$(git log --format='%s' "$range")"
bodies="$(git log --format='%b' "$range")"
count="$(printf '%s\n' "$subjects" | sed '/^$/d' | wc -l | tr -d ' ')"
if (( count == 0 )); then
  echo "sin commits desde ${last:-el inicio}: nada que publicar" >&2
  exit 1
fi

bump="patch"
if printf '%s\n' "$subjects" | grep -qE '^[a-z]+(\([^)]*\))?!:' \
   || printf '%s\n' "$bodies" | grep -q 'BREAKING CHANGE'; then
  bump="major"
elif printf '%s\n' "$subjects" | grep -qE '^feat(\([^)]*\))?:'; then
  bump="minor"
fi

# En 0.x todo puede cambiar: un cambio incompatible sube minor, como hace
# release-please con bump-minor-pre-major. El 1.0.0 se decide, no se calcula.
if [[ "$bump" == "major" && "$major" == "0" ]]; then
  bump="minor"
  why="cambio incompatible, pero en 0.x sube minor"
fi

case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

echo "$major.$minor.$patch"
echo "desde ${last:-el inicio}: $count commit(s), salto $bump${why:+ ($why)}" >&2
