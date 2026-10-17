"""Passada de detalhe da roupa da heroína em 512 (depois que o corpo pintado em 256 é ampliado):
trama do tecido, rugas (cotovelo, joelho, cintura), couro com grão, costuras pespontadas,
zíper com dentes e joelheira acolchoada. O material de cada pixel é reconhecido pela cor.

Usado por tools/make_textures.py. Coordenadas: art/atlas.py vezes atlas.TEX_SCALE.
"""
import math
import random

from PIL import Image, ImageDraw

import atlas

rng = random.Random(5)
K = atlas.TEX_SCALE
STITCH = (112, 116, 98)
STITCH_LEATHER = (150, 116, 84)


def rect(name):
    x, y, w, h = atlas.RECTS[name]
    return x * K, y * K, w * K, h * K


def ux(name, u):
    x, _, w, _ = rect(name)
    return int(round(x + u * w))


def zy(name, z):
    return int(round(atlas.z_to_py(name, z) * K))


def _noise(w, h, cell):
    small = Image.new("L", (w // cell + 2, h // cell + 2))
    small.putdata([rng.randrange(256) for _ in range(small.width * small.height)])
    big = small.resize((w + 2 * cell, h + 2 * cell), Image.BICUBIC).crop((cell, cell, cell + w, cell + h))
    data = big.load()
    return lambda i, j: data[i, j] / 255.0 - 0.5


def material(c):
    r, g, b = c
    if r > 170 and g > 120:  # pele
        return "skin"
    if r > g + 14 and r > b + 20:  # couro marrom (correias, cinto, botas, coldre)
        return "leather"
    if b >= r and b > g - 4 and max(c) > 70:  # metal cinza-azulado
        return "metal"
    return "fabric"


def texture_pass(img, names, folds=None):
    """Trama/grão e rugas sobre as peças `names`. folds: {nome: [(v0, v1, força)]} faixas com rugas."""
    px = img.load()
    folds = folds or {}
    for name in names:
        x0, y0, w, h = rect(name)
        grain = _noise(w, h, 2)
        blot = _noise(w, h, 12)
        wrinkle = _noise(w, h // 3 + 1, 6)
        for j in range(h):
            v = j / h
            band = sum(f for a, b, f in folds.get(name, []) if a <= v <= b)
            for i in range(w):
                c = px[x0 + i, y0 + j]
                m = material(c[:3])
                if m == "skin":
                    continue
                k = 1.0 + 0.08 * blot(i, j)
                if m == "fabric":
                    k += 0.05 if (i + j) % 4 < 2 else -0.05  # sarja
                    k += 0.06 * grain(i, j)
                    if band:
                        # rugas: faixas horizontais onduladas, vale escuro e crista clara
                        wv = math.sin(j * 0.55 + 6 * wrinkle(i, j // 3) + i * 0.05)
                        k += band * 0.22 * wv
                elif m == "leather":
                    k += 0.12 * grain(i, j) + (0.08 if rng.random() < 0.02 else 0.0)
                elif m == "metal":
                    k += 0.04 * grain(i, j)
                px[x0 + i, y0 + j] = tuple(max(0, min(255, int(ch * k))) for ch in c[:3]) + c[3:]


def stitch(d, pts, color=STITCH, dash=3, gap=2):
    """Pesponto tracejado ao longo da polilinha."""
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(bx - ax, by - ay)))
        for s in range(0, n, dash + gap):
            t0, t1 = s / n, min(1.0, (s + dash) / n)
            d.line([(ax + (bx - ax) * t0, ay + (by - ay) * t0), (ax + (bx - ax) * t1, ay + (by - ay) * t1)], fill=color)


def seams(img):
    d = ImageDraw.Draw(img)
    # tronco: costuras laterais, recortes da frente e das costas, barra acima do cinto
    x, y, w, h = rect("torso")
    top, belt = zy("torso", 1.44), zy("torso", 1.0)
    for u in (0.25, 0.75):
        stitch(d, [(ux("torso", u) + 2, top), (ux("torso", u) + 2, belt)])
        stitch(d, [(ux("torso", u) - 2, top), (ux("torso", u) - 2, belt)])
    for u in (0.31, 0.69, 0.06, 0.94):
        stitch(d, [(ux("torso", u), top + 6), (ux("torso", u + (0.015 if u < 0.5 else -0.015)), zy("torso", 1.2)),
                   (ux("torso", u), belt)])
    stitch(d, [(x, zy("torso", 1.02)), (x + w - 1, zy("torso", 1.02))])
    # zíper: dentes alternados no meio da frente
    cx = ux("torso", 0.5)
    for yy in range(top - 10, belt, 2):
        c = (150, 152, 140) if (yy // 2) % 2 else (70, 72, 64)
        d.line([(cx - 2, yy), (cx + 1, yy)], fill=c)
    # mangas: costura de baixo e punho pespontado
    for name in ("sleeve_upper", "sleeve_lower"):
        sx, sy, sw, sh = rect(name)
        stitch(d, [(ux(name, 0.25) + 2, sy), (ux(name, 0.25) + 2, sy + sh - 1)])
    sx, sy, sw, sh = rect("sleeve_lower")
    stitch(d, [(sx, sy + sh - 8), (sx + sw - 1, sy + sh - 8)])
    # calça: costura lateral e joelheira acolchoada na frente
    for name in ("thigh", "shin"):
        tx, ty, tw, th = rect(name)
        for u in (0.25, 0.75):
            stitch(d, [(ux(name, u) + 2, ty), (ux(name, u) + 2, ty + th // 2 if name == "shin" else ty + th - 1)])
    k0, k1 = zy("shin", 0.50), zy("shin", 0.40)
    d.rounded_rectangle([ux("shin", 0.36), k0, ux("shin", 0.64), k1], radius=6, fill=(52, 52, 46), outline=(30, 30, 26), width=2)
    stitch(d, [(ux("shin", 0.38), k0 + 4), (ux("shin", 0.62), k0 + 4), (ux("shin", 0.62), k1 - 4), (ux("shin", 0.38), k1 - 4), (ux("shin", 0.38), k0 + 4)])
    for kk in (k0 + (k1 - k0) // 3, k0 + 2 * (k1 - k0) // 3):
        d.line([(ux("shin", 0.38), kk), (ux("shin", 0.62), kk)], fill=(38, 38, 34))
    # botas: pesponto do cano e da sola
    fx, fy, fw, fh = rect("foot")
    stitch(d, [(fx, fy + fh - 10), (fx + fw - 1, fy + fh - 10)], STITCH_LEATHER)


def detail(img):
    names = ["torso", "sleeve_upper", "sleeve_lower", "thigh", "shin", "foot", "hand", "pouch", "leather", "neck"]
    folds = {
        "sleeve_upper": [(0.75, 1.0, 0.8)],  # dobra do cotovelo
        "sleeve_lower": [(0.0, 0.3, 1.0), (0.85, 1.0, 0.5)],  # cotovelo e punho
        "torso": [(0.68, 0.76, 0.6)],  # cintura, acima do cinto
        "thigh": [(0.0, 0.1, 0.6), (0.9, 1.0, 0.5)],  # virilha e atrás do joelho
        "shin": [(0.0, 0.12, 0.4), (0.62, 0.72, 0.5)],  # joelho e tornozelo (cano da bota)
    }
    texture_pass(img, names, folds)
    seams(img)
