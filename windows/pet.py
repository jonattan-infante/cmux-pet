# Punto de entrada de la mascota de Windows.
#
#   python pet.py              arranca la mascota flotante
#   python pet.py --selftest   prueba de humo sin bloquear: alimenta eventos
#                              sinteticos, verifica los estados y sale
#
# La logica vive en el paquete cmux_pet_win para que sea testeable; este archivo
# solo arranca (como main.swift en macOS).

import sys
import tkinter as tk
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from cmux_pet_win.app import App          # noqa: E402
from cmux_pet_win.config import Config    # noqa: E402
from cmux_pet_win.state import Mood        # noqa: E402
from cmux_pet_win.events import Tailer     # noqa: E402


def selftest() -> int:
    """ Construye la ventana real, le mete una secuencia de eventos por un
    archivo temporal y verifica que los estados y la burbuja responden. Prueba
    el pipeline completo (tail -> estado -> voz -> dibujo) sin abrir mainloop. """
    import json
    import tempfile

    tmp = Path(tempfile.mkdtemp()) / "shell.jsonl"
    tmp.write_text("", encoding="utf-8")

    root = tk.Tk()
    app = App(root, config=Config(), tailer=Tailer(tmp))

    def emit(ev):
        with tmp.open("a", encoding="utf-8") as f:
            f.write(json.dumps(ev) + "\n")

    def frame(now):
        mood = app.tick(now=now)
        root.update()      # fuerza el dibujo real en el canvas
        return mood

    checks = []
    t = 1000.0

    frame(t)  # arranque: saludo

    # Cada estado se prueba limpio. Se ordena para que las ventanas de tiempo no
    # se pisen: error > done por prioridad, asi que 'done' se verifica antes de
    # que exista cualquier error.
    emit({"event": "PreToolUse", "session": "a", "cwd": "C:/code/Fineract", "tool": "Bash"})
    checks.append(("working", frame(t + 1)))

    emit({"event": "Stop", "session": "a", "cwd": "C:/code/Fineract"})
    checks.append(("done", frame(t + 2)))

    emit({"event": "Notification", "session": "b", "cwd": "C:/code/Backend",
          "message": "Claude needs permission to run Bash"})
    checks.append(("attention", frame(t + 3)))

    emit({"event": "UserPromptSubmit", "session": "b"})   # respondiste: se limpia
    emit({"event": "PostToolUse", "session": "b", "cwd": "C:/code/Backend",
          "tool": "Bash", "ok": False, "exit": 1, "cmd": "npm test"})
    checks.append(("error", frame(t + 4)))

    # Hover: el roster debe listar sesiones sin reventar.
    app.window._hovering = True
    app.window.set_roster(app.sm.roster(t + 4))
    app.window.render(t + 4)
    root.update()

    idle = frame(t + 1000)   # todo decae a reposo
    checks.append(("idle", idle))

    root.destroy()

    ok = True
    for expected, got in checks:
        status = "ok" if got == expected else "FALLO"
        if got != expected:
            ok = False
        print(f"  [{status}] esperado={expected:10s} obtuvo={got}")
    print("selftest:", "OK" if ok else "FALLO")
    return 0 if ok else 1


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    root = tk.Tk()
    App(root).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
