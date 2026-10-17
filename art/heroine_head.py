"""Cabeça e cabelo da heroína no orçamento de "PS2 do começo" (referência: ruiva de cabelo liso e longo,
franja varrida para os lados, mechas emoldurando o rosto até o peito).

Cabeça: loft de 16 lados esculpido com empurrões (queixo, lábios, nariz, maçãs, órbitas, arco da sobrancelha).
Cabelo: calota com linha do cabelo de verdade (testa livre), franja e mechas em fitas, cortina nas costas.
As fitas usam o retângulo "hair" do atlas: u = largura da mecha, v = comprimento (pontas recortadas por alfa).
Índices do anel de 16 lados: 0 = nuca, 4 = esquerda dela (+X), 8 = frente, 12 = direita dela.
"""
import math

from mathutils import Vector

from heroine_mesh import MAT_HAIR, R

X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))
SIDES = 16
Y0 = -0.012  # centro da cabeça em Y

# (z, centro y, rx, ry, empurrões {índice: metros}) — de baixo (queixo) para cima
HEAD = [
    (1.505, Y0 - 0.040, 0.026, 0.030, {}),
    (1.520, Y0 - 0.028, 0.038, 0.062, {8: 0.006}),
    (1.540, Y0 - 0.014, 0.050, 0.080, {8: 0.002}),
    (1.558, Y0 - 0.008, 0.058, 0.087, {8: 0.004}),
    (1.578, Y0 - 0.006, 0.066, 0.091, {8: 0.003}),
    (1.598, Y0 - 0.004, 0.072, 0.093, {6: 0.005, 10: 0.005}),
    (1.618, Y0 - 0.002, 0.077, 0.095, {7: -0.003, 9: -0.003}),
    (1.640, Y0, 0.078, 0.096, {8: 0.004, 7: 0.004, 9: 0.004}),
    (1.665, Y0 + 0.002, 0.078, 0.096, {}),
    (1.690, Y0 + 0.004, 0.072, 0.090, {}),
    (1.712, Y0 + 0.006, 0.056, 0.071, {}),
    (1.728, Y0 + 0.008, 0.026, 0.032, {}),
]


def build_head(mb):
    head = {"Head": 1}
    # anéis sempre horizontais: com o queixo avançando, o eixo inclina e o anel do queixo subiria até a boca
    rings = [R((0, y, z), rx, ry, head, push or None, frame=(X, Y)) for z, y, rx, ry, push in HEAD]
    mb.loft(rings, "head", SIDES, v_by_z=True)
    build_nose(mb)


def _face_out(mb, pts, out, rect, uvs, mat=0):
    """Face com a normal virada para `out` (inverte a ordem se precisar)."""
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
    if n.dot(out) < 0:
        pts, uvs = pts[::-1], uvs[::-1]
    w = {"Head": 1}
    mb._face([mb._vert(p, w) for p in pts], [mb.atlas.uv(rect, u, v) for u, v in uvs], mat)


def build_nose(mb):
    """Nariz fino em peça própria (no anel de 16 lados um vértice empurrado vira um focinho de 6 cm).
    Usa a textura do rosto no mesmo lugar: u = ângulo/2pi, v pela altura."""
    def P(th, z, off):
        return head_point(th, z, off), (th / (2 * math.pi), mb.atlas.z_to_v("head", z))

    bridge = P(math.pi, 1.630, 0.001)
    tip = P(math.pi, 1.586, 0.021)
    base = P(math.pi, 1.574, 0.011)
    for s in (1, -1):  # 1 = esquerda dela (+X, ângulo menor)
        root = P(math.pi - s * 0.15, 1.614, 0.0)
        wing = P(math.pi - s * 0.19, 1.577, 0.006)
        side = Vector((s, -1, 0)).normalized()
        _face_out(mb, [bridge[0], root[0], wing[0], tip[0]], side, "head", [bridge[1], root[1], wing[1], tip[1]])
        _face_out(mb, [tip[0], wing[0], base[0]], Vector((0, -0.3, -1)), "head", [tip[1], wing[1], base[1]])


def head_point(th, z, off=0.0):
    """Ponto na superfície da cabeça (sem empurrões) no ângulo `th` (0 = nuca, pi = frente) e altura `z`,
    afastado `off` metros para fora."""
    zs = [r[0] for r in HEAD]
    z = min(max(z, zs[0]), zs[-1])
    for (z0, y0, rx0, ry0, _), (z1, y1, rx1, ry1, _) in zip(HEAD, HEAD[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            y, rx, ry = y0 + (y1 - y0) * t, rx0 + (rx1 - rx0) * t, ry0 + (ry1 - ry0) * t
            break
    return Vector((0, y, z)) + X * ((rx + off) * math.sin(th)) + Y * ((ry + off) * math.cos(th))


def head_normal(th):
    return (X * math.sin(th) + Y * math.cos(th)).normalized()


def _uv(mb, u, v):
    return mb.atlas.uv("hair", u, v)


def ribbon(mb, pts, half_w, outs, weights, u0=0.0, u1=1.0, bulge=0.004):
    """Mecha em fita: 3 vértices na largura (o do meio estufado para fora), v = comprimento."""
    n = len(pts)
    rows = []
    for i in range(n):
        along = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        across = along.cross(outs[i]).normalized()
        c = pts[i]
        row = [c - across * half_w[i], c + outs[i] * bulge, c + across * half_w[i]]
        rows.append([mb._vert(p, weights[i]) for p in row])
    for i in range(n - 1):
        v0, v1 = i / (n - 1), (i + 1) / (n - 1)
        for k in range(2):
            ua, ub = u0 + (u1 - u0) * k / 2, u0 + (u1 - u0) * (k + 1) / 2
            _quad_out(
                mb,
                [rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]],
                [_uv(mb, ua, v0), _uv(mb, ua, v1), _uv(mb, ub, v1), _uv(mb, ub, v0)],
                outs[i],
            )


def _quad_out(mb, verts, uvs, out):
    """Face de cabelo com a frente virada para `out` (o verso também aparece, mas a luz e a prévia usam a frente)."""
    n = (verts[1].co - verts[0].co).cross(verts[2].co - verts[0].co)
    if n.dot(out) < 0:
        verts, uvs = verts[::-1], uvs[::-1]
    mb._face(verts, uvs, MAT_HAIR)


def _hairline(th):
    """Altura da linha do cabelo: alta na testa, desce pelas têmporas até a nuca."""
    front = (1 - math.cos(th)) / 2  # 1 na frente, 0 na nuca
    return 1.59 + 0.115 * front ** 1.5


def build_scalp(mb, rows=5):
    """Calota: do alto da cabeça até a linha do cabelo (v = 0 no topo, 1 na linha, onde o alfa recorta)."""
    head = {"Head": 1}
    grid = []
    for r in range(rows + 1):
        s = r / rows
        row = []
        for j in range(SIDES + 1):
            th = 2 * math.pi * j / SIDES
            z = 1.745 + (_hairline(th) - 1.745) * s
            off = 0.011 + 0.004 * s
            p = head_point(th, z, off)
            if r == 0:
                p = Vector((p.x * 0.25, Y0 + 0.008 + (p.y - Y0 - 0.008) * 0.25, 1.745))
            row.append(mb._vert(p, head))
        grid.append(row)
    for r in range(rows):
        # topo fora da raiz escura do retângulo (senão a coroa vira um anel escuro)
        va, vb = 0.15 + 0.85 * r / rows, 0.15 + 0.85 * (r + 1) / rows
        for j in range(SIDES):
            u0, u1 = j / SIDES, (j + 1) / SIDES
            mb._face(
                [grid[r][j], grid[r][j + 1], grid[r + 1][j + 1], grid[r + 1][j]],
                [_uv(mb, u0, va), _uv(mb, u1, va), _uv(mb, u1, vb), _uv(mb, u0, vb)],
                MAT_HAIR,
            )
    mb._face([grid[0][j] for j in range(SIDES)], [_uv(mb, j / SIDES, 0.15) for j in range(SIDES)], MAT_HAIR)


def build_fringe(mb):
    """Franja: mechas pontudas que saem da risca (um pouco à esquerda dela) e varrem para os lados;
    curtas no meio (ponta na sobrancelha) e mais longas para as têmporas."""
    head = {"Head": 1}
    part = math.pi - 0.16
    for k, (root, sweep, tip_z) in enumerate([
        (part - 0.05, -0.55, 1.632), (part - 0.20, -0.62, 1.620), (part - 0.38, -0.55, 1.612),
        (part + 0.05, 0.50, 1.646), (part + 0.20, 0.62, 1.636), (part + 0.38, 0.66, 1.624), (part + 0.58, 0.58, 1.612),
    ]):
        steps = [(0.0, 1.740, 0.010, 0.016), (0.4, 1.712, 0.015, 0.024), (0.75, 1.676, 0.019, 0.018), (1.0, tip_z, 0.022, 0.003)]
        pts, outs, widths = [], [], []
        for t, z, off, w in steps:
            th = root + sweep * t
            pts.append(head_point(th, z, off))
            outs.append(head_normal(th))
            widths.append(w)
        ribbon(mb, pts, widths, outs, [head] * 4, u0=(k % 4) * 0.25, u1=(k % 4) * 0.25 + 0.25)


def _lerp_path(points, s):
    """Interpola uma polilinha [(s, Vector), ...] no parâmetro s."""
    for (s0, p0), (s1, p1) in zip(points, points[1:]):
        if s0 <= s <= s1:
            return p0.lerp(p1, (s - s0) / (s1 - s0))
    return points[-1][1]


def build_side_locks(mb, cols=3):
    """Laterais: casca de cabelo larga que desce do lado da cabeça (cobrindo a orelha) e cai na frente
    do ombro até o peito, emoldurando o rosto. c = 0 na beira do rosto, 1 para trás da orelha."""
    rows_s = [0.0, 0.14, 0.28, 0.42, 0.58, 0.74, 0.88, 1.0]
    for side in (1, -1):  # 1 = esquerda dela (+X)
        grid = []
        for s in rows_s:
            row = []
            for j in range(cols + 1):
                c = j / cols
                th = math.pi - side * (0.95 + 0.62 * c)
                x = side * (0.085 + 0.075 * c)
                path = [
                    (0.0, head_point(th, 1.700, 0.016)),
                    (0.28, head_point(th - side * 0.05, 1.600, 0.026)),
                    (0.42, head_point(th - side * 0.08, 1.530, 0.032)),
                    (0.58, Vector((x * 1.05, -0.055 + 0.03 * c, 1.455))),
                    (0.74, Vector((x * 1.12, -0.112 + 0.02 * c, 1.370))),
                    (0.88, Vector((x * 1.15, -0.138 + 0.01 * c, 1.290))),
                    (1.0, Vector((x * 1.12, -0.142, 1.225))),
                ]
                p = _lerp_path(path, s)
                w = {"Head": 1} if s <= 0.42 else ({"Head": 0.5, "Chest": 0.5} if s <= 0.58 else {"Chest": 1})
                row.append((mb._vert(p, w), c))
            grid.append(row)
        for r in range(len(rows_s) - 1):
            for j in range(cols):
                (a, ca), (b, cb) = grid[r][j], grid[r][j + 1]
                (cc, _), (dd, _) = grid[r + 1][j + 1], grid[r + 1][j]
                u0, u1 = 0.5 * ca + (0.5 if side < 0 else 0.0), 0.5 * cb + (0.5 if side < 0 else 0.0)
                v0, v1 = rows_s[r], rows_s[r + 1]
                quad = [a, b, cc, dd]
                uvs = [_uv(mb, u0, v0), _uv(mb, u1, v0), _uv(mb, u1, v1), _uv(mb, u0, v1)]
                mid = sum((q.co for q in quad), Vector()) / 4
                _quad_out(mb, quad, uvs, Vector((mid.x, mid.y - Y0, 0)).normalized())


def build_back(mb):
    """Cortina de cabelo nas costas, afinando abaixo dos ombros; pontas recortadas pelo alfa (v = 1)."""
    head = {"Head": 1}
    wide, narrow = math.radians(118), math.radians(84)
    mb.loft([
        R((0, Y0 + 0.008, 1.68), 0.090, 0.108, head, arc=(-wide, wide)),
        R((0, Y0 + 0.012, 1.61), 0.093, 0.109, head, arc=(-wide, wide)),
        R((0, Y0 + 0.020, 1.54), 0.098, 0.106, head, arc=(-wide, wide)),
        R((0, 0.040, 1.48), 0.122, 0.100, {"Head": 0.6, "Chest": 0.4}, arc=(-narrow, narrow)),
        R((0, 0.075, 1.40), 0.165, 0.090, {"Chest": 1}, arc=(-narrow, narrow)),
        R((0, 0.128, 1.30), 0.152, 0.050, {"Chest": 1}, arc=(-narrow, narrow)),
        R((0, 0.135, 1.20), 0.142, 0.040, {"Chest": 1}, arc=(-narrow, narrow)),
        R((0, 0.130, 1.10), 0.128, 0.030, {"Chest": 1}, arc=(-narrow, narrow)),
    ], "hair", 10, mat=MAT_HAIR, arc=(-wide, wide))


def build_hair(mb):
    build_scalp(mb)
    build_back(mb)
    build_fringe(mb)
    build_side_locks(mb)
