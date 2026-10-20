"""Medidas da heroína (metros, Blender: Z para cima, personagem olhando para -Y, esquerda dela em +X).

Altura ~1,72 m. Uma fonte só para malha, esqueleto e pistola.
"""
import math

from mathutils import Vector

ARM_SPREAD = math.radians(12)  # braços levemente abertos na pose de descanso

# Proporção perna/tronco: as medidas abaixo foram feitas com o gancho a 0,80 m (46% da altura, tronco comprido).
# remap_z sobe o gancho LEG_EXTRA metros esticando a perna (tornozelo até o gancho) e encurtando a barriga
# (gancho até WAIST_TOP); pés, peito, ombros, braços e cabeça não mudam, nem a altura total.
LEG_EXTRA = 0.035
ANKLE_Z, CROTCH_Z, WAIST_TOP = 0.085, 0.80, 1.15


def remap_z(z):
    if ANKLE_Z < z <= CROTCH_Z:
        return ANKLE_Z + (z - ANKLE_Z) * (CROTCH_Z + LEG_EXTRA - ANKLE_Z) / (CROTCH_Z - ANKLE_Z)
    if CROTCH_Z < z < WAIST_TOP:
        return CROTCH_Z + LEG_EXTRA + (z - CROTCH_Z) * (WAIST_TOP - CROTCH_Z - LEG_EXTRA) / (WAIST_TOP - CROTCH_Z)
    return z


def rz(v):
    """Vetor com a altura remapeada (ver remap_z)."""
    return Vector((v.x, v.y, remap_z(v.z)))


SHOULDER_L = Vector((0.18, 0.0, 1.385))
ARM_DIR_L = Vector((math.sin(ARM_SPREAD), 0.0, -math.cos(ARM_SPREAD)))
UPPER_ARM_LEN = 0.25
FOREARM_LEN = 0.235
HAND_LEN = 0.10  # punho fechado (segura a pistola)

HIP_L = rz(Vector((0.09, 0.0, 0.88)))
KNEE_L = rz(Vector((0.09, -0.01, 0.49)))
ANKLE_L = rz(Vector((0.09, 0.02, 0.085)))
TOE_L = Vector((0.09, -0.13, 0.03))


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def side(v, s):
    """s = 'L' devolve o vetor como está; 'R' espelha em X."""
    return v.copy() if s == "L" else mirror(v)


def arm_point(s, dist):
    """Ponto a `dist` metros do ombro ao longo do braço do lado `s`."""
    return side(SHOULDER_L, s) + side(ARM_DIR_L, s) * dist


def elbow(s):
    return arm_point(s, UPPER_ARM_LEN)


def wrist(s):
    return arm_point(s, UPPER_ARM_LEN + FOREARM_LEN)


# Tronco (cabeça, cauda) de cada osso; use_joints troca pelo do modelo base (art/heroine_body.py).
TORSO_BONES = {
    "Hips": (rz(Vector((0, 0, 0.92))), rz(Vector((0, 0, 1.02)))),
    "Spine": (rz(Vector((0, 0, 1.02))), Vector((0, 0, 1.20))),
    "Chest": (Vector((0, 0, 1.20)), Vector((0, 0, 1.44))),
    "Neck": (Vector((0, -0.005, 1.44)), Vector((0, -0.01, 1.52))),
    "Head": (Vector((0, -0.01, 1.52)), Vector((0, -0.01, 1.72))),
}


EXTRA_BONES = []  # ossos além dos 17 do corpo (a trança da heroína: use_joints)


def use_joints(j):
    """Esqueleto nas juntas de outro corpo (a heroína usa o modelo base: art/heroine_body.py). `j`: lado
    esquerdo (+X) de ombro, punho, quadril, joelho, tornozelo, ponta do pé, comprimentos do braço e da mão e os
    ossos do tronco. O braço continua reto em ARM_SPREAD (o modelo é posto assim). Sem chamar: as medidas acima
    (o guerrilheiro usa essas)."""
    global SHOULDER_L, UPPER_ARM_LEN, FOREARM_LEN, HAND_LEN, HIP_L, KNEE_L, ANKLE_L, TOE_L, TORSO_BONES, EXTRA_BONES
    SHOULDER_L = j["shoulder"].copy()
    UPPER_ARM_LEN, FOREARM_LEN, HAND_LEN = j["upper_arm"], j["forearm"], j["hand"]
    HIP_L, KNEE_L, ANKLE_L, TOE_L = j["hip"].copy(), j["knee"].copy(), j["ankle"].copy(), j["toe"].copy()
    TORSO_BONES = {k: (h.copy(), t.copy()) for k, (h, t) in j["torso"].items()}
    EXTRA_BONES = list(j.get("extra_bones", []))


# (nome, cabeça, cauda, pai). Nomes sem ponto para virarem nomes válidos no Godot.
def bones():
    tb = TORSO_BONES
    out = [
        ("Hips", *tb["Hips"], None),
        ("Spine", *tb["Spine"], "Hips"),
        ("Chest", *tb["Chest"], "Spine"),
        ("Neck", *tb["Neck"], "Chest"),
        ("Head", *tb["Head"], "Neck"),
    ]
    for s in ("L", "R"):
        out += [
            (f"UpperArm_{s}", side(SHOULDER_L, s), elbow(s), "Chest"),
            (f"LowerArm_{s}", elbow(s), wrist(s), f"UpperArm_{s}"),
            (f"Hand_{s}", wrist(s), arm_point(s, UPPER_ARM_LEN + FOREARM_LEN + HAND_LEN), f"LowerArm_{s}"),
            (f"UpperLeg_{s}", side(HIP_L, s), side(KNEE_L, s), "Hips"),
            (f"LowerLeg_{s}", side(KNEE_L, s), side(ANKLE_L, s), f"UpperLeg_{s}"),
            (f"Foot_{s}", side(ANKLE_L, s), side(TOE_L, s), f"LowerLeg_{s}"),
        ]
    return out + list(EXTRA_BONES)


BONE_NAMES = [b[0] for b in bones()]
