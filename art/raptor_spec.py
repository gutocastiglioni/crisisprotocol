"""Medidas do velociraptor (metros, Blender: Z para cima, olhando para -Y, esquerda dele em +X).

Raptor "de Dino Crisis": ~3,3 m do focinho à ponta da cauda, quadril a 0,93 m, cabeça a ~1,4 m.
As juntas das pernas ficam todas no mesmo plano (x constante) para o IK das animações ser exato.
"""
from mathutils import Vector

LEG_X = 0.17

HIP_HEAD = Vector((0, 0.05, 0.93))
HIP_JOINT = Vector((LEG_X, 0.02, 0.90))
KNEE = Vector((LEG_X, -0.20, 0.56))
ANKLE = Vector((LEG_X, 0.12, 0.20))
BALL = Vector((LEG_X, 0.04, 0.05))
TOE_TIP = Vector((LEG_X, -0.16, 0.03))

SHOULDER = Vector((0.13, -0.58, 0.92))
ELBOW = Vector((0.17, -0.62, 0.74))
WRIST = Vector((0.15, -0.80, 0.70))
HAND_TIP = Vector((0.13, -0.90, 0.60))

JAW_HINGE = Vector((0, -0.93, 1.29))
MOUTH = Vector((0, -1.22, 1.27))  # onde a presa fica na mordida (marcador "Mouth")


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def side(v, s):
    return v.copy() if s == "L" else mirror(v)


# (nome, cabeça, cauda, pai, eixo do roll). "up": Z local para cima (corpo, cauda, cabeça);
# "fwd": Z local para a frente (membros). Ver o cabeçalho de raptor_anims.py.
def bones():
    out = [
        ("Hips", HIP_HEAD, Vector((0, -0.20, 0.93)), None, "up"),
        ("Spine", Vector((0, -0.20, 0.93)), Vector((0, -0.45, 0.97)), "Hips", "up"),
        ("Chest", Vector((0, -0.45, 0.97)), Vector((0, -0.66, 1.04)), "Spine", "up"),
        ("Neck1", Vector((0, -0.66, 1.04)), Vector((0, -0.78, 1.20)), "Chest", "up"),
        ("Neck2", Vector((0, -0.78, 1.20)), Vector((0, -0.88, 1.36)), "Neck1", "up"),
        ("Head", Vector((0, -0.88, 1.36)), Vector((0, -1.36, 1.28)), "Neck2", "up"),
        ("Jaw", JAW_HINGE, Vector((0, -1.34, 1.23)), "Head", "up"),
        ("Tail1", HIP_HEAD, Vector((0, 0.45, 0.95)), "Hips", "up"),
        ("Tail2", Vector((0, 0.45, 0.95)), Vector((0, 0.85, 0.95)), "Tail1", "up"),
        ("Tail3", Vector((0, 0.85, 0.95)), Vector((0, 1.25, 0.93)), "Tail2", "up"),
        ("Tail4", Vector((0, 1.25, 0.93)), Vector((0, 1.80, 0.90)), "Tail3", "up"),
    ]
    for s in ("L", "R"):
        out += [
            (f"Thigh_{s}", side(HIP_JOINT, s), side(KNEE, s), "Hips", "fwd"),
            (f"Shin_{s}", side(KNEE, s), side(ANKLE, s), f"Thigh_{s}", "fwd"),
            (f"Meta_{s}", side(ANKLE, s), side(BALL, s), f"Shin_{s}", "fwd"),
            (f"Toe_{s}", side(BALL, s), side(TOE_TIP, s), f"Meta_{s}", "up"),
            (f"Arm_{s}", side(SHOULDER, s), side(ELBOW, s), "Chest", "fwd"),
            (f"Forearm_{s}", side(ELBOW, s), side(WRIST, s), f"Arm_{s}", "fwd"),
            (f"Hand_{s}", side(WRIST, s), side(HAND_TIP, s), f"Forearm_{s}", "fwd"),
        ]
    return out


BONE_NAMES = [b[0] for b in bones()]
