"""Medidas do alossauro (metros, Blender: Z para cima, olhando para -Y, esquerda dele em +X).

Chefe da última sala: ~9 m do focinho à ponta da cauda, quadril a 2,6 m, cabeça a ~3,7 m (crista ~3,9 m).
Mesmos ossos do raptor (nomes e hierarquia), então o Godot reaproveita o modelo/ragdoll e as animações usam o mesmo IK.
Silhueta: cabeça grande e encaixotada com cristas sobre os olhos, pescoço grosso e curto, tronco fundo, coxas enormes,
canela e pé curtos (bicho pesado), braços curtos com três garras, cauda longa e grossa.
As juntas das pernas ficam todas no mesmo plano (x constante) para o IK das animações ser exato.
"""
from mathutils import Vector

LEG_X = 0.50

HIP_HEAD = Vector((0, 0.25, 2.62))
HIP_JOINT = Vector((LEG_X, 0.30, 2.52))
KNEE = Vector((LEG_X, -0.30, 1.45))
ANKLE = Vector((LEG_X, 0.30, 0.58))
BALL = Vector((LEG_X, 0.08, 0.16))
TOE_TIP = Vector((LEG_X, -0.45, 0.07))

SHOULDER = Vector((0.32, -1.25, 2.40))
ELBOW = Vector((0.45, -1.15, 1.98))
WRIST = Vector((0.42, -1.50, 1.85))
HAND_TIP = Vector((0.38, -1.78, 1.70))

NECK_BASE = Vector((0, -1.45, 2.85))
NECK_MID = Vector((0, -1.80, 3.15))
NAPE = Vector((0, -2.05, 3.35))
JAW_HINGE = Vector((0, -2.15, 2.95))
MOUTH = Vector((0, -2.90, 2.90))  # onde a presa fica na mordida (marcador "Mouth")


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def side(v, s):
    return v.copy() if s == "L" else mirror(v)


# (nome, cabeça, cauda, pai, eixo do roll): mesma convenção de raptor_spec.bones()
def bones():
    out = [
        ("Hips", HIP_HEAD, Vector((0, -0.40, 2.70)), None, "up"),
        ("Spine", Vector((0, -0.40, 2.70)), Vector((0, -0.95, 2.78)), "Hips", "up"),
        ("Chest", Vector((0, -0.95, 2.78)), NECK_BASE, "Spine", "up"),
        ("Neck1", NECK_BASE, NECK_MID, "Chest", "up"),
        ("Neck2", NECK_MID, NAPE, "Neck1", "up"),
        ("Head", NAPE, Vector((0, -3.30, 3.15)), "Neck2", "up"),
        ("Jaw", JAW_HINGE, Vector((0, -3.25, 2.80)), "Head", "up"),
        ("Tail1", HIP_HEAD, Vector((0, 1.40, 2.72)), "Hips", "up"),
        ("Tail2", Vector((0, 1.40, 2.72)), Vector((0, 2.70, 2.72)), "Tail1", "up"),
        ("Tail3", Vector((0, 2.70, 2.72)), Vector((0, 4.00, 2.66)), "Tail2", "up"),
        ("Tail4", Vector((0, 4.00, 2.66)), Vector((0, 5.55, 2.62)), "Tail3", "up"),
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
