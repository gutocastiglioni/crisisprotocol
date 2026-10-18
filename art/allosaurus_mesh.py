"""Malha low-poly do alossauro: mesma construção do raptor (pele única), outras medidas.

Usa o atlas do raptor (mesmo layout; a textura é outra, `tools/make_allosaurus_texture.py`) e as ferramentas de
`raptor_mesh`: anéis de emenda (`joint`), união booleana das peças que se cruzam e pesos das juntas.
Cadeias: cauda -> tronco -> pescoço -> cabeça; coxa -> canela -> metatarso; braço -> antebraço. Fundidos por união:
coxas, braços, dedos dos pés e das mãos, as cristas em quilha sobre os olhos e as saliências do focinho. Soltos:
mandíbula, dentes e unhas dos pés. A cabeça tem quinas vivas (`_sharp_head`), o resto da pele é liso.
Peças horizontais usam b_hint = Z: u = 0 no dorso, u = 0.5 na barriga (12 lados: 0 = alto, 3 = lado esq., 6 = embaixo).
"""
import math

import bmesh
from mathutils import Vector

import allosaurus_spec as S
import raptor_atlas
from heroine_mesh import MeshBuilder, R
from raptor_mesh import _interp, _self_union, _tooth, joint

X = Vector((1, 0, 0))
Z = Vector((0, 0, 1))
SPINE_SIDES = 12
LEG_SIDES = 8
ARM_SIDES = 6

HEAD_RINGS = [
    # (centro, rx, ry): nuca -> focinho. Crânio fundo e encaixotado (mais alto que largo), focinho rombudo.
    ((0, -2.10, 3.32), 0.34, 0.44),
    ((0, -2.35, 3.33), 0.37, 0.45),
    ((0, -2.65, 3.29), 0.34, 0.40),
    ((0, -2.95, 3.22), 0.29, 0.34),
    ((0, -3.20, 3.16), 0.23, 0.28),
    ((0, -3.35, 3.12), 0.15, 0.21),
    ((0, -3.45, 3.11), 0.06, 0.09),  # ponta em cunha (tampa pequena, sem disco chapado)
]
JAW_RINGS = [
    # topo bem dentro da cabeça: de boca fechada só aparece a linha do lábio; o canto sobe para o olho
    ((0, -2.12, 2.92), 0.36, 0.32),
    ((0, -2.40, 2.84), 0.37, 0.22),
    ((0, -2.70, 2.84), 0.32, 0.19),
    ((0, -3.00, 2.86), 0.26, 0.15),
    ((0, -3.25, 2.88), 0.18, 0.11),
    ((0, -3.40, 2.92), 0.10, 0.07),
]
LIP = {4: 0.03, 5: 0.025, 7: 0.025, 8: 0.03, 1: -0.02, 11: -0.02}  # crânio largo embaixo, estreito em cima
RIDGE = {0: 0.04, 1: 0.015, 11: 0.015}
KEEL = {6: 0.07, 5: 0.03, 7: 0.03, 0: 0.03}
HUMP = {0: 0.08, 1: 0.035, 11: 0.035, 6: 0.06, 5: 0.025, 7: 0.025}

J_TAIL = joint((0, 0.60, 2.72), 0.48, 0.62, {"Hips": 0.5, "Tail1": 0.5}, (0, 1.30, 2.77), (0, 0.30, 2.70), RIDGE, Z)
J_NECK = joint((0, -1.50, 2.95), 0.36, 0.55, {"Chest": 0.5, "Neck1": 0.5}, (0, -1.30, 2.84), (0, -1.68, 3.12), None, Z)
J_HEAD = joint(HEAD_RINGS[0][0], HEAD_RINGS[0][1], HEAD_RINGS[0][2], {"Head": 1}, (0, -2.00, 3.34), HEAD_RINGS[1][0], None, Z)


def build_tail(mb):
    mb.loft([
        J_TAIL,
        R((0, 1.30, 2.77), 0.37, 0.50, {"Hips": 0.2, "Tail1": 0.8}, RIDGE),
        R((0, 2.00, 2.75), 0.28, 0.40, {"Tail1": 0.5, "Tail2": 0.5}, RIDGE),
        R((0, 2.70, 2.72), 0.21, 0.32, {"Tail2": 0.6, "Tail3": 0.4}),
        R((0, 3.50, 2.68), 0.15, 0.24, {"Tail3": 1}),
        R((0, 4.40, 2.64), 0.10, 0.16, {"Tail3": 0.3, "Tail4": 0.7}),
        R((0, 5.00, 2.62), 0.06, 0.09, {"Tail4": 1}),
        R((0, 5.60, 2.60), 0.015, 0.015, {"Tail4": 1}),
    ], "tail", SPINE_SIDES, caps=(False, True), b_hint=Z)


def build_body(mb):
    mb.loft([
        J_TAIL,
        R((0, 0.30, 2.70), 0.55, 0.72, {"Hips": 1}, RIDGE),
        R((0, -0.10, 2.66), 0.57, 0.76, {"Hips": 0.5, "Spine": 0.5}, RIDGE),
        R((0, -0.55, 2.66), 0.56, 0.78, {"Spine": 0.6, "Chest": 0.4}, KEEL),
        R((0, -0.95, 2.72), 0.50, 0.74, {"Chest": 1}, HUMP),
        R((0, -1.30, 2.84), 0.42, 0.63, {"Chest": 0.7, "Neck1": 0.3}, KEEL),
        J_NECK,
    ], "body", SPINE_SIDES, caps=(False, False), b_hint=Z)


def build_neck(mb):
    """Pescoço grosso e curto, em S suave, que entra na nuca sem afinar."""
    mb.loft([
        J_NECK,
        R((0, -1.68, 3.12), 0.33, 0.48, {"Neck1": 1}),
        R((0, -1.85, 3.27), 0.31, 0.44, {"Neck1": 0.4, "Neck2": 0.6}),
        R((0, -2.00, 3.34), 0.33, 0.43, {"Neck2": 0.5, "Head": 0.5}),
        J_HEAD,
    ], "neck", SPINE_SIDES, caps=(False, False), b_hint=Z)


def build_head(mb):
    head = {"Head": 1}
    shape = {
        1: {2: 0.09, 10: 0.09, 3: -0.03, 9: -0.03, 4: 0.05, 8: 0.05},  # arco do olho, órbita funda, bochecha
        2: {2: 0.05, 10: 0.05, 3: -0.015, 9: -0.015, 4: 0.06, 8: 0.06, 1: 0.03, 11: 0.03},
        3: {1: 0.035, 11: 0.035, 0: -0.015, 4: 0.03, 8: 0.03},  # cristas nasais em par (sulco no meio)
        4: {1: 0.03, 11: 0.03, 0: -0.012},
        5: {1: 0.015, 11: 0.015},
    }
    tip_lip = {4: 0.015, 5: 0.015, 7: 0.015, 8: 0.015}
    rings = [J_HEAD]
    for i, (c, rx, ry) in enumerate(HEAD_RINGS[1:], start=1):
        push = dict(LIP) if i <= 4 else dict(tip_lip)
        push.update(shape.get(i, {}))
        rings.append(R(c, rx, ry, head, push))
    mb.loft(rings, "head", SPINE_SIDES, caps=(False, True), b_hint=Z)


def _ridge(mb, points, half_width, rect):
    """Saliência óssea em quilha: loft de 4 lados (losango, com uma aresta em cima) que nasce de dentro da cabeça.
    points: (x, y, z da base na pele, altura acima dela)."""
    rings = []
    for x, y, z, h in points:
        rings.append(R((x, y, z + h * 0.5 - 0.02), half_width, h * 0.5 + 0.04, {"Head": 1}))
    mb.loft(rings, rect, 4, b_hint=Z)


def build_crests(mb):
    """Cristas sobre os olhos (a marca do alossauro): quilha triangular que sobe até o pico acima do olho e desce
    para o focinho; e uma fileira baixa de saliências ao longo do focinho, de cada lado da crista nasal."""
    for k in (1, -1):
        _ridge(mb, [
            (k * 0.20, -2.15, 3.68, 0.02),
            (k * 0.20, -2.30, 3.69, 0.10),
            (k * 0.19, -2.42, 3.68, 0.17),
            (k * 0.18, -2.58, 3.63, 0.10),
            (k * 0.17, -2.80, 3.55, 0.04),
        ], 0.045, "head")
        _ridge(mb, [
            (k * 0.10, -2.80, 3.55, 0.025),
            (k * 0.095, -3.00, 3.52, 0.045),
            (k * 0.085, -3.15, 3.45, 0.04),
            (k * 0.075, -3.30, 3.35, 0.02),
        ], 0.025, "head")


def build_jaw(mb):
    jaw = []
    for i, (c, rx, ry) in enumerate(JAW_RINGS):
        jaw.append(R(c, rx, ry, {"Jaw": 0.6, "Head": 0.4} if i == 0 else {"Jaw": 1}))
    mb.loft(jaw, "jaw", 8, b_hint=Z)


def build_teeth(mb):
    """Dentes grandes nas duas arcadas (de boca fechada quase somem atrás do lábio)."""
    for k in (1, -1):
        for i in range(10):
            y = -2.30 - i * (1.0 / 9)
            c, rx, ry = _interp(HEAD_RINGS, y)
            base = c + X * (k * rx * 0.86) - Z * (ry * 0.55)
            half = Vector((0, 0.035, 0))
            _tooth(mb, base - half, base + half, base - Z * (0.028 - 0.008 * i / 9) - Vector((0, 0.01, 0)), "Head")
        for i in range(8):
            y = -2.40 - i * (0.85 / 7)
            c, rx, ry = _interp(JAW_RINGS, y)
            base = c + X * (k * rx * 0.80) + Z * (ry * 0.6)
            half = Vector((0, 0.03, 0))
            _tooth(mb, base - half, base + half, base + Z * 0.045, "Jaw")


def build_leg(mb, s):
    k = 1 if s == "L" else -1
    x = k * S.LEG_X
    th, sh, mt, toe = f"Thigh_{s}", f"Shin_{s}", f"Meta_{s}", f"Toe_{s}"
    knee = joint((x, -0.30, 1.45), 0.20, 0.22, {th: 0.5, sh: 0.5}, (k * 0.51, -0.18, 1.62), (x, -0.10, 1.15))
    ankle = joint((x, 0.30, 0.58), 0.18, 0.20, {sh: 0.5, mt: 0.5}, (x, 0.12, 0.85), (x, 0.20, 0.36))
    # coxa enorme: nasce de dentro do quadril
    mb.loft([
        R((k * 0.22, 0.32, 2.85), 0.20, 0.30, {"Hips": 1}),
        R((x, 0.30, 2.52), 0.30, 0.55, {"Hips": 0.5, th: 0.5}),
        R((k * 0.52, 0.18, 2.20), 0.32, 0.58, {th: 1}),
        R((k * 0.52, -0.02, 1.85), 0.27, 0.45, {th: 1}),
        R((k * 0.51, -0.18, 1.62), 0.20, 0.28, {th: 1}),
        knee,
    ], "thigh", LEG_SIDES, caps=(True, False))
    mb.loft([
        knee,
        R((x, -0.10, 1.15), 0.21, 0.28, {sh: 1}, {0: 0.1, 1: 0.05, 7: 0.05}),
        R((x, 0.12, 0.85), 0.16, 0.20, {sh: 1}, {0: 0.04}),
        ankle,
    ], "shin", LEG_SIDES, caps=(False, False))
    mb.loft([
        ankle,
        R((x, 0.20, 0.36), 0.17, 0.18, {mt: 1}),
        R((x, 0.08, 0.16), 0.21, 0.15, {mt: 0.5, toe: 0.5}),
    ], "meta", LEG_SIDES, caps=(False, True))
    # três dedos grandes no chão, abertos em leque
    for dx, reach in ((-0.13, 0.85), (0.0, 1.0), (0.13, 0.85)):
        tx = x + k * dx
        mb.loft([
            R((tx, 0.12, 0.13), 0.11, 0.10, {toe: 1}),
            R((x + k * dx * 1.6, 0.10 - 0.30 * reach, 0.10), 0.085, 0.075, {toe: 1}),
            R((x + k * dx * 2.0, 0.10 - 0.48 * reach, 0.065), 0.055, 0.045, {toe: 1}),
        ], "toe", 6, b_hint=Z)


def build_foot_claws(mb, s):
    k = 1 if s == "L" else -1
    x = k * S.LEG_X
    toe = f"Toe_{s}"
    for dx, reach in ((-0.13, 0.85), (0.0, 1.0), (0.13, 0.85)):
        y0 = 0.10 - 0.46 * reach
        tx = x + k * dx * 2.0
        mb.loft([
            R((tx, y0, 0.07), 0.04, 0.035, {toe: 1}),
            R((tx, y0 - 0.10, 0.04), 0.02, 0.018, {toe: 1}),
            R((tx, y0 - 0.16, 0.0), 0.003, 0.003, {toe: 1}),
        ], "claw", 4, b_hint=Z)


def build_arm(mb, s):
    arm, fore, hand = f"Arm_{s}", f"Forearm_{s}", f"Hand_{s}"
    sh, el, wr = S.side(S.SHOULDER, s), S.side(S.ELBOW, s), S.side(S.WRIST, s)
    mid_a, mid_f = sh.lerp(el, 0.45), el.lerp(wr, 0.5)
    elbow = joint(el, 0.13, 0.14, {arm: 0.5, fore: 0.5}, mid_a, mid_f)
    mb.loft([
        R(Vector((sh.x * 0.45, sh.y, sh.z + 0.08)), 0.15, 0.16, {"Chest": 1}),  # dentro do peito
        R(sh, 0.18, 0.19, {"Chest": 0.5, arm: 0.5}),
        R(mid_a, 0.16, 0.17, {arm: 1}),
        elbow,
    ], "arm", ARM_SIDES, caps=(True, False))
    mb.loft([
        elbow,
        R(mid_f, 0.12, 0.13, {fore: 1}),
        R(wr, 0.10, 0.105, {fore: 0.5, hand: 0.5}),
    ], "arm", ARM_SIDES, caps=(False, True))


def build_hand_claws(mb, s):
    """Três dedos curtos e grossos com garras grandes, relaxados (curvados para baixo)."""
    k = 1 if s == "L" else -1
    hand = f"Hand_{s}"
    el, wr = S.side(S.ELBOW, s), S.side(S.WRIST, s)
    root = wr.lerp(el, 0.15)
    for dx, reach in ((-0.04, 0.85), (0.0, 1.0), (0.04, 0.9)):
        base = wr + Vector((k * dx, 0, 0))
        knuckle = base + Vector((k * dx * 0.3, -0.12 * reach, -0.05))
        bend = knuckle + Vector((0, -0.06 * reach, -0.12 * reach))
        tip = bend + Vector((0, 0.04, -0.10 * reach))
        mb.loft([
            R(root + Vector((k * dx * 0.4, 0, 0)), 0.045, 0.045, {"Forearm_" + s: 0.5, hand: 0.5}),
            R(base, 0.06, 0.06, {hand: 1}),
            R(knuckle, 0.045, 0.045, {hand: 1}),
            R(bend, 0.028, 0.028, {hand: 1}),
            R(tip, 0.004, 0.004, {hand: 1}),
        ], "claw", 4)


def _sharp_head(bm, bone_names, angle=25.0):
    """Quinas vivas na cabeça (arco do olho, cristas, bochecha, crista nasal): arestas só da cabeça com dobra acima de
    `angle` graus ficam sem suavizar, como os planos do low-poly de PS1/PS2. O resto do corpo continua liso."""
    dl = bm.verts.layers.deform.active
    head = bone_names.index("Head")
    limit = math.radians(angle)
    for e in bm.edges:
        if not e.is_manifold or any(v[dl].get(head, 0.0) < 0.99 for v in e.verts):
            continue
        if e.calc_face_angle(0.0) > limit:
            e.smooth = False


def build_all(bone_names):
    skin = MeshBuilder(bone_names, raptor_atlas)
    build_tail(skin)
    build_body(skin)
    build_neck(skin)
    build_head(skin)
    build_crests(skin)
    for s in ("L", "R"):
        build_leg(skin, s)
        build_arm(skin, s)
        build_hand_claws(skin, s)
    bmesh.ops.remove_doubles(skin.bm, verts=skin.bm.verts, dist=1e-5)  # solda os anéis das emendas
    mb = MeshBuilder(bone_names, raptor_atlas)
    mb.bm.free()
    mb.bm = _self_union(skin.bm, bone_names, keep_bones=("Head",))
    mb.uv = mb.bm.loops.layers.uv.active
    mb.dl = mb.bm.verts.layers.deform.active
    _sharp_head(mb.bm, bone_names)
    build_jaw(mb)
    build_teeth(mb)
    for s in ("L", "R"):
        build_foot_claws(mb, s)
    return mb
