# Rutas del asistente en Windows. Analogo de Support/Paths.swift.
#
# Todo el estado en disco vive bajo %USERPROFILE%\.lucy, igual que la
# version de macOS usa ~/.lucy. El repo nunca escribe ahi.

import os
import shutil
from pathlib import Path

HOME = Path(os.path.expanduser("~")) / ".lucy"
# El nombre viejo del producto (cmux-pet) escribia aqui. Ver ensure_home().
LEGACY_HOME = Path(os.path.expanduser("~")) / ".cmux-pet"

CONFIG = HOME / "config.json"
SHELL_LOG = HOME / "shell.jsonl"
PID = HOME / "pet.pid"
NOTEBOOK = HOME / "notebook.json"
SPRITES = HOME / "sprites"
VOICES = HOME / "voices"
LOG = HOME / "pet.log"
REMINDER_WAV = HOME / "reminder.wav"
# Misma forma en macOS y Windows: ver docs/reference/versioning.md.
UPDATE = HOME / "update.json"


def ensure_home() -> None:
    # Migrar en vez de empezar de cero: nadie deberia perder su configuracion,
    # sus mascotas o sus frases generadas solo porque el producto cambio de
    # nombre de cmux-pet a LucyGlow.
    if not HOME.exists() and LEGACY_HOME.exists():
        try:
            shutil.move(str(LEGACY_HOME), str(HOME))
        except OSError:
            pass
    HOME.mkdir(parents=True, exist_ok=True)
    VOICES.mkdir(parents=True, exist_ok=True)


def voice_file(pet_id: str) -> Path:
    return VOICES / f"{pet_id}.json"


# Las mascotas incluidas viven en el repo, no en disco del usuario: windows/ y
# pets/ son hermanos. Se resuelve relativo a este archivo para que funcione sin
# importar desde donde se lance.
REPO_ROOT = Path(__file__).resolve().parents[2]
BUNDLED_PETS = REPO_ROOT / "pets"
