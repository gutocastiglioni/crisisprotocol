"""Colete do guerrilheiro (o do painel do usuário: placas pretas de frente e de costas, alças com almofada no ombro,
faixa em volta da cintura com as tiras de lado e as três bolsas de carregador), sem gola, vestido por cima do corpo de
moletom (art/guerrilla_spec.BARE). Cada parte é uma peça fechada que entra CARRIER_IN no corpo; a união
(raptor_mesh._self_union, em art/guerrilla_body.py) solda tudo numa pele só e tira o que fica dentro. Medidas em
art/guerrilla_spec.py (CARRIER_*); UV no retângulo "vest" do atlas (frente na metade esquerda, costas na direita, de
frente: u pelo x, v pela altura), pintado por tools/make_guerrilla_texture.paint_vest.
"""
import math

import bmesh
from mathutils import Vector

import guerrilla_atlas
import guerrilla_spec as G
from heroine_mesh import R

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
MAT = 1  # MAT_GEAR de art/guerrilla_body.py: a união não arredonda as quinas do colete
BAND_SIDES = 16
PLATE_X = (0.0, 0.078, 0.115, 0.150, 0.168, 0.178)  # cortes da placa (espelhados); a de fora passa do lado do corpo
PLATE_T = (0.0, 0.15, 0.36, 0.60, 0.82, 1.0)  # alturas da frente da placa entre o pé e o alto
STRAP_X = (0.078, 0.148)
STRAP_N = 4  # pontos de cada lado da alça (frente e costas) até o alto do ombro


def _weights(z):
    return G.torso_bones(z) if z < 1.50 else {"Chest": 1}


def _surface(x, z, back):
    """Ponto (y) do moletom em x, z, com o volume do peito/escápula; None fora da largura."""
    y = G.bare_y(x, z, back)
    if y is None:
        return None
    yc, rx, ryf, ryb = G.bare_ring(z)
    th = math.atan2(x / rx, (y - yc) / (ryb if back else ryf))
    push = G.bare_volume(th, z)
    return y + push if back else y - push


def plate_y(x, z, back=False):
    """y da face de fora da placa em x, z: a elipse do moletom crescida CARRIER_T (igual na frente e no lado, sem degrau
    onde a placa passa do corpo), mais o volume do peito/escápula."""
    yc, rx, ryf, ryb = G.bare_ring(z)
    ry = (ryb if back else ryf) + G.CARRIER_T
    k = math.sqrt(max(0.0, 1 - (x / (rx + G.CARRIER_T)) ** 2))
    y = yc + ry * k if back else yc - ry * k
    s = _surface(x, z, back)
    if s is not None:
        th = math.atan2(x / rx, (s - yc) / (ryb if back else ryf))
        push = max(0.0, G.bare_volume(th, z))
        y = y + push if back else y - push
    return y


def _plate(mb, back):
    """Placa da frente ou de trás, inteira do pé (cantos redondos) ao alto (decote, alça, cava): cortes em x de um lado
    ao outro, com a face de fora e a de dentro (no corpo; onde a placa passa do lado do corpo, quase no meio dele)."""
    xs = [-x for x in PLATE_X[:0:-1]] + list(PLATE_X)
    rings = []
    for x in xs:
        bottom, top = G.carrier_bottom(x), G.carrier_top(x, back)
        zs = [bottom + (top - bottom) * t for t in PLATE_T]
        outer = [Vector((x, plate_y(x, z, back), z)) for z in zs]
        inner = []
        for z in (zs[-1], zs[len(zs) // 2], zs[0]):
            yc = G.bare_ring(z)[0]
            s = _surface(x, z, back) if abs(x) < G.bare_ring(z)[1] - 0.006 else None
            y = s + (-G.CARRIER_IN if back else G.CARRIER_IN) if s is not None else yc + (0.004 if back else -0.004)
            inner.append(Vector((x, y, z)))
        pts = outer + inner
        c = sum(pts, Vector()) / len(pts)
        rings.append(R(c, 0.1, 0.1, _weights(c.z), pts=pts, frame=(Y, Z)))
    mb.loft(rings, "vest", len(rings[0]["pts"]), mat=MAT)


def _band(mb):
    """Faixa da cintura (as tiras de lado): em volta do corpo, mais baixa que as placas; aparece só nos lados, entre a
    placa da frente e a de trás (no resto fica dentro delas)."""
    z0, z1, t = G.CARRIER_BAND
    rings = []
    for z in (z0, (z0 + z1) / 2, z1):
        pts = []
        yc, rx, ryf, ryb = G.bare_ring(z)
        for j in range(BAND_SIDES):
            th = 2 * math.pi * j / BAND_SIDES
            s, c = math.sin(th), math.cos(th)
            ry = ryb if c > 0 else ryf
            n = Vector((s / rx, c / ry, 0.0)).normalized()
            pts.append(Vector((rx * s, yc + ry * c, z)) + n * t)
        rings.append(R((0, 0, z), 0.1, 0.1, _weights(z), pts=pts, frame=(X, Y)))
    mb.loft(rings, "vest", BAND_SIDES, mat=MAT)


def _shoulder_top(x):
    """z do alto do ombro do moletom em x (onde a meia-largura do anel vale x)."""
    lo, hi = 1.40, G.BARE[-1][0]
    for _ in range(40):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if G.bare_ring(mid)[1] > x else (lo, mid)
    return lo


def _strap(mb, k):
    """Alça de um lado: cortes em x com o caminho por cima do ombro (da placa da frente à de trás), para fora e para
    dentro do corpo, mais grossa no alto (a almofada). k = 1 esquerda (+x), -1 direita."""
    rings = []
    for x in STRAP_X:
        zt = _shoulder_top(x) - 0.001
        z0 = G.CARRIER_STRAP[3]
        path = [(G.bare_y(x, z0 + (zt - z0) * i / STRAP_N), z0 + (zt - z0) * i / STRAP_N) for i in range(STRAP_N)]
        path += [(G.bare_ring(zt)[0], zt + 0.004)]
        path += [(G.bare_y(x, z0 + (zt - z0) * i / STRAP_N, True), z0 + (zt - z0) * i / STRAP_N)
                 for i in range(STRAP_N - 1, -1, -1)]
        out, inn = [], []
        for i, (y, z) in enumerate(path):
            (ya, za), (yb, zb) = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
            t = Vector((yb - ya, zb - za)).normalized()
            n = Vector((-t.y, t.x))  # a curva vai da frente para trás por cima: a normal de fora é a da esquerda
            pad = G.CARRIER_PAD[2] if abs(i - STRAP_N) <= 1 else 0.0  # almofada: a alça engrossa no alto do ombro
            t_out = G.CARRIER_STRAP[2] + pad
            out.append(Vector((k * x, y + n.x * t_out, z + n.y * t_out)))
            inn.append(Vector((k * x, y - n.x * G.CARRIER_IN, z - n.y * G.CARRIER_IN)))
        pts = out + inn[::-1]
        c = sum(pts, Vector()) / len(pts)
        rings.append(R(c, 0.1, 0.1, {"Chest": 1}, pts=pts, frame=(Y, Z)))
    mb.loft(rings, "vest", len(rings[0]["pts"]), mat=MAT)


def _gear(mb):
    """Bolsas de carregador na placa da frente e as tiras de lado com fivela."""
    hx, hy, hz = G.MAG_HALF
    fx, fy, fz = G.MAG_FLAP
    for x, z in G.MAG_POUCHES:
        c = Vector((x, plate_y(x, z) - hy * 0.6, z))  # um pedaço entra na placa (a união solda)
        mb.box(c, X, Y, G.MAG_HALF, "pouch", {"Chest": 1}, MAT)
        mb.box(Vector((x, c.y - hy - fy + 0.004, z + hz - fz)), X, Y, G.MAG_FLAP, "pouch", {"Chest": 1}, MAT)
    for x, z in G.CARRIER_TABS:
        yc, rx, ryf, _ = G.bare_ring(z)
        th = math.asin(max(-1.0, min(1.0, x / (rx + G.CARRIER_T))))
        p = Vector(((rx + G.CARRIER_T) * math.sin(th), yc - (ryf + G.CARRIER_T) * math.cos(th), z))
        tangent = Vector((math.cos(th), math.sin(th) * (ryf / rx), 0.0)).normalized()
        out = Vector((tangent.y, -tangent.x, 0.0))  # para fora (frente e lado)
        mb.box(p + out * 0.002, tangent, out, G.CARRIER_TAB_HALF, "pouch", _weights(z), MAT)


def _vest_uv(mb, faces):
    """UV de frente no retângulo "vest": a frente na metade esquerda, as costas na direita; u pelo x, v pela altura."""
    for f in faces:
        back = f.calc_center_median().y > G.bare_ring(f.calc_center_median().z)[0]
        for loop in f.loops:
            co = loop.vert.co
            u = (0.75 if back else 0.25) + co.x / G.VEST_UV_SPAN
            v = guerrilla_atlas.z_to_v("vest", co.z)
            loop[mb.uv].uv = guerrilla_atlas.uv("vest", u, v)


def build_vest(mb):
    """O colete inteiro no MeshBuilder do corpo (antes da união)."""
    before = set(mb.bm.faces)
    _band(mb)
    _plate(mb, False)
    _plate(mb, True)
    for k in (1, -1):
        _strap(mb, k)
    gear_before = set(mb.bm.faces)
    _gear(mb)
    _vest_uv(mb, [f for f in gear_before - before])
    bmesh.ops.recalc_face_normals(mb.bm, faces=[f for f in mb.bm.faces if f not in before])
