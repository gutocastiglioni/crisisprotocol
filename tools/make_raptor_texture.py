"""Pinta o atlas 512x512 do velociraptor (visual de PS2 do começo): verde-oliva com listras escuras de borda
irregular, escamas miúdas, placas transversais na barriga bege, olho amarelo com pupila em fenda.

Uso: python tools/make_raptor_texture.py [saida.png]
Saída padrão: game/assets/characters/raptor_atlas.png
Peças "loft": u = volta (0 dorso, 0.5 barriga), v = comprimento (ver art/raptor_atlas.py).
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "art"))
sys.path.insert(0, str(ROOT / "tools"))
import paint_face  # noqa: E402  (pad: preenche o fundo para o filtro linear)
import raptor_atlas as atlas  # noqa: E402

rng = random.Random(11)
K = atlas.TEX_SCALE
TEX = atlas.SIZE * K

# Paleta da referência (Dino Crisis): oliva/musgo, listras marrom-escuras, ventre bege
BACK = (56, 64, 36)
SIDE = (104, 110, 64)
SIDE_HI = (138, 138, 88)
BELLY = (186, 172, 124)
BELLY_LO = (150, 136, 96)
STRIPE = (42, 38, 24)
STRIPE_CORE = (26, 24, 16)
EYE = (232, 176, 36)
EYE_HI = (252, 222, 120)
EYE_RING = (30, 26, 18)
PUPIL = (10, 8, 6)
MOUTH = (124, 38, 38)
MOUTH_LO = (80, 22, 24)
GUM = (176, 82, 84)
TONGUE = (170, 78, 82)
TOOTH = (236, 228, 200)
TOOTH_LO = (178, 164, 128)
CLAW = (40, 36, 32)
CLAW_HI = (132, 122, 104)

img = Image.new("RGB", (TEX, TEX), (255, 0, 255))
px = img.load()
d = ImageDraw.Draw(img)


def rect(name):
    x, y, w, h = atlas.RECTS[name]
    return x * K, y * K, w * K, h * K


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(3))


def smooth_noise(w, h, cell):
    """Ruído suave (grade aleatória ampliada com bicúbica) com valores 0..1."""
    small = Image.new("L", (max(2, w // cell + 2), max(2, h // cell + 2)))
    small.putdata([rng.randrange(256) for _ in range(small.width * small.height)])
    big = small.resize((w + cell * 2, h + cell * 2), Image.BICUBIC).crop((cell, cell, cell + w, cell + h))
    data = big.load()
    return lambda i, j: data[i, j] / 255.0


def skin(u, belly_width):
    """Cor base pela volta: dorso escuro -> lado claro -> barriga bege (u=0.5)."""
    side = abs(u - 0.5) * 2  # 0 na barriga, 1 no dorso
    if side < belly_width * 2:
        return lerp(BELLY, BELLY_LO, side / (belly_width * 2) * 0.6)
    t = (side - belly_width * 2) / max(0.01, 1 - belly_width * 2)
    return lerp(SIDE_HI, SIDE, t * 2) if t < 0.5 else lerp(SIDE, BACK, (t - 0.5) * 2)


def scales(i, j, size):
    """Escamas miúdas em fileiras alternadas: escurece a borda de cada escama."""
    row = j // size
    x = i + (row % 2) * size * 0.5
    cx = (x % size) / size - 0.5
    cy = (j % size) / size - 0.5
    return 1.0 - 0.22 * min(1.0, (cx * cx + cy * cy) * 4)


def paint_skin(name, count, reach=0.36, belly_width=0.16, width=0.32, scale=5, scutes=0):
    """Pele de uma peça: base pela volta, listras transversais (variam com v) que descem do dorso até perto
    da barriga com borda irregular, escamas e, na barriga, placas transversais (`scutes` por peça)."""
    x0, y0, w, h = rect(name)
    edge = smooth_noise(w, h, 6)
    blot = smooth_noise(w, h, 3)
    phase = rng.uniform(0, 1)
    for j in range(h):
        v = (j + 0.5) / h
        for i in range(w):
            u = (i + 0.5) / w
            c = skin(u, belly_width)
            side = abs(u - 0.5) * 2
            wave = math.sin((v * count + phase) * 2 * math.pi + 2.2 * (edge(i, j) - 0.5) + 1.2 * math.sin(u * 9))
            limit = 1 - width * 2 + 0.25 * (1 - side) + 0.3 * (blot(i, j) - 0.5)
            if side > 1 - reach * 2 and wave > limit:
                core = wave > limit + 0.32
                c = STRIPE_CORE if core else lerp(STRIPE, c, 0.15)
            elif side > 1 - reach * 2 - 0.05 and wave > limit - 0.12:
                c = lerp(c, STRIPE, 0.45)  # borda esfumada da listra
            k = scales(i, j, scale) if side > belly_width * 2 else 1.0
            if scutes and side <= belly_width * 2 and (v * scutes) % 1.0 < 0.12:
                k = 0.78  # sulco entre placas da barriga
            k *= 0.92 + 0.16 * blot(i, j)
            px[x0 + i, y0 + j] = tuple(min(255, int(ch * k)) for ch in c)


def speckle(name, chance=0.012):
    x0, y0, w, h = rect(name)
    for _ in range(int(w * h * chance)):
        i, j = rng.randrange(w), rng.randrange(h)
        if abs((i + 0.5) / w - 0.5) > 0.2:
            r = rng.choice((1, 1, 2))
            d.ellipse([x0 + i - r, y0 + j - r, x0 + i + r, y0 + j + r], fill=STRIPE)


def noise(name, amount=5):
    x0, y0, w, h = rect(name)
    for j in range(h):
        for i in range(w):
            n = rng.randint(-amount, amount)
            px[x0 + i, y0 + j] = tuple(max(0, min(255, c + n)) for c in px[x0 + i, y0 + j])


def paint_head():
    paint_skin("head", 3.0, reach=0.3, belly_width=0.13, width=0.22, scale=4)
    x, y, w, h = rect("head")
    # céu da boca (embaixo da cabeça) com a gengiva, e lábio claro na borda
    for j in range(h):
        for i in range(w):
            side = abs((i + 0.5) / w - 0.5)
            if side < 0.07:
                px[x + i, y + j] = lerp(MOUTH, MOUTH_LO, (0.07 - side) / 0.07)
            elif side < 0.1:
                px[x + i, y + j] = GUM
            elif side < 0.13:
                px[x + i, y + j] = lerp(BELLY, BELLY_LO, (side - 0.1) / 0.03)
    # olho: anel escuro, íris amarela com degradê, pupila em fenda, brilho; sobrancelha óssea escura
    eu, ev = atlas.EYE_UV
    for u0 in (eu, 1 - eu):
        cx, cy = x + u0 * w, y + ev * h
        d.ellipse([cx - 10, cy - 7, cx + 10, cy + 7], fill=EYE_RING)
        for r in range(7, 0, -1):
            d.ellipse([cx - r * 1.2, cy - r * 0.86, cx + r * 1.2, cy + r * 0.86], fill=lerp(EYE_HI, EYE, r / 7))
        d.ellipse([cx - 1.4, cy - 5.5, cx + 1.4, cy + 5.5], fill=PUPIL)
        d.ellipse([cx - 4, cy - 4, cx - 2, cy - 2], fill=(255, 250, 230))
        d.line([cx - 13, cy - 8, cx, cy - 11, cx + 11, cy - 9], fill=STRIPE_CORE, width=4)
    # narinas perto da ponta do focinho
    for u0 in (0.15, 0.85):
        cx = x + u0 * w
        d.ellipse([cx - 3, y + h - 16, cx + 3, y + h - 11], fill=PUPIL)
        d.arc([cx - 5, y + h - 18, cx + 5, y + h - 9], 180, 360, fill=STRIPE, width=2)
    noise("head", 3)


def paint_jaw():
    x, y, w, h = rect("jaw")
    blot = smooth_noise(w, h, 4)
    for j in range(h):
        v = (j + 0.5) / h
        for i in range(w):
            side = abs((i + 0.5) / w - 0.5) * 2
            if side > 0.86:  # topo da mandíbula = dentro da boca: língua com sulco no meio
                c = lerp(TONGUE, MOUTH_LO, (side - 0.86) / 0.14 * 0.3) if side < 0.97 else MOUTH_LO
            elif side > 0.76:
                c = GUM
            elif side > 0.62:
                c = BELLY
            else:
                c = lerp(BELLY, SIDE, max(0, side - 0.3) * 2)
                if (v * 7) % 1.0 < 0.1:
                    c = lerp(c, BELLY_LO, 0.7)  # placas da garganta
            k = 0.92 + 0.16 * blot(i, j)
            px[x + i, y + j] = tuple(min(255, int(ch * k)) for ch in c)


def paint_gradient(name, top, bottom, streak=None):
    x, y, w, h = rect(name)
    for j in range(h):
        d.line([x, y + j, x + w - 1, y + j], fill=lerp(top, bottom, j / max(1, h - 1)))
    if streak:
        d.line([x + w // 3, y, x + w // 3, y + h - 1], fill=streak, width=2)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game/assets/characters/raptor_atlas.png"
    paint_skin("body", 7.0, reach=0.4, belly_width=0.18, scutes=14)
    paint_skin("neck", 3.0, reach=0.38, belly_width=0.2, scutes=6, scale=4)
    paint_skin("tail", 9.0, reach=0.48, belly_width=0.12, width=0.36, scutes=18)
    paint_skin("thigh", 3.5, reach=0.5, belly_width=0.1, width=0.36, scale=6)
    paint_skin("shin", 4.0, reach=0.5, belly_width=0.08, scale=4)
    paint_skin("meta", 3.0, reach=0.5, belly_width=0.0, scale=3)
    paint_skin("arm", 3.0, reach=0.45, belly_width=0.15, scale=3)
    paint_skin("toe", 2.0, reach=0.5, belly_width=0.0, scale=3)
    for n in ("body", "neck", "tail", "thigh", "shin", "arm"):
        speckle(n)
    paint_head()
    paint_jaw()
    paint_gradient("teeth", TOOTH, TOOTH_LO)
    paint_gradient("mouth", MOUTH, MOUTH_LO)
    paint_gradient("claw", CLAW_HI, CLAW, streak=(170, 160, 140))
    final = paint_face.pad(img)
    out.parent.mkdir(parents=True, exist_ok=True)
    final.convert("RGB").save(out)
    print(f"[raptor] atlas salvo em {out}")


if __name__ == "__main__":
    main()
