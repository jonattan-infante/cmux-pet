# Orquestador. Analogo del PetController de macOS: conecta las fuentes (aqui,
# el tail de shell.jsonl) con el estado (los seis) y con la vista.
#
# Decide CUANDO hablar; el pet pack decide COMO. Esa separacion es la misma del
# proyecto original y es lo que hace posible reusar los packs astro/gatito tal
# cual.

import os
import time
import tkinter as tk

from . import paths, voice as voicemod
from .config import Config
from .events import Tailer
from .state import StateMachine, Mood
from .ui import PetWindow

FRAME_MS = 40                      # ~25 fps: fluido y barato


class App:
    def __init__(self, root: tk.Tk, config: Config = None, tailer: Tailer = None):
        paths.ensure_home()
        self.root = root
        self.config = config or Config.load()
        self.sm = StateMachine()
        self.tailer = tailer or Tailer(paths.SHELL_LOG)

        self.pack = self._load_pack(self.config["activePet"])
        self.voice = voicemod.Voice(self.pack)

        self.last_cwd = None
        self._last_narrate = 0.0

        self.window = PetWindow(
            root, self.pack,
            on_click=self._on_click,
            on_menu={
                "items": self._menu_items(),
                "moved": self._on_moved,
            })
        self.window.place_bottom_right(self.config.get("position"))

        # Saludo al arrancar.
        greet = self.voice.phrase("greeting", {})
        if greet and not self.config["quiet"]:
            self.window.show_bubble(greet, time.time(), seconds=5.0)

    # --- ciclo de vida ------------------------------------------------------

    def run(self):
        self._write_pid()
        self._schedule()
        try:
            self.root.mainloop()
        finally:
            self._clear_pid()

    def _schedule(self):
        self.tick()
        self.root.after(FRAME_MS, self._schedule)

    def tick(self, now=None):
        if now is None:
            now = time.time()
        for ev in self.tailer.read_new():
            self._handle(ev, now)
        self._maybe_narrate(now)
        mood = self.sm.mood(now)
        self.window.set_mood(mood)
        self.window.set_roster(self.sm.roster(now))
        self.window.render(now)
        return mood

    # --- eventos ------------------------------------------------------------

    def _handle(self, ev, now):
        ann = self.sm.ingest(ev, now)
        if ev.get("cwd"):
            self.last_cwd = ev["cwd"]
        if ann and not self.config["quiet"]:
            text = self.voice.phrase(ann.kind, ann.vars)
            if text:
                self.window.show_bubble(text, now)

    def _maybe_narrate(self, now):
        every = self.config.get("narrateEverySeconds", 150) or 0
        if every <= 0 or self.config["quiet"]:
            return
        if now - self._last_narrate < every:
            return
        ann = self.sm.working_narration(now)
        if ann:
            self._last_narrate = now
            text = self.voice.phrase(ann.kind, ann.vars)
            if text:
                self.window.show_bubble(text, now)

    # --- acciones de la vista ----------------------------------------------

    def _on_click(self):
        # En cmux el click salta al workspace; aqui, sin control de la terminal,
        # el analogo honesto es abrir la carpeta del ultimo aviso en Explorer.
        if self.last_cwd and os.path.isdir(self.last_cwd):
            try:
                os.startfile(self.last_cwd)   # noqa: solo existe en Windows
            except OSError:
                pass

    def _on_moved(self, x, y):
        self.config["position"] = [x, y]
        self.config.save()

    def _installed_pets(self):
        # Se descubren escaneando pets/: soltar una carpeta con pet.json basta,
        # sin tocar codigo. Por eso los packs locales (no versionados) aparecen.
        out = []
        if paths.BUNDLED_PETS.exists():
            for d in sorted(paths.BUNDLED_PETS.iterdir()):
                if (d / "pet.json").exists():
                    out.append(d.name)
        return out or ["astro"]

    def _menu_items(self):
        items = []
        for pid in self._installed_pets():
            mark = "  (activa)" if pid == self.config["activePet"] else ""
            items.append((f"Mascota: {pid}{mark}",
                          lambda p=pid: self._use_pet(p)))
        items.append(("-", None))
        quiet_label = "Reactivar avisos" if self.config["quiet"] else "Silenciar avisos"
        items.append((quiet_label, self._toggle_quiet))
        items.append(("-", None))
        items.append(("Salir", self._quit))
        return items

    def _use_pet(self, pid):
        if pid == self.config["activePet"]:
            return
        self.config["activePet"] = pid
        self.config.save()
        self.pack = self._load_pack(pid)
        self.voice = voicemod.Voice(self.pack)
        self.window.set_pack(self.pack)
        self.window.on_menu["items"] = self._menu_items()

    def _toggle_quiet(self):
        self.config["quiet"] = not self.config["quiet"]
        self.config.save()
        self.window.on_menu["items"] = self._menu_items()

    def _quit(self):
        self.root.destroy()

    # --- soporte ------------------------------------------------------------

    def _load_pack(self, pet_id):
        d = paths.BUNDLED_PETS / pet_id
        if not (d / "pet.json").exists():
            d = paths.BUNDLED_PETS / "astro"
        return voicemod.load_pack(d)

    def _write_pid(self):
        try:
            paths.PID.write_text(str(os.getpid()), encoding="utf-8")
        except OSError:
            pass

    def _clear_pid(self):
        try:
            paths.PID.unlink()
        except OSError:
            pass
