"""Malha low-poly do velociraptor (mesmo construtor por anéis da heroína, com o atlas do raptor).

Peças horizontais (corpo, pescoço, cabeça, mandíbula, cauda, dedos) usam b_hint = Z: u = 0 no dorso,
u = 0.5 na barriga. A mandíbula é uma peça separada presa ao osso Jaw; os dentes são triângulos soltos.
"""
from mathutils import Vector

import raptor_atlas
import raptor_spec as S
from heroine_mesh import MeshBuilder, R

X = Vector((1, 0, 0))
Z = Vector((0, 0, 1))

MAT_SKIN = 0
MAT_TEETH = 1  # sem backface culling (dente é um triângulo só)

HEAD_RINGS = [
    # (centro, rx, ry)
    ((0, -0.90, 1.400), 0.060, 0.065),
    ((0, -0.98, 1.415), 0.085, 0.085),
    ((0, -1.08, 1.395), 0.080, 0.072),
    ((0, -1.20, 1.360), 0.062, 0.058),
    ((0, -1.32, 1.325), 0.045, 0.045),
    ((0, -1.40, 1.300), 0.022, 0.025),
]
JAW_RINGS = [
    ((0, -0.95, 1.300), 0.060, 0.040),
    ((0, -1.05, 1.285), 0.065, 0.040),
    ((0, -1.17, 1.262), 0.055, 0.042),
    ((0, -1.29, 1.240), 0.040, 0.040),
    ((0, -1.36, 1.235), 0.020, 0.030),
]


def _interp(rings, y):
    """Centro e raios do anel na profundidade y (interpolação linear entre anéis)."""
    for (c0, rx0, ry0), (c1, rx1, ry1) in zip(rings, rings[1:]):
        if c1[1] <= y <= c0[1]:
            t = (c0[1] - y) / (c0[1] - c1[1])
            c = Vector(c0).lerp(Vector(c1), t)
            return c, rx0 + (rx1 - rx0) * t, ry0 + (ry1 - ry0) * t
    c, rx, ry = rings[-1]
    return Vector(c), rx, ry


def build_body(mb):
    hips, spine, chest = {"Hips": 1}, {"Spine": 1}, {"Chest": 1}
    belly = {5: 0.02, 6: 0.035, 7: 0.02}  # 12 lados: 6 = barriga
    mb.loft([
        R((0, 0.30, 0.95), 0.10, 0.12, {"Hips": 0.5, "Tail1": 0.5}),
        R((0, 0.12, 0.95), 0.15, 0.17, hips),
        R((0, -0.05, 0.94), 0.17, 0.20, {"Hips": 0.8, "Spine": 0.2}),
        R((0, -0.25, 0.93), 0.165, 0.21, spine, belly),
        R((0, -0.45, 0.96), 0.15, 0.19, {"Spine": 0.5, "Chest": 0.5}, belly),
        R((0, -0.60, 1.00), 0.125, 0.16, chest),
        R((0, -0.70, 1.07), 0.095, 0.115, {"Chest": 0.5, "Neck1": 0.5}),
    ], "body", 12, b_hint=Z)


def build_neck(mb):
    mb.loft([
        R((0, -0.68, 1.06), 0.095, 0.11, {"Chest": 0.5, "Neck1": 0.5}),
        R((0, -0.76, 1.17), 0.075, 0.085, {"Neck1": 1}),
        R((0, -0.83, 1.28), 0.065, 0.07, {"Neck1": 0.5, "Neck2": 0.5}),
        R((0, -0.88, 1.36), 0.065, 0.07, {"Neck2": 0.5, "Head": 0.5}),
        R((0, -0.91, 1.41), 0.062, 0.068, {"Head": 1}),
    ], "neck", 10, b_hint=Z)


def build_head(mb):
    head = {"Head": 1}
    # 12 lados: 0 = alto da cabeça, 3 = lado esquerdo, 6 = embaixo
    shape = {
        1: {1: 0.017, 11: 0.017, 2: 0.009, 10: 0.009},  # arco ósseo acima do olho
        2: {3: 0.006, 9: 0.006, 1: 0.004, 11: 0.004},  # bochecha
        4: {1: 0.006, 11: 0.006},  # narinas
    }
    rings = []
    for i, (c, rx, ry) in enumerate(HEAD_RINGS):
        rings.append(R(c, rx, ry, head, shape.get(i)))
    mb.loft(rings, "head", 12, b_hint=Z)
    jaw = []
    for i, (c, rx, ry) in enumerate(JAW_RINGS):
        jaw.append(R(c, rx, ry, {"Jaw": 0.6, "Head": 0.4} if i == 0 else {"Jaw": 1}))
    mb.loft(jaw, "jaw", 8, b_hint=Z)


def _tooth(mb, base_a, base_b, tip, bone):
    w = {bone: 1}
    verts = [mb._vert(base_a, w), mb._vert(base_b, w), mb._vert(tip, w)]
    uvs = [raptor_atlas.uv("teeth", 0.1, 0.1), raptor_atlas.uv("teeth", 0.9, 0.1), raptor_atlas.uv("teeth", 0.5, 0.9)]
    mb._face(verts, uvs, MAT_TEETH)


def build_teeth(mb):
    """Fileira de dentes nas bordas das duas arcadas (aparecem de boca fechada, como na referência)."""
    for k in (1, -1):
        n = 11
        for i in range(n):
            y = -1.00 - i * (0.36 / (n - 1))
            c, rx, ry = _interp(HEAD_RINGS, y)
            base = c + X * (k * rx * 0.86) - Z * (ry * 0.52)
            half = Vector((0, 0.016, 0))
            length = 0.034 - 0.012 * i / n
            _tooth(mb, base - half, base + half, base - Z * length - Vector((0, 0.004, 0)), "Head")
        for i in range(9):
            y = -1.02 - i * (0.30 / 8)
            c, rx, ry = _interp(JAW_RINGS, y)
            base = c + X * (k * rx * 0.80) + Z * (ry * 0.6)
            half = Vector((0, 0.014, 0))
            _tooth(mb, base - half, base + half, base + Z * 0.026, "Jaw")


def build_tail(mb):
    mb.loft([
        R((0, 0.28, 0.955), 0.10, 0.12, {"Hips": 0.3, "Tail1": 0.7}),
        R((0, 0.45, 0.96), 0.085, 0.10, {"Tail1": 0.5, "Tail2": 0.5}),
        R((0, 0.70, 0.96), 0.07, 0.08, {"Tail2": 1}),
        R((0, 0.85, 0.955), 0.062, 0.07, {"Tail2": 0.5, "Tail3": 0.5}),
        R((0, 1.10, 0.945), 0.05, 0.055, {"Tail3": 1}),
        R((0, 1.25, 0.935), 0.042, 0.046, {"Tail3": 0.5, "Tail4": 0.5}),
        R((0, 1.55, 0.92), 0.028, 0.03, {"Tail4": 1}),
        R((0, 1.84, 0.90), 0.006, 0.006, {"Tail4": 1}),
    ], "tail", 8, b_hint=Z)


def build_leg(mb, s):
    k = 1 if s == "L" else -1
    x = k * S.LEG_X
    th, sh, mt, toe = f"Thigh_{s}", f"Shin_{s}", f"Meta_{s}", f"Toe_{s}"
    mb.loft([
        R((x, 0.03, 0.93), 0.11, 0.15, {"Hips": 0.5, th: 0.5}),
        R((k * 0.173, 0.0, 0.87), 0.112, 0.158, {th: 1}),
        R((k * 0.175, -0.04, 0.80), 0.10, 0.14, {th: 1}),
        R((k * 0.175, -0.13, 0.66), 0.07, 0.085, {th: 1}),
        R((x, -0.20, 0.56), 0.045, 0.05, {th: 0.5, sh: 0.5}),
    ], "thigh", 10)
    mb.loft([
        R((x, -0.19, 0.57), 0.045, 0.05, {th: 0.5, sh: 0.5}),
        R((x, -0.10, 0.46), 0.045, 0.05, {sh: 1}),
        R((x, 0.03, 0.31), 0.032, 0.035, {sh: 1}),
        R((x, 0.12, 0.20), 0.028, 0.03, {sh: 0.5, mt: 0.5}),
    ], "shin", 8)
    mb.loft([
        R((x, 0.12, 0.20), 0.028, 0.03, {sh: 0.5, mt: 0.5}),
        R((x, 0.08, 0.12), 0.026, 0.028, {mt: 1}),
        R((x, 0.04, 0.05), 0.03, 0.03, {mt: 0.5, toe: 0.5}),
    ], "meta", 6)
    # dedos III e IV no chão, com unha na ponta
    for dx, reach in ((0.0, 0.0), (k * 0.045, 0.05)):
        tx = x + dx
        mb.loft([
            R((tx, 0.05, 0.04), 0.022, 0.022, {toe: 1}),
            R((tx, -0.07 + reach, 0.032), 0.018, 0.016, {toe: 1}),
            R((tx, -0.15 + reach, 0.022), 0.011, 0.01, {toe: 1}),
        ], "toe", 4, b_hint=Z)
        mb.loft([
            R((tx, -0.145 + reach, 0.024), 0.008, 0.008, {toe: 1}),
            R((tx, -0.19 + reach, 0.012), 0.004, 0.004, {toe: 1}),
            R((tx, -0.205 + reach, 0.0), 0.001, 0.001, {toe: 1}),
        ], "claw", 4, b_hint=Z)
    # dedo II com a garra em foice levantada
    ix = x - k * 0.035
    mb.loft([
        R((ix, 0.04, 0.05), 0.016, 0.016, {mt: 0.5, toe: 0.5}),
        R((ix, -0.02, 0.05), 0.014, 0.014, {toe: 1}),
    ], "toe", 4, b_hint=Z)
    mb.loft([
        R((ix, -0.015, 0.06), 0.012, 0.014, {toe: 1}),
        R((ix, -0.05, 0.10), 0.009, 0.011, {toe: 1}),
        R((ix, -0.10, 0.095), 0.006, 0.007, {toe: 1}),
        R((ix, -0.125, 0.06), 0.001, 0.001, {toe: 1}),
    ], "claw", 4, b_hint=Z)


def build_arm(mb, s):
    k = 1 if s == "L" else -1
    arm, fore, hand = f"Arm_{s}", f"Forearm_{s}", f"Hand_{s}"
    mb.loft([
        R((k * 0.13, -0.58, 0.92), 0.04, 0.045, {"Chest": 0.5, arm: 0.5}),
        R((k * 0.16, -0.61, 0.82), 0.035, 0.038, {arm: 1}),
        R((k * 0.17, -0.62, 0.74), 0.028, 0.03, {arm: 0.5, fore: 0.5}),
    ], "arm", 6)
    mb.loft([
        R((k * 0.17, -0.62, 0.745), 0.028, 0.03, {arm: 0.5, fore: 0.5}),
        R((k * 0.16, -0.72, 0.72), 0.025, 0.027, {fore: 1}),
        R((k * 0.15, -0.80, 0.70), 0.022, 0.024, {fore: 0.5, hand: 0.5}),
    ], "arm", 6)
    for dx in (-0.02, 0.0, 0.02):
        mb.loft([
            R((k * (0.15 + dx), -0.80, 0.70), 0.012, 0.012, {hand: 1}),
            R((k * (0.14 + dx), -0.86, 0.66), 0.008, 0.008, {hand: 1}),
            R((k * (0.13 + dx * 1.4), -0.91, 0.58), 0.001, 0.001, {hand: 1}),
        ], "claw", 4)


def build_all(bone_names):
    mb = MeshBuilder(bone_names, raptor_atlas)
    build_body(mb)
    build_neck(mb)
    build_head(mb)
    build_teeth(mb)
    build_tail(mb)
    for s in ("L", "R"):
        build_leg(mb, s)
        build_arm(mb, s)
    return mb
