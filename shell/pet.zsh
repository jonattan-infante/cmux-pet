# Integracion de zsh con el asistente flotante de cmux.
#
# Reporta a ~/.lucy/shell.jsonl:
#   - comandos que tardaron mas de LUCY_MIN_SECONDS
#   - comandos que fallaron (cualquier exit code distinto de cero)
#
# Escribe con append a un archivo plano: nunca bloquea el prompt, y si el
# asistente no esta corriendo simplemente no lo lee nadie.
#
# Activar:  echo 'source ~/.lucy/shell/pet.zsh' >> ~/.zshrc

[[ -o interactive || -n ${LUCY_FORCE:-} ]] || return 0

zmodload zsh/datetime 2>/dev/null || return 0

: ${LUCY_LOG:="$HOME/.lucy/shell.jsonl"}
: ${LUCY_MIN_SECONDS:=20}
# Comandos interactivos o de larga duracion por diseno: avisar de ellos es ruido.
: ${LUCY_IGNORE:="vim nvim vi nano emacs less more man top htop btop ssh tmux screen watch tail claude codex gemini opencode lazygit gitui k9s fzf bat delta psql mysql redis-cli python3 python node irb ipython crontab visudo"}

typeset -g _lucy_cmd=""
typeset -gF _lucy_start=0

_lucy_json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  s=${s//$'\t'/\\t}
  print -r -- "$s"
}

_lucy_preexec() {
  _lucy_cmd=$1
  _lucy_start=$EPOCHREALTIME
}

_lucy_precmd() {
  local status_code=$?
  local cmd=$_lucy_cmd
  local start=$_lucy_start
  _lucy_cmd=""
  _lucy_start=0

  # Prompt vacio (enter pelado) o primer prompt de la sesion.
  [[ -z $cmd ]] && return
  (( start == 0 )) && return

  local -F elapsed=$(( EPOCHREALTIME - start ))

  # Ctrl-C y Ctrl-Z no son fallos que valga la pena reportar.
  (( status_code == 130 || status_code == 146 || status_code == 148 )) && return

  # Primer token real, saltando asignaciones de entorno y sudo/env.
  local -a words
  words=(${(z)cmd})
  local head=""
  local w
  for w in $words; do
    case $w in
      *=*)        continue ;;
      sudo|env|command|nohup|time) continue ;;
      *)          head=${w:t}; break ;;
    esac
  done
  [[ -n $head && " $LUCY_IGNORE " == *" $head "* ]] && return

  # Reportar solo lo que importa: tardo mucho, o fallo.
  if (( status_code == 0 )) && (( elapsed < LUCY_MIN_SECONDS )); then
    return
  fi

  local esc_cmd=$(_lucy_json_escape "$cmd")
  local esc_cwd=$(_lucy_json_escape "$PWD")

  printf '{"kind":"command","status":%d,"seconds":%.2f,"command":"%s","cwd":"%s","workspace":"%s","surface":"%s"}\n' \
    "$status_code" "$elapsed" "$esc_cmd" "$esc_cwd" \
    "${CMUX_WORKSPACE_ID:-}" "${CMUX_SURFACE_ID:-}" \
    >> "$LUCY_LOG" 2>/dev/null

  # Rotacion barata: el archivo es un buzon, no un historial.
  if [[ -f $LUCY_LOG ]]; then
    local size=$(zstat +size "$LUCY_LOG" 2>/dev/null || echo 0)
    (( size > 262144 )) && : > "$LUCY_LOG"
  fi
}

autoload -Uz add-zsh-hook 2>/dev/null && {
  zmodload zsh/stat 2>/dev/null
  add-zsh-hook preexec _lucy_preexec
  add-zsh-hook precmd  _lucy_precmd
}

# Arranca el asistente si no esta corriendo.
#
# Por que desde el shell y no desde launchd: cmux solo acepta control de
# procesos descendientes de cmux (socketControlMode). Un proceso lanzado por
# launchd no lo es y el socket lo rechaza en silencio. Toda terminal de cmux
# si es hija de cmux, asi que el asistente hereda el acceso.
#
# Para desactivar:  export LUCY_NO_AUTOSTART=1  antes del source.
if [[ -z ${LUCY_NO_AUTOSTART:-} && -x $HOME/.lucy/bin/lucy ]]; then
  if ! pgrep -f 'lucy/bin/lucy' >/dev/null 2>&1; then
    ( nohup "$HOME/.lucy/bin/lucy" >> "$HOME/.lucy/pet.log" 2>&1 & ) >/dev/null 2>&1
  fi
fi
