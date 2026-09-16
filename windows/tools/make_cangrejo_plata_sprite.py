# Genera los sprites "working" e "idle" del cangrejo a partir del dibujo con
# ojos de dolar y billetes en las dos tenazas (pets/cangrejo/fuente_plata.png,
# fondo verde). Misma tecnica que make_cangrejo_sprite.py: capas por region,
# rotaciones alrededor de las articulaciones, GIF con borde negro.
#
#   working: sacude la plata con energia y los ojos de dolar vibran
#   (el modo idle quedo reemplazado por make_cangrejo_idle_sprite.py)
#
# Uso: python make_cangrejo_plata_sprite.py [working|idle|all]  (usar working)

import math
import sys
from pathlib import Path

from PIL import Image, ImageFilter

import make_cangrejo_sprite as base

FRAMES = 48
MARGIN = (16, 12)
PAD = 60                    # aire alrededor de la fuente: las capas giran sin salirse del lienzo
BG_TOL = 90                 # distancia de color al verde de la esquina


def remove_background(im):
    # El verde del fondo no se parece a ningun color del personaje (los billetes
    # son un verde mas claro), asi que se borra en TODA la imagen, no solo lo
    # conectado al borde: asi caen tambien los huecos cerrados entre brazos y cuerpo.
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    cr, cg, cb = px[2, 2]
    data = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if abs(r - cr) + abs(g - cg) + abs(b - cb) > BG_TOL:
                data[y * w + x] = 255
    alpha = Image.frombytes("L", (w, h), bytes(data))
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def split_layers(im, off=0):
    # regiones en coordenadas de la imagen ORIGINAL; off compensa el PAD
    w, h = im.size
    src = im.load()
    names = ("eyes", "lclaw", "rclaw", "body")
    layers = {n: Image.new("RGBA", im.size, (0, 0, 0, 0)) for n in names}
    dst = {n: layers[n].load() for n in names}
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] == 0:
                continue
            ox, oy = x - off, y - off
            if oy < 218 and 128 <= ox <= 250:
                n = "eyes"
            elif ox < 128 and oy < 305:
                n = "lclaw"
            elif ox >= 250 and oy < 305:
                n = "rclaw"
            else:
                n = "body"
            dst[n][x, y] = p
    return layers


# (pivote, amplitud grados, frecuencia por loop, fase)
MOTION = {
    "working": {
        "eyes":  ((188, 222), 5.0, 4, 0.0),
        "lclaw": ((118, 288), 8.0, 2, 0.0),
        "rclaw": ((255, 288), 8.0, 2, 0.5),
    },
    "idle": {
        "eyes":  ((188, 222), 2.0, 1, 0.5),
        "lclaw": ((118, 288), 2.0, 1, 0.0),
        "rclaw": ((255, 288), 2.0, 1, 0.5),
    },
}
BOB = {"working": 3, "idle": 2}
ORDER = ("eyes", "body", "rclaw", "lclaw")


def render_frame(layers, i, canvas_size, mode):
    t = i / FRAMES
    frame = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    bob = round(BOB[mode] * math.sin(2 * math.pi * t))
    mx, my = MARGIN
    for name in ORDER:
        layer = layers[name]
        if name in MOTION[mode]:
            (px, py), amp, freq, ph = MOTION[mode][name]
            ang = amp * math.sin(2 * math.pi * (freq * t + ph))
            layer = layer.rotate(ang, resample=Image.BICUBIC, center=(px + PAD, py + PAD))
        frame.alpha_composite(layer, (mx, my + bob))
    return frame


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    modes = ("working", "idle") if mode == "all" else (mode,)
    pack = Path(__file__).resolve().parents[2] / "pets" / "cangrejo"
    src = Image.open(pack / "fuente_plata.png")
    im = remove_background(src)
    full = Image.new("RGBA", (src.width + 2 * PAD, src.height + 2 * PAD), (0, 0, 0, 0))
    full.alpha_composite(im, (PAD, PAD))
    layers = split_layers(full, PAD)
    canvas = (full.width + 2 * MARGIN[0], full.height + 2 * MARGIN[1])
    for m in modes:
        frames = [render_frame(layers, i, canvas, m) for i in range(FRAMES)]
        # recorta el aire sobrante (fondo verde era casi todo el lienzo)
        union = None
        for f in frames:
            bb = f.getbbox()
            union = bb if union is None else (min(union[0], bb[0]), min(union[1], bb[1]), max(union[2], bb[2]), max(union[3], bb[3]))
        pad = 6
        frames = [f.crop((union[0] - pad, union[1] - pad, union[2] + pad, union[3] + pad)) for f in frames]
        out = pack / "sprites" / f"{m}.gif"
        size, tidx = base.bake(frames, out)
        print(f"ok {out} {size} frames={FRAMES} transp_idx={tidx}")


if __name__ == "__main__":
    main()
