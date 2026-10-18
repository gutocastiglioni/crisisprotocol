"""Guerrilheiro encapuzado (milícia): homem de moletom com o capuz levantado por cima de uma balaclava preta,
colete com bolsas de carregador, luvas, calça cargo larga e coturno. Mesmo esqueleto (heroine_spec) e mesmas
animações da heroína, mas a malha é toda daqui, com medidas de homem e roupa folgada:
  - tronco: moletom reto e largo (sem cintura), bainha com aba sobre a calça, bolso canguru e peitoral leves;
  - capuz: casca aberta na frente (material de dois lados), mais alto e largo que a cabeça, caindo sobre os ombros;
  - cabeça: crânio de homem (os anéis da heroína mais largos), coberto pela balaclava pintada (olhos e boca);
  - braços: mangas largas com punho canelado, mão de luva maior; pernas: calça reta com bolso cargo, barra
    embolada sobre o cano do coturno, coturno de bico largo.
Os anéis seguem as medidas da heroína antes do ajuste de perna (heroine_spec.remap_z é aplicado pelo MeshBuilder),
para baterem com os ossos. Atlas: guerrilla_atlas.py (pintado por tools/make_guerrilla_texture.py).
"""
import math

from mathutils import Vector

import guerrilla_atlas
import heroine_head
import heroine_mesh as M
import heroine_spec as S

X, Y, Z = M.X, M.Y, M.Z
R = M.R

# ------------------------------------------------------------------ tronco (moletom; embaixo, o começo da calça)
# (z, centro y, rx, ry): do gancho até a base do pescoço. A bainha é um degrau: 0.905 (calça, por dentro) -> 0.907 (aba)
TORSO = [
    (0.80, 0.000, 0.112, 0.088),
    (0.84, 0.000, 0.148, 0.100),
    (0.88, 0.004, 0.158, 0.106),
    (0.905, 0.004, 0.150, 0.100),
    (0.907, 0.002, 0.180, 0.125),
    (0.95, 0.000, 0.178, 0.123),
    (0.97, 0.000, 0.174, 0.119),
    (1.03, 0.000, 0.172, 0.117),
    (1.10, -0.004, 0.174, 0.116),
    (1.18, -0.006, 0.182, 0.119),
    (1.26, -0.006, 0.192, 0.123),
    (1.32, -0.004, 0.198, 0.121),
    (1.37, 0.000, 0.184, 0.113),
    (1.41, 0.000, 0.168, 0.104),
    (1.435, 0.000, 0.138, 0.094),
    (1.455, 0.000, 0.108, 0.085),
    (1.47, 0.000, 0.086, 0.079),
]


def _torso_bones(z):
    if z <= 0.97:
        return {"Hips": 1}
    if z < 1.05:
        return {"Hips": 0.5, "Spine": 0.5}
    if z < 1.13:
        return {"Spine": 1}
    if z < 1.17:
        return {"Spine": 0.7, "Chest": 0.3}
    if z < 1.23:
        return {"Spine": 0.3, "Chest": 0.7}
    if z < 1.46:
        return {"Chest": 1}
    return {"Chest": 0.5, "Neck": 0.5}


def _volume(th, z):
    """Volume além da elipse (th: 0 = costas, pi = frente): bolso canguru, peitoral e escápulas, discretos."""
    v = M._lobe(th, z, math.pi, 1.00, 0.010, 0.55, 0.045)
    for k in (1, -1):
        v += M._lobe(th, z, math.pi - k * 0.5, 1.28, 0.008, 0.4, 0.06)
        v += M._lobe(th, z, k * 0.6, 1.32, 0.008, 0.4, 0.06)
    return v


def build_torso(mb):
    rings = []
    for z, y, rx, ry in TORSO:
        w = _torso_bones(z)
        push = {j: _volume(2 * math.pi * j / M.TORSO_SIDES, z) for j in range(M.TORSO_SIDES)}
        deep = 1.1 if 0.95 < z < 1.44 else 1.0  # moletom folgado: mais fundo de perfil
        rings.append(R((0, y, z), rx, ry * deep, w, push, frame=(X, Y), wfn=M._torso_weights(w, z)))
    mb.loft(rings, "torso", M.TORSO_SIDES, v_by_z=True)


# ------------------------------------------------------------------ cabeça, balaclava e capuz
HEAD_RX, HEAD_RY = 1.07, 1.04  # crânio de homem: mais largo


def build_head(mb):
    head = {"Head": 1}
    rings = [R((0, y, z), rx * HEAD_RX, ry * HEAD_RY, head, push or None, frame=(X, Y))
             for z, y, rx, ry, push in heroine_head.HEAD]
    mb.loft(rings, "head", heroine_head.SIDES, v_by_z=True)
    neck = {"Neck": 1}
    mb.loft([
        R((0, -0.003, 1.43), 0.078, 0.072, {"Chest": 0.5, "Neck": 0.5}),
        R((0, -0.005, 1.47), 0.064, 0.060, neck),
        R((0, -0.008, 1.50), 0.060, 0.058, neck),
        R((0, -0.012, 1.535), 0.058, 0.060, {"Neck": 0.5, "Head": 0.5}),
    ], "neck", 8)


# (z, centro y, rx, ry, meia abertura da frente em radianos, pesos): de cima dos ombros até o topo
HOOD = [
    (1.45, 0.024, 0.134, 0.120, 1.00, {"Chest": 0.6, "Neck": 0.4}),
    (1.50, 0.014, 0.114, 0.118, 0.80, {"Neck": 0.7, "Head": 0.3}),
    (1.55, 0.006, 0.108, 0.124, 0.66, {"Head": 1}),
    (1.60, 0.002, 0.108, 0.128, 0.68, {"Head": 1}),
    (1.65, 0.000, 0.108, 0.130, 0.66, {"Head": 1}),
    (1.69, 0.000, 0.104, 0.128, 0.56, {"Head": 1}),
    (1.715, 0.004, 0.094, 0.120, 0.30, {"Head": 1}),  # alto da abertura (aba sobre a testa)
    (1.735, 0.008, 0.082, 0.108, 0.0, {"Head": 1}),  # daqui para cima fechado
    (1.765, 0.014, 0.060, 0.082, 0.0, {"Head": 1}),
    (1.79, 0.020, 0.030, 0.044, 0.0, {"Head": 1}),
    (1.80, 0.022, 0.008, 0.012, 0.0, {"Head": 1}),
]


def build_hood(mb):
    """Capuz levantado: aberto na frente (o rosto de balaclava aparece), dos dois lados (material do cabelo)."""
    rings = [R((0, y, z), rx, ry, w, frame=(X, Y), arc=(-(math.pi - o), math.pi - o)) for z, y, rx, ry, o, w in HOOD]
    mb.loft(rings, "hair", 12, mat=M.MAT_HAIR)
    # cordões saindo da abertura e caindo no peito
    for k in (1, -1):
        mb.box(Vector((k * 0.046, -0.138, 1.40)), X, Y, (0.0045, 0.004, 0.065), "cord", {"Chest": 1})


# ------------------------------------------------------------------ braços e mãos
def build_arm(mb, s):
    ua, la, hand, chest = f"UpperArm_{s}", f"LowerArm_{s}", f"Hand_{s}", "Chest"
    p = lambda d: S.arm_point(s, d)
    UA, w0 = S.UPPER_ARM_LEN, S.UPPER_ARM_LEN + S.FOREARM_LEN
    pu = lambda f: p(UA * f)
    pl = lambda f: p(UA + S.FOREARM_LEN * f)
    # manga larga de moletom (ombro arredondado, sem afinar muito até o punho)
    mb.loft([
        R(p(-0.038), 0.020, 0.024, {chest: 0.6, ua: 0.4}),
        R(p(-0.026), 0.040, 0.046, {chest: 0.5, ua: 0.5}),
        R(p(-0.008), 0.054, 0.060, {chest: 0.3, ua: 0.7}),
        R(pu(0.08), 0.064, 0.066, {chest: 0.12, ua: 0.88}),
        R(pu(0.30), 0.062, 0.064, {ua: 1}),
        R(pu(0.60), 0.058, 0.060, {ua: 1}),
        R(pu(0.85), 0.055, 0.056, {ua: 1}),
        R(p(UA + 0.005), 0.052, 0.054, {ua: 0.5, la: 0.5}),
    ], "sleeve_upper", 8)
    mb.loft([
        R(p(UA - 0.005), 0.053, 0.055, {ua: 0.5, la: 0.5}),
        R(pl(0.30), 0.052, 0.054, {la: 1}),
        R(pl(0.60), 0.049, 0.051, {la: 1}),
        R(pl(0.80), 0.047, 0.048, {la: 1}),
        R(p(w0 - 0.035), 0.040, 0.042, {la: 1}),
        R(p(w0 - 0.012), 0.036, 0.038, {la: 0.8, hand: 0.2}),
        R(p(w0 + 0.004), 0.031, 0.033, {la: 0.5, hand: 0.5}),
    ], "sleeve_lower", 8)
    # punho fechado de luva, maior que o dela
    mb.loft([
        R(p(w0), 0.028, 0.036, {hand: 0.6, la: 0.4}),
        R(p(w0 + 0.03), 0.033, 0.052, {hand: 1}),
        R(p(w0 + 0.062), 0.035, 0.056, {hand: 1}),
        R(p(w0 + 0.088), 0.031, 0.050, {hand: 1}),
        R(p(w0 + 0.104), 0.019, 0.036, {hand: 1}),
    ], "hand", 6)
    a, _ = M.ring_frame(S.side(S.ARM_DIR_L, s))
    mb.box(p(w0 + 0.045) + Vector((0, -0.057, 0)), a, Y, (0.016, 0.013, 0.03), "hand", {hand: 1})


# ------------------------------------------------------------------ pernas e coturno
def build_leg(mb, s):
    k = 1 if s == "L" else -1
    ul, ll, foot, hips = f"UpperLeg_{s}", f"LowerLeg_{s}", f"Foot_{s}", "Hips"
    # calça cargo reta e larga
    mb.loft([
        R((k * 0.085, 0, 0.93), 0.098, 0.104, {hips: 0.5, ul: 0.5}),
        R((k * 0.09, 0, 0.86), 0.096, 0.100, {hips: 0.2, ul: 0.8}),
        R((k * 0.092, -0.003, 0.78), 0.089, 0.093, {ul: 1}),
        R((k * 0.092, -0.006, 0.69), 0.082, 0.085, {ul: 1}),
        R((k * 0.091, -0.008, 0.60), 0.075, 0.078, {ul: 1}),
        R((k * 0.09, -0.01, 0.53), 0.069, 0.072, {ul: 1}),
        R((k * 0.09, -0.01, 0.48), 0.067, 0.070, {ul: 0.5, ll: 0.5}),
    ], "thigh", 8, v_by_z=True)
    # canela; a barra embola em cima do cano do coturno (anel mais largo e depois um degrau para dentro)
    mb.loft([
        R((k * 0.09, -0.01, 0.51), 0.067, 0.070, {ul: 0.5, ll: 0.5}),
        R((k * 0.09, -0.005, 0.45), 0.067, 0.069, {ll: 1}),
        R((k * 0.09, 0.0, 0.38), 0.065, 0.067, {ll: 1}),
        R((k * 0.09, 0.005, 0.30), 0.063, 0.065, {ll: 1}),
        R((k * 0.09, 0.008, 0.24), 0.066, 0.068, {ll: 1}),
        R((k * 0.09, 0.010, 0.215), 0.069, 0.071, {ll: 1}),
        R((k * 0.09, 0.012, 0.205), 0.054, 0.058, {ll: 1}),
        R((k * 0.09, 0.015, 0.15), 0.050, 0.056, {ll: 0.8, foot: 0.2}),
        R((k * 0.09, 0.02, 0.10), 0.051, 0.058, {ll: 0.6, foot: 0.4}),
        R((k * 0.09, 0.02, 0.08), 0.053, 0.060, {ll: 0.5, foot: 0.5}),
    ], "shin", 8, v_by_z=True)
    fr = (X, Z)
    mb.loft([
        R((k * 0.09, 0.075, 0.06), 0.050, 0.060, {ll: 0.3, foot: 0.7}, frame=fr),
        R((k * 0.09, 0.0, 0.06), 0.055, 0.062, {foot: 1}, frame=fr),
        R((k * 0.09, -0.09, 0.05), 0.057, 0.050, {foot: 1}, frame=fr),
        R((k * 0.09, -0.165, 0.038), 0.050, 0.036, {foot: 1}, frame=fr),
        R((k * 0.09, -0.195, 0.030), 0.034, 0.024, {foot: 1}, frame=fr),
    ], "foot", 6)
    # bolso cargo na lateral da coxa
    mb.box(Vector((k * 0.176, -0.01, 0.70)), X, Y, (0.008, 0.05, 0.06), "cargo", {ul: 1})


def build_gear(mb):
    # colete de peito simples: três bolsas de carregador
    for x in (-0.066, 0.0, 0.066):
        mb.box(Vector((x, -0.152, 1.235)), X, Y, (0.029, 0.017, 0.042), "pouch", {"Chest": 1})


def build_all(bone_names):
    mb = M.MeshBuilder(bone_names, atlas_module=guerrilla_atlas, remap=M._proportion)
    build_torso(mb)
    build_head(mb)
    build_hood(mb)
    for s in ("L", "R"):
        build_arm(mb, s)
        build_leg(mb, s)
    build_gear(mb)
    return mb
