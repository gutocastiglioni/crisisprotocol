"""Pinta o atlas 512x512 do alossauro: mesmo layout e mesmas ferramentas do raptor (`make_raptor_texture`), com as cores
originais do projeto (dorso marrom-escuro, flancos terrosos, barriga creme, garras cor de ferrugem) e o padrão da
referência realista (a "Alice", só olhada): faixa de placas (osteodermos) no dorso do pescoço, costas e cauda, rosto
liso com manchas escuras em volta do olho e no focinho, mandíbula clara; olho amarelo com pupila em fenda (globo de
malha, retângulo "mouth"); os dentes são malha.

Uso: python tools/make_allosaurus_texture.py [saida.png]
Saída padrão: game/assets/characters/allosaurus_atlas.png
"""
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "art"))
sys.path.insert(0, str(ROOT / "tools"))
import raptor_atlas  # noqa: E402

raptor_atlas.TEX_SCALE = 4  # chefe: atlas de 1024 (o mesmo layout do raptor, 4x os pixels da cabeça do de 512)
import make_raptor_texture as T  # noqa: E402
import allosaurus_ref as REF  # noqa: E402
import allosaurus_rings as RINGS  # noqa: E402
import paint_face  # noqa: E402

# cores originais do projeto: dorso marrom-escuro quase preto, flancos terrosos, barriga creme, garras cor de ferrugem
T.BACK = (40, 34, 30)
T.SIDE = (92, 76, 58)
T.SIDE_HI = (128, 108, 82)
T.BELLY = (190, 172, 132)
T.BELLY_LO = (150, 132, 98)
T.STRIPE = (30, 24, 20)
T.STRIPE_CORE = (18, 14, 12)
T.EYE = (196, 150, 40)
T.EYE_HI = (236, 200, 110)


def paint_horn():
    """Chifre (metade direita do retângulo "mouth"): osso claro no fio de cima, cor do alto do focinho para a base."""
    x0, y0, w, h = T.rect("mouth")
    for j in range(h):
        for i in range(w // 2, w):
            u = (i - w // 2 + 0.5) / (w - w // 2)
            edge = min(u, 1 - u) * 2  # 0 no fio de cima, 1 embaixo (dentro da pele)
            T.px[x0 + i, y0 + j] = T.lerp(BONE, FACE_TOP, edge ** 0.7)
    lid = T.lerp(T.STRIPE, T.SIDE, 0.35)  # pálpebras (u = 0,75, v = 0,5: no chifre é o fundo enterrado na pele)
    cx, cy = x0 + w * 3 // 4, y0 + h // 2
    T.d.rectangle([cx - w // 16, cy - h // 6, cx + w // 16, cy + h // 6], fill=lid)


def paint_eye():
    """Olho (globo de malha, metade esquerda do retângulo "mouth"): aro escuro, íris em degradê (âmbar escuro na borda,
    amarelo perto da pupila) com veios, pupila em fenda em pé, brilho pequeno."""
    x0, y0, w, h = T.rect("mouth")
    cx, cy, r = x0 + w * 0.25, y0 + h * 0.5, min(w * 0.25, h * 0.5)
    T.d.rectangle([x0, y0, x0 + w // 2 - 1, y0 + h - 1], fill=T.STRIPE_CORE)
    rim, deep = (30, 20, 12), T.lerp(T.EYE, (90, 56, 16), 0.6)
    for j in range(int(cy - r), int(cy + r) + 1):
        for i in range(int(cx - r), int(cx + r) + 1):
            d = math.hypot(i - cx, j - cy) / r
            if d > 1:
                continue
            if d > 0.86:
                c = rim
            else:
                c = T.lerp(T.EYE_HI, deep, (d / 0.86) ** 1.4)
                ang = math.atan2(j - cy, i - cx)
                if math.sin(ang * 23) > 0.75 and d > 0.3:
                    c = T.lerp(c, deep, 0.35)  # veios da íris
            T.px[i, j] = c
    T.d.ellipse([cx - r * 0.11, cy - r * 0.72, cx + r * 0.11, cy + r * 0.72], fill=T.PUPIL)
    T.d.ellipse([cx + r * 0.22, cy - r * 0.5, cx + r * 0.4, cy - r * 0.32], fill=(240, 230, 200))


# Cabeça e mandíbula: cada pixel do retângulo sabe onde fica no bicho (os anéis da retopologia, HEAD_DENSE/JAW_DENSE, com
# o mesmo u/v do loft: u = posição na volta, v = distância ao longo dos centros dos anéis) e o desenho é feito pela
# posição, visto de lado como na referência: dorso escuro, rosto mais claro embaixo, barras ósseas em volta do olho
# claras, órbita escura, faixa escura sobre o nariz, manchas no focinho, lábio de escamas claras, mandíbula creme com a
# marca escura atrás; tudo nas cores do projeto.
EYE = (-2.909, 2.69)  # centro do olho (y, z), no espaço da referência (as tabelas; o gerador sobe a cabeça)
MOUTH_IN = (70, 32, 30)
BONE = T.lerp(T.SIDE_HI, T.BELLY, 0.55)
BONE_HI = T.lerp(T.BELLY, (236, 230, 214), 0.2)  # moldura óssea da órbita: o mais claro do rosto, para se destacar  # barras ósseas, escamas do lábio, chifre


def _jj(u, n):
    j = u * n
    return min(j, n - j)


def _cells(w, h, size, seed):
    """Rede de escamas (Voronoi numa grade sorteada, `size` px): f(i, j) -> (distância à borda em px, 0..1 da escama)."""
    import random
    rng = random.Random(seed)
    pts = {(a, b): ((a + rng.random()) * size, (b + rng.random()) * size, rng.random())
           for a in range(-1, w // size + 2) for b in range(-1, h // size + 2)}

    def f(i, j):
        a, b = int(i // size), int(j // size)
        near = sorted((math.hypot(i - x, j - y), k) for da in (-1, 0, 1) for db in (-1, 0, 1)
                      for x, y, k in [pts.get((a + da, b + db), (1e9, 1e9, 0.0))])
        return (near[1][0] - near[0][0]) * 0.5, near[0][1]
    return f


def _scaled(c, edge, shade, dark, line=0.9):
    """Escama: a cor varia de escama para escama (`shade` 0..1) e a borda (`edge` px) escurece para `dark`."""
    c = T.lerp(c, T.lerp(c, (255, 255, 255), 0.12), shade) if shade > 0.5 else T.lerp(c, dark, (0.5 - shade) * 0.35)
    return T.lerp(dark, c, min(1.0, edge / line)) if edge < line else c


def _bump(x, lo, hi):
    if not lo < x < hi:
        return 0.0
    t = (x - lo) / (hi - lo)
    return 4 * t * (1 - t)


def _rings(table):
    """Por anel (como o loft): pontos da volta inteira com atributos (x, y, z, nx, ny, nz, fundo, s) e o v do anel.
    n = normal para fora, fundo = quanto a pele afunda em relação aos vizinhos (m; > 0 = côncavo, sombra), s = distância
    pela volta a partir do alto (com sinal: + lado esquerdo)."""
    pts = []
    for y, half in table:
        full = list(half) + [(-x, z) for x, z in reversed(half[1:-1])]
        pts.append([(x, y, z) for x, z in full])
    centers = []
    for ring in pts:
        zs = [p[2] for p in ring]
        centers.append((ring[0][1], (max(zs) + min(zs)) / 2))
    acc = [0.0]
    for (ya, za), (yb, zb) in zip(centers, centers[1:]):
        acc.append(acc[-1] + math.hypot(yb - ya, zb - za))
    vs = [a / acc[-1] for a in acc]
    nr, n = len(pts), len(pts[0])

    def sub(a, b):
        return (a[0] - b[0], a[1] - b[1], a[2] - b[2])

    out = []
    for r in range(nr):
        ring = pts[r]
        arc = [0.0]
        for j in range(1, n + 1):
            arc.append(arc[-1] + math.dist(ring[j - 1], ring[j % n]))
        row = []
        for j in range(n):
            p = ring[j]
            ta = sub(ring[(j + 1) % n], ring[j - 1])
            tb = sub(pts[min(r + 1, nr - 1)][j], pts[max(r - 1, 0)][j])
            nx, ny, nz = ta[1] * tb[2] - ta[2] * tb[1], ta[2] * tb[0] - ta[0] * tb[2], ta[0] * tb[1] - ta[1] * tb[0]
            ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
            nx, ny, nz = nx / ln, ny / ln, nz / ln
            out_d = (p[0], 0.0, p[2] - centers[r][1])
            if nx * out_d[0] + nz * out_d[2] < 0:
                nx, ny, nz = -nx, -ny, -nz
            nb = [ring[(j + 1) % n], ring[j - 1]] + [pts[rr][j] for rr in (r - 1, r + 1) if 0 <= rr < nr]
            m = [sum(q[k] for q in nb) / len(nb) - p[k] for k in range(3)]
            cav = m[0] * nx + m[1] * ny + m[2] * nz
            s = arc[j] if arc[j] <= arc[n] / 2 else arc[j] - arc[n]
            row.append((p[0], p[1], p[2], nx, ny, nz, cav, s))
        out.append(row)
    return out, vs


def _at(rings, vs, u, v):
    """Atributos (ver _rings) da pele no pixel (u, v), interpolados como o loft."""
    r = len(vs) - 2
    for i in range(len(vs) - 1):
        if vs[i + 1] >= v:
            r = i
            break
    t = (v - vs[r]) / max(vs[r + 1] - vs[r], 1e-9)
    n = len(rings[0])
    jf = u * n
    j0 = int(jf) % n
    f = jf - int(jf)
    j1 = (j0 + 1) % n
    a, b, c, d = rings[r][j0], rings[r][j1], rings[r + 1][j0], rings[r + 1][j1]
    return [(a[k] + (b[k] - a[k]) * f) * (1 - t) + (c[k] + (d[k] - c[k]) * f) * t for k in range(8)]


def _seg(py, pz, a, b, r):
    """Quanto o ponto (y, z) está dentro do traço de a a b de raio r (1 no eixo, 0 na borda)."""
    ay, az = a
    by, bz = b
    dy, dz = by - ay, bz - az
    t = max(0.0, min(1.0, ((py - ay) * dy + (pz - az) * dz) / max(dy * dy + dz * dz, 1e-9)))
    d = math.hypot(py - (ay + dy * t), pz - (az + dz * t))
    return max(0.0, 1 - d / r)


def _lip_top(y):
    """Linha do lábio (z) e alto da cabeça (z) em y, pelos pontos-chave da tabela."""
    rows = sorted(REF.HEAD, key=lambda r: r[0])
    for (ya, a), (yb, b) in zip(rows, rows[1:]):
        if ya <= y <= yb:
            t = (y - ya) / (yb - ya)
            return a[4][1] + (b[4][1] - a[4][1]) * t, a[0][1] + (b[0][1] - a[0][1]) * t
    row = rows[0] if y < rows[0][0] else rows[-1]
    return row[1][4][1], row[1][0][1]


def _spots(y, z, sp, rad, seed=3):
    """Pintas redondas sorteadas numa grade de `sp` m no plano (y, z) (1 no meio, borda suave), uma em cada três células."""
    best = 0.0
    for a in (math.floor(y / sp), math.floor(y / sp) + 1):
        for b in (math.floor(z / sp), math.floor(z / sp) + 1):
            h = math.sin(a * 91.7 + b * 47.3 + seed) * 43758.5453
            h -= math.floor(h)
            if h > 0.34:
                continue
            cy, cz = (a + h * 2.5) * sp, (b + (h * 13 % 1)) * sp
            best = max(best, min(1.0, 2 * (1 - math.hypot(y - cy, z - cz) / (rad * (0.7 + h)))))
    return best


def _vnoise(a, b, cell, seed=0):
    """Ruído suave 0..1 no espaço (a, b em metros, grade de `cell` m): o mesmo valor no mesmo ponto do bicho em qualquer
    retângulo do atlas (as listras passam do pescoço para a cabeça sem emenda)."""
    def h(i, j):
        x = math.sin(i * 127.1 + j * 311.7 + seed * 74.7) * 43758.5453
        return x - math.floor(x)
    fa, fb = a / cell, b / cell
    i, j = math.floor(fa), math.floor(fb)
    ta, tb = fa - i, fb - j
    ta, tb = ta * ta * (3 - 2 * ta), tb * tb * (3 - 2 * tb)
    top = h(i, j) + (h(i + 1, j) - h(i, j)) * ta
    bot = h(i, j + 1) + (h(i + 1, j + 1) - h(i, j + 1)) * ta
    return top + (bot - top) * tb


STRIPE_PERIOD, STRIPE_WIDTH, STRIPE_REACH = 0.26, 0.24, 0.34  # listras do pescoço (as do paint_skin "neck", em metros)


def _dorsal(y, t, s):
    """Pele do pescoço no jeito do corpo (Dino Crisis): cor pela altura (dorso escuro, lado terroso, barriga clara) e as
    listras transversais largas que descem do dorso com borda irregular. t = 1 no alto, 0 embaixo; s = metros pela
    volta. Mesma regra do `paint_skin`, mas pela posição no bicho."""
    c = T.skin(0.5 * (1 - t), 0.2)
    n = _vnoise(y, s, 0.06, 1)
    b = _vnoise(y, s, 0.03, 2)
    wave = math.sin((y / STRIPE_PERIOD) * 2 * math.pi + 2.2 * (n - 0.5) + 1.2 * math.sin(s * 5.6))
    limit = 1 - STRIPE_WIDTH * 2 + 0.25 * (1 - t) + 0.3 * (b - 0.5)
    if t > 1 - STRIPE_REACH * 2 and wave > limit:
        c = T.STRIPE_CORE if wave > limit + 0.32 else T.lerp(T.STRIPE, c, 0.15)
    elif t > 1 - STRIPE_REACH * 2 - 0.05 and wave > limit - 0.12:
        c = T.lerp(c, T.STRIPE, 0.45)
    return c


def _shade(c, nz, cav, k=1.0):
    """Sombra pintada (jeito PS2): luz de cima pela normal e oclusão nas dobras/cavidades."""
    lit = 0.92 + 0.22 * max(-0.6, min(1.0, nz))
    occ = 1 - k * min(0.45, max(0.0, cav) * 28)
    rim = 1 + k * min(0.12, max(0.0, -cav) * 12)  # quinas/cristas um pouco mais claras
    f = lit * occ * rim
    return tuple(max(0, min(255, int(ch * f))) for ch in c)


# cores do rosto (todas da paleta do projeto)
FACE = T.lerp(T.SIDE_HI, T.BELLY, 0.2)  # rosto (parte de cima)
FACE_TOP = T.lerp(T.SIDE, T.SIDE_HI, 0.35)  # alto do focinho
LIP = T.lerp(FACE, T.BELLY, 0.4)  # escamas do lábio de cima
UNDER = T.lerp(T.BELLY, (236, 230, 214), 0.45)  # por baixo (fundo da mandíbula e garganta): esbranquiçado
JAWC = T.lerp(UNDER, T.BELLY, 0.35)  # mandíbula e o bloco da bochecha atrás da boca: bem mais claro que o rosto (partes
# distintas, como na referência)
# borda de trás do bloco bochecha-mandíbula (medida: onde a largura cai no pescoço), (z, y) de cima para baixo, e o alto
# dele atrás do canto da boca, (y, z)
JAW_EDGE = [(2.66, -2.47), (2.60, -2.40), (2.55, -2.35), (2.35, -2.35), (2.30, -2.38), (2.15, -2.41)]
JAW_LINE = [(-2.70, 2.47), (-2.60, 2.56), (-2.50, 2.62), (-2.40, 2.63)]


def _lin(table, a):
    """Interpolação linear numa tabela [(a, b)] ordenada por a (crescente ou decrescente)."""
    t = sorted(table)
    if a <= t[0][0]:
        return t[0][1]
    for (a0, b0), (a1, b1) in zip(t, t[1:]):
        if a <= a1:
            return b0 + (b1 - b0) * (a - a0) / (a1 - a0)
    return t[-1][1]


def _jaw_block(y, z):
    """Quanto (0..1) o ponto atrás do canto da boca está no bloco bochecha-mandíbula (claro)."""
    if y < -2.70:
        return 0.0
    inside_back = (_lin(JAW_EDGE, z) - y) / 0.05 + 0.5  # esfumado nos dois lados da borda de trás
    below = (_lin(JAW_LINE, y) - z) / 0.04 + 0.5  # e do alto do bloco
    return max(0.0, min(1.0, inside_back, below))
# mancha escura do olho e barra de osso clara de trás (pós-orbital), lidas na textura da referência sobre a pele (vista de
# lado, a cada 2 cm): mancha de y -2,96 a -2,74 e z 2,58 a 2,78 (continua atrás da barra); barra estreita (~3 cm) quase
# em pé, de (-2,80; 2,78) a (-2,845; 2,55). ORBIT = (centro y, z), semi-eixos, inclinação
ORBIT = ((-2.86, 2.675), 0.11, 0.105, 0.0)
POSTORBITAL = [(-2.81, 2.80), (-2.80, 2.70), (-2.82, 2.62), (-2.845, 2.55)]  # quase em pé, o pé um pouco à frente


def _orbit(y, z):
    """Distância normalizada ao oval da órbita (1 na borda)."""
    (cy, cz), a, b, tilt = ORBIT
    dy, dz = y - cy, z - cz
    ry = dy * math.cos(tilt) - dz * math.sin(tilt)
    rz = dy * math.sin(tilt) + dz * math.cos(tilt)
    return math.hypot(ry / a, rz / b)


def paint_head():
    """Pescoço medido + crânio, desenhados pela posição (ver o comentário de EYE)."""
    x0, y0, w, h = T.rect("head")
    rings, vs = _rings(RINGS.head_rings())  # os mesmos anéis da malha
    zr = [(min(p[2] for p in ring), max(p[2] for p in ring)) for ring in rings]
    cell = _cells(w, h, 4, 7)
    blot = T.smooth_noise(w, h, 10)
    warp = T.smooth_noise(w, h, 5)
    for j in range(h):
        v = (j + 0.5) / h
        r = next((k for k in range(len(vs) - 1) if vs[k + 1] >= v), len(vs) - 2)
        tv = (v - vs[r]) / max(vs[r + 1] - vs[r], 1e-9)
        zmin = zr[r][0] + (zr[r + 1][0] - zr[r][0]) * tv
        zmax = zr[r][1] + (zr[r + 1][1] - zr[r][1]) * tv
        for i in range(w):
            u = (i + 0.5) / w
            jj = min(u, 1 - u) * 12  # 0 alto, 4 lábio, 6 céu da boca (pescoço e garganta: 6 embaixo)
            x, y, z, nx, ny, nz, cav, s = _at(rings, vs, u, v)
            edge, shade = cell(i, j)
            throat = y > -2.66
            wv = (warp(i, j) - 0.5) * 0.03  # borda irregular das manchas
            if jj > 4.0 and not throat and y < -3.36:  # frente da boca vista de frente: a mesma pele do focinho
                c = _shade(T.lerp(FACE, FACE_TOP, 0.4), nz, cav)
            elif jj > 4.0 and not throat:  # por dentro da saia do lábio e céu da boca
                c = MOUTH_IN if jj < 5.0 else T.lerp(T.MOUTH_LO, MOUTH_IN, 0.4)
            else:
                if throat:
                    t = (z - zmin) / max(zmax - zmin, 0.05)  # 0 embaixo, 1 no alto
                    lip = zmin + 0.3 * (zmax - zmin)
                else:
                    lip, top = _lip_top(y)
                    t = max(0.0, min(1.0, (z - lip) / max(top - lip, 0.05)))  # 0 no lábio, 1 no alto
                # base: rosto em cima; o bloco bochecha-mandíbula atrás da boca na cor clara da mandíbula; atrás da
                # borda dele o pescoço (rosto em cima, garganta esbranquiçada embaixo)
                c = T.lerp(FACE, FACE_TOP, max(0.0, (t - 0.55) / 0.45))
                if throat:  # pescoço: a pele listrada do corpo, que vai virando o rosto até o olho
                    neck = _dorsal(y, t, s)
                    if t < 0.3:
                        neck = T.lerp(UNDER, neck, max(0.0, (t - 0.16) / 0.14))
                        if (y / 0.045) % 1.0 < 0.12 and t < 0.16:
                            neck = T.lerp(neck, T.BELLY_LO, 0.5)  # dobras da garganta
                    c = T.lerp(neck, c, min(1.0, max(0.0, (-2.52 - y) / 0.14)))
                    blk = _jaw_block(y + wv * 0.3, z)
                    c = T.lerp(c, JAWC, blk)
                elif t > 0.7 and y > -2.84:  # alto do crânio atrás do olho: as listras do pescoço chegam até aqui
                    c = T.lerp(c, _dorsal(y, t, s), min(1.0, (t - 0.7) / 0.15) * min(1.0, (y + 2.84) / 0.1))
                side = 1.2 < jj < 4.2
                # manchas escuras (desenho nosso): órbita, faixa de trás do olho até o canto da boca, barras no
                # focinho, pintas perto dos dentes, faixa sobre o nariz, sardas
                k = 0.0
                if side:
                    k = max(k, 0.9 * min(1.0, max(0.0, (1.0 - _orbit(y + wv * 0.6, z + wv * 0.4)) / 0.25)))  # mancha do olho
                    k = max(k, min(1.0, 2.0 * _seg(y + wv, z, (-2.85, 2.585), (-2.66, 2.47), 0.026)))  # embaixo da órbita-canto da boca
                    for yb, z0, z1, rw in ((-3.05, 2.50, 2.78, 0.022), (-3.17, 2.47, 2.74, 0.02),
                                           (-3.28, 2.45, 2.64, 0.018)):
                        k = max(k, min(1.0, 2.0 * _seg(y + wv, z + wv, (yb, z0), (yb - 0.03, z1), rw)))
                    k = max(k, min(1.0, 2.0 * _seg(y + wv, z, (-3.31, 2.42), (-3.24, 2.47), 0.03)))
                    k = max(k, min(1.0, 2.0 * _seg(y + wv, z, (-3.14, 2.41), (-3.10, 2.44), 0.022)))
                if jj < 1.6:
                    k = max(k, min(1.0, 2.0 * _seg(y + wv, s, (-3.19, -0.12), (-3.17, 0.12), 0.022)))
                if side and not throat:  # pintas redondas espalhadas (no espaço, não no atlas)
                    k = max(k, 0.8 * _spots(y, z, 0.05, 0.011))
                k = max(k, 1.0 if math.hypot((y + 3.375) / 0.022, (z - 2.48) / 0.016) < 1 else 0.0)  # narina
                c = T.lerp(c, T.STRIPE, k)
                # barra de osso claro de trás (pós-orbital), larga, cortando a mancha escura de cima a baixo, com a
                # borda escura dos dois lados
                if side:
                    bar = max(_seg(y + wv * 0.2, z, a, b, 0.017) for a, b in zip(POSTORBITAL, POSTORBITAL[1:]))
                    c = T.lerp(c, BONE_HI, min(1.0, bar * 2.2))
                if not throat and 0.0 < z - lip < 0.024 and y < -2.75:  # escamas do lábio: blocos claros, junta escura
                    c = T.lerp(LIP, T.STRIPE, 0.55) if (y / 0.026) % 1.0 < 0.16 else LIP
                elif not throat and 0.024 <= z - lip < 0.034 and y < -2.75:
                    c = T.lerp(c, T.STRIPE, 0.6)  # linha escura em cima das escamas: o lábio fica desenhado
                c = _scaled(c, edge, shade, T.lerp(c, T.STRIPE, 0.3), 0.4)
                c = _shade(c, nz, cav)
            k = 0.94 + 0.12 * blot(i, j)
            T.px[x0 + i, y0 + j] = tuple(min(255, int(ch * k)) for ch in c)


def paint_jaw():
    """Mandíbula desenhada pela posição: língua e gengiva por dentro, escamas do lábio em cima do lado, lado na cor do
    rosto, embaixo esbranquiçado com dobras, marca escura atrás (abaixo do canto da boca) e manchas no queixo."""
    x0, y0, w, h = T.rect("jaw")
    rings, vs = _rings(RINGS.jaw_rings())
    cell = _cells(w, h, 4, 11)
    blot = T.smooth_noise(w, h, 8)
    warp = T.smooth_noise(w, h, 5)
    for j in range(h):
        v = (j + 0.5) / h
        for i in range(w):
            u = (i + 0.5) / w
            jj = min(u, 1 - u) * 8  # 0 língua, 1 braço, 2 lado, 3 quina, 4 fundo
            x, y, z, nx, ny, nz, cav, s = _at(rings, vs, u, v)
            edge, shade = cell(i, j)
            wv = (warp(i, j) - 0.5) * 0.03
            if y > -2.70 and jj < 1.55:  # atrás da boca, a parte de cima da mandíbula entra sob a bochecha: pele
                c = _shade(FACE, nz, cav)
            elif jj < 0.85:
                c = T.lerp(T.MOUTH_LO, T.TONGUE, 0.35)
            elif jj < 1.05:
                c = T.lerp(T.GUM, MOUTH_IN, 0.3)
            elif jj < 1.4:
                c = T.lerp(LIP, T.STRIPE, 0.55) if (y / 0.026) % 1.0 < 0.16 else LIP  # escamas do lábio
            elif jj < 1.55:
                c = T.lerp(T.STRIPE, T.SIDE, 0.3)  # linha escura que marca a borda da mandíbula
            else:
                c = T.lerp(JAWC, UNDER, min(1.0, max(0.0, (jj - 2.7) / 0.4)))  # mandíbula clara, embaixo esbranquiçado
                k = 0.0
                k = max(k, min(1.0, 2.0 * _seg(y + wv, z, (-2.68, 2.44), (-2.56, 2.22), 0.04)))  # marca atrás
                k = max(k, min(1.0, 2.0 * _seg(y + wv, z + wv, (-3.27, 2.40), (-3.22, 2.30), 0.02)))  # queixo
                k = max(k, min(1.0, 2.0 * _seg(y + wv, z + wv, (-3.10, 2.39), (-3.06, 2.31), 0.016)))
                if jj < 2.6:
                    k = max(k, 0.7 * _spots(y, z, 0.05, 0.01, 9))
                c = T.lerp(c, T.STRIPE, k)
                if jj > 3.0 and (y / 0.05) % 1.0 < 0.1:
                    c = T.lerp(c, T.BELLY_LO, 0.6)  # placas da garganta
                c = _scaled(c, edge, shade, T.lerp(c, T.STRIPE, 0.3), 0.4)
                c = _shade(c, max(nz, -0.2), cav)  # embaixo: um pouco de sombra, sem apagar o claro
            k = 0.94 + 0.12 * blot(i, j)
            T.px[x0 + i, y0 + j] = tuple(min(255, int(ch * k)) for ch in c)


# anéis do pescoço que sai do peito (allosaurus_mesh.build_neck: J_NECK e os 3 anéis): (y, z do meio, rx, ry)
NECK_TUBE = [(-1.50, 2.95, 0.36, 0.55), (-1.70, 3.18, 0.28, 0.44), (-1.85, 3.40, 0.235, 0.36), (-2.02, 3.48, 0.15, 0.24)]


def paint_neck_tube():
    """Retângulo "neck" (12 lados, u = 0 no alto, 0,5 embaixo; v da base para a cabeça): a mesma pele listrada do
    pescoço medido (`_dorsal`, pela posição), que vira a pele do corpo perto do peito: sem emenda nas duas pontas."""
    x0, y0, w, h = T.rect("neck")
    acc = [0.0]
    for a, b in zip(NECK_TUBE, NECK_TUBE[1:]):
        acc.append(acc[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    vs = [a / acc[-1] for a in acc]
    cell = _cells(w, h, 4, 13)
    for j in range(h):
        v = (j + 0.5) / h
        r = next((k for k in range(len(vs) - 1) if vs[k + 1] >= v), len(vs) - 2)
        f = (v - vs[r]) / max(vs[r + 1] - vs[r], 1e-9)
        y, _, rx, ry = (a + (b - a) * f for a, b in zip(NECK_TUBE[r], NECK_TUBE[r + 1]))
        mix = min(1.0, max(0.0, (v - 0.03) / 0.25))  # 0 no peito (pele do corpo), inteiro logo depois
        for i in range(w):
            u = (i + 0.5) / w
            th = 2 * math.pi * u
            t = (math.cos(th) + 1) / 2  # 1 no alto, 0 embaixo
            s = (th if th <= math.pi else th - 2 * math.pi) * (rx + ry) / 2
            edge, shade = cell(i, j)
            c = _dorsal(y, t, s)
            if t < 0.3:
                c = T.lerp(UNDER, c, max(0.0, (t - 0.16) / 0.14))
            c = _scaled(c, edge, shade, T.lerp(c, T.STRIPE, 0.3), 0.4)
            c = _shade(c, math.cos(th), 0.0)
            old = T.px[x0 + i, y0 + j]
            T.px[x0 + i, y0 + j] = tuple(int(o + (n - o) * mix) for o, n in zip(old, c))


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game/assets/characters/allosaurus_atlas.png"
    T.paint_skin("body", 5.0, reach=0.36, belly_width=0.17, width=0.26, scale=4, scutes=12)
    T.paint_skin("neck", 2.5, reach=0.34, belly_width=0.2, width=0.24, scutes=6, scale=4)
    T.paint_skin("tail", 7.0, reach=0.44, belly_width=0.12, width=0.3, scutes=16)
    T.paint_skin("thigh", 2.5, reach=0.4, belly_width=0.0, width=0.28, scale=5)
    T.paint_skin("shin", 3.0, reach=0.4, belly_width=0.0, scale=4)
    T.paint_skin("meta", 2.0, reach=0.5, belly_width=0.0, scale=3)
    T.paint_skin("arm", 2.0, reach=0.4, belly_width=0.0, scale=3)
    T.paint_skin("toe", 2.0, reach=0.5, belly_width=0.0, scale=3)
    for n in ("body", "neck", "tail", "thigh"):
        T.speckle(n, 0.008)
    paint_head()
    paint_jaw()
    paint_eye()
    paint_horn()
    T.shade_trunk("body", 0.17, ends=(0.15, 0.2), hang=0.1)
    T.shade_trunk("neck", 0.2, ends=(0.22, 0.2))
    T.throat_folds("neck", 6, 0.2)
    paint_neck_tube()
    T.shade_trunk("tail", 0.12, sheen=0.22, flank=0.36, ends=(0.25, 0.0))
    T.shade_limb("thigh", top=1.18, bottom=0.62, bulge=0.15, ends=(0.3, 0.35))
    T.shade_limb("shin", top=1.02, bottom=0.72, bulge=0.12, ends=(0.35, 0.25))
    T.shade_limb("meta", top=0.95, bottom=0.8, ends=(0.2, 0.25))
    T.shade_limb("arm", top=1.08, bottom=0.8, bulge=0.08, ends=(0.3, 0.2))
    T.shade_limb("toe", top=0.95, bottom=0.8, ends=(0.2, 0.0))
    T.paint_gradient("teeth", T.TOOTH, T.TOOTH_LO)
    T.paint_gradient("claw", (120, 70, 44), (40, 28, 22), streak=(150, 100, 70))  # garras cor de ferrugem
    final = paint_face.pad(T.img)
    out.parent.mkdir(parents=True, exist_ok=True)
    final.convert("RGB").save(out)
    print(f"[allosaurus] atlas salvo em {out}")


if __name__ == "__main__":
    main()
