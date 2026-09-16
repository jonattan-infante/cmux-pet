# Genera pets/cangrejo/sprites/dance.gif a partir de un dibujo estatico del
# cangrejo (JPG/PNG con fondo blanco). Separa el dibujo en capas (ojos, pinza
# izquierda, pinza derecha, cuerpo) por regiones y color, y anima cada capa
# con rotaciones pequenas alrededor de su articulacion. Salida: GIF con
# transparencia por indice, borde duro, ~150px de alto (igual que la llama).
#
# Uso: python make_cangrejo_sprite.py <imagen> [modo] [salida.gif]
#   modo: dance (baila, por defecto) | working (tira billetes al aire) | idle (tenazas abajo)

import math
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

FRAMES = 48
DURATION_MS = 40
OUT_H = 150
OUTLINE_PX = 1             # borde negro alrededor de la silueta (se ve sobre fondos blancos)
MARGIN = (60, 30)          # (x, y) espacio extra para que las pinzas no se corten
BG_TOL = 232               # blanco de fondo: canales >= esto, conectado al borde


def remove_background(im: Image.Image) -> Image.Image:
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    bg = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or bg[y * w + x]:
            continue
        r, g, b = px[x, y]
        if min(r, g, b) < BG_TOL:
            continue
        bg[y * w + x] = 1
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    alpha = Image.frombytes("L", (w, h), bytes(0 if v else 255 for v in bg))
    # 1px de erosion para tragarse el borde claro que deja el JPG contra el blanco
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def is_red(p):
    r, g, b, _ = p
    return r > 150 and g < 110 and b < 110


def is_blue(p):
    r, g, b, _ = p
    return b > r + 25 and b > 90


def split_layers(im: Image.Image):
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
            in_stalks = (y < 330 and 280 <= x <= 470) or (330 <= y < 352 and 330 <= x <= 425)
            if in_stalks and not is_red(p):
                n = "eyes"
            elif x < 245 and y < 475:
                n = "lclaw"
            elif x >= 530 and y >= 415 and not is_blue(p):
                n = "rclaw"
            else:
                n = "body"
            dst[n][x, y] = p
    return layers


# (capa, pivote, amplitud grados, frecuencia por loop, fase, angulo de reposo)
# El angulo de reposo gira la capa de forma fija (positivo = antihorario en
# pantalla); sirve para bajar la pinza alzada en el modo idle.
IDLE_CLAW_REST = 100.0
MOTION = {
    "dance": {
        "eyes":  ((375, 345), 4.0, 1, 0.5, 0.0),
        "lclaw": ((245, 440), 9.0, 2, 0.0, 0.0),
        "rclaw": ((530, 435), 2.5, 1, 0.25, 0.0),
    },
    # trabajando: la pinza alzada sacude mas rapido (esta lanzando plata) y
    # los ojos siguen los billetes
    "working": {
        "eyes":  ((375, 345), 6.0, 3, 0.25, 0.0),
        "lclaw": ((245, 440), 12.0, 3, 0.0, 0.0),
        "rclaw": ((530, 435), 3.0, 1, 0.25, 0.0),
    },
    # sin hacer nada: las dos tenazas abajo, apenas se mecen
    "idle": {
        "eyes":  ((375, 345), 3.0, 1, 0.5, 0.0),
        "lclaw": ((245, 440), 3.0, 1, 0.0, IDLE_CLAW_REST),
        "rclaw": ((530, 435), 2.0, 1, 0.5, 0.0),
    },
}
ORDER = ("eyes", "bills", "body", "rclaw", "lclaw")   # ojos detras: la cabeza tapa la base; billetes detras del cuerpo

# Billetes: se emiten desde la pinza alzada, suben y caen en parabola. Vida de
# un loop entero y emision cada FRAMES/N cuadros, asi el ciclo cierra sin salto.
BILL_W, BILL_H = 90, 48
BILL_LIFE = 2 * FRAMES        # vida en cuadros: dos loops
BILL_N = 6                    # k y k+3 comparten trayectoria, desfasados un loop -> ciclo cerrado
BILL_ORIGIN = (120, 250)
BILL_VX = (-1.6, -0.4, 1.0)
BILL_VY = -16.0
BILL_G = 0.4603               # llega al piso del lienzo justo al morir
WAD_POS = (612, 548)          # fajo que sostiene la pinza baja (coords fuente)


def draw_bill(angle=0.0, scale=1.0):
    w, h = round(BILL_W * scale), round(BILL_H * scale)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o = max(2, round(4 * scale))
    d.rectangle([0, 0, w - 1, h - 1], fill=(20, 20, 20, 255))
    d.rectangle([o, o, w - 1 - o, h - 1 - o], fill=(96, 190, 105, 255))
    m = round(8 * scale)
    d.rectangle([m, m, w - 1 - m, h - 1 - m], outline=(50, 130, 62, 255), width=max(1, round(2 * scale)))
    r = round(h * 0.28)
    d.ellipse([w // 2 - r, h // 2 - r, w // 2 + r, h // 2 + r], fill=(160, 225, 165, 255), outline=(50, 130, 62, 255), width=max(1, round(2 * scale)))
    if angle:
        im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
    return im


def attach_wad(rclaw):
    """ Fajo de billetes pegado a la pinza baja (rota con ella). """
    out = rclaw.copy()
    x, y = WAD_POS
    for k in range(3):
        b = draw_bill(angle=-12 + 9 * k, scale=0.85)
        out.alpha_composite(b, (x - b.width // 2 + 6 * k, y - b.height // 2 - 10 * k))
    return out


def draw_bills(frame, i, offset):
    mx, my = MARGIN
    ox, oy = BILL_ORIGIN
    step = BILL_LIFE // BILL_N
    for k in range(BILL_N):
        t = (i - k * step) % BILL_LIFE
        vx = BILL_VX[k % len(BILL_VX)]
        x = ox + vx * t
        y = oy + BILL_VY * t + 0.5 * BILL_G * t * t
        if t < 2:
            continue                      # nace escondido en la pinza
        b = draw_bill(angle=(t * 9 + k * 60) % 360)
        frame.alpha_composite(b, (round(mx + x - b.width / 2), round(my + offset + y - b.height / 2)))


def render_frame(layers, i, canvas_size, mode="dance"):
    t = i / FRAMES
    frame = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    bob = round(3 * math.sin(2 * math.pi * t))
    mx, my = MARGIN
    motion = MOTION[mode]
    for name in ORDER:
        if name == "bills":
            if mode == "working":
                draw_bills(frame, i, bob)
            continue
        layer = layers[name]
        if mode == "working" and name == "rclaw":
            layer = attach_wad(layer)
        if name in motion:
            (px, py), amp, freq, ph, rest = motion[name]
            ang = rest + amp * math.sin(2 * math.pi * (freq * t + ph))
            layer = layer.rotate(ang, resample=Image.BICUBIC, center=(px, py))
        frame.alpha_composite(layer, (mx, my + bob))
    return frame


def bake(frames_rgba, out_path):
    magenta = (255, 0, 255)
    flat = []
    for f in frames_rgba:
        w = round(f.width * OUT_H / f.height)
        f = f.resize((w, OUT_H), Image.LANCZOS)
        r, g, b, a = f.split()
        a = a.point(lambda v: 255 if v >= 128 else 0)
        bg = Image.new("RGB", f.size, magenta)
        if OUTLINE_PX:
            # silueta dilatada pintada de negro, debajo del dibujo: queda un
            # contorno fino que lo separa de fondos blancos
            grown = a.filter(ImageFilter.MaxFilter(2 * OUTLINE_PX + 1))
            bg.paste((0, 0, 0), (0, 0), grown)
        bg.paste(Image.merge("RGB", (r, g, b)), (0, 0), a)
        flat.append(bg)
    pal = flat[0].quantize(255, method=Image.MEDIANCUT, dither=Image.Dither.NONE)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in flat]
    tidx = q[0].getpixel((0, 0))
    q[0].save(out_path, save_all=True, append_images=q[1:], duration=DURATION_MS,
              loop=0, transparency=tidx, disposal=2, optimize=False)
    return flat[0].size, tidx


def main():
    src = Path(sys.argv[1])
    mode = sys.argv[2] if len(sys.argv) > 2 else "dance"
    if mode not in MOTION:
        sys.exit(f"modo desconocido: {mode} (usa dance | working | idle)")
    out = Path(sys.argv[3]) if len(sys.argv) > 3 else         Path(__file__).resolve().parents[2] / "pets" / "cangrejo" / "sprites" / f"{mode}.gif"
    im = remove_background(Image.open(src))
    layers = split_layers(im)
    canvas = (im.width + 2 * MARGIN[0], im.height + 2 * MARGIN[1])
    frames = [render_frame(layers, i, canvas, mode) for i in range(FRAMES)]
    size, tidx = bake(frames, out)
    print(f"ok {out} {size} frames={FRAMES} transp_idx={tidx}")


if __name__ == "__main__":
    main()
