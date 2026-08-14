# La mascota flotante en tkinter. Analogo de Views/ (PetView, BubbleView,
# RosterView) del proyecto macOS, pero con Canvas en vez de AppKit.
#
# Truco de transparencia en Windows: -transparentcolor hace que un color magico
# se vuelva invisible Y click-through, asi la ventana no se come los clicks fuera
# del cuerpo de la mascota. Es el equivalente al hitTest que devuelve nil en las
# zonas transparentes (limite duro 13 del proyecto).

import math
import tkinter as tk
from tkinter import font as tkfont

from .state import Mood, DEFAULT_ACCENT, rgb_to_hex, blend

TRANSPARENT = "#ff00ff"     # magenta: color que desaparece y deja pasar el click
STEEL = "#B2BAC6"
STEEL_DARK = "#586273"
INK = "#1E222C"
BUBBLE_BG = "#1B1E27"
BUBBLE_FG = "#EEF1F6"

# Caja del cuerpo dentro del canvas y margenes al borde de pantalla.
BODY_W, BODY_H = 104, 120
CANVAS_W, CANVAS_H = 440, 300
MARGIN = 24


def accent_hex(mood, pack) -> str:
    rgb = None
    if pack and mood in getattr(pack, "accents", {}):
        rgb = pack.accents[mood]
    if rgb is None:
        rgb = DEFAULT_ACCENT.get(mood, DEFAULT_ACCENT[Mood.IDLE])
    return rgb_to_hex(rgb)


class PetWindow:
    """ La ventana. No sabe de eventos de Claude Code: recibe mood, texto de
    burbuja y roster ya resueltos, y los dibuja. """

    def __init__(self, root: tk.Tk, pack, on_click=None, on_menu=None):
        self.root = root
        self.pack = pack
        self.on_click = on_click
        self.on_menu = on_menu or {}

        self.mood = Mood.IDLE
        self.phase = 0.0
        self._bubble_text = ""
        self._bubble_until = 0.0
        self._roster = []
        self._hovering = False
        self._drag = None

        root.overrideredirect(True)
        root.attributes("-topmost", True)
        try:
            root.attributes("-transparentcolor", TRANSPARENT)
        except tk.TclError:
            pass
        root.config(bg=TRANSPARENT)

        self.canvas = tk.Canvas(root, width=CANVAS_W, height=CANVAS_H,
                                bg=TRANSPARENT, highlightthickness=0, bd=0)
        self.canvas.pack()

        self._font = tkfont.Font(family="Segoe UI", size=10)
        self._font_bold = tkfont.Font(family="Segoe UI", size=10, weight="bold")

        # El cuerpo vive en la esquina inferior derecha del canvas.
        self.body_cx = CANVAS_W - MARGIN - BODY_W / 2
        self.body_bottom = CANVAS_H - MARGIN

        self._bind()

    # --- API que usa la app -------------------------------------------------

    def set_pack(self, pack):
        self.pack = pack

    def set_mood(self, mood):
        self.mood = mood

    def show_bubble(self, text, now, seconds=6.0):
        if text:
            self._bubble_text = text
            self._bubble_until = now + seconds

    def set_roster(self, rows):
        self._roster = rows

    def place_bottom_right(self, position=None):
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        if position:
            x, y = position
        else:
            x = sw - CANVAS_W
            y = sh - CANVAS_H - 40   # deja hueco sobre la barra de tareas
        self.root.geometry(f"{CANVAS_W}x{CANVAS_H}+{int(x)}+{int(y)}")

    def render(self, now):
        self.phase += 0.05
        self.canvas.delete("all")
        blink = (int(self.phase * 2) % 37) == 0
        self._draw_droid(blink)
        if self._hovering and self._roster:
            self._draw_roster()
        elif self._bubble_text and now < self._bubble_until:
            self._draw_bubble(self._bubble_text)

    # --- dibujo del droide --------------------------------------------------

    def _draw_droid(self, blink):
        c = self.canvas
        accent = accent_hex(self.mood, self.pack)
        bx = self.body_cx - BODY_W / 2
        by_top = self.body_bottom - BODY_H
        dome_h = BODY_W * 0.42
        torso_top = by_top + dome_h
        torso = (bx + 7, torso_top, bx + BODY_W - 7, self.body_bottom - 12)
        tx0, ty0, tx1, ty1 = torso
        tmid_x = (tx0 + tx1) / 2
        tmid_y = (ty0 + ty1) / 2

        sway = self._dome_sway()

        # Sombra en el piso: ancla la mascota.
        c.create_oval(bx + 10, self.body_bottom - 4, bx + BODY_W - 10,
                      self.body_bottom + 6, fill="#0A0C10", outline="")

        # Patas (dos traseras + una central), antes del torso.
        self._leg(tx0 + 5, bx + 4, ty1 - 6)
        self._leg(tx1 - 5, bx + BODY_W - 4, ty1 - 6)
        c.create_rectangle(tmid_x - 3, ty1 - 4, tmid_x + 3, self.body_bottom - 2,
                           fill=STEEL_DARK, outline="")
        c.create_rectangle(tmid_x - 8, self.body_bottom - 6, tmid_x + 8,
                           self.body_bottom, fill=INK, outline="")

        # Torso.
        c.create_rectangle(tx0, ty0, tx1, ty1, fill=STEEL, outline=INK, width=1)
        c.create_rectangle(tx0, ty0, tx0 + (tx1 - tx0) * 0.28, ty1,
                           fill=self._shade(STEEL, 0.10), outline="")   # sombra lateral
        # Banda central.
        c.create_rectangle(tx0, tmid_y, tx1, tmid_y + 4, fill=STEEL_DARK, outline="")
        # Rejilla inferior.
        for i in range(4):
            gx = tx0 + 5 + i * 7.5
            c.create_rectangle(gx, ty1 - 9, gx + 4, ty1 - 4, fill=STEEL_DARK, outline="")

        # Panel de color: el unico elemento del torso que cambia con el estado.
        c.create_rectangle(tx0 + 4, tmid_y - 12, tx0 + 16, tmid_y - 1,
                           fill=accent, outline=INK, width=1)
        c.create_rectangle(tx1 - 16, tmid_y - 11, tx1 - 4, tmid_y - 2,
                           fill=STEEL_DARK, outline="")

        # Luces de estado: parpadean en secuencia solo mientras trabaja.
        lights = ["#F25A5A", "#FAC84D", "#66CCF2"]
        for i, col in enumerate(lights):
            if self.mood == Mood.WORKING:
                on = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(self.phase * 6 - i * 1.1))
            else:
                on = 0.5
            lx = tx0 + 6 + i * 6
            c.create_oval(lx, ty0 + 4, lx + 3.6, ty0 + 7.6,
                          fill=self._dim(col, on), outline="")

        # Cupula (semicirculo).
        dome_cx = tmid_x + sway * 0.35
        dome_r = (tx1 - tx0) / 2 + 1
        c.create_arc(dome_cx - dome_r, torso_top - dome_r, dome_cx + dome_r,
                     torso_top + dome_r, start=0, extent=180,
                     fill=STEEL, outline=INK, width=1, style=tk.PIESLICE)
        # Franja de la cupula, tenida por el estado.
        c.create_arc(dome_cx - dome_r + 5, torso_top - dome_r + 5,
                     dome_cx + dome_r - 5, torso_top + dome_r - 5,
                     start=118 - sway, extent=34, style=tk.ARC,
                     outline=accent, width=3)

        # Lente: aro oscuro + ojo tenido que late cuando hay algo que atender.
        lens_x = dome_cx + sway
        lens_y = torso_top - dome_r * 0.42
        c.create_oval(lens_x - 8.5, lens_y - 8.5, lens_x + 8.5, lens_y + 8.5,
                      fill=INK, outline=STEEL_DARK, width=1)
        glow = 0.25 if blink else 1.0
        if self.mood == Mood.ATTENTION:
            glow *= 0.65 + 0.35 * (0.5 + 0.5 * math.sin(self.phase * 6))
        elif self.mood == Mood.ERROR:
            glow *= 0.4 + 0.6 * (1.0 if math.sin(self.phase * 14) > 0 else 0.35)
        # Halo (dos ovalos tenues) + nucleo.
        c.create_oval(lens_x - 7, lens_y - 7, lens_x + 7, lens_y + 7,
                      fill=self._dim(accent, 0.30 * glow), outline="")
        c.create_oval(lens_x - 5, lens_y - 5, lens_x + 5, lens_y + 5,
                      fill=self._dim(accent, glow), outline="")
        c.create_oval(lens_x - 3.2, lens_y - 3.2, lens_x - 0.8, lens_y - 0.8,
                      fill=self._dim("#FFFFFF", 0.85 * glow), outline="")

        # Signo de admiracion cuando te necesita.
        if self.mood == Mood.ATTENTION:
            ex = tx1 + 6
            ey = ty0 - 6
            c.create_text(ex, ey, text="!", fill=accent, font=self._font_bold)

    def _leg(self, top_x, bot_x, top_y):
        c = self.canvas
        c.create_line(top_x, top_y, bot_x, self.body_bottom - 6,
                      fill=STEEL_DARK, width=6, capstyle=tk.ROUND)
        c.create_rectangle(bot_x - 6, self.body_bottom - 6, bot_x + 6,
                           self.body_bottom, fill=INK, outline="")

    def _dome_sway(self):
        p = self.phase
        if self.mood == Mood.WORKING:
            return math.sin(p * 2.6) * 6
        if self.mood == Mood.ATTENTION:
            return math.sin(p * 5.0) * 3
        if self.mood == Mood.ERROR:
            return math.sin(p * 1.2) * 2
        return math.sin(p * 0.7) * 5

    # --- burbuja y roster ---------------------------------------------------

    def _draw_bubble(self, text):
        c = self.canvas
        anchor_x = self.body_cx - BODY_W / 2 - 8
        anchor_y = self.body_bottom - BODY_H - 6
        pad = 10
        maxw = 300
        # Crear el texto primero para medirlo, luego el globo detras.
        t = c.create_text(0, 0, text=text, anchor="nw", width=maxw,
                          fill=BUBBLE_FG, font=self._font)
        x0, y0, x1, y1 = c.bbox(t)
        w = (x1 - x0) + pad * 2
        h = (y1 - y0) + pad * 2
        bx1 = anchor_x
        by1 = anchor_y
        bx0 = bx1 - w
        by0 = by1 - h
        c.delete(t)
        self._round_rect(bx0, by0, bx1, by1, 10, fill=BUBBLE_BG, outline=STEEL_DARK)
        # Colita hacia la mascota.
        c.create_polygon(bx1 - 22, by1 - 1, bx1 - 6, by1 - 1, bx1 - 4, by1 + 12,
                         fill=BUBBLE_BG, outline="")
        c.create_text(bx0 + pad, by0 + pad, text=text, anchor="nw", width=maxw,
                      fill=BUBBLE_FG, font=self._font)

    def _draw_roster(self):
        c = self.canvas
        rows = self._roster[:6]
        pad = 10
        line_h = 18
        w = 260
        h = pad * 2 + line_h * (len(rows) + 1)
        bx1 = self.body_cx - BODY_W / 2 - 8
        by1 = self.body_bottom - BODY_H - 6
        bx0 = bx1 - w
        by0 = by1 - h
        self._round_rect(bx0, by0, bx1, by1, 10, fill=BUBBLE_BG, outline=STEEL_DARK)
        c.create_text(bx0 + pad, by0 + pad, anchor="nw", fill=STEEL,
                      font=self._font_bold, text="Agentes")
        y = by0 + pad + line_h
        for r in rows:
            dot = "#FA8C33" if r["attention"] else accent_hex(
                Mood.WORKING if r["doing"] not in ("en reposo",) else Mood.IDLE, self.pack)
            c.create_oval(bx0 + pad, y + 4, bx0 + pad + 8, y + 12, fill=dot, outline="")
            label = f"{r['workspace']}  {r['doing']}  ({r['steps']})"
            c.create_text(bx0 + pad + 16, y, anchor="nw", fill=BUBBLE_FG,
                          font=self._font, text=label)
            y += line_h

    def _round_rect(self, x0, y0, x1, y1, r, **kw):
        pts = [x0 + r, y0, x1 - r, y0, x1, y0, x1, y0 + r, x1, y1 - r, x1, y1,
               x1 - r, y1, x0 + r, y1, x0, y1, x0, y1 - r, x0, y0 + r, x0, y0]
        return self.canvas.create_polygon(pts, smooth=True, **kw)

    # --- color helpers ------------------------------------------------------

    def _dim(self, hexcol, alpha):
        # tkinter no tiene alpha por item: se simula mezclando contra el fondo.
        alpha = max(0.0, min(1.0, alpha))
        h = hexcol.lstrip("#")
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        bg = 0x1B, 0x1E, 0x27
        r = int(r * alpha + bg[0] * (1 - alpha))
        g = int(g * alpha + bg[1] * (1 - alpha))
        b = int(b * alpha + bg[2] * (1 - alpha))
        return "#%02X%02X%02X" % (r, g, b)

    def _shade(self, hexcol, frac):
        rgb = tuple(int(hexcol.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4))
        return rgb_to_hex(blend(rgb, frac))

    # --- interaccion --------------------------------------------------------

    def _bind(self):
        c = self.canvas
        c.bind("<Enter>", self._on_enter)
        c.bind("<Leave>", self._on_leave)
        c.bind("<ButtonPress-1>", self._on_press)
        c.bind("<B1-Motion>", self._on_move)
        c.bind("<ButtonRelease-1>", self._on_release)
        c.bind("<Button-3>", self._on_right)

    def _in_body(self, x, y):
        return (abs(x - self.body_cx) < BODY_W / 2 + 10 and
                self.body_bottom - BODY_H - 10 < y < self.body_bottom + 10)

    def _on_enter(self, _):
        self._hovering = True

    def _on_leave(self, _):
        self._hovering = False

    def _on_press(self, e):
        if self._in_body(e.x, e.y):
            self._drag = (e.x_root, e.y_root, self.root.winfo_x(),
                          self.root.winfo_y(), False)

    def _on_move(self, e):
        if not self._drag:
            return
        dx = e.x_root - self._drag[0]
        dy = e.y_root - self._drag[1]
        moved = self._drag[4] or abs(dx) > 3 or abs(dy) > 3
        self._drag = (self._drag[0], self._drag[1], self._drag[2], self._drag[3], moved)
        self.root.geometry(f"+{self._drag[2] + dx}+{self._drag[3] + dy}")

    def _on_release(self, e):
        if self._drag:
            _, _, _, _, moved = self._drag
            self._drag = None
            if moved and callable(self.on_menu.get("moved")):
                self.on_menu["moved"](self.root.winfo_x(), self.root.winfo_y())
            elif not moved and callable(self.on_click):
                self.on_click()

    def _on_right(self, e):
        menu = tk.Menu(self.root, tearoff=0)
        for label, cb in (self.on_menu.get("items") or []):
            if label == "-":
                menu.add_separator()
            else:
                menu.add_command(label=label, command=cb)
        try:
            menu.tk_popup(e.x_root, e.y_root)
        finally:
            menu.grab_release()
