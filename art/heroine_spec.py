"""Medidas da heroína (metros, Blender: Z para cima, personagem olhando para -Y, esquerda dela em +X).

Altura ~1,72 m. Uma fonte só para malha, esqueleto e pistola.
"""
import math

from mathutils import Vector

ARM_SPREAD = math.radians(12)  # braços levemente abertos na pose de descanso

SHOULDER_L = Vector((0.18, 0.0, 1.385))
ARM_DIR_L = Vector((math.sin(ARM_SPREAD), 0.0, -math.cos(ARM_SPREAD)))
UPPER_ARM_LEN = 0.25
FOREARM_LEN = 0.235
HAND_LEN = 0.10  # punho fechado (segura a pistola)

HIP_L = Vector((0.09, 0.0, 0.88))
KNEE_L = Vector((0.09, -0.01, 0.49))
ANKLE_L = Vector((0.09, 0.02, 0.085))
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


# (nome, cabeça, cauda, pai). Nomes sem ponto para virarem nomes válidos no Godot.
def bones():
    out = [
        ("Hips", Vector((0, 0, 0.92)), Vector((0, 0, 1.02)), None),
        ("Spine", Vector((0, 0, 1.02)), Vector((0, 0, 1.20)), "Hips"),
        ("Chest", Vector((0, 0, 1.20)), Vector((0, 0, 1.44)), "Spine"),
        ("Neck", Vector((0, -0.005, 1.44)), Vector((0, -0.01, 1.52)), "Chest"),
        ("Head", Vector((0, -0.01, 1.52)), Vector((0, -0.01, 1.72)), "Neck"),
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
    return out


BONE_NAMES = [b[0] for b in bones()]
