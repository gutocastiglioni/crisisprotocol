"""Pinta o atlas 512x512 do velociraptor (visual de PS2 do começo): verde-oliva com listras escuras de borda
irregular, escamas miúdas, placas transversais na barriga bege, olho amarelo com pupila em fenda.
Volume pintado por cima (como as texturas de PS2 com luz "assada"): brilho ao longo do dorso, sombra no flanco
baixo onde o corpo vira para baixo, oclusão nas juntas, músculo da coxa, dobras da garganta e órbita do olho.

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
EYE = (200, 124, 28)  # âmbar escuro
EYE_HI = (240, 186, 84)
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
    # céu da boca (embaixo da cabeça) com a gengiva, e lábio escuro na borda (emenda com a mandíbula)
    for j in range(h):
        if (j + 0.5) / h > 0.85:
            continue  # ponta do focinho: fica com a pele (a mandíbula termina antes e a ponta aparece por baixo)
        for i in range(w):
            side = abs((i + 0.5) / w - 0.5)
            if side < 0.07:
                px[x + i, y + j] = lerp(MOUTH, MOUTH_LO, (0.07 - side) / 0.07)
            elif side < 0.1:
                px[x + i, y + j] = GUM
            elif side < 0.13:
                px[x + i, y + j] = lerp(STRIPE, SIDE, (side - 0.1) / 0.03)
    # olho de predador: amendoado e semicerrado, com o arco ósseo pesado cobrindo a parte de cima e descendo para
    # o focinho (cara de bravo); a íris ocupa o olho todo, mais escura em cima (sombra da pálpebra), pupila em fenda
    # em pé e um brilho pequeno. No atlas, x = volta da cabeça (vertical no modelo, ~465 px/m) e y = comprimento
    # (horizontal no modelo, ~213 px/m, cresce para o focinho); os pontos abaixo são (altura, frente) no modelo.
    eu, ev = atlas.EYE_UV
    for u0, up in ((eu, -1), (1 - eu, 1)):  # up: lado do dorso no atlas (u menor no olho esquerdo)
        cx, cy = x + u0 * w, y + ev * h

        def pt(hh, ll):
            return (cx + up * hh, cy + ll)

        socket = [pt(4, -9), pt(5, 0), pt(1, 9), pt(-6, 8), pt(-12, 3), pt(-12, -3), pt(-7, -8)]
        d.polygon(socket, fill=lerp(STRIPE_CORE, BACK, 0.35))
        lid = [pt(2, -7), pt(2, -2), pt(-1, 3), pt(-4, 7), pt(-8, 4), pt(-10, 0), pt(-8, -5)]
        d.polygon(lid, fill=EYE_RING)
        iris = [pt(1, -5), pt(1, -2), pt(-1, 2), pt(-4, 5), pt(-7, 3), pt(-8, 0), pt(-6, -4)]
        d.polygon(iris, fill=EYE)
        d.polygon([pt(-3, -3), pt(-2, 1), pt(-5, 3), pt(-7, 0), pt(-6, -3)], fill=EYE_HI)
        d.polygon([pt(1, -5), pt(1, -2), pt(-1, 2), pt(-1, -2)], fill=lerp(EYE, EYE_RING, 0.6))  # sombra da pálpebra
        d.line([pt(0, 0), pt(-7, 0)], fill=PUPIL, width=2)
        d.point([pt(-2, -2)], fill=(255, 240, 210))
        # arco ósseo: cunha escura por cima do olho, mais baixa na frente
        d.polygon([pt(3, -10), pt(9, -9), pt(8, 9), pt(1, 10), pt(-2, 8), pt(2, 0)], fill=STRIPE_CORE)
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
            elif side > 0.68:
                c = lerp(STRIPE, SIDE, (0.76 - side) / 0.08 * 0.4)  # lábio escuro, igual ao da cabeça
            elif side > 0.22:
                c = lerp(SIDE, SIDE_HI, (0.68 - side) / 0.46 * 0.6)  # lado da mandíbula com a pele da cabeça
            else:
                c = lerp(BELLY, SIDE_HI, side / 0.22 * 0.5)  # embaixo do queixo
                if (v * 7) % 1.0 < 0.1:
                    c = lerp(c, BELLY_LO, 0.7)  # placas da garganta
            k = (0.92 + 0.16 * blot(i, j)) * (scales(i, j, 4) if 0.22 < side < 0.68 else 1.0)
            px[x + i, y + j] = tuple(min(255, int(ch * k)) for ch in c)


def paint_gradient(name, top, bottom, streak=None):
    x, y, w, h = rect(name)
    for j in range(h):
        d.line([x, y + j, x + w - 1, y + j], fill=lerp(top, bottom, j / max(1, h - 1)))
    if streak:
        d.line([x + w // 3, y, x + w // 3, y + h - 1], fill=streak, width=2)


def gauss(x, w):
    return math.exp(-(x / w) ** 2)


def multiply(name, factor):
    """Multiplica cada pixel da peça por factor(u, v) (u = volta, v = comprimento, os dois 0..1)."""
    x0, y0, w, h = rect(name)
    for j in range(h):
        v = (j + 0.5) / h
        for i in range(w):
            f = factor((i + 0.5) / w, v)
            px[x0 + i, y0 + j] = tuple(max(0, min(255, int(ch * f))) for ch in px[x0 + i, y0 + j])


def shade_trunk(name, belly_width, sheen=0.28, flank=0.42, ends=(0.0, 0.0), hang=0.0):
    """Peças horizontais (u = 0 no dorso): brilho no alto, sombra no flanco baixo logo acima da barriga clara,
    barriga um pouco mais escura no meio (fica de frente para o chão), oclusão nas pontas (`ends` = início, fim).
    `hang` escurece a barriga no meio do comprimento (a pança que pende)."""
    edge = belly_width * 2 + 0.16

    def f(u, v):
        side = abs(u - 0.5) * 2  # 1 no dorso, 0 na barriga
        k = 1 + sheen * gauss(1 - side, 0.2) + 0.08 * gauss(side - 0.72, 0.15)
        k *= 1 - flank * gauss(side - edge, 0.14)
        k *= 1 - 0.05 * gauss(side, 0.12) - hang * gauss(side, 0.2) * gauss(v - 0.5, 0.25)
        k *= 1 - ends[0] * gauss(v, 0.08) - ends[1] * gauss(1 - v, 0.08)
        return k
    multiply(name, f)


def shade_limb(name, top=1.1, bottom=0.72, bulge=0.0, ends=(0.2, 0.2)):
    """Membros: claro em cima e escuro embaixo (luz de cima), músculo realçado no primeiro terço (`bulge`)
    e oclusão nas juntas."""
    def f(u, v):
        k = top + (bottom - top) * v
        k *= 1 + bulge * gauss(v - 0.3, 0.16)
        k *= 1 - ends[0] * gauss(v, 0.07) - ends[1] * gauss(1 - v, 0.07)
        return k
    multiply(name, f)


def throat_folds(name, count, belly_width):
    """Dobras transversais de pele na garganta e no peito (só do lado de baixo)."""
    def f(u, v):
        side = abs(u - 0.5) * 2
        if side > belly_width * 2 + 0.25:
            return 1.0
        fold = (v * count) % 1.0
        return 1 - 0.22 * gauss(fold - 0.5, 0.09) + 0.06 * gauss(fold - 0.62, 0.06)
    multiply(name, f)


def shade_head():
    """Cabeça: sombra embaixo do arco sobre o olho, órbita escura, bochecha e focinho com brilho."""
    eu, ev = atlas.EYE_UV
    shade_trunk("head", 0.13, sheen=0.26, flank=0.3, ends=(0.18, 0.0))

    def f(u, v):
        k = 1.0
        for u0 in (eu, 1 - eu):
            du, dv = (u - u0) * 2.0, v - ev
            r = math.hypot(du, dv * 1.6)
            up = -1 if u0 < 0.5 else 1  # lado do dorso
            k *= 1 - 0.3 * gauss(r - 0.09, 0.05)  # órbita em volta do olho (o olho em si fica fora)
            k *= 1 - 0.4 * gauss(du - up * 0.08, 0.05) * gauss(dv, 0.16)  # sombra do arco ósseo, por cima
            k *= 1 + 0.12 * gauss(du + up * 0.16, 0.06) * gauss(dv - 0.05, 0.15)  # bochecha, por baixo
        return k
    multiply("head", f)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game/assets/characters/raptor_atlas.png"
    paint_skin("body", 7.0, reach=0.4, belly_width=0.18, scutes=14)
    paint_skin("neck", 3.0, reach=0.38, belly_width=0.2, scutes=6, scale=4)
    paint_skin("tail", 9.0, reach=0.48, belly_width=0.12, width=0.36, scutes=18)
    paint_skin("thigh", 3.5, reach=0.5, belly_width=0.0, width=0.36, scale=6)
    paint_skin("shin", 4.0, reach=0.5, belly_width=0.0, scale=4)
    paint_skin("meta", 3.0, reach=0.5, belly_width=0.0, scale=3)
    paint_skin("arm", 3.0, reach=0.45, belly_width=0.0, scale=3)
    paint_skin("toe", 2.0, reach=0.5, belly_width=0.0, scale=3)
    for n in ("body", "neck", "tail", "thigh", "shin", "arm"):
        speckle(n)
    paint_head()
    paint_jaw()
    shade_trunk("body", 0.18, ends=(0.15, 0.2), hang=0.1)
    shade_trunk("neck", 0.2, ends=(0.22, 0.2))
    throat_folds("neck", 7, 0.2)
    shade_trunk("tail", 0.12, sheen=0.22, flank=0.36, ends=(0.25, 0.0))
    shade_limb("thigh", top=1.18, bottom=0.62, bulge=0.15, ends=(0.3, 0.35))
    shade_limb("shin", top=1.02, bottom=0.72, bulge=0.12, ends=(0.35, 0.25))
    shade_limb("meta", top=0.95, bottom=0.8, ends=(0.2, 0.25))
    shade_limb("arm", top=1.08, bottom=0.8, bulge=0.08, ends=(0.3, 0.2))
    shade_limb("toe", top=0.95, bottom=0.8, ends=(0.2, 0.0))
    shade_head()
    multiply("jaw", lambda u, v: 1 - 0.25 * gauss(abs(u - 0.5) * 2 - 0.35, 0.12) - 0.12 * gauss(v, 0.1))
    paint_gradient("teeth", TOOTH, TOOTH_LO)
    paint_gradient("mouth", MOUTH, MOUTH_LO)
    paint_gradient("claw", CLAW_HI, CLAW, streak=(170, 160, 140))
    final = paint_face.pad(img)
    out.parent.mkdir(parents=True, exist_ok=True)
    final.convert("RGB").save(out)
    print(f"[raptor] atlas salvo em {out}")


if __name__ == "__main__":
    main()
