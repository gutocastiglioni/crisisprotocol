"""Malha low-poly do alossauro: mesma construção do raptor (pele única), outras medidas.

Usa o atlas do raptor (mesmo layout; a textura é outra, `tools/make_allosaurus_texture.py`) e as ferramentas de
`raptor_mesh`: anéis de emenda (`joint`), união booleana das peças que se cruzam e pesos das juntas.
Cadeias: cauda -> tronco -> pescoço -> cabeça; coxa -> canela -> metatarso; braço -> antebraço. Fundidos por união:
coxas, braços, dedos dos pés e das mãos (pele). Soltos (rígidos, presos a um osso): chifres, mandíbula, dentes, olhos e garras.
Cabeça esculpida (`allosaurus_head`: proporções da tabela `allosaurus_ref`, medida na referência por
`tools/measure_allosaurus.py`, forma desenhada aqui), fundida ao pescoço pela união; a pele toda é lisa.
Peças horizontais usam b_hint = Z: u = 0 no dorso, u = 0.5 na barriga (12 lados: 0 = alto, 3 = lado esq., 6 = embaixo).
"""
import math

import bmesh
from mathutils import Vector

import allosaurus_head as H
import allosaurus_ref as REF
import allosaurus_rings as RINGS
import allosaurus_spec as S
import raptor_atlas
from heroine_mesh import MeshBuilder, R, ring_frame
from raptor_mesh import _self_union, claw, joint

X = Vector((1, 0, 0))
Z = Vector((0, 0, 1))
SPINE_SIDES = 12
LIMB_SIDES = 12  # membros: os 12 raios medidos


# tronco medido: (y de começo, y de fim, osso), da frente para trás; nas emendas os pesos se misturam (BLEND)
TRUNK_BONES = [(-1.90, -1.45, "Neck1"), (-1.45, -0.95, "Chest"), (-0.95, -0.40, "Spine"), (-0.40, 0.60, "Hips"),
               (0.60, 1.40, "Tail1"), (1.40, 2.70, "Tail2"), (2.70, 4.00, "Tail3"), (4.00, 5.60, "Tail4")]
BLEND = 0.15
NECK_END, BODY_END = -1.45, 0.55  # (anéis medidos) onde o retângulo "neck" vira "body" e "body" vira "tail"
NECK_OVERLAP = -1.85  # daqui para a frente o tronco entra no pescoço medido (allosaurus_head); a união funde


def _trunk_weights(y):
    if y < NECK_OVERLAP + 0.05:
        return H._neck_weights(y)
    w = {}
    for y0, y1, bone in TRUNK_BONES:
        d = max(y0 - y, y - y1, 0.0)  # 0 dentro do trecho
        if d < BLEND:
            w[bone] = 1 - d / BLEND
    total = sum(w.values())
    return {k: v / total for k, v in w.items()}


def _trunk_scale(y):
    """No trecho que entra no pescoço medido: um pouco maior no começo dele (cobre a tampa) e menor lá dentro."""
    if y > NECK_OVERLAP + 0.05:
        return 1.0
    return 1.03 if y > NECK_OVERLAP - 0.03 else 0.9


def build_trunk(mb):
    """Pescoço (base), tronco e cauda pelos anéis medidos (`allosaurus_rings.body_rings`, subidos HEAD_LIFT como a
    cabeça), em três peças que continuam uma da outra sem emenda (mesmos vértices); cada uma no seu retângulo do atlas."""
    rows = []
    for y, half in H._lift(RINGS.body_rings()):
        k = _trunk_scale(y)
        zs = [z for _, z in half]
        zc = (max(zs) + min(zs)) / 2
        rows.append(H._ring(y, [(x * k, zc + (z - zc) * k) for x, z in half], _trunk_weights(y)))
    neck = [r for r in rows if r["c"].y <= NECK_END + 1e-6]
    body = [r for r in rows if NECK_END - 1e-6 <= r["c"].y <= BODY_END + 1e-6]
    tail = [r for r in rows if r["c"].y >= BODY_END - 1e-6]
    sides = 2 * (len(RINGS.REF.BODY[0][1]) - 1)
    grid = mb.loft(list(reversed(neck)), "neck", sides, caps=(False, True), b_hint=Z)
    body[0] = dict(body[0], verts=grid[0])
    grid = mb.loft(body, "body", sides, caps=(False, False), b_hint=Z)
    tail[0] = dict(tail[0], verts=grid[-1])
    mb.loft(tail, "tail", sides, caps=(False, True), b_hint=Z)


# dedos em cunha alta como os da Capcom (medidos: o pé tem 0,4-0,6 m de largura ainda a 0,16-0,32 m do chão e os
# dedos abrem 0,8 m no chão): (dx da base, dx da ponta, y da ponta, escala); o do meio é o maior
TOES = ((0.0, 0.0, -0.50, 1.0), (0.14, 0.36, -0.36, 0.85), (-0.14, -0.34, -0.34, 0.85))
TOE_R = ((0.13, 0.17), (0.10, 0.11), (0.065, 0.05))  # (rx, ry) na base, no meio e na ponta; o fundo fica no chão


def _toes(x, k):
    for dx0, dx1, y1, sc in TOES:
        r = [(rx * sc, ry * sc) for rx, ry in TOE_R]
        a = Vector((x + k * dx0, S.BALL.y + 0.04, r[0][1] + 0.01))  # TOES: y da ponta em relação à bola em y 0,08
        b = Vector((x + k * dx1, S.BALL.y + y1 - 0.08, r[2][1] + 0.015))
        mid = a.lerp(b, 0.5)
        mid.z = r[1][1] + 0.01
        yield a, b, mid, r


def _limb_rings(name, a, b, weights, k):
    """Anéis medidos do membro `name` (REF.LIMBS: fração do eixo e (lado, fundo) de 12 raios no referencial do eixo)
    postos no nosso osso de a até b (os raios são em metros, o comprimento é o nosso); lado esquerdo medido, k = -1
    espelha. Pontos na ordem do loft (ângulo a partir do eixo de fundo, como os anéis procedurais)."""
    _, rows = REF.LIMBS[name]
    al, bl = Vector((a.x * k, a.y, a.z)), Vector((b.x * k, b.y, b.z))  # osso do lado esquerdo
    axis = (bl - al).normalized()
    side = (X - axis * axis.x).normalized()
    dep = axis.cross(side)
    fa, fb = ring_frame(b - a)
    out = []
    for t, pts in rows:
        c = al.lerp(bl, t)
        ps = [c + side * x + dep * z for x, z in pts]
        if k < 0:
            ps = [Vector((-p.x, p.y, p.z)) for p in ps]
        cc = a.lerp(b, t)
        ps.sort(key=lambda p: math.atan2((p - cc).dot(fa), (p - cc).dot(fb)) % (2 * math.pi))
        out.append((t, R(cc, 0.1, 0.1, weights(t), pts=ps)))
    return out


def build_leg(mb, s):
    """Perna pelos cortes medidos da referência (coxa em coxa de galinha, canela, metatarso) nos nossos ossos; a coxa
    nasce de dentro do quadril."""
    k = 1 if s == "L" else -1
    th, sh, mt, toe = f"Thigh_{s}", f"Shin_{s}", f"Meta_{s}", f"Toe_{s}"
    hip, knee, ankle, ball = S.side(S.HIP_JOINT, s), S.side(S.KNEE, s), S.side(S.ANKLE, s), S.side(S.BALL, s)

    def thigh_w(t):
        return {"Hips": 0.5, th: 0.5} if t < 0.15 else ({th: 0.5, sh: 0.5} if t > 0.99 else {th: 1})

    def shin_w(t):
        return {sh: 0.5, mt: 0.5} if t > 0.99 else {sh: 1}

    def meta_w(t):
        return {mt: 0.5, toe: 0.5} if t > 0.99 else {mt: 1}

    start = R((k * 0.22, hip.y, hip.z + 0.33), 0.20, 0.30, {"Hips": 1})  # dentro do quadril
    segs = [[r for _, r in _limb_rings("thigh", hip, knee, thigh_w, k)],
            [r for t, r in _limb_rings("shin", knee, ankle, shin_w, k) if t > 0.05],
            [r for t, r in _limb_rings("meta", ankle, ball, meta_w, k) if t > 0.05]]
    shared = None
    for i, (rect, rings) in enumerate(zip(("thigh", "shin", "meta"), segs)):
        if shared is not None:
            rings = [{"c": rings[0]["c"], "rx": 0.1, "ry": 0.1, "w": rings[0]["w"], "verts": shared}] + rings
        first = [start] if i == 0 else []
        grid = mb.loft(first + rings, rect, LIMB_SIDES, caps=(i == 0, i == 2))
        shared = grid[-1]
    # três dedos compridos no chão, em leque: cunhas grossas que afinam até a garra (Capcom)
    for a, b, mid, r in _toes(S.side(S.BALL, s).x, k):
        mb.loft([
            R(a, r[0][0], r[0][1], {toe: 1}),
            R(mid, r[1][0], r[1][1], {toe: 1}),
            R(b, r[2][0], r[2][1], {toe: 1}),
        ], "toe", 6, b_hint=Z)


def build_foot_claws(mb, s):
    k = 1 if s == "L" else -1
    x = k * S.LEG_X
    for a, b, _, r in _toes(x, k):
        claw(mb, b, (b - a).normalized(), 0.2 * r[2][0] / TOE_R[2][0], r[2][0] * 0.9, r[2][1] * 0.9, f"Toe_{s}", drop=0.06)


def build_arm(mb, s):
    """Braço, antebraço e palma pelos cortes medidos da referência, uma pele só (mesmos vértices nas juntas); nasce de
    dentro do peito. As garras vêm depois (build_hand_claws)."""
    k = 1 if s == "L" else -1
    arm, fore, hand = f"Arm_{s}", f"Forearm_{s}", f"Hand_{s}"
    sh, el, wr = S.side(S.SHOULDER, s), S.side(S.ELBOW, s), S.side(S.WRIST, s)
    upper = [r for _, r in _limb_rings("arm", sh, el, lambda t: {"Chest": 0.5, arm: 0.5} if t < 0.15 else (
        {arm: 0.5, fore: 0.5} if t > 0.99 else {arm: 1}), k)]
    lower = [r for t, r in _limb_rings("forearm", el, wr, lambda t: {fore: 0.5, hand: 0.5} if t > 0.99 else {fore: 1}, k)
             if t > 0.05]
    start = R(Vector((sh.x * 0.45, sh.y, sh.z + 0.06)), 0.12, 0.13, {"Chest": 1})  # dentro do peito
    grid = mb.loft([start] + upper, "arm", LIMB_SIDES, caps=(True, False))
    lower = [{"c": upper[-1]["c"], "rx": 0.1, "ry": 0.1, "w": upper[-1]["w"], "verts": grid[-1]}] + lower
    grid = mb.loft(lower, "arm", LIMB_SIDES, caps=(False, False))
    # palma: continua o antebraço (mesmos vértices no pulso) pelos cortes medidos da mão, até HAND_PALM
    tip = S.side(S.HAND_TIP, s)
    palm = [r for t, r in _limb_rings("hand", wr, tip, lambda t: {hand: 1}, k) if 0.05 < t <= HAND_PALM + 0.01]
    mb.loft([{"c": lower[-1]["c"], "rx": 0.1, "ry": 0.1, "w": lower[-1]["w"], "verts": grid[-1]}] + palm, "arm",
            LIMB_SIDES, caps=(False, True))


# mão medida na referência: palma (anéis de REF.LIMBS["hand"] até HAND_PALM do comprimento do pulso à ponta da garra)
# e três garras compridas e curvas saindo dela; (deslocamento de lado, comprimento)
HAND_PALM = 0.55
HAND_CLAWS = ((-0.07, 0.30), (0.03, 0.28), (0.12, 0.14))
HAND_DROOP = 0.35  # as garras caem um pouco além da palma


def _hand_frame(s):
    """Pulso, direção da mão e eixo de lado (para fora) do lado `s`."""
    k = 1 if s == "L" else -1
    wr, tip = S.side(S.WRIST, s), S.side(S.HAND_TIP, s)
    d = (tip - wr).normalized()
    side = (Vector((k, 0, 0)) - d * d.x * k).normalized()
    return wr, d, side


def build_hand_claws(mb, s):
    """Garras retas quase paralelas, saindo da ponta da pá na direção da mão."""
    wr, d, side = _hand_frame(s)
    end = wr + (S.side(S.HAND_TIP, s) - wr) * HAND_PALM
    for off, length in HAND_CLAWS:
        di = (d + side * (off * 0.25) - Z * HAND_DROOP).normalized()
        claw(mb, end + side * off - d * 0.03, di, length, 0.05, 0.045, f"Hand_{s}", drop=0.06)


def build_all(bone_names):
    skin = MeshBuilder(bone_names, raptor_atlas)
    build_trunk(skin)
    H.build_skull(skin)
    for s in ("L", "R"):
        build_leg(skin, s)
        build_arm(skin, s)
    bmesh.ops.remove_doubles(skin.bm, verts=skin.bm.verts, dist=1e-5)  # solda os anéis das emendas
    mb = MeshBuilder(bone_names, raptor_atlas)
    mb.bm.free()
    mb.bm = _self_union(skin.bm, bone_names, keep_bones=("Head",))
    mb.uv = mb.bm.loops.layers.uv.active
    mb.dl = mb.bm.verts.layers.deform.active
    H.build_horns(mb)  # chifre é osso rígido preso à cabeça: peça à parte (a união deixava lascas e vincos na pele)
    H.build_jaw(mb)
    H.build_teeth(mb)
    H.build_eyes(mb)
    for s in ("L", "R"):
        build_foot_claws(mb, s)
        build_hand_claws(mb, s)
    return mb
