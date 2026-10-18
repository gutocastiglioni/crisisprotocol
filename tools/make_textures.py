"""Pinta o atlas da heroína (512x512: corpo em 256 ampliado, rosto e cabelo em 512 via paint_face.py).

Uso: python tools/make_textures.py [saida.png]
Saída padrão: game/assets/characters/heroine_atlas.png
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "art"))
import atlas  # noqa: E402
import paint_clothes  # noqa: E402
import paint_face  # noqa: E402

R = atlas.RECTS
rng = random.Random(7)

# Paleta tirada da referência (jaqueta oliva, couro marrom, calça escura, cabelo ruivo)
JACKET = (66, 69, 60)
JACKET_HI = (88, 92, 80)
JACKET_LO = (44, 46, 40)
VEST = (56, 58, 50)
STRAP = (92, 64, 44)
STRAP_HI = (122, 88, 60)
STRAP_LO = (62, 42, 30)
PANTS = (44, 43, 38)
PANTS_HI = (60, 59, 52)
PANTS_LO = (30, 29, 26)
BOOT = (40, 32, 27)
BOOT_HI = (64, 52, 42)
BOOT_LO = (24, 19, 16)
SOLE = (20, 18, 17)
LACE = (110, 96, 80)
HAIR = (168, 22, 26)
HAIR_HI = (222, 52, 40)
HAIR_LO = (104, 12, 16)
SKIN = (228, 180, 155)
SKIN_LO = (196, 140, 118)
SKIN_HI = (240, 200, 178)
LIP = (176, 86, 84)
EYE_WHITE = (226, 220, 214)
IRIS = (70, 92, 62)
BROW = (110, 30, 24)
GLOVE = (72, 74, 64)
GLOVE_LO = (50, 52, 45)
METAL = (44, 46, 50)
METAL_HI = (86, 90, 96)
METAL_LO = (24, 25, 28)
ZIP = (120, 122, 112)

img = Image.new("RGB", (atlas.SIZE, atlas.SIZE), (255, 0, 255))
d = ImageDraw.Draw(img)


def rect(name):
    x, y, w, h = R[name]
    return x, y, w, h


def fill(name, color):
    x, y, w, h = rect(name)
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def hline(x0, x1, y, color, thick=1):
    d.rectangle([x0, y, x1, y + thick - 1], fill=color)


def vline(x, y0, y1, color, thick=1):
    d.rectangle([x, y0, x + thick - 1, y1], fill=color)


def strap(x0, x1, y, thick=3):
    """Correia de couro horizontal com borda clara em cima e escura embaixo."""
    hline(x0, x1, y, STRAP, thick)
    hline(x0, x1, y, STRAP_HI)
    hline(x0, x1, y + thick - 1, STRAP_LO)


def vstrap(x, y0, y1, thick=3):
    vline(x, y0, y1, STRAP, thick)
    vline(x, y0, y1, STRAP_HI)
    vline(x + thick - 1, y0, y1, STRAP_LO)


def shade_vertical(name, top_mul=1.08, bottom_mul=0.82):
    """Gradiente vertical leve (luz de cima), como a sombra pintada dos jogos de PS1."""
    x, y, w, h = rect(name)
    px = img.load()
    for j in range(h):
        k = top_mul + (bottom_mul - top_mul) * (j / max(1, h - 1))
        for i in range(w):
            r, g, b = px[x + i, y + j]
            px[x + i, y + j] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)))


def shade_sides(name, depth=0.78):
    """Escurece as laterais e as costas (u=0, 0.25 e 0.75 ficam mais escuros que a frente u=0.5)."""
    x, y, w, h = rect(name)
    px = img.load()
    for i in range(w):
        u = (i + 0.5) / w
        # 1 na frente (u=0.5), "depth" nas costas (u=0/1)
        k = depth + (1 - depth) * (1 - abs(u - 0.5) * 2) ** 0.6
        for j in range(h):
            r, g, b = px[x + i, y + j]
            px[x + i, y + j] = (int(r * k), int(g * k), int(b * k))


def noise(name, amount=6):
    x, y, w, h = rect(name)
    px = img.load()
    for j in range(h):
        for i in range(w):
            n = rng.randint(-amount, amount)
            r, g, b = px[x + i, y + j]
            px[x + i, y + j] = tuple(max(0, min(255, c + n)) for c in (r, g, b))


def ty(name, z):
    return int(round(atlas.z_to_py(name, z)))


def ux(name, u):
    x, _, w, _ = rect(name)
    return int(round(x + u * w))


# ---------------------------------------------------------------- tronco (jaqueta + colete + cinto + calça)
def paint_torso():
    x, y, w, h = rect("torso")
    fill("torso", JACKET)
    belt_top, belt_bot = ty("torso", 0.995), ty("torso", 0.95)
    # calça abaixo do cinto
    d.rectangle([x, belt_bot, x + w - 1, y + h - 1], fill=PANTS)
    # colete na frente e nas costas (mais escuro que a jaqueta)
    vest_top, vest_bot = ty("torso", 1.40), ty("torso", 1.02)
    d.rectangle([ux("torso", 0.33), vest_top, ux("torso", 0.67), vest_bot], fill=VEST)
    d.rectangle([x, ty("torso", 1.42), ux("torso", 0.14), vest_bot], fill=VEST)
    d.rectangle([ux("torso", 0.86), ty("torso", 1.42), x + w - 1, vest_bot], fill=VEST)
    # webbing (linhas MOLLE) no colete
    for zz in (1.36, 1.33, 1.08, 1.05):
        hline(ux("torso", 0.35), ux("torso", 0.65), ty("torso", zz), JACKET_LO)
    # alças verticais do colete subindo pelos ombros
    for u in (0.42, 0.56):
        vstrap(ux("torso", u), vest_top - 6, vest_bot, 3)
    for u in (0.06, 0.92):
        vstrap(ux("torso", u), ty("torso", 1.44), vest_bot, 3)
    # correias horizontais da frente
    for zz in (1.29, 1.205, 1.10):
        strap(ux("torso", 0.35), ux("torso", 0.65), ty("torso", zz), 3)
    # correia em X nas costas
    for k in range(ty("torso", 1.40), vest_bot):
        t = (k - ty("torso", 1.40)) / max(1, vest_bot - ty("torso", 1.40))
        a = int(t * 14)
        d.point([(x + 2 + a, k), (x + w - 3 - a, k)], fill=STRAP)
    # gola alta e zíper central
    collar = ty("torso", 1.42)
    d.rectangle([x, y, x + w - 1, collar], fill=JACKET_LO)
    hline(x, x + w - 1, collar, JACKET_HI)
    vline(ux("torso", 0.5) - 1, y, belt_top, ZIP, 1)
    vline(ux("torso", 0.5), y, belt_top, JACKET_LO, 1)
    # costura lateral e sombra sob o busto
    for u in (0.25, 0.75):
        vline(ux("torso", u), collar, belt_top, JACKET_LO)
    hline(ux("torso", 0.36), ux("torso", 0.64), ty("torso", 1.175), JACKET_LO, 2)
    # cinto com fivela
    d.rectangle([x, belt_top, x + w - 1, belt_bot], fill=STRAP)
    hline(x, x + w - 1, belt_top, STRAP_HI)
    hline(x, x + w - 1, belt_bot, STRAP_LO)
    cx = ux("torso", 0.5)
    d.rectangle([cx - 4, belt_top, cx + 3, belt_bot], fill=METAL_HI)
    d.rectangle([cx - 2, belt_top + 2, cx + 1, belt_bot - 2], fill=STRAP_LO)
    # costura da virilha
    vline(cx, belt_bot + 1, y + h - 1, PANTS_LO)
    shade_sides("torso", 0.72)
    noise("torso", 5)


# ---------------------------------------------------------------- braços e mãos
def paint_sleeves():
    for name in ("sleeve_upper", "sleeve_lower"):
        x, y, w, h = rect(name)
        fill(name, JACKET)
        vline(ux(name, 0.25), y, y + h - 1, JACKET_LO)
        vline(ux(name, 0.75), y, y + h - 1, JACKET_LO)
    x, y, w, h = rect("sleeve_upper")
    # ombreira e faixa de couro no bíceps
    d.rectangle([x, y, x + w - 1, y + 5], fill=JACKET_HI)
    for i in range(w):
        d.point([(x + i, y + 6)], fill=JACKET_LO)
    strap(x, x + w - 1, y + 18, 4)
    x, y, w, h = rect("sleeve_lower")
    # punho da jaqueta
    d.rectangle([x, y + h - 7, x + w - 1, y + h - 1], fill=JACKET_LO)
    hline(x, x + w - 1, y + h - 7, JACKET_HI)
    hline(x, x + w - 1, y + 4, JACKET_LO)
    for name in ("sleeve_upper", "sleeve_lower"):
        shade_sides(name, 0.8)
        noise(name, 5)

    # mão: luva sem dedos (oliva) + dedos de pele
    x, y, w, h = rect("hand")
    fill("hand", GLOVE)
    split = y + int(h * 0.62)
    d.rectangle([x, split, x + w - 1, y + h - 1], fill=SKIN)
    hline(x, x + w - 1, split, GLOVE_LO, 2)
    hline(x, x + w - 1, y + 3, GLOVE_LO)
    for i in range(0, w, 4):
        vline(x + i, split + 2, y + h - 1, SKIN_LO)
    shade_sides("hand", 0.8)
    noise("hand", 4)


def paint_pistol():
    x, y, w, h = rect("pistol")
    fill("pistol", METAL)
    for j in range(h):
        t = j / (h - 1)
        c = METAL_HI if t < 0.15 else (METAL_LO if t > 0.85 else METAL)
        hline(x, x + w - 1, y + j, c)
    for i in range(x + 4, x + w - 4, 3):
        vline(i, y + 6, y + 10, METAL_LO)
    noise("pistol", 3)


def paint_rifle():
    """M16: preto fosco com arestas mais claras, frisos (telha) e desgaste."""
    x, y, w, h = rect("rifle")
    for j in range(h):
        t = j / (h - 1)
        c = METAL_HI if t < 0.1 else (METAL_LO if t > 0.88 else (34, 35, 38))
        hline(x, x + w - 1, y + j, c)
    for i in range(x + 6, x + w - 6, 5):
        vline(i, y + 8, y + h - 9, METAL_LO)
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=METAL_LO)
    noise("rifle", 4)


def paint_shotgun():
    """Escopeta: aço oxidado (azulado, gasto nas arestas) e madeira de nogueira com veios (coronha, cabo, telha)."""
    x, y, w, h = rect("shotgun")
    for j in range(h):
        t = j / (h - 1)
        c = (96, 100, 112) if t < 0.1 else ((20, 21, 26) if t > 0.88 else (40, 43, 52))
        hline(x, x + w - 1, y + j, c)
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=(20, 21, 26))
    noise("shotgun", 3)
    x, y, w, h = rect("shotgun_wood")
    rng = random.Random(12)
    for j in range(h):
        t = j / (h - 1)
        base = (112, 66, 34) if 0.1 < t < 0.88 else ((140, 88, 48) if t <= 0.1 else (70, 40, 20))
        hline(x, x + w - 1, y + j, base)
    # veios ondulados ao longo da peça e frisos da telha (pegada)
    for k in range(7):
        y0 = y + 4 + k * 4 + rng.randrange(2)
        pts = [(x + i, y0 + round(1.5 * math.sin(i * 0.11 + k))) for i in range(0, w, 4)]
        d.line(pts, fill=(84, 48, 24))
    for i in range(x + 30, x + 66, 4):
        vline(i, y + 5, y + h - 6, (78, 44, 22))
    noise("shotgun_wood", 4)


# ---------------------------------------------------------------- pernas e botas
def paint_legs():
    x, y, w, h = rect("thigh")
    fill("thigh", PANTS)
    for u in (0.5, 0.25, 0.75):
        vline(ux("thigh", u), y, y + h - 1, PANTS_LO)
    # painel acolchoado acima do joelho
    hline(x, x + w - 1, ty("thigh", 0.56), PANTS_HI)
    hline(x, x + w - 1, ty("thigh", 0.555), PANTS_LO)
    # correia da coxa
    strap(x, x + w - 1, ty("thigh", 0.745), 4)
    d.rectangle([ux("thigh", 0.72), ty("thigh", 0.745), ux("thigh", 0.78), ty("thigh", 0.745) + 3], fill=METAL_HI)
    shade_sides("thigh", 0.75)
    shade_vertical("thigh", 1.05, 0.9)
    noise("thigh", 4)

    x, y, w, h = rect("shin")
    boot_top = ty("shin", 0.435)
    fill("shin", PANTS)
    d.rectangle([x, boot_top, x + w - 1, y + h - 1], fill=BOOT)
    # dobra no topo da bota
    d.rectangle([x, boot_top, x + w - 1, boot_top + 3], fill=BOOT_HI)
    hline(x, x + w - 1, boot_top + 4, BOOT_LO)
    # cadarço cruzado na frente
    cx = ux("shin", 0.5)
    vline(cx - 4, boot_top + 5, y + h - 2, BOOT_LO)
    vline(cx + 4, boot_top + 5, y + h - 2, BOOT_LO)
    for j in range(boot_top + 6, y + h - 3, 4):
        d.line([(cx - 3, j), (cx + 3, j + 3)], fill=LACE)
        d.line([(cx + 3, j), (cx - 3, j + 3)], fill=LACE)
    for u in (0.25, 0.75):
        vline(ux("shin", u), boot_top + 5, y + h - 1, BOOT_LO)
    shade_sides("shin", 0.75)
    noise("shin", 4)

    x, y, w, h = rect("foot")
    fill("foot", BOOT)
    d.rectangle([x, y + h - 7, x + w - 1, y + h - 1], fill=SOLE)
    hline(x, x + w - 1, y + h - 8, BOOT_HI)
    hline(x, x + w - 1, y + 2, BOOT_HI)
    noise("foot", 4)


def paint_gear():
    x, y, w, h = rect("pouch")
    fill("pouch", VEST)
    d.rectangle([x, y, x + w - 1, y + 10], fill=JACKET)
    hline(x, x + w - 1, y + 10, JACKET_LO, 2)
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=JACKET_LO)
    d.rectangle([x + w // 2 - 2, y + 7, x + w // 2 + 1, y + 12], fill=STRAP)
    noise("pouch", 4)

    x, y, w, h = rect("leather")
    fill("leather", STRAP)
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=STRAP_LO)
    for i in range(x + 2, x + w - 2, 3):
        d.point([(i, y + 2), (i, y + h - 3)], fill=STRAP_HI)
    noise("leather", 4)

    x, y, w, h = rect("neck")
    fill("neck", SKIN)
    d.rectangle([x, y, x + w - 1, y + 9], fill=JACKET_LO)
    hline(x, x + w - 1, y + 9, JACKET_HI)
    vline(ux("neck", 0.5), y, y + 8, ZIP)
    shade_sides("neck", 0.8)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game/assets/characters/heroine_atlas.png"
    paint_torso()
    paint_sleeves()
    paint_pistol()
    paint_rifle()
    paint_shotgun()
    paint_legs()
    paint_gear()
    # corpo pintado em 256 e ampliado; rosto e cabelo pintados direto em 512 (atlas.TEX_SCALE)
    k = atlas.TEX_SCALE
    big = img.resize((atlas.SIZE * k, atlas.SIZE * k), Image.NEAREST).convert("RGBA")
    paint_clothes.detail(big)
    paint_face.paint_head(big)
    paint_face.paint_hair(big)
    # sem reduzir a paleta da textura inteira (rosto e cabelo perderiam tons); o corpo já vem com poucas cores
    final = paint_face.pad(big)
    out.parent.mkdir(parents=True, exist_ok=True)
    final.save(out)
    print(f"atlas salvo em {out}")


if __name__ == "__main__":
    main()
