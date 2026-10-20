"""Rosto e cabelo da heroína pintados direto na textura de 512 (com supersampling 4x no rosto).

Coordenadas: retângulos de art/atlas.py vezes atlas.TEX_SCALE. Na cabeça (loft de 16 lados de
art/heroine_head.py) u = volta (0.5 = frente, u < 0.5 = lado esquerdo dela) e v = altura (Z_RANGES["head"]).
Usado por tools/make_textures.py.
"""
import math
import random

from PIL import Image, ImageDraw, ImageFilter

import atlas

rng = random.Random(21)

SKIN = (232, 186, 160)
SKIN_LO = (196, 142, 120)
SKIN_SH = (170, 116, 98)
BLUSH = (226, 150, 136)
LIP_UP = (158, 58, 70)
LIP_LO = (186, 82, 92)
LIP_LINE = (112, 46, 50)
BROW = (92, 30, 24)
LASH = (34, 18, 18)
EYE_WHITE = (226, 220, 212)
IRIS = (96, 112, 78)
IRIS_LO = (54, 66, 44)
PUPIL = (16, 14, 12)
HAIR = (186, 26, 28)
HAIR_LO = (112, 12, 16)
HAIR_DK = (78, 8, 12)
HAIR_HI = (236, 78, 60)

S = 4  # supersampling do rosto


def rect512(name):
    k = atlas.TEX_SCALE
    x, y, w, h = atlas.RECTS[name]
    return x * k, y * k, w * k, h * k


def _mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _rx_at(z):
    """Raio lateral da cabeça na altura z (mesmos anéis de heroine_head, copiados aqui por serem só 3 pontos úteis)."""
    pts = [(1.52, 0.038), (1.558, 0.058), (1.598, 0.072), (1.64, 0.078), (1.69, 0.072)]
    for (z0, r0), (z1, r1) in zip(pts, pts[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return pts[0][1] if z < pts[0][0] else pts[-1][1]


def paint_head(img):
    x0, y0, w0, h0 = rect512("head")
    W, H = w0 * S, h0 * S
    top, bot = atlas.Z_RANGES["head"]
    canvas = Image.new("RGB", (W, H), HAIR_LO)
    d = ImageDraw.Draw(canvas)
    px = canvas.load()

    def zy(z):
        return (top - z) / (top - bot) * H

    def ux(u):
        return u * W

    def lat(x_m, z):
        """Deslocamento lateral em metros (positivo = esquerda dela) -> u."""
        return 0.5 - math.asin(max(-1, min(1, x_m / _rx_at(z)))) / (2 * math.pi)

    # pele com sombreado: frente clara, laterais e parte de baixo do queixo mais escuras
    for j in range(H):
        z = top - (j / H) * (top - bot)
        for i in range(W):
            u = i / W
            side = abs(u - 0.5) * 2  # 0 frente, 1 nuca
            if side > 0.62 or z > 1.70:
                continue
            k = 1.0 - 0.55 * max(0.0, side - 0.18) ** 1.3
            c = _mix(SKIN_SH, SKIN, max(0.0, min(1.0, k)))
            px[i, j] = c

    def ru(m):
        """Raio lateral em metros -> largura em u (volta da cabeça ~ 2*pi*7,7 cm)."""
        return m / 0.077 / (2 * math.pi)

    def ell(u, z, ru, rz, color):
        d.ellipse([ux(u - ru), zy(z + rz), ux(u + ru), zy(z - rz)], fill=color)

    soft = Image.new("RGB", (W, H), (0, 0, 0))
    sd = ImageDraw.Draw(soft)

    def shade(u, z, ru, rz, amount):
        sd.ellipse([ux(u - ru), zy(z + rz), ux(u + ru), zy(z - rz)], fill=(amount, amount, amount))

    for s in (1, -1):
        eu = lat(s * 0.031, 1.618)
        shade(eu, 1.622, 0.042, 0.011, 40)  # órbita
        shade(lat(s * 0.016, 1.598), 1.598, 0.012, 0.016, 34)  # lateral do nariz
        shade(lat(s * 0.05, 1.56), 1.555, 0.03, 0.03, 26)  # bochecha/mandíbula
    shade(0.5, 1.568, 0.022, 0.004, 46)  # sombra sob o nariz
    shade(0.5, 1.538, 0.03, 0.004, 30)  # sombra sob o lábio
    soft = soft.filter(ImageFilter.GaussianBlur(S * 3))
    canvas = Image.composite(Image.new("RGB", (W, H), SKIN_SH), canvas, soft.convert("L"))
    d = ImageDraw.Draw(canvas)

    # blush e brilho do nariz e do queixo
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    for s in (1, -1):
        u = lat(s * 0.042, 1.588)
        gd.ellipse([ux(u - 0.03), zy(1.598), ux(u + 0.03), zy(1.578)], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 4))
    canvas = Image.composite(Image.new("RGB", (W, H), BLUSH), canvas, glow)
    hl = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(hl)
    hd.rectangle([ux(0.496), zy(1.628), ux(0.504), zy(1.586)], fill=90)
    hd.ellipse([ux(0.49), zy(1.585), ux(0.51), zy(1.575)], fill=110)
    hd.ellipse([ux(0.485), zy(1.53), ux(0.515), zy(1.518)], fill=60)
    hl = hl.filter(ImageFilter.GaussianBlur(S * 1.5))
    canvas = Image.composite(Image.new("RGB", (W, H), (246, 212, 192)), canvas, hl)
    d = ImageDraw.Draw(canvas)

    # sobrancelhas: arco grosso por dentro, afinando para fora
    for s in (1, -1):
        pts = []
        for t in [i / 10 for i in range(11)]:
            xm = s * (0.011 + 0.036 * t)
            z = 1.643 + 0.005 * math.sin(math.pi * min(1.0, t * 1.3)) - 0.002 * t
            pts.append((ux(lat(xm, z)), zy(z), 3.4 - 2.0 * t))
        for (ax, ay, aw), (bx, by, bw) in zip(pts, pts[1:]):
            d.line([ax, ay, bx, by], fill=BROW, width=int(aw * S))

    # olhos amendoados: branco, íris, pupila, brilho, cílios de cima com ponta para fora, pálpebra
    for s in (1, -1):
        cxm, cz = s * 0.031, 1.618
        top_lid = [(ux(lat(s * (0.016 + 0.030 * t), cz)), zy(cz + 0.0066 * math.sin(math.pi * t) ** 0.8)) for t in [i / 8 for i in range(9)]]
        bot_lid = [(ux(lat(s * (0.016 + 0.030 * t), cz)), zy(cz - 0.0042 * math.sin(math.pi * t))) for t in [i / 8 for i in range(9)]]
        d.polygon(top_lid + bot_lid[::-1], fill=EYE_WHITE)
        iu = lat(cxm, cz)
        r = 0.0053
        ell(iu, cz + 0.0005, ru(r), r, IRIS_LO)
        ell(iu, cz + 0.0005, ru(r * 0.78), r * 0.78, IRIS)
        ell(iu, cz + 0.0005, ru(r * 0.38), r * 0.38, PUPIL)
        ell(iu + s * ru(0.0016), cz + 0.0022, ru(0.0011), 0.0011, (250, 250, 246))
        # cílios e pálpebra de cima por cima da íris (corta o topo dela)
        d.line(top_lid, fill=LASH, width=int(2.2 * S))
        wing = (ux(lat(s * 0.050, cz + 0.0045)), zy(cz + 0.0045))
        d.line([top_lid[-2], wing], fill=LASH, width=int(1.2 * S))
        d.line(bot_lid[2:], fill=_mix(SKIN_SH, LASH, 0.35), width=int(0.6 * S))
        crease = [(xx, yy - 0.0055 / (top - bot) * H) for xx, yy in top_lid[1:-1]]
        d.line(crease, fill=SKIN_SH, width=int(0.8 * S))

    # narinas
    for s in (1, -1):
        ell(lat(s * 0.0075, 1.575), 1.5745, ru(0.003), 0.0012, (150, 92, 82))

    # boca: lábio de cima com arco do cupido, de baixo mais cheio e claro, linha entre eles
    mz = 1.553
    half = 0.024

    def mouth_u(t):
        return lat(t * half, mz)

    upper = [(ux(mouth_u(t)), zy(mz + 0.0062 * (1 - abs(t)) ** 0.5 - 0.0012 * (abs(t) < 0.25))) for t in [i / 10 - 1 for i in range(21)]]
    line = [(ux(mouth_u(t)), zy(mz + 0.0004 * (1 - abs(t)))) for t in [i / 10 - 1 for i in range(21)]]
    lower = [(ux(mouth_u(t * 0.92)), zy(mz - 0.0085 * (1 - t * t) ** 0.6)) for t in [i / 10 - 1 for i in range(21)]]
    d.polygon(upper + line[::-1], fill=LIP_UP)
    d.polygon(line + lower[::-1], fill=LIP_LO)
    d.line(line, fill=LIP_LINE, width=int(0.9 * S))
    ell(0.5 + 0.003, mz - 0.0035, ru(0.004), 0.0012, (206, 112, 116))

    # orelhas (meio escondidas pelo cabelo) e linha do cabelo esfumada na testa
    for u in (0.25, 0.75):
        d.ellipse([ux(u - 0.018), zy(1.628), ux(u + 0.018), zy(1.582)], fill=SKIN_LO)
        d.ellipse([ux(u - 0.008), zy(1.618), ux(u + 0.008), zy(1.592)], fill=SKIN_SH)
    face = canvas.resize((w0, h0), Image.LANCZOS)
    fp = face.load()
    for j in range(h0):
        for i in range(w0):
            n = rng.randint(-3, 3)
            fp[i, j] = tuple(max(0, min(255, c + n)) for c in fp[i, j])
    img.paste(face, (x0, y0))


def paint_hair(img):
    """Fios na vertical (v = comprimento): raiz escura, faixa de brilho, pontas recortadas por alfa."""
    x0, y0, w, h = rect512("hair")
    px = img.load()
    cols = []
    for i in range(w):
        base = rng.choice((HAIR, HAIR, HAIR, HAIR_LO, _mix(HAIR, HAIR_HI, 0.3)))
        window = (i / w * 4) % 1.0  # as fitas usam janelas de 1/4 da largura
        edge = abs(window - 0.5) * 2
        cut = 0.9 + 0.09 * rng.random() - 0.1 * edge ** 1.5
        cols.append((base, cut))
    for i, (base, cut) in enumerate(cols):
        for j in range(h):
            t = j / (h - 1)
            k = 0.62 + 0.38 * min(1.0, t * 5)  # raiz mais escura
            c = _mix(HAIR_DK, base, k)
            if 0.12 < t < 0.24:  # brilho do cabelo liso
                c = _mix(c, HAIR_HI, 0.55 * math.sin((t - 0.12) / 0.12 * math.pi))
            elif 0.5 < t < 0.58:
                c = _mix(c, HAIR_HI, 0.25 * math.sin((t - 0.5) / 0.08 * math.pi))
            a = 255 if t < cut else 0
            px[x0 + i, y0 + j] = c + (a,)
    for _ in range(260):
        i = rng.randrange(w)
        j0 = rng.randrange(h - 12)
        color = rng.choice((HAIR_HI, HAIR_LO, HAIR_DK))
        for j in range(j0, min(h, j0 + rng.randint(6, 26))):
            r, g, b, a = px[x0 + i, y0 + j]
            px[x0 + i, y0 + j] = _mix((r, g, b), color, 0.6) + (a,)


def paint_braid(img, lobes=9):
    """Trança (retângulo "braid", tubo de art/heroine_head.build_braid): u = volta (0 = lado de fora, 0.25 = esquerda
    dela), v = comprimento. Lateral x linear na volta (1 = esquerda, -1 = direita; o lado de dentro repete o de fora).
    Gomo k vem do lado (+ se k par) e desce em diagonal passando do meio, por cima do começo do seguinte:
    fios ao longo do gomo, brilho no meio e vão escuro só entre um gomo e outro."""
    x0, y0, w, h = rect512("braid")
    ss = 4
    W, H = w * ss, h * ss
    canvas = Image.new("RGB", (W, H), HAIR_DK)
    px = canvas.load()
    for j in range(H):
        p = j / H * lobes
        for i in range(W):
            u = (i + 0.5) / W
            x = 4 * u if u <= 0.25 else (2 - 4 * u if u <= 0.75 else 4 * u - 4)
            best = None
            for k in (int(p) - 1, int(p)):  # o gomo de cima ainda cobre o começo deste
                t = p - k
                if k < 0 or t > 1.35:
                    continue
                s = 1 if k % 2 == 0 else -1
                e = (x - s * (1.05 - 1.25 * t)) / (0.85 * math.sin(math.pi * min(t, 1.0) * 0.8 + 0.35))
                if abs(e) < 1 and (best is None or t > best[0]):
                    best = (t, e, k, s)
            if best is None:
                continue
            t, e, k, s = best
            shade = (1 - e * e) ** 0.5 * (0.45 + 0.55 * math.sin(math.pi * min(1.0, t * 0.9 + 0.05)))
            c = _mix(HAIR_DK, HAIR, min(1.0, 0.25 + shade))
            gloss = max(0.0, 1 - abs(e + 0.2 * s) / 0.4) * max(0.0, math.sin(math.pi * (t - 0.15) / 0.6))
            if 0.15 < t < 0.75:
                c = _mix(c, HAIR_HI, 0.5 * gloss)
            if math.sin(e * 10 + k * 1.7) > 0.6:  # fios
                c = _mix(c, HAIR_LO, 0.35)
            px[i, j] = c
    braid = canvas.resize((w, h), Image.LANCZOS)
    bp = braid.load()
    out = img.load()
    for j in range(h):
        for i in range(w):
            n = rng.randint(-4, 4)
            out[x0 + i, y0 + j] = tuple(max(0, min(255, c + n)) for c in bp[i, j]) + (255,)


def pad(img, bg=(255, 0, 255), passes=6):
    """Espalha a cor das peças por cima do fundo (magenta): com filtro linear e mipmaps a borda não puxa magenta."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    p = rgb.load()
    empty = {(i, j) for j in range(h) for i in range(w) if p[i, j] == bg}
    for _ in range(passes):
        fill = {}
        for (i, j) in empty:
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (i + di, j + dj)
                if 0 <= q[0] < w and 0 <= q[1] < h and q not in empty:
                    fill[(i, j)] = p[q]
                    break
        for k, c in fill.items():
            p[k] = c
        empty -= fill.keys()
    for k in empty:  # longe de qualquer peça: cinza neutro (nunca é amostrado)
        p[k] = (40, 40, 40)
    out = rgb.convert("RGBA")
    if img.mode == "RGBA":
        out.putalpha(img.getchannel("A"))
    return out
