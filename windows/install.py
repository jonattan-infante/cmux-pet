# Instalador de cmux-pet para Windows.
#
# Registra los hooks de Claude Code que alimentan a la mascota y prepara
# %USERPROFILE%\.cmux-pet. Idempotente: correrlo dos veces no duplica nada.
#
#   python install.py            # instalar los hooks en ~/.claude/settings.json
#   python install.py --uninstall
#   python install.py --settings <ruta>   # para pruebas
#
# El instalador va en Python (no en PowerShell) porque Python ya es requisito de
# la mascota y el merge de settings.json es mas seguro asi. El hook en si
# (cmux-pet-hook.ps1) si es PowerShell: lo ejecuta Claude Code en cada evento.

import argparse
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOOK = HERE / "hooks" / "cmux-pet-hook.ps1"

# Todos los eventos que la mascota entiende. Los de herramienta llevan matcher "".
TOOL_EVENTS = ["PreToolUse", "PostToolUse"]
PLAIN_EVENTS = ["SessionStart", "SessionEnd", "UserPromptSubmit",
                "Notification", "Stop", "SubagentStop"]
ALL_EVENTS = TOOL_EVENTS + PLAIN_EVENTS

MARK = "cmux-pet-hook.ps1"   # firma para reconocer nuestros hooks al desinstalar


def hook_command(hook_path: Path) -> str:
    return ('powershell -NoProfile -ExecutionPolicy Bypass -File '
            f'"{hook_path}"')


def _has_our_hook(entries) -> bool:
    for entry in entries or []:
        for h in entry.get("hooks", []):
            if MARK in str(h.get("command", "")):
                return True
    return False


def _strip_our_hooks(entries):
    out = []
    for entry in entries or []:
        kept = [h for h in entry.get("hooks", []) if MARK not in str(h.get("command", ""))]
        if kept:
            e = dict(entry)
            e["hooks"] = kept
            out.append(e)
    return out


def merge(settings: dict, hook_path: Path, uninstall: bool = False) -> dict:
    """ Devuelve settings con nuestros hooks agregados (o quitados). Idempotente:
    no duplica, y respeta cualquier hook ajeno que ya exista. """
    settings = dict(settings or {})
    hooks = dict(settings.get("hooks") or {})
    cmd = hook_command(hook_path)

    for event in ALL_EVENTS:
        entries = list(hooks.get(event) or [])
        entries = _strip_our_hooks(entries)   # siempre limpiamos los nuestros primero
        if not uninstall:
            spec = {"type": "command", "command": cmd}
            if event in TOOL_EVENTS:
                entries.append({"matcher": "", "hooks": [spec]})
            else:
                entries.append({"hooks": [spec]})
        if entries:
            hooks[event] = entries
        else:
            hooks.pop(event, None)

    if hooks:
        settings["hooks"] = hooks
    else:
        settings.pop("hooks", None)
    return settings


def default_settings_path() -> Path:
    return Path(os.path.expanduser("~")) / ".claude" / "settings.json"


def load_settings(path: Path) -> dict:
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except ValueError:
            print(f"aviso: {path} no es JSON valido; se respalda y se recrea",
                  file=sys.stderr)
            path.replace(path.with_suffix(".json.bak"))
    return {}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Instala los hooks de cmux-pet para Claude Code")
    ap.add_argument("--uninstall", action="store_true")
    ap.add_argument("--settings", default=None, help="ruta a settings.json (default ~/.claude)")
    args = ap.parse_args(argv)

    if not HOOK.exists():
        print(f"error: no encuentro el hook en {HOOK}", file=sys.stderr)
        return 1

    settings_path = Path(args.settings) if args.settings else default_settings_path()
    settings_path.parent.mkdir(parents=True, exist_ok=True)

    settings = load_settings(settings_path)
    updated = merge(settings, HOOK, uninstall=args.uninstall)
    settings_path.write_text(json.dumps(updated, indent=2, ensure_ascii=False),
                             encoding="utf-8")

    # Preparar el estado en disco de la mascota.
    petdir = Path(os.path.expanduser("~")) / ".cmux-pet"
    (petdir / "voices").mkdir(parents=True, exist_ok=True)

    if args.uninstall:
        print(f"listo: hooks de cmux-pet quitados de {settings_path}")
        return 0

    print(f"listo: hooks de cmux-pet instalados en {settings_path}")
    print("")
    print("La mascota arranca sola en tu proxima sesion de Claude Code.")
    print("Para lanzarla ahora mismo:")
    print(f"    python \"{HERE / 'pet.py'}\"")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
