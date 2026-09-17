# Rutas del asistente en Windows. Analogo de Support/Paths.swift.
#
# Todo el estado en disco vive bajo %USERPROFILE%\.cmux-pet, igual que la
# version de macOS usa ~/.cmux-pet. El repo nunca escribe ahi.

import os
from pathlib import Path

HOME = Path(os.path.expanduser("~")) / ".cmux-pet"

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
    HOME.mkdir(parents=True, exist_ok=True)
    VOICES.mkdir(parents=True, exist_ok=True)


def voice_file(pet_id: str) -> Path:
    return VOICES / f"{pet_id}.json"


# Las mascotas incluidas viven en el repo, no en disco del usuario: windows/ y
# pets/ son hermanos. Se resuelve relativo a este archivo para que funcione sin
# importar desde donde se lance.
REPO_ROOT = Path(__file__).resolve().parents[2]
BUNDLED_PETS = REPO_ROOT / "pets"
