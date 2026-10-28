"""Atlas 512x512 da parte de cima do guerrilheiro (art/guerrilla_body.py), no layout de art/guerrilla_atlas.py e com
as cores de art/guerrilla_spec.py COLORS: moletom cinza-chumbo liso (tronco com a barra canelada e mangas), colete preto
com debrum e costuras do painel (retângulo "vest", art/guerrilla_vest.py), bolsas de carregador pretas, mãos de pele.
A cabeça (balaclava, olhos e janela dos olhos), os braços e a calça/coturnos têm texturas próprias (art/guerrilla_head.py,
art/guerrilla_paint.py, art/guerrilla_arms.py, art/guerrilla_lower.py); com "colete_antigo" sai o atlas das partes antigas
(colete pintado no tronco, capuz com a frente projetada da referência).
As armas são copiadas do atlas da heroína (mesmos retângulos); trama e rugas de tools/paint_clothes.py (texture_pass);
o fundo é preenchido com a cor das peças (paint_face.pad).

Uso: python tools/make_guerrilla_texture.py [saida.png] [colete_antigo]   (depois art/build_guerrilla.py)
Saída padrão: game/assets/characters/guerrilla_atlas.png
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "art"))
sys.path.insert(0, str(ROOT / "tools"))
import guerrilla_atlas as GA  # noqa: E402
import guerrilla_spec as G  # noqa: E402
import paint_clothes  # noqa: E402
import paint_face  # noqa: E402

OUT = ROOT / "game/assets/characters/guerrilla_atlas.png"
HEROINE = ROOT / "game/assets/characters/heroine_atlas.png"
K = GA.TEX_SCALE
C = G.COLORS
rng = random.Random(47)

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


def scale(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def shade(name, fn):
    """Multiplica cada pixel da peça por fn(u, v) (luz pintada, como nos jogos da época)."""
    x, y, w, h = rect(name)
    px = img.load()
    for j in range(h):
        for i in range(w):
            k = fn((i + 0.5) / w, (j + 0.5) / h)
            r, g, b, a = px[x + i, y + j]
            px[x + i, y + j] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)


def round_shade(depth=0.75):
    """Frente (u = 0.5) clara, costas (u = 0/1) escuras."""
    return lambda u, v: depth + (1 - depth) * (1 - abs(u - 0.5) * 2) ** 0.6


def stitch(pts, color, dash=3, gap=2):
    paint_clothes.stitch(d, pts, color, dash, gap)


def _coverage_grid():
    """O colete cobre o vértice (anel z, coluna j)? A mesma conta da malha (art/guerrilla_body._torso_ring)."""
    grid = {}
    for z, *_ in G.BODY:
        row = []
        for j in range(G.TORSO_SIDES):
            v = G.vest_point(z, 2 * math.pi * j / G.TORSO_SIDES)
            row.append(v is not None and G.vest_covers(z, v[0]))
        grid[z] = row
    return grid


def _vest_x(z, i, w):
    """x do colete na coluna i (para as costuras do painel), interpolando os anéis."""
    zs = [r for r in sorted(G.VEST)]
    th = 2 * math.pi * (i + 0.5) / w
    if z <= zs[0]:
        return G.vest_point(zs[0], th)[0]
    for a, b in zip(zs, zs[1:]):
        if a <= z <= b:
            t = (z - a) / (b - a)
            return G.vest_point(a, th)[0] * (1 - t) + G.vest_point(b, th)[0] * t
    return G.vest_point(zs[-1], th)[0]


# ------------------------------------------------------------------ moletom e colete (tronco)
def paint_torso():
    """Mesma regra da malha (guerrilla_spec.vest_covers): o colete cobre tudo abaixo da axila e, acima, até a cava;
    o resto é o moletom. Debrum mais escuro em todas as bordas do colete, manchas escuras suaves (mais embaixo, como na
    referência) e as costuras do painel da placa."""
    x, y, w, h = rect("torso")
    top_z, bot_z = GA.Z_RANGES["torso"]
    grid = _coverage_grid()
    zs = sorted(grid)
    zrow = lambda j: top_z - (j + 0.5) / h * (top_z - bot_z)
    covered = np.zeros((h, w), bool)
    for j in range(h):
        z = zrow(j)
        zn = min(zs, key=lambda q: abs(q - z))  # a borda cai no meio das faces do degrau, como na malha
        for i in range(w):
            covered[j, i] = grid[zn][int(round(i / w * G.TORSO_SIDES)) % G.TORSO_SIDES]
    # borda: pixel do colete com vizinho de moletom (2 px)
    edge = covered & ~(np.roll(covered, 2, 1) & np.roll(covered, -2, 1) & np.roll(covered, 2, 0) & np.roll(covered, -2, 0))
    # debrum só onde o colete tem borda de verdade: a cava (acima da axila) e a barra; nas laterais abaixo da axila o
    # colete é contínuo (a grade dos vértices desenhava uma "gota" ali)
    rows_z = np.array([zrow(j) for j in range(h)])
    edge &= ((rows_z >= 1.33) | (rows_z <= G.VEST_Z[0] + 0.012))[:, None]
    px = img.load()
    # manchas escuras suaves
    blot = Image.new("L", (w, h), 0)
    bd = ImageDraw.Draw(blot)
    for _ in range(55):
        z = G.VEST_Z[0] + rng.random() ** 1.7 * 0.40
        cx, cy = rng.random() * w, zy("torso", z) - y
        rx, ry = rng.uniform(8, 20), rng.uniform(4, 9)
        bd.polygon([(cx + rx * math.cos(a) * rng.uniform(0.7, 1.15), cy + ry * math.sin(a) * rng.uniform(0.7, 1.15))
                    for a in [i * math.pi / 5 for i in range(10)]], fill=150)
    blot = np.asarray(blot.filter(ImageFilter.GaussianBlur(2.5))) / 255.0
    # alto do colete mais claro, de 1,22 para baixo mais escuro com as manchas (como na referência); a gola do capuz
    # cai sobre o alto do colete (faixa de cima do tronco na cor do capuz)
    vest_hi, vest_lo, dark, hoodie = (np.array(C[k]) for k in ("vest", "vest_low", "vest_dark", "hoodie"))
    cowl = np.array(C["hood"])
    for j in range(h):
        z = zrow(j)
        tone = min(1.0, max(0.0, (1.30 - z) / 0.06))
        vest = vest_hi + (vest_lo - vest_hi) * tone
        for i in range(w):
            if z > 1.489 and abs(math.sin(2 * math.pi * (i + 0.5) / w)) < 0.64:  # só em volta do pescoço
                col = cowl
            elif covered[j, i]:
                col = vest + (dark * 0.85 - vest) * min(1.0, blot[j, i] * 1.2) * (0.3 + 0.45 * tone)
                if edge[j, i]:
                    col = dark * 0.85
            else:
                col = hoodie
            px[x + i, y + j] = tuple(int(v) for v in col) + (255,)
    # costuras do painel da placa (frente e costas), de 1,00 a 1,40
    seam = tuple(int(v) for v in dark * 0.8) + (255,)
    for j in range(zy("torso", 1.40) - y, zy("torso", 1.00) - y):
        z = zrow(j)
        for i in range(w):
            if covered[j, i] and abs(abs(_vest_x(z, i, w)) - 0.15) < 0.004:
                px[x + i, y + j] = seam
    # costura de cima do bolso da placa (frente), em z 1,40, entre as costuras laterais
    j = zy("torso", 1.40) - y
    for i in range(w):
        if covered[j, i] and abs(_vest_x(1.40, i, w)) < 0.15 and math.cos(2 * math.pi * (i + 0.5) / w) < 0:
            px[x + i, y + j] = seam
    shade("torso", round_shade(0.78))
    shade("torso", lambda u, v: 1.04 - 0.10 * v)


# ------------------------------------------------------------------ capuz e balaclava
def face_u(j):
    return j / G.HEAD_SIDES


def paint_head():
    """Capuz (retângulo "head", u = volta, 0.5 = frente): a frente entre as bordas (FACE_RIM) é a balaclava; entre a
    borda e o rosto, a parede de dentro do capuz. Fresta dos olhos com pele e olhos discretos."""
    x, y, w, h = rect("head")
    fill("head", C["hood"])
    for u in (0.0, 1.0):  # costura do meio (nuca ao alto)
        d.line([(ux("head", u), y), (ux("head", u), zy("head", 1.56))], fill=scale(C["hood"], 0.75), width=2)
    front = G.HEAD_SIDES // 2
    rim_l, rim_r = front - G.FACE_RIM, front + G.FACE_RIM
    face_l, face_r = rim_l + 1, rim_r - 1
    open_top, open_bot = zy("head", 1.722), zy("head", 1.522)
    d.rectangle([ux("head", face_u(rim_l)), open_top, ux("head", face_u(rim_r)), open_bot], fill=C["hood_in"])
    for j in (rim_l, rim_r):  # a borda da abertura, um pouco mais clara
        d.line([(ux("head", face_u(j)), open_top), (ux("head", face_u(j)), open_bot)], fill=scale(C["hood"], 1.25), width=2)
    fx0, fx1 = ux("head", face_u(face_l)), ux("head", face_u(face_r))
    knit = np.array(C["knit"])
    px = img.load()
    for j in range(open_top, open_bot):
        for i in range(fx0, fx1):
            k = 0.86 if (i + (j // 2)) % 4 == 0 else (1.1 if j % 4 == 0 else 1.0)
            px[i, j] = tuple(int(v * k) for v in knit) + (255,)
    # fresta dos olhos (como na referência: estreita, pele escura na sombra do capuz, olhos pequenos)
    e0, e1 = zy("head", 1.672), zy("head", 1.642)
    eye_off = 0.5 * (0.032 / G.FACE[1][0]) / G.HEAD_SIDES
    sx0, sx1 = ux("head", 0.5 - eye_off * 2.3), ux("head", 0.5 + eye_off * 2.3)
    skin = np.array(C["eye_skin"])
    for j in range(e0, e1 + 1):
        t = (j - e0) / max(1, e1 - e0)
        for i in range(sx0, sx1):
            edge = min(i - sx0, sx1 - 1 - i)
            k = (0.55 + 0.45 * t) * (0.75 if edge < 2 else 1.0)
            px[i, j] = tuple(int(v * k) for v in skin) + (255,)
    cy = (e0 + e1) // 2 + 1
    for sgn in (-1, 1):
        cx = ux("head", 0.5 + sgn * eye_off)
        d.ellipse([cx - 4, cy - 2, cx + 4, cy + 2], fill=(124, 110, 100))
        d.ellipse([cx - 1, cy - 2, cx + 2, cy + 2], fill=(42, 30, 24))
        d.line([(cx - 5, cy - 3), (cx + 5, cy - 4)], fill=(48, 36, 30), width=1)  # sobrancelha
    for s2 in (-1, 1):  # ilhoses dos cordões na gola
        cx, cy2 = ux("head", 0.5 + s2 * 0.058), zy("head", 1.52)
        d.ellipse([cx - 2, cy2 - 2, cx + 2, cy2 + 2], fill=(110, 110, 104))
    shade("head", lambda u, v: 0.84 + 0.22 * min(1.0, (1 - v) / 0.7))


# ------------------------------------------------------------------ mangas, mãos e equipamento
def paint_sleeves():
    for name in ("sleeve_upper", "sleeve_lower"):
        fill(name, C["hoodie"])
        x, y, w, h = rect(name)
        d.line([(ux(name, 0.0), y), (ux(name, 0.0), y + h - 1)], fill=scale(C["hoodie"], 0.85), width=1)
    x, y, w, h = rect("sleeve_lower")
    cuff = y + int(h * 0.82)
    d.rectangle([x, cuff, x + w - 1, y + h - 1], fill=scale(C["hoodie"], 0.85))
    for i in range(x, x + w, 3):  # punho canelado
        d.line([(i, cuff), (i, y + h - 1)], fill=scale(C["hoodie"], 0.68))
    d.line([(x, cuff), (x + w - 1, cuff)], fill=scale(C["hoodie"], 1.2))
    for name in ("sleeve_upper", "sleeve_lower"):
        shade(name, round_shade(0.76))


def paint_hand():
    x, y, w, h = rect("hand")
    fill("hand", C["skin"])
    # dedos dobrados na frente do punho (u = 0.5): sulcos entre eles e os nós mais claros
    for u in (0.42, 0.5, 0.58):
        d.line([(ux("hand", u), vy("hand", 0.45)), (ux("hand", u), y + h - 1)], fill=scale(C["skin"], 0.7), width=1)
    d.line([(ux("hand", 0.34), vy("hand", 0.42)), (ux("hand", 0.66), vy("hand", 0.42))], fill=scale(C["skin"], 1.12), width=2)
    shade("hand", round_shade(0.78))


def paint_gear():
    x, y, w, h = rect("pouch")  # bolsa de carregador (corpo e aba são caixas à parte): lona lisa com borda costurada
    fill("pouch", C["mag"])
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=scale(C["mag"], 0.66), width=3)
    d.rectangle([x + w // 2 - 4, y + 4, x + w // 2 + 4, y + h // 3], fill=scale(C["mag"], 0.72))  # lingueta da aba
    stitch([(x + 6, y + 6), (x + w - 7, y + 6), (x + w - 7, y + h - 7), (x + 6, y + h - 7), (x + 6, y + 6)], scale(C["mag"], 1.18))
    x, y, w, h = rect("neck")  # pescoço da balaclava (entre a gola e a cabeça do corpo base): malha
    for j in range(y, y + h):
        for i in range(x, x + w):
            k = 0.8 if (i + j // 2) % 4 == 0 else 1.0
            img.putpixel((i, j), scale(C["knit"], k) + (255,))
    x, y, w, h = rect("cord")  # cordão claro com a ponteira escura
    fill("cord", C["cord"])
    d.rectangle([x, y + int(h * 0.8), x + w - 1, y + h - 1], fill=(56, 56, 54))


# ------------------------------------------------------------------ projeção da referência (frente do tronco e bolsas)
REF_IMG = ROOT / "art/ref/guerrilla_front.png"  # o primeiro boneco do painel que o usuário mandou (vista de frente)
REF_TOP, REF_H, REF_CX = 61, 582, 333  # nessa imagem: alto do capuz, altura do boneco (1,80 m) e meio, em pixels
RIFLE, RIFLE_HALF = ((262, 280), (208, 652)), 12  # eixo do fuzil pendurado na imagem (px) e meia-largura da faixa
REF_GAIN, REF_GAMMA = 1.0, 1.0  # a referência já traz a luz do render dela: escurece e aumenta o contraste para a
# luz que a cena põe por cima não lavar a pintura (calibrado na prévia contra a própria referência)


def load_ref():
    """Referência sem o aramado e com a metade sem o fuzil espelhada. Aramado = pixel bem mais escuro que a mediana em
    volta (linha de 1 px): vira a mediana; as sombras de verdade (áreas escuras largas) ficam como estão."""
    img = Image.open(REF_IMG).convert("RGB")
    a = np.asarray(img).astype(np.float32)
    med = np.asarray(img.filter(ImageFilter.MedianFilter(5))).astype(np.float32)
    line = (med.mean(axis=2) - a.mean(axis=2)) > 10
    a[line] = med[line]
    # o fuzil pendurado (só na referência) cobre uma faixa inclinada do lado direito dele: ali entra o outro lado
    # espelhado; o resto fica como está (a luz da referência vem de lado, as sombras não são simétricas)
    (x0, y0), (x1, y1) = RIFLE
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip(((xx - x0) * (x1 - x0) + (yy - y0) * (y1 - y0)) / ((x1 - x0) ** 2 + (y1 - y0) ** 2), 0, 1)
    dist = np.hypot(xx - (x0 + t * (x1 - x0)), yy - (y0 + t * (y1 - y0)))
    rifle = dist < RIFLE_HALF
    mx = np.clip(2 * REF_CX - xx, 0, w - 1)
    a[rifle] = a[yy[rifle], mx[rifle]]
    bg = np.array([85, 86, 90], np.float32)
    mask = np.abs(a - bg).sum(axis=2) > 30
    return a, mask


def ref_at(ref, x, z):
    """Cor da referência no ponto (x, z) do corpo (m), com interpolação; None fora do boneco."""
    a, mask = ref
    fx = REF_CX + x / G.HEIGHT * REF_H
    fy = REF_TOP + (1 - z / G.HEIGHT) * REF_H
    ix, iy = int(fx), int(fy)
    if not (0 <= ix < a.shape[1] - 1 and 0 <= iy < a.shape[0] - 1) or not mask[iy, ix]:
        return None
    tx, ty = fx - ix, fy - iy
    c = (a[iy, ix] * (1 - tx) * (1 - ty) + a[iy, ix + 1] * tx * (1 - ty) + a[iy + 1, ix] * (1 - tx) * ty
         + a[iy + 1, ix + 1] * tx * ty)
    return 255.0 * (c / 255.0) ** REF_GAMMA * REF_GAIN


def _torso_points():
    """Os vértices de cada anel do tronco (a mesma conta de art/guerrilla_body._torso_ring, sem mathutils)."""
    rings = {}
    for z, *_ in G.BODY:
        pts = []
        for j in range(G.TORSO_SIDES):
            th = 2 * math.pi * j / G.TORSO_SIDES
            x, y = G.body_point(z, th)
            v = G.vest_point(z, th)
            if v is not None and G.vest_covers(z, v[0]):
                x, y = v
                if 1.0 <= z <= 1.40 and y < 0 and abs(x) < 0.16:
                    y -= G.PLATE * math.cos(abs(x) / 0.16 * math.pi / 2)
            pts.append((x, y))
        rings[z] = pts
    return rings


def project_torso(ref):
    """Pinta a frente do tronco com a referência: cada pixel do retângulo vira o ponto da malha (anéis e colunas
    interpolados, como o UV) e pega a cor da referência nesse (x, z); as costas ficam com a pintura procedural, e a
    passagem pelos lados é gradual."""
    x0, y0, w, h = rect("torso")
    top_z, bot_z = GA.Z_RANGES["torso"]
    rings = _torso_points()
    zs = sorted(rings)
    px = img.load()
    for j in range(h):
        z = top_z - (j + 0.5) / h * (top_z - bot_z)
        if z < zs[0] or z > zs[-1]:
            continue
        za = max(q for q in zs if q <= z)
        zb = min(q for q in zs if q >= z)
        t = 0.0 if zb == za else (z - za) / (zb - za)
        for i in range(w):
            u = (i + 0.5) / w * G.TORSO_SIDES
            k0 = int(u) % G.TORSO_SIDES
            k1 = (k0 + 1) % G.TORSO_SIDES
            f = u - int(u)
            pa = [rings[za][k0][n] * (1 - f) + rings[za][k1][n] * f for n in (0, 1)]
            pb = [rings[zb][k0][n] * (1 - f) + rings[zb][k1][n] * f for n in (0, 1)]
            x, y = pa[0] * (1 - t) + pb[0] * t, pa[1] * (1 - t) + pb[1] * t
            # só onde a face olha para a frente (a pintura de frente esticaria nos lados): normal da face no plano
            ta = [rings[za][k1][n] - rings[za][k0][n] for n in (0, 1)]
            front = -ta[0] / max(math.hypot(*ta), 1e-9)  # componente -y da normal (para fora) desta coluna
            wgt = min(1.0, max(0.0, (front - 0.12) / 0.38)) * min(1.0, max(0.0, (-y - 0.01) / 0.03))
            if wgt <= 0:
                continue
            c = ref_at(ref, x, z)
            if c is None:
                continue
            old = np.array(px[x0 + i, y0 + j][:3], np.float32)
            new = old * (1 - wgt) + c * wgt
            px[x0 + i, y0 + j] = tuple(int(min(255, v)) for v in new) + (255,)


def _hood_points(z, yc, rx, ryf, ryb, opening, face_k):
    """Os vértices do anel do capuz (a mesma conta de art/guerrilla_body._hood_ring, sem mathutils)."""
    rim_y = yc - ryf
    front = G.HEAD_SIDES // 2
    pts = []
    for j in range(G.HEAD_SIDES):
        th = 2 * math.pi * j / G.HEAD_SIDES
        c = math.cos(th)
        p = (rx * math.sin(th), yc + (ryb if c > 0 else ryf) * c)
        k = 1.0 if j < front else -1.0
        off = abs(j - front)
        t = None
        if off == G.FACE_RIM:
            t = (k * G.RIM_X, rim_y)
        elif off in G.FACE:
            w, back = G.FACE[off]
            t = (k * w * face_k, rim_y + back)
        if t is not None and opening > 0:
            p = (p[0] + (t[0] - p[0]) * opening, p[1] + (t[1] - p[1]) * opening)
        pts.append(p)
    return pts


def project_head(ref):
    """Frente do capuz e o rosto (balaclava, fresta dos olhos, borda) pintados pela referência, como o tronco: cada
    pixel do retângulo "head" vira o ponto do anel (interpolado) e pega a cor da referência; o resto fica pintado."""
    x0, y0, w, h = rect("head")
    top_z, bot_z = GA.Z_RANGES["head"]
    rings = {row[0]: _hood_points(*row) for row in G.HOOD}
    zs = sorted(rings)
    px = img.load()
    for j in range(h):
        z = top_z - (j + 0.5) / h * (top_z - bot_z)
        if z < zs[0] or z > zs[-1]:
            continue
        za = max(q for q in zs if q <= z)
        zb = min(q for q in zs if q >= z)
        t = 0.0 if zb == za else (z - za) / (zb - za)
        for i in range(w):
            u = (i + 0.5) / w * G.HEAD_SIDES
            k0 = int(u) % G.HEAD_SIDES
            k1 = (k0 + 1) % G.HEAD_SIDES
            f = u - int(u)
            pa = [rings[za][k0][n] * (1 - f) + rings[za][k1][n] * f for n in (0, 1)]
            pb = [rings[zb][k0][n] * (1 - f) + rings[zb][k1][n] * f for n in (0, 1)]
            x, y = pa[0] * (1 - t) + pb[0] * t, pa[1] * (1 - t) + pb[1] * t
            ta = [rings[za][k1][n] - rings[za][k0][n] for n in (0, 1)]
            front = -ta[0] / max(math.hypot(*ta), 1e-9)
            wgt = min(1.0, max(0.0, (front - 0.55) / 0.3)) * min(1.0, max(0.0, (-y - 0.005) / 0.02))
            if wgt <= 0:
                continue
            c = ref_at(ref, x, z)
            if c is None:
                continue
            old = np.array(px[x0 + i, y0 + j][:3], np.float32)
            px[x0 + i, y0 + j] = tuple(int(min(255, v)) for v in old * (1 - wgt) + c * wgt) + (255,)


def project_pouch(ref):
    """A bolsa do meio da referência (frente) no retângulo das bolsas (cada face da caixa mostra o retângulo)."""
    x0, y0, w, h = rect("pouch")
    hx, _, hz = G.MAG_HALF
    xc, zc = G.MAG_POUCHES[1]
    px = img.load()
    for j in range(h):
        z = zc + hz - (j + 0.5) / h * 2 * hz
        for i in range(w):
            x = xc - hx + (i + 0.5) / w * 2 * hx
            c = ref_at(ref, x, z)
            if c is not None:
                px[x0 + i, y0 + j] = tuple(int(min(255, v)) for v in c) + (255,)


def copy_weapons():
    src = Image.open(HEROINE).convert("RGBA")
    for name in ("pistol", "rifle", "shotgun", "shotgun_wood", "m79", "m79_wood"):
        x, y, w, h = rect(name)
        img.paste(src.crop((x, y, x + w, y + h)), (x, y))


def paint_bare_torso():
    """Tronco só de moletom (sem o colete): liso, costuras laterais, barra canelada em cima do cinto."""
    x, y, w, h = rect("torso")
    fill("torso", C["hoodie"])
    for u in (0.25, 0.75):
        d.line([(ux("torso", u), y), (ux("torso", u), y + h - 1)], fill=scale(C["hoodie"], 0.82), width=1)
    hem0, hem1 = zy("torso", 0.995), zy("torso", 0.955)
    d.rectangle([x, hem0, x + w - 1, hem1], fill=scale(C["hoodie"], 0.88))
    for i in range(x, x + w, 3):
        d.line([(i, hem0), (i, hem1)], fill=scale(C["hoodie"], 0.74))
    d.line([(x, hem0), (x + w - 1, hem0)], fill=scale(C["hoodie"], 1.15))
    shade("torso", round_shade(0.80))
    shade("torso", lambda u, v: 1.03 - 0.08 * v)


def _vest_px(x, z, back=False):
    """Pixel do ponto (x, z) do colete no retângulo "vest" (frente na metade esquerda, costas na direita)."""
    x0, y0, w, h = rect("vest")
    u = (0.75 if back else 0.25) + x / G.VEST_UV_SPAN
    return x0 + u * w, zy("vest", z)


def paint_carrier_pouch():
    """Bolsas do colete de agora (o do painel do usuário): pretas como ele, com a borda e a lingueta da aba."""
    x, y, w, h = rect("pouch")
    fill("pouch", C["carrier_mag"])
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=scale(C["carrier_mag"], 0.62), width=3)
    d.rectangle([x + w // 2 - 4, y + 4, x + w // 2 + 4, y + h // 3], outline=scale(C["carrier_mag"], 0.6), width=2)
    d.line([(x + 5, y + 5), (x + w - 6, y + 5)], fill=scale(C["carrier_mag"], 1.35))


def paint_vest():
    """Colete preto (o do painel do usuário): lona lisa com sombra embaixo, debrum costurado nas bordas (pé, decote,
    cava e alças), costuras do painel de cima em V e a do meio, nas placas da frente e de trás."""
    x0, y0, w, h = rect("vest")
    top, bottom = GA.Z_RANGES["vest"]
    base, edge = C["carrier"], scale(C["carrier"], 0.62)
    px = img.load()
    for j in range(h):
        z = top - (j + 0.5) / h * (top - bottom)
        for i in range(w):
            u = (i + 0.5) / w
            back = u >= 0.5
            x = (u - (0.75 if back else 0.25)) * G.VEST_UV_SPAN
            ax = abs(x)
            # distância até a borda: pé, alto da placa (decote/cava) e os lados da alça
            dist = z - G.carrier_bottom(x)
            if z <= G.carrier_top(x, back) + 0.002:
                dist = min(dist, G.carrier_top(x, back) - z) if z > 1.21 else dist
            elif G.CARRIER_STRAP[0] <= ax <= G.CARRIER_STRAP[1]:
                dist = min(ax - G.CARRIER_STRAP[0], G.CARRIER_STRAP[1] - ax)
            k = 0.86 + 0.14 * min(1.0, (z - bottom) / 0.25) + 0.03 * rng.random()
            k *= 1 - 0.30 * min(1.0, max(0.0, (ax - 0.150) / 0.025))  # a lateral da placa vira para o lado: na sombra
            e = 1 - min(1.0, max(0.0, (dist - 0.006) / 0.003)) if dist >= 0 else 0.0  # debrum, borda suave
            st = max(0.0, 1 - abs(dist - 0.0105) / 0.0022)  # costura do debrum
            c = tuple(b * (1 - e) + g * e for b, g in zip(base, edge))
            c = tuple(v * (1 + 0.22 * st) for v in c)
            px[x0 + i, y0 + j] = scale(c, k) + (255,)
    # costuras desenhadas 4x maiores e reduzidas (sem serrilhado: cada pixel do atlas vale ~4 mm do colete)
    SS = 4
    mask = Image.new("L", (w * SS, h * SS), 0)
    lit = Image.new("L", (w * SS, h * SS), 0)
    dm, dl = ImageDraw.Draw(mask), ImageDraw.Draw(lit)
    for back in (False, True):
        for line in G.CARRIER_SEAMS:
            for side in (1, -1):
                pts = [((p[0] - x0) * SS, (p[1] - y0) * SS) for p in (_vest_px(side * x, z, back) for x, z in line)]
                dl.line([(p[0], p[1] + SS * 1.2) for p in pts], fill=255, width=SS)  # a costura levanta o pano
                dm.line(pts, fill=255, width=int(SS * 1.3))
    mask, lit = (m.resize((w, h), Image.LANCZOS) for m in (mask, lit))
    for j in range(h):
        for i in range(w):
            a, b = mask.getpixel((i, j)) / 255.0, lit.getpixel((i, j)) / 255.0
            if a or b:
                r, g, bl, al = px[x0 + i, y0 + j]
                f = (1 - 0.5 * a) * (1 + 0.25 * b * (1 - a))
                px[x0 + i, y0 + j] = (min(255, int(r * f)), min(255, int(g * f)), min(255, int(bl * f)), al)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    bare = "colete_antigo" not in sys.argv[2:]  # o colete pintado no tronco (partes antigas) só com essa opção
    paint_bare_torso() if bare else paint_torso()
    paint_head()
    paint_sleeves()
    paint_hand()
    paint_gear()
    paint_vest()
    paint_carrier_pouch()
    if REF_IMG.exists():  # frente do capuz e do rosto pintada pela referência (projeção de frente)
        project_head(load_ref())
    if REF_IMG.exists() and not bare:  # frente do tronco e bolsas pintadas pela referência (projeção de frente)
        ref = load_ref()
        project_torso(ref)
        project_pouch(ref)
    # só a lona das bolsas leva trama (moletom, colete e capuz são lisos, como na referência)
    paint_clothes.texture_pass(img, ["pouch"], {})
    copy_weapons()
    final = paint_face.pad(img)
    out.parent.mkdir(parents=True, exist_ok=True)
    final.save(out)
    print(out)


if __name__ == "__main__":
    main()
