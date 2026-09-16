# Genera el sprite "idle" del cangrejo (tenazas abajo, tranquilo) a partir de
# pets/cangrejo/fuente_idle.png: fotograma de la serie ya recortado con rembg
# (mascara = u2net + isnet-anime en la zona de los tallos, porque u2net perdia
# los ojos y isnet colaba cuerda y piso). Mismo esquema de capas y horneado que
# los otros generadores; movimiento minimo: respira, mece los ojos y las tenazas.
#
# Uso: python make_cangrejo_idle_sprite.py

import math
from pathlib import Path

from PIL import Image, ImageFilter

import make_cangrejo_sprite as base

FRAMES = 48
MARGIN = (12, 10)
PAD = 40                    # aire alrededor de la fuente: las capas giran sin salirse del lienzo

# Recolor: el fotograma de la serie tiene tonos mas suaves; se llevan a la
# paleta del dibujo de la plata (working) para que ambos estados se vean del
# mismo personaje. Cada pixel se asigna al color fuente mas cercano y se escala
# canal a canal (conserva sombras y brillos). Pares (fuente, destino).
RECOLOR = [
    ((252, 82, 65), (241, 46, 50)),      # caparazon rojo
    ((116, 99, 151), (164, 133, 181)),   # pantalon morado
    ((172, 186, 203), (195, 230, 248)),  # camisa celeste
    ((200, 230, 182), (220, 235, 122)),  # tallos de los ojos
]
RECOLOR_MAXDIST = 80


def recolor(im):
    out = im.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            best, bd = None, RECOLOR_MAXDIST
            for src, dst in RECOLOR:
                d = (abs(r - src[0]) ** 2 + abs(g - src[1]) ** 2 + abs(b - src[2]) ** 2) ** 0.5
                if d < bd:
                    best, bd = (src, dst), d
            if best is None:
                continue
            src, dst = best
            px[x, y] = (min(255, round(r * dst[0] / src[0])),
                        min(255, round(g * dst[1] / src[1])),
                        min(255, round(b * dst[2] / src[2])), a)
    return out


def is_purple_or_blue(p):
    r, g, b, _ = p
    return b > r + 15 and b > 80


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
            if oy < 245 and 262 <= ox <= 385:
                n = "eyes"
            elif ox < 148 and oy >= 418 and not is_purple_or_blue(p):
                n = "lclaw"
            elif ox >= 365 and oy >= 415 and not is_purple_or_blue(p):
                n = "rclaw"
            else:
                n = "body"
            dst[n][x, y] = p
    return layers


# (pivote, amplitud grados, frecuencia por loop, fase)
MOTION = {
    "eyes":  ((315, 248), 3.0, 1, 0.5),
    "lclaw": ((150, 425), 2.0, 1, 0.0),
    "rclaw": ((385, 420), 2.0, 1, 0.5),
}
ORDER = ("eyes", "body", "rclaw", "lclaw")
BOB = 2


def render_frame(layers, i, canvas_size):
    t = i / FRAMES
    frame = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    bob = round(BOB * math.sin(2 * math.pi * t))
    mx, my = MARGIN
    for name in ORDER:
        layer = layers[name]
        if name in MOTION:
            (px, py), amp, freq, ph = MOTION[name]
            ang = amp * math.sin(2 * math.pi * (freq * t + ph))
            layer = layer.rotate(ang, resample=Image.BICUBIC, center=(px + PAD, py + PAD))
        frame.alpha_composite(layer, (mx, my + bob))
    return frame


def main():
    pack = Path(__file__).resolve().parents[2] / "pets" / "cangrejo"
    im = Image.open(pack / "fuente_idle.png").convert("RGBA")
    r, g, b, a = im.split()
    a = a.filter(ImageFilter.MinFilter(3))          # 1px de erosion: fuera el halo del fondo
    im = recolor(Image.merge("RGBA", (r, g, b, a)))
    full = Image.new("RGBA", (im.width + 2 * PAD, im.height + 2 * PAD), (0, 0, 0, 0))
    full.alpha_composite(im, (PAD, PAD))
    layers = split_layers(full, PAD)
    canvas = (full.width + 2 * MARGIN[0], full.height + 2 * MARGIN[1])
    frames = [render_frame(layers, i, canvas) for i in range(FRAMES)]
    union = None
    for f in frames:
        bb = f.getbbox()
        union = bb if union is None else (min(union[0], bb[0]), min(union[1], bb[1]), max(union[2], bb[2]), max(union[3], bb[3]))
    pad = 6
    frames = [f.crop((union[0] - pad, union[1] - pad, union[2] + pad, union[3] + pad)) for f in frames]
    out = pack / "sprites" / "idle.gif"
    size, tidx = base.bake(frames, out)
    print(f"ok {out} {size} frames={FRAMES} transp_idx={tidx}")


if __name__ == "__main__":
    main()
