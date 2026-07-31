# Integracion de zsh con el asistente flotante de cmux.
#
# Reporta a ~/.cmux-pet/shell.jsonl:
#   - comandos que tardaron mas de CMUX_PET_MIN_SECONDS
#   - comandos que fallaron (cualquier exit code distinto de cero)
#
# Escribe con append a un archivo plano: nunca bloquea el prompt, y si el
# asistente no esta corriendo simplemente no lo lee nadie.
#
# Activar:  echo 'source ~/.cmux-pet/shell/pet.zsh' >> ~/.zshrc

[[ -o interactive || -n ${CMUX_PET_FORCE:-} ]] || return 0

zmodload zsh/datetime 2>/dev/null || return 0

: ${CMUX_PET_LOG:="$HOME/.cmux-pet/shell.jsonl"}
: ${CMUX_PET_MIN_SECONDS:=20}
# Comandos interactivos o de larga duracion por diseno: avisar de ellos es ruido.
: ${CMUX_PET_IGNORE:="vim nvim vi nano emacs less more man top htop btop ssh tmux screen watch tail claude codex gemini opencode lazygit gitui k9s fzf bat delta psql mysql redis-cli python3 python node irb ipython crontab visudo"}

typeset -g _cmux_pet_cmd=""
typeset -gF _cmux_pet_start=0

_cmux_pet_json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  s=${s//$'\t'/\\t}
  print -r -- "$s"
}

_cmux_pet_preexec() {
  _cmux_pet_cmd=$1
  _cmux_pet_start=$EPOCHREALTIME
}

_cmux_pet_precmd() {
  local status_code=$?
  local cmd=$_cmux_pet_cmd
  local start=$_cmux_pet_start
  _cmux_pet_cmd=""
  _cmux_pet_start=0

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
  [[ -n $head && " $CMUX_PET_IGNORE " == *" $head "* ]] && return

  # Reportar solo lo que importa: tardo mucho, o fallo.
  if (( status_code == 0 )) && (( elapsed < CMUX_PET_MIN_SECONDS )); then
    return
  fi

  local esc_cmd=$(_cmux_pet_json_escape "$cmd")
  local esc_cwd=$(_cmux_pet_json_escape "$PWD")

  printf '{"kind":"command","status":%d,"seconds":%.2f,"command":"%s","cwd":"%s","workspace":"%s","surface":"%s"}\n' \
    "$status_code" "$elapsed" "$esc_cmd" "$esc_cwd" \
    "${CMUX_WORKSPACE_ID:-}" "${CMUX_SURFACE_ID:-}" \
    >> "$CMUX_PET_LOG" 2>/dev/null

  # Rotacion barata: el archivo es un buzon, no un historial.
  if [[ -f $CMUX_PET_LOG ]]; then
    local size=$(zstat +size "$CMUX_PET_LOG" 2>/dev/null || echo 0)
    (( size > 262144 )) && : > "$CMUX_PET_LOG"
  fi
}

autoload -Uz add-zsh-hook 2>/dev/null && {
  zmodload zsh/stat 2>/dev/null
  add-zsh-hook preexec _cmux_pet_preexec
  add-zsh-hook precmd  _cmux_pet_precmd
}

# Arranca el asistente si no esta corriendo.
#
# Por que desde el shell y no desde launchd: cmux solo acepta control de
# procesos descendientes de cmux (socketControlMode). Un proceso lanzado por
# launchd no lo es y el socket lo rechaza en silencio. Toda terminal de cmux
# si es hija de cmux, asi que el asistente hereda el acceso.
#
# Para desactivar:  export CMUX_PET_NO_AUTOSTART=1  antes del source.
if [[ -z ${CMUX_PET_NO_AUTOSTART:-} && -x $HOME/.cmux-pet/bin/cmux-pet ]]; then
  if ! pgrep -f 'cmux-pet/bin/cmux-pet' >/dev/null 2>&1; then
    ( nohup "$HOME/.cmux-pet/bin/cmux-pet" >> "$HOME/.cmux-pet/pet.log" 2>&1 & ) >/dev/null 2>&1
  fi
fi
