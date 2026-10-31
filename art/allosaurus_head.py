"""Cabeça do alossauro, esculpida (modelo nosso; a "Alice" de `possible_models/` serviu só de base para olhar: as
proporções vêm da tabela medida `allosaurus_ref`, a forma é desenhada aqui).

Como é feita:
- cada fatia é uma curva lisa (Catmull-Rom) que passa pelos pontos-chave da tabela (alto, base da crista, quina,
  bochecha, lábio, céu da boca; mandíbula: língua, braço, lado, quina, fundo) e é reamostrada com 2 pontos por
  trecho: 36 pontos no crânio (3 por trecho) e 16 na mandíbula, sempre com o mesmo ponto-chave no mesmo índice (a pintura usa isso);
- os pontos-chave também passam por uma curva lisa ao longo do comprimento, com um anel a cada ~4 cm;
- depois vem a escultura: campos de deslocamento ao longo da normal (arco da sobrancelha, órbita funda, narina,
  cristas nasais baixas, bochecha, músculo da mandíbula) e peças: globo do olho dentro da órbita, chifre lacrimal
  (entra na união com a pele), dentes em pirâmide de 3 lados;
- o crânio é uma peça fechada que entra no pescoço e é fundida a ele pela união (pele única), por isso pode ter mais
  pontos que o pescoço.
Volta do crânio (36): j = 0 alto, 3 base da crista, 6 quina/crista, 9 bochecha, 12 lábio, 15 borda e 18 meio do céu
da boca (atrás da boca, fechado: raios a cada 30°, j = 3 k); na pintura, jj = u * 12 é o mesmo em qualquer densidade. Mandíbula (16): 0 língua, 2 braço, 4 lado, 6 quina, 8 fundo.
"""
import math

from mathutils import Vector

import allosaurus_ref as REF
import allosaurus_rings as RINGS
from allosaurus_spec import HEAD_LIFT
from heroine_mesh import MAT_BODY, R
from raptor_mesh import MAT_TEETH

Z = Vector((0, 0, 1))
STEP = 0.03  # distância entre anéis
BACK_Y = -2.30  # traseira do crânio (dentro do pescoço; a união funde)
OPEN = (-3.40, -2.73)  # trecho da boca (dentes de cima: do canto, -2,73, até a frente)
LID = (0.044, 0.031, 0.010, 0.012)  # aro das pálpebras: meia-abertura de frente-trás e de cima-baixo (amêndoa), raio do
# tubo, quanto a de cima desce na frente (olhar de caçador)
TOOTH_STEP = 0.022  # um dente a cada 2,2 cm pela borda do lábio (fileira fechada)
EYE_C, EYE_R = Vector((0.184, -2.909, 2.69 + HEAD_LIFT)), 0.039  # globo do olho (medido: 0,188 / 2,69, r 0,037), afundado no aro
LOWER_TEETH = (-3.30, -2.80, 12)
TOOTH_UP, TOOTH_LOW = 0.05, 0.03
# chifres (no espaço da referência): (trecho em y da base sobre a quina, ponta (x, y, z), meia-espessura); a ponta passa
# do alto medido da quina (~2,98 e ~2,93) para virar lâmina
HORNS = [((-3.14, -2.91), (0.236, -2.960, 3.075), 0.024),  # lacrimal: frente longa, cai logo antes do olho
         ((-2.87, -2.76), (0.262, -2.800, 2.990), 0.02)]  # pós-orbital


def _lift(table):
    return [(y, tuple((x, z + HEAD_LIFT) for x, z in half)) for y, half in table]


# tabelas medidas, na altura do nosso corpo
HEAD, JAW, HEAD_DENSE, JAW_DENSE, NECK_DENSE = map(_lift, (REF.HEAD, REF.JAW, REF.HEAD_DENSE, REF.JAW_DENSE, REF.NECK_DENSE))


# ------------------------------------------------------------------ curvas
def _cr(p0, p1, p2, p3, t):
    """Ponto da Catmull-Rom (uniforme) entre p1 e p2."""
    t2, t3 = t * t, t * t * t
    return tuple(0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
                 for a, b, c, d in zip(p0, p1, p2, p3))


def _smooth_half(keys, per=2):
    """Meia volta lisa (do alto em x = 0 até embaixo em x = 0) passando pelos pontos-chave, `per` pontos por trecho;
    nas pontas usa o espelho como vizinho (a volta inteira fica lisa no meio)."""
    ext = [(-keys[1][0], keys[1][1])] + list(keys) + [(-keys[-2][0], keys[-2][1])]
    out = []
    for i in range(len(keys) - 1):
        for s in range(per):
            out.append(_cr(ext[i], ext[i + 1], ext[i + 2], ext[i + 3], s / per))
    out.append(tuple(keys[-1]))
    return [(max(0.0, x) if i not in (0, len(out) - 1) else 0.0, z) for i, (x, z) in enumerate(out)]


def _keys_at(table, y):
    """Pontos-chave na profundidade y: curva lisa entre as fatias da tabela (ordem da tabela qualquer)."""
    rows = sorted(table, key=lambda r: r[0])
    ys = [r[0] for r in rows]
    if y <= ys[0]:
        return rows[0][1]
    if y >= ys[-1]:
        return rows[-1][1]
    i = max(k for k in range(len(ys) - 1) if ys[k] <= y)
    t = (y - ys[i]) / (ys[i + 1] - ys[i])
    a, b = rows[max(i - 1, 0)][1], rows[i][1]
    c, d = rows[i + 1][1], rows[min(i + 2, len(rows) - 1)][1]
    return [_cr(pa, pb, pc, pd, t) for pa, pb, pc, pd in zip(a, b, c, d)]


def _ys(y0, y1):
    n = max(2, round(abs(y1 - y0) / STEP))
    return [y0 + (y1 - y0) * i / n for i in range(n + 1)]


def _ring(y, half, weights):
    full = half + [(-x, z) for x, z in reversed(half[1:-1])]
    pts = [Vector((x, y, z)) for x, z in full]
    zs = [z for _, z in half]
    c = Vector((0.0, y, (max(zs) + min(zs)) / 2))
    return R(c, max(x for x, _ in half), (max(zs) - min(zs)) / 2, weights, pts=pts)


# ------------------------------------------------------------------ escultura
def _gauss(p, c, r):
    d = Vector(((p.x - c.x) / r[0], (p.y - c.y) / r[1], (p.z - c.z) / r[2]))
    return math.exp(-d.length_squared)


def _face_fields():
    """Escultura por cima da retopologia: órbita funda com aro, arco grosso sobre o olho, barras ósseas atrás e embaixo do
    olho, fossa na frente do olho e narina."""
    out = []
    for k in (1, -1):
        e = Vector((k * EYE_C.x, EYE_C.y, EYE_C.z))
        out += [
            (e + Vector((k * 0.03, 0.012, -0.020)), (0.05, 0.055, 0.07), -0.032),  # órbita funda (o oval da pintura)
            (e + Vector((0.0, -0.01, 0.075)), (0.07, 0.10, 0.04), 0.02),  # arco sobre o olho
            (e + Vector((0.0, 0.10, 0.07)), (0.05, 0.015, 0.06), 0.02),  # barra de trás (pós-orbital), que
            (e + Vector((0.0, 0.08, -0.09)), (0.05, 0.015, 0.06), 0.02),  # corta a mancha escura quase em pé (medido)
            (e + Vector((0.0, 0.03, -0.088)), (0.06, 0.15, 0.032), 0.015),  # barra de baixo (jugal)
            (Vector((k * 0.2, -3.08, 2.60 + HEAD_LIFT)), (0.05, 0.09, 0.055), -0.02),  # fossa antorbital
            (Vector((k * 0.07, -3.375, 2.48 + HEAD_LIFT)), (0.03, 0.025, 0.02), -0.02),  # narina
        ]
    return out


SKULL_EXTRA = _face_fields()
JAW_EXTRA = []


def sculpt(mb, verts, fields):
    """Desloca os vértices ao longo da normal da peça pelos campos (incha/afunda), como um pincel de escultura."""
    mb.bm.normal_update()
    moves = []
    for v in verts:
        dz = sum(a * _gauss(v.co, c, r) for c, r, a in fields)
        if abs(dz) > 1e-5:
            moves.append((v, v.normal.copy() * dz))
    for v, m in moves:
        v.co += m


# ------------------------------------------------------------------ peças
def _neck_weights(y):
    """Pesos pelo comprimento: Neck1 na base do pescoço medido, Neck2 no meio, Head da nuca para a frente."""
    a = min(1.0, max(0.0, (-1.85 - y) / 0.45))  # 0 na base (-1,85), 1 na nuca (-2,30)
    head = min(1.0, max(0.0, (a - 0.6) / 0.4 * 0.5 + max(0.0, (-2.30 - y) / 0.15) * 0.5))
    n1 = max(0.0, 0.5 - 1.5 * a)
    w = {"Neck1": n1, "Neck2": 1.0 - n1 - head, "Head": head}
    return {k: v for k, v in w.items() if v > 1e-3}


def build_skull(mb):
    """Pescoço medido e crânio, fechados, da base do pescoço à ponta, pelos anéis da retopologia já acertados
    (`allosaurus_rings.head_rings`), com a escultura por cima."""
    before = set(mb.bm.verts)
    rings = [_ring(y, list(half), _neck_weights(y)) for y, half in _lift(RINGS.head_rings())]
    mb.loft(rings, "head", 2 * (len(HEAD_DENSE[0][1]) - 1), caps=(True, True), b_hint=Z)
    sculpt(mb, [v for v in mb.bm.verts if v not in before], SKULL_EXTRA)


def build_horns(mb):
    """Chifres em lâmina que crescem da quina medida: perfil em triângulo ao longo de y (sobe devagar da frente até a
    ponta e cai de repente atrás), finos de lado; a base fica 5 cm dentro da pele em todo o comprimento (a união funde).
    Pintura na metade direita do retângulo "mouth" (u = 0 no fio de cima)."""
    rect = mb.atlas.RECTS["mouth"]
    x0, w = rect[0] / mb.atlas.SIZE, rect[2] / mb.atlas.SIZE
    for k in (1, -1):
        for (y0, y1), tip, thick in HORNS:
            yt, n = tip[1], 9
            cxt, czt = _keys_at(HEAD, yt)[2]
            rise = tip[2] + HEAD_LIFT - czt  # altura da ponta acima da quina
            rings = []
            for i in range(n):
                y = y0 + (y1 - y0) * i / (n - 1)
                cx, cz = _keys_at(HEAD, y)[2]
                f = (y - y0) / (yt - y0) if y <= yt else (y1 - y) / (y1 - yt)
                f = max(0.0, f) ** 1.3
                top, bottom = cz + rise * f, cz - 0.05
                x = k * (cx * 0.97 + (tip[0] - cxt) * f)
                rings.append(R(Vector((x, y, (top + bottom) / 2)), thick * (0.5 + 0.5 * f), (top - bottom) / 2, {"Head": 1}))
            before = set(mb.bm.faces)
            mb.loft(rings, "mouth", 6, b_hint=Z)
            for f in set(mb.bm.faces) - before:  # u do loft (0..1 no retângulo) vai para a metade direita
                for loop in f.loops:
                    uv = loop[mb.uv].uv
                    uv.x = x0 + w * (0.5 + 0.5 * (uv.x - x0) / w)


def build_jaw(mb):
    """Mandíbula da ponta de trás até o queixo (`allosaurus_rings.jaw_rings`). Atrás da boca ela fica por baixo da
    garganta e termina numa ponta para trás e para baixo (o osso que sai do fim da mandíbula, como na referência)."""
    before = set(mb.bm.verts)
    rings = [_ring(y, list(half), {"Jaw": 1}) for y, half in _lift(RINGS.jaw_rings())]
    mb.loft(rings, "jaw", 2 * (len(JAW_DENSE[0][1]) - 1), b_hint=Z)
    sculpt(mb, [v for v in mb.bm.verts if v not in before], JAW_EXTRA)


def _keypoint(table, y, k):
    return _keys_at(table, y)[k]


def _tooth(mb, base, along, out, down, length, width, bone):
    """Dente em pirâmide de 3 lados (com volume): base = triângulo com a face de fora virada para `out` (larga ao longo
    da fileira, `along`), ponta a `length` na direção `down` (já curvada para trás)."""
    w = {bone: 1}
    a = base + along * width
    b = base - along * width
    c = base - out * width * 0.8
    tip = base + down * length
    vs = [mb._vert(p, w) for p in (a, b, c, tip)]
    uv = [mb.atlas.uv("teeth", 0.1, 0.1), mb.atlas.uv("teeth", 0.9, 0.1), mb.atlas.uv("teeth", 0.5, 0.9)]
    mid = (a + b + c + tip) / 4
    for i, j in ((0, 1), (1, 2), (2, 0)):
        pa, pb = (a, b, c)[i], (a, b, c)[j]
        f = [vs[i], vs[j], vs[3]]
        n = (pb - pa).cross(tip - pa)
        if n.dot((pa + pb + tip) / 3 - mid) < 0:  # face para fora (o Godot corta as de trás)
            f = [vs[j], vs[i], vs[3]]
        mb._face(f, uv, MAT_TEETH)


def _lip_path(table, js, y_back):
    """Borda de baixo da boca de y_back até a ponta, lado esquerdo, um ponto por anel: o mais baixo dos índices `js`
    da meia volta (do lábio à borda do céu da boca; na frente o céu da boca desce abaixo do lábio)."""
    out = []
    for y, half in reversed(table):
        if y <= y_back:
            x, z = min((half[j] for j in js), key=lambda p: p[1])
            out.append(Vector((x, y, z)))
    return out


def _outer_x(table, y, z):
    """x de fora da peça (anéis densos) na altura z, em y (anel mais perto); 0 se a altura não cruza a peça."""
    _, half = min(table, key=lambda r: abs(r[0] - y))
    best = 0.0
    for (xa, za), (xb, zb) in zip(half, half[1:]):
        if (za - z) * (zb - z) <= 0 and za != zb:
            best = max(best, xa + (xb - xa) * (z - za) / (zb - za))
    return best


def _top_z(table, y):
    """Alto (z) do anel denso mais perto de y."""
    _, half = min(table, key=lambda r: abs(r[0] - y))
    return max(z for _, z in half)


def _gum_wall(mb, gum, k):
    """Parede de gengiva escura atrás da fileira de dentes, do lábio até abaixo da borda da mandíbula: entre os dentes
    aparece o vermelho-escuro da boca, nunca o outro lado (fundo). Cor: língua do retângulo "jaw"."""
    uv = mb.atlas.uv("jaw", 0.02, 0.5)
    w = {"Head": 1}
    rows = [(mb._vert(top + Vector((0, 0, 0.006)), w), mb._vert(Vector((top.x, top.y, bottom)), w)) for top, bottom, _ in gum]
    for (a, b), (c, d), (_, _, out) in zip(rows, rows[1:], gum):
        q = [a, c, d, b]
        n = (c.co - a.co).cross(b.co - a.co)
        if n.dot(out) < 0:
            q.reverse()
        mb._face(q, [uv] * 4, MAT_BODY)


def _along(path, step):
    """Pontos a cada `step` metros pelo caminho, com a direção do caminho."""
    out, acc, nxt = [], 0.0, step * 0.5
    for p, q in zip(path, path[1:]):
        d = (q - p).length
        while nxt <= acc + d:
            t = (nxt - acc) / d
            out.append((p.lerp(q, t), (q - p).normalized()))
            nxt += step
        acc += d
    return out


def build_teeth(mb):
    """Dentes como os do Dino Crisis: fileira cheia e fechada de cima, do canto da boca até a frente do focinho (dá a
    volta na ponta), pendurada na borda do lábio POR FORA da mandíbula (cobre a borda dela, como nos terópodes); os de
    baixo ficam por dentro, menores."""
    path = _lip_path(HEAD_DENSE, range(12, 16), OPEN[1])
    front = path[-1]
    path.append(Vector((0.0, front.y - 0.004, front.z)))  # fecha a volta no meio da frente
    pts = _along(path, TOOTH_STEP)
    total = len(pts)
    for k in (1, -1):
        m = Vector((k, 1, 1))
        gum = []
        for i, (p, d) in enumerate(pts):
            p, d = p * m, d * m  # espelho em x
            t = 1 - i / max(1, total - 1)  # 0 na frente, 1 no canto da boca
            length = TOOTH_UP * (0.72 + 0.4 * math.sin(math.pi * min(1.0, (1 - t) * 1.6)) * (1 - 0.45 * t))
            out = d.cross(Vector((0, 0, 1))) * (-k)  # para fora (lado esquerdo: +x)
            if out.length < 1e-6:
                out = Vector((0, -1, 0))
            out.normalize()
            if out.dot(Vector((p.x, -0.6, 0)).normalized()) < 0:
                out = -out
            jaw_top = _top_z(JAW_DENSE, p.y)
            length = max(length, p.z - jaw_top + 0.018)  # desce até passar da borda da mandíbula: fecha a linha da boca
            tip_z = p.z - length
            jaw_x = _outer_x(JAW_DENSE, p.y, tip_z + 0.01)  # o dente fica por fora da borda da mandíbula
            base = p.copy()
            if abs(p.x) < jaw_x + 0.008 and abs(p.x) > 0.06:
                base.x = k * (jaw_x + 0.008)
            down = (Vector((0, 0.25, -1)) + out * 0.08).normalized()  # para baixo, curvado para trás e um pouco para fora
            _tooth(mb, base - out * 0.004, d, out, down, length, TOOTH_STEP * 0.42, "Head")
            gum.append((base - out * 0.012, jaw_top - 0.02, out))
        _gum_wall(mb, gum, k)
        ly0, ly1, n = LOWER_TEETH
        for i in range(n):
            y = ly0 + (ly1 - ly0) * i / (n - 1)
            x, z = _keypoint(JAW, y, 1)
            out = Vector((k, 0, 0))
            _tooth(mb, Vector((k * x * 0.85, y, z - 0.01)), Vector((0, 1, 0)), out, Vector((0, 0.25, 1)).normalized(),
                   TOOTH_LOW, 0.009, "Jaw")


def build_eyes(mb):
    """Globo do olho (esfera baixa, 8 x 6) dentro da órbita; pintura no retângulo "mouth" do atlas (íris virada para
    fora)."""
    w = {"Head": 1}
    for k in (1, -1):
        c = Vector((k * EYE_C.x, EYE_C.y, EYE_C.z))
        out = Vector((k, -0.2, 0.05)).normalized()
        a = out.cross(Z).normalized()
        b = a.cross(out).normalized()
        rows = []
        for i in range(7):  # do polo de fora (íris) ao de dentro
            th = math.pi * i / 6
            row = []
            for j in range(8):
                ph = 2 * math.pi * j / 8
                d = out * math.cos(th) + (a * math.cos(ph) + b * math.sin(ph)) * math.sin(th)
                row.append((mb._vert(c + d * EYE_R, w), (0.25 + 0.24 * math.sin(th) * math.cos(ph) * (1 if th < 1.6 else 0.2),
                                                       0.5 + 0.48 * math.sin(th) * math.sin(ph) * (1 if th < 1.6 else 0.2))))
            rows.append(row)
        for i in range(6):
            for j in range(8):
                q = [rows[i][j], rows[i + 1][j], rows[i + 1][(j + 1) % 8], rows[i][(j + 1) % 8]]
                if k < 0:
                    q = q[::-1]
                if i == 0:
                    tri = [q[0], q[1], q[2]] if k > 0 else [q[1], q[2], q[3]]
                    mb._face([p[0] for p in tri], [mb.atlas.uv("mouth", *p[1]) for p in tri], MAT_BODY)
                    continue
                mb._face([p[0] for p in q], [mb.atlas.uv("mouth", *p[1]) for p in q], MAT_BODY)
        _lids(mb, c, out, a, b, w)


def _lids(mb, c, out, a, b, w):
    """Aro das pálpebras (como o da referência): tubo em amêndoa em volta do olho, na frente do globo, a pele de cima
    descendo um pouco na frente; o globo fica afundado dentro dele. Cor de pele escura (retângulo "mouth", u = 0,75)."""
    ry, rz, tube, droop = LID
    front = a if a.y < 0 else -a  # a = eixo frente-trás do olho; front aponta para o focinho
    centre = c + out * (EYE_R * 0.55)
    uv = mb.atlas.uv("mouth", 0.75, 0.5)
    n_ring, n_tube = 14, 4
    grid = []
    for i in range(n_ring):
        th = 2 * math.pi * i / n_ring
        cy, sz = math.cos(th), math.sin(th)
        rz_i = rz * (abs(sz) ** 0.8) * (1 if sz >= 0 else 0.8) * (1 if sz > 0 else 1)
        p = centre + front * (ry * cy) + b * (math.copysign(rz_i, sz) - (droop * max(0.0, cy) if sz > 0 else 0.0))
        radial = (p - centre).normalized()
        row = []
        for j in range(n_tube):
            ph = 2 * math.pi * j / n_tube
            row.append(mb._vert(p + (radial * math.cos(ph) + out * math.sin(ph)) * tube, w))
        grid.append((row, p))
    for i in range(n_ring):
        (r0, p0), (r1, p1) = grid[i], grid[(i + 1) % n_ring]
        for j in range(n_tube):
            q = [r0[j], r1[j], r1[(j + 1) % n_tube], r0[(j + 1) % n_tube]]
            n = (q[1].co - q[0].co).cross(q[3].co - q[0].co)
            if n.dot(sum((v.co for v in q), Vector()) / 4 - (p0 + p1) / 2) < 0:
                q.reverse()
            mb._face(q, [uv] * 4, MAT_BODY)
