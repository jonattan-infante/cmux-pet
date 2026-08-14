# Voz de la mascota activa y carga del pet pack. Puerto de Voice/Voice.swift y
# de la parte de carga de Model/PetPack.swift que necesita la mascota.
#
# Las frases no viven en el codigo: cada pack trae phrases.json (respaldo) y,
# si Claude Code las genero, viven en ~/.cmux-pet/voices/<id>.json. Este modulo
# NO genera frases (eso es trabajo del CLI de macOS); solo las carga y rellena.

import json
import random
from pathlib import Path
from typing import Optional

from . import paths

# Marcadores obligatorios de cada clase. Identico a Voice.kinds en Swift: es el
# vocabulario compartido entre generador, validador y formato de pack.
KINDS = {
    "agentDone":    {"agent", "where"},
    "commandDone":  {"cmd", "time", "where"},
    "commandError": {"cmd", "code", "where"},
    "attention":    {"agent", "what", "where"},
    "working":      {"agent", "doing", "time", "where"},
    "portUp":       {"port", "where"},
    "portDown":     {"port", "where"},
    "greeting":     set(),
}

_ALLOWED = set().union(*KINDS.values())


class Pack:
    def __init__(self, pet_id, name, accents, fallback, persona, language, renderer):
        self.id = pet_id
        self.name = name
        self.accents = accents          # {mood: (r,g,b)} normalizado
        self.fallback = fallback        # {kind: [templates]}
        self.persona = persona
        self.language = language
        self.renderer = renderer        # "vector:droid" | "vector:ball" | ...


def load_pack(pack_dir: Path) -> Pack:
    """ Carga y valida lo minimo de un pet pack. Frontera del sistema: lo
    escribe un tercero, asi que se valida antes de confiar. """
    pack_dir = Path(pack_dir)
    manifest = json.loads((pack_dir / "pet.json").read_text(encoding="utf-8"))

    pet_id = manifest["id"]
    name = manifest.get("name", pet_id)
    language = manifest.get("language", "es")
    renderer = manifest.get("renderer", "vector:droid")

    accents = {}
    for mood, hexv in (manifest.get("accent") or {}).items():
        rgb = _hex_to_rgb(hexv)
        if rgb is not None:
            accents[mood] = rgb

    fallback = {}
    phrases_path = pack_dir / "phrases.json"
    if phrases_path.exists():
        raw = json.loads(phrases_path.read_text(encoding="utf-8"))
        fallback = validate(raw)

    persona = None
    persona_path = pack_dir / "persona.md"
    if persona_path.exists():
        persona = persona_path.read_text(encoding="utf-8")

    return Pack(pet_id, name, accents, fallback, persona, language, renderer)


def validate(raw: dict) -> dict:
    """ Solo sobreviven las plantillas que usan todos sus marcadores y ninguno
    inventado. Puerto de Voice.validate. Sin esto, se veria '{time}' literal. """
    out = {}
    if not isinstance(raw, dict):
        return out
    for kind, required in KINDS.items():
        lst = raw.get(kind)
        if not isinstance(lst, list):
            continue
        good = [t for t in lst if _template_ok(t, required)]
        if good:
            out[kind] = good
    return out


def _template_ok(t, required) -> bool:
    if not isinstance(t, str) or len(t) > 220 or "\n" in t:
        return False
    for r in required:
        if "{" + r + "}" not in t:
            return False
    # Ningun marcador fuera del vocabulario.
    scan = t
    while "{" in scan:
        i = scan.index("{")
        j = scan.find("}", i)
        if j == -1:
            break
        name = scan[i + 1:j]
        if name not in _ALLOWED:
            return False
        scan = scan[j + 1:]
    return True


class Voice:
    def __init__(self, pack: Pack, rng: Optional[random.Random] = None):
        self.pack = pack
        self.fallback = pack.fallback
        self.generated = {}
        self._last_pick = {}
        self._rng = rng or random.Random()
        self._load_generated()

    def _load_generated(self) -> None:
        vf = paths.voice_file(self.pack.id)
        if vf.exists():
            try:
                raw = json.loads(vf.read_text(encoding="utf-8"))
                self.generated = validate(raw)
            except (ValueError, OSError):
                self.generated = {}

    def phrase(self, kind: str, vars: dict) -> Optional[str]:
        """ Rellena una plantilla. Lo generado gana; el respaldo cubre huecos.
        None solo si la mascota no tiene nada para esa clase. """
        options = self.generated.get(kind) or self.fallback.get(kind) or []
        if not options:
            return None
        i = self._rng.randrange(len(options))
        if len(options) > 1 and self._last_pick.get(kind) == i:
            i = (i + 1) % len(options)
        self._last_pick[kind] = i
        s = options[i]
        for k, v in vars.items():
            s = s.replace("{" + k + "}", v)
        return s.replace("  ", " ")


def _hex_to_rgb(hexv):
    if not isinstance(hexv, str):
        return None
    h = hexv.lstrip("#")
    if len(h) != 6:
        return None
    try:
        return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255)
    except ValueError:
        return None
