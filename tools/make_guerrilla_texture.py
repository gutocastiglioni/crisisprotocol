"""Atlas 512x512 do guerrilheiro encapuzado (milícia), no layout de art/guerrilla_atlas.py: moletom cinza-escuro com
capuz, bolso canguru, punhos e bainha canelados e as tiras pretas do colete; balaclava preta de malha com os furos
dos olhos e da boca; luvas pretas; calça cargo cáqui com bolsos e a barra embolada; coturno de couro marrom.
As armas são copiadas do atlas da heroína (mesmos retângulos). A trama e as rugas do tecido vêm de
tools/paint_clothes.py (texture_pass), como na heroína; o fundo é preenchido com a cor das peças (paint_face.pad).

Uso: python tools/make_guerrilla_texture.py   (depois art/build_guerrilla.py)
Saída: game/assets/characters/guerrilla_atlas.png
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "art"))
sys.path.insert(0, str(ROOT / "tools"))
import guerrilla_atlas as GA  # noqa: E402
import paint_clothes  # noqa: E402
import paint_face  # noqa: E402

OUT = ROOT / "game/assets/characters/guerrilla_atlas.png"
HEROINE = ROOT / "game/assets/characters/heroine_atlas.png"
K = GA.TEX_SCALE
rng = random.Random(47)

HOODIE = (64, 67, 62)
HOODIE_HI = (86, 90, 83)
HOODIE_LO = (40, 42, 39)
HOODIE_DK = (28, 30, 28)
WEB = (30, 31, 29)  # tiras do colete
WEB_HI = (52, 53, 49)
KHAKI = (98, 88, 62)
KHAKI_HI = (120, 110, 80)
KHAKI_LO = (72, 64, 46)
KHAKI_DK = (52, 46, 34)
BOOT = (68, 49, 36)
BOOT_HI = (98, 72, 52)
BOOT_LO = (44, 32, 24)
SOLE = (24, 22, 20)
LACE = (40, 34, 28)
GLOVE = (34, 34, 36)
GLOVE_HI = (56, 56, 60)
KNIT = (24, 24, 27)
KNIT_HI = (42, 42, 47)
KNIT_RIM = (54, 54, 60)
SKIN = (172, 124, 96)
SKIN_LO = (120, 82, 62)
LIP = (84, 54, 50)
EYE_WHITE = (214, 206, 194)
IRIS = (70, 50, 34)
CORD = (186, 182, 168)
METAL = (150, 150, 140)

img = Image.new("RGBA", (GA.SIZE * K, GA.SIZE * K), (255, 0, 255, 255))
d = ImageDraw.Draw(img)


def rect(name):
    x, y, w, h = GA.RECTS[name]
    return x * K, y * K, w * K, h * K


def ux(name, u):
    x, _, w, _ = rect(name)
    return int(round(x + u * w))


def zy(name, z):
    return int(round(GA.z_to_py(name, z) * K))


def vy(name, v):
    _, y, _, h = rect(name)
    return int(round(y + v * h))


def fill(name, color):
    x, y, w, h = rect(name)
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=color)


def shade(name, fn):
    """Multiplica cada pixel da peça por fn(u, v) (luz pintada, como nos jogos da época)."""
    x, y, w, h = rect(name)
    px = img.load()
    for j in range(h):
        for i in range(w):
            k = fn((i + 0.5) / w, (j + 0.5) / h)
            r, g, b, a = px[x + i, y + j]
            px[x + i, y + j] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)


def round_shade(depth=0.72):
    """Frente (u = 0.5) clara, costas (u = 0/1) escuras."""
    return lambda u, v: depth + (1 - depth) * (1 - abs(u - 0.5) * 2) ** 0.6


def ribs(x0, y0, x1, y1, base, lo, step=4):
    """Canelado (punho, bainha, malha): colunas claras e escuras."""
    d.rectangle([x0, y0, x1, y1], fill=base)
    for x in range(x0, x1 + 1, step):
        d.line([(x, y0), (x, y1)], fill=lo)


def stitch(pts, color=HOODIE_HI, dash=3, gap=2):
    paint_clothes.stitch(d, pts, color, dash, gap)


# ------------------------------------------------------------------ moletom (tronco) e calça
def paint_torso():
    x, y, w, h = rect("torso")
    fill("torso", HOODIE)
    hem_bot, hem_top = zy("torso", 0.905), zy("torso", 0.95)
    # calça por baixo da bainha: cáqui com braguilha e passadores do cinto escondidos
    d.rectangle([x, hem_bot, x + w - 1, y + h - 1], fill=KHAKI)
    d.line([(ux("torso", 0.5), hem_bot), (ux("torso", 0.5), y + h - 1)], fill=KHAKI_DK, width=2)
    stitch([(ux("torso", 0.53), hem_bot + 2), (ux("torso", 0.53), y + h - 8), (ux("torso", 0.5), y + h - 2)], KHAKI_HI)
    # bainha canelada e a aba por cima da calça (sombra embaixo)
    ribs(x, hem_top, x + w - 1, hem_bot, HOODIE_LO, HOODIE_DK, 4)
    d.line([(x, hem_top), (x + w - 1, hem_top)], fill=HOODIE_HI)
    d.rectangle([x, hem_bot + 1, x + w - 1, hem_bot + 4], fill=KHAKI_DK)
    # bolso canguru na frente: trapézio com as aberturas inclinadas dos lados
    top, bot = zy("torso", 1.13), zy("torso", 0.96)
    l0, l1, r0, r1 = ux("torso", 0.39), ux("torso", 0.36), ux("torso", 0.61), ux("torso", 0.64)
    d.polygon([(l0, top), (r0, top), (r1, bot), (l1, bot)], fill=(70, 73, 68))
    for a, b in (((l0, top), (l1, bot)), ((r0, top), (r1, bot))):
        d.line([a, b], fill=HOODIE_DK, width=3)
    stitch([(l0 + 3, top + 2), (r0 - 3, top + 2)])
    stitch([(l1 + 3, bot - 2), (r1 - 3, bot - 2)])
    # costuras raglan (do pescoço à axila) e laterais
    neck, arm = zy("torso", 1.46), zy("torso", 1.33)
    for u0, u1 in ((0.42, 0.31), (0.58, 0.69), (0.08, 0.19), (0.92, 0.81)):
        d.line([(ux("torso", u0), neck), (ux("torso", u1), arm)], fill=HOODIE_LO, width=2)
        stitch([(ux("torso", u0) + 3, neck), (ux("torso", u1) + 3, arm)])
    for u in (0.25, 0.75):
        d.line([(ux("torso", u), arm), (ux("torso", u), hem_top)], fill=HOODIE_LO, width=2)
    # colete: alças pretas pelos ombros, cinta embaixo das bolsas e X nas costas
    strap_top, belly = zy("torso", 1.47), zy("torso", 1.19)
    for u in (0.405, 0.595):
        d.rectangle([ux("torso", u) - 6, strap_top, ux("torso", u) + 6, zy("torso", 1.28)], fill=WEB)
        d.line([(ux("torso", u) - 6, strap_top), (ux("torso", u) - 6, zy("torso", 1.28))], fill=WEB_HI)
    d.rectangle([x, belly - 6, x + w - 1, belly + 6], fill=WEB)
    d.line([(x, belly - 6), (x + w - 1, belly - 6)], fill=WEB_HI)
    d.rectangle([ux("torso", 0.5) - 8, belly - 7, ux("torso", 0.5) + 8, belly + 7], fill=(60, 60, 56))  # fivela
    # X nas costas (u = 0 = 1 é o meio das costas: desenha com a volta, de -0.1 a 0.1)
    for u0, u1 in ((-0.10, 0.10), (0.10, -0.10)):
        for off in (0, w):
            d.line([(x + u0 * w + off, zy("torso", 1.47)), (x + u1 * w + off, zy("torso", 1.19))], fill=WEB, width=10)
    # sombra (oclusão) logo abaixo das bolsas e no pescoço, debaixo do capuz
    shade("torso", lambda u, v: 1.0 - 0.25 * max(0.0, 1 - abs(v - GA.z_to_v("torso", 1.43)) / 0.06))
    shade("torso", round_shade(0.68))
    shade("torso", lambda u, v: 1.06 - 0.16 * v)


def paint_hood():
    """Capuz (retângulo "hair"): u ao longo da abertura (0 e 1 = beiras do rosto, 0.5 = nuca), v da base ao topo."""
    x, y, w, h = rect("hair")
    fill("hair", HOODIE)
    # beira da abertura: barra dobrada e pespontada, mais escura
    for u0, u1 in ((0.0, 0.07), (0.93, 1.0)):
        d.rectangle([ux("hair", u0), y, ux("hair", u1), y + h - 1], fill=HOODIE_LO)
    stitch([(ux("hair", 0.07) - 3, y), (ux("hair", 0.07) - 3, y + h - 1)])
    stitch([(ux("hair", 0.93) + 3, y), (ux("hair", 0.93) + 3, y + h - 1)])
    # ilhoses dos cordões embaixo, costura do meio (topo da cabeça até a nuca)
    for u in (0.035, 0.965):
        cx, cy = ux("hair", u), vy("hair", 0.12)
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=METAL, outline=HOODIE_DK)
    d.line([(ux("hair", 0.5), vy("hair", 0.25)), (ux("hair", 0.5), y + h - 1)], fill=HOODIE_LO, width=2)
    stitch([(ux("hair", 0.5) + 3, vy("hair", 0.25)), (ux("hair", 0.5) + 3, y + h - 1)])
    # caimento: sombra embaixo (sobre os ombros) e luz no alto
    shade("hair", lambda u, v: 0.70 + 0.38 * min(1.0, v / 0.6))
    shade("hair", lambda u, v: 0.80 + 0.20 * (1 - abs(u - 0.5) * 2) ** 0.4)


def paint_sleeves():
    for name in ("sleeve_upper", "sleeve_lower"):
        fill(name, HOODIE)
        x, y, w, h = rect(name)
        d.line([(ux(name, 0.25), y), (ux(name, 0.25), y + h - 1)], fill=HOODIE_LO, width=2)
    x, y, w, h = rect("sleeve_lower")
    cuff = y + int(h * 0.84)
    ribs(x, cuff, x + w - 1, y + h - 1, HOODIE_LO, HOODIE_DK, 3)
    d.line([(x, cuff), (x + w - 1, cuff)], fill=HOODIE_HI)
    for name in ("sleeve_upper", "sleeve_lower"):
        shade(name, round_shade(0.74))
    x, y, w, h = rect("hand")
    fill("hand", GLOVE)
    for i in range(x + 3, x + w, 9):  # nós dos dedos acolchoados
        d.rounded_rectangle([i, y + int(h * 0.45), i + 6, y + int(h * 0.62)], radius=2, fill=GLOVE_HI)
    d.rectangle([x, y, x + w - 1, y + int(h * 0.18)], fill=(26, 26, 28))  # punho da luva
    shade("hand", round_shade(0.8))


def paint_legs():
    x, y, w, h = rect("thigh")
    fill("thigh", KHAKI)
    for u in (0.25, 0.75):
        d.line([(ux("thigh", u), y), (ux("thigh", u), y + h - 1)], fill=KHAKI_LO, width=2)
        stitch([(ux("thigh", u) + 3, y), (ux("thigh", u) + 3, y + h - 1)], KHAKI_HI)
    shade("thigh", round_shade(0.72))
    shade("thigh", lambda u, v: 1.04 - 0.1 * v)
    x, y, w, h = rect("shin")
    fill("shin", KHAKI)
    for u in (0.25, 0.75):
        d.line([(ux("shin", u), y), (ux("shin", u), zy("shin", 0.215))], fill=KHAKI_LO, width=2)
    # pences do joelho
    for u in (0.42, 0.58):
        d.arc([ux("shin", u) - 10, zy("shin", 0.50), ux("shin", u) + 10, zy("shin", 0.46)], 0, 180, fill=KHAKI_LO, width=2)
    # barra embolada (vincos) e cano do coturno
    boot = zy("shin", 0.205)
    for k in range(5):
        yy = zy("shin", 0.25) + k * 4
        d.line([(x, yy + rng.randint(-1, 1)), (x + w - 1, yy + rng.randint(-1, 1))], fill=KHAKI_DK if k % 2 else KHAKI_HI)
    d.rectangle([x, boot, x + w - 1, y + h - 1], fill=BOOT)
    d.rectangle([x, boot, x + w - 1, boot + 6], fill=BOOT_LO)  # gola acolchoada
    cx = ux("shin", 0.5)
    for j in range(boot + 10, y + h - 2, 7):  # cadarço cruzado com ilhoses
        d.line([(cx - 7, j), (cx + 7, j + 5)], fill=LACE, width=2)
        d.line([(cx + 7, j), (cx - 7, j + 5)], fill=LACE, width=2)
        for s in (-9, 9):
            d.ellipse([cx + s - 2, j - 1, cx + s + 2, j + 3], fill=METAL)
    for u in (0.25, 0.75):
        stitch([(ux("shin", u), boot + 8), (ux("shin", u), y + h - 1)], BOOT_HI)
    shade("shin", round_shade(0.72))
    # coturno: u = 0 em cima do pé, 0.5 = sola; v do calcanhar (0) ao bico (1)
    x, y, w, h = rect("foot")
    fill("foot", BOOT)
    d.rectangle([ux("foot", 0.32), y, ux("foot", 0.68), y + h - 1], fill=SOLE)
    for u in (0.32, 0.68):
        d.line([(ux("foot", u), y), (ux("foot", u), y + h - 1)], fill=BOOT_HI, width=2)  # vira da sola
    d.line([(x, vy("foot", 0.72)), (ux("foot", 0.32), vy("foot", 0.72))], fill=BOOT_LO, width=2)  # biqueira
    d.line([(ux("foot", 0.68), vy("foot", 0.72)), (x + w - 1, vy("foot", 0.72))], fill=BOOT_LO, width=2)
    for v in (0.2, 0.32, 0.44, 0.56):  # cadarço em cima
        d.line([(x, vy("foot", v)), (ux("foot", 0.08), vy("foot", v) + 3)], fill=LACE, width=2)
        d.line([(ux("foot", 0.92), vy("foot", v) + 3), (x + w - 1, vy("foot", v))], fill=LACE, width=2)


def paint_gear():
    # bolsas de carregador (nylon preto-oliva): aba com fecho, laterais com elástico
    x, y, w, h = rect("pouch")
    fill("pouch", (44, 46, 40))
    d.rectangle([x, y, x + w - 1, y + int(h * 0.36)], fill=(54, 56, 49))
    d.line([(x, y + int(h * 0.36)), (x + w - 1, y + int(h * 0.36))], fill=WEB, width=3)
    d.rectangle([x + w // 2 - 7, y + int(h * 0.26), x + w // 2 + 6, y + int(h * 0.46)], fill=(70, 70, 64))
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=WEB, width=2)
    # bolso cargo cáqui com aba e botão
    x, y, w, h = rect("cargo")
    fill("cargo", KHAKI)
    d.rectangle([x, y, x + w - 1, y + int(h * 0.32)], fill=KHAKI_HI)
    d.line([(x, y + int(h * 0.32)), (x + w - 1, y + int(h * 0.32))], fill=KHAKI_DK, width=2)
    d.ellipse([x + w // 2 - 4, y + int(h * 0.2), x + w // 2 + 4, y + int(h * 0.2) + 8], fill=KHAKI_DK)
    stitch([(x + 3, y + 3), (x + w - 4, y + 3), (x + w - 4, y + h - 4), (x + 3, y + h - 4), (x + 3, y + 3)], KHAKI_LO)
    # cordão do capuz com a ponteira escura
    x, y, w, h = rect("cord")
    fill("cord", CORD)
    d.rectangle([x, y + int(h * 0.75), x + w - 1, y + h - 1], fill=(60, 60, 58))
    # gola da balaclava (malha)
    x, y, w, h = rect("neck")
    ribs(x, y, x + w - 1, y + h - 1, KNIT, (16, 16, 18), 3)


def _hole(cx, cy, rx, ry, inner):
    """Furo da balaclava: borda de malha mais clara e, dentro, pele (inner desenha o resto)."""
    d.ellipse([cx - rx - 3, cy - ry - 3, cx + rx + 3, cy + ry + 3], fill=KNIT_RIM)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=SKIN)
    inner(cx, cy, rx, ry)


def _eye(cx, cy, rx, ry):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + 1], fill=SKIN_LO)  # sombra da pálpebra
    d.ellipse([cx - rx + 2, cy - 2, cx + rx - 2, cy + ry - 1], fill=EYE_WHITE)
    d.ellipse([cx - 3, cy - 2, cx + 3, cy + ry - 1], fill=IRIS)
    d.point([(cx, cy), (cx - 1, cy)], fill=(12, 10, 10))
    d.line([(cx - rx + 1, cy - 2), (cx + rx - 1, cy - 2)], fill=(30, 22, 18), width=1)  # pálpebra


def _mouth(cx, cy, rx, ry):
    d.ellipse([cx - rx + 2, cy - ry + 2, cx + rx - 2, cy + ry - 2], fill=LIP)
    d.line([(cx - rx + 4, cy), (cx + rx - 4, cy)], fill=(50, 28, 26), width=2)


def paint_balaclava():
    x, y, w, h = rect("head")
    fill("head", KNIT)
    # malha: pontos em V discretos (colunas) e um brilho suave nas fileiras
    px = img.load()
    for j in range(y, y + h):
        for i in range(x, x + w):
            if (i + (j // 2)) % 4 == 0:
                px[i, j] = (20, 20, 22, 255)
            elif j % 6 == 0:
                px[i, j] = (32, 32, 36, 255)
    eye_y = zy("head", 1.624)
    for s in (-1, 1):
        _hole(ux("head", 0.5 + s * 0.06), eye_y, 10, 6, _eye)
    _hole(ux("head", 0.5), zy("head", 1.566), 9, 4, _mouth)
    shade("head", round_shade(0.78))


def copy_weapons():
    src = Image.open(HEROINE).convert("RGBA")
    for name in ("pistol", "rifle", "shotgun", "shotgun_wood"):
        x, y, w, h = rect(name)
        img.paste(src.crop((x, y, x + w, y + h)), (x, y))


def main():
    paint_torso()
    paint_hood()
    paint_sleeves()
    paint_legs()
    paint_gear()
    paint_balaclava()
    # trama do tecido, grão do couro e rugas (cotovelo, bainha, joelho, barra embolada)
    folds = {
        "torso": [(0.68, 0.78, 0.7)],
        "sleeve_upper": [(0.72, 1.0, 0.9)],
        "sleeve_lower": [(0.0, 0.25, 1.0), (0.6, 0.84, 0.8)],
        "thigh": [(0.0, 0.12, 0.6), (0.86, 1.0, 0.6)],
        "shin": [(0.0, 0.12, 0.5), (0.5, 0.71, 1.0)],
        "hair": [(0.0, 0.25, 0.8)],
    }
    paint_clothes.texture_pass(img, ["torso", "hair", "sleeve_upper", "sleeve_lower", "thigh", "shin", "foot", "hand", "pouch"], folds)
    copy_weapons()
    final = paint_face.pad(img)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    final.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
