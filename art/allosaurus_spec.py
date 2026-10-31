"""Medidas do alossauro (metros, Blender: Z para cima, olhando para -Y, esquerda dele em +X).

Chefe da última sala: ~9 m do focinho à ponta da cauda, nas proporções da referência medida (allosaurus_ref): quadril a
~1,95 m, alto do dorso ~2,6 m, crista ~3,1 m.
Mesmos ossos do raptor (nomes e hierarquia), então o Godot reaproveita o modelo/ragdoll e as animações usam o mesmo IK.
Silhueta: cabeça grande e encaixotada com cristas sobre os olhos, pescoço grosso e curto, tronco fundo, coxas enormes,
canela e pé curtos (bicho pesado), braços curtos com três garras, cauda longa e grossa.
As juntas das pernas ficam todas no mesmo plano (x constante) para o IK das animações ser exato.
"""
from mathutils import Vector

HEAD_LIFT = 0.0  # quanto o medido (cabeça, pescoço, tronco, braços) sobe: 0 = nas alturas da referência

# pernas nas juntas medidas (allosaurus_ref.JOINTS: joelho, tornozelo e bola do pé; o quadril fica no encaixe, acima da
# borda medida da coxa), todas no mesmo x
LEG_X = 0.48
HIP_HEAD = Vector((0, 0.25, 1.93))  # meio do tronco medido no quadril
HIP_JOINT = Vector((LEG_X, 0.32, 1.95))
KNEE = Vector((LEG_X, 0.171, 1.145))
ANKLE = Vector((LEG_X, 0.542, 0.624))
BALL = Vector((LEG_X, 0.418, 0.16))
TOE_TIP = Vector((LEG_X, -0.11, 0.07))

# braço nas juntas medidas da referência (allosaurus_ref.JOINTS): preso no meio do peito
SHOULDER = Vector((0.345, -1.537, 1.906 + HEAD_LIFT))
ELBOW = Vector((0.522, -1.473, 1.495 + HEAD_LIFT))
WRIST = Vector((0.562, -1.625, 1.351 + HEAD_LIFT))
HAND_TIP = Vector((0.377, -2.100, 1.032 + HEAD_LIFT))

NECK_BASE = Vector((0, -1.45, 2.11 + HEAD_LIFT))  # coluna pelo meio do tronco medido
NECK_MID = Vector((0, -1.90, 2.62 + HEAD_LIFT))  # meio do pescoço medido (sobe do peito para a cabeça, em S)
NAPE = Vector((0, -2.30, 2.65 + HEAD_LIFT))  # nuca da cabeça medida (allosaurus_ref: anel de emenda)
JAW_HINGE = Vector((0, -2.554, 2.346 + HEAD_LIFT))  # junta da mandíbula da referência (a mesma em que a boca dela foi fechada)
MOUTH = Vector((0, -3.00, 2.45 + HEAD_LIFT))  # onde a presa fica na mordida (marcador "Mouth"): entre o céu da boca e a língua


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def side(v, s):
    return v.copy() if s == "L" else mirror(v)


# (nome, cabeça, cauda, pai, eixo do roll): mesma convenção de raptor_spec.bones()
def bones():
    out = [
        ("Hips", HIP_HEAD, Vector((0, -0.40, 1.97)), None, "up"),
        ("Spine", Vector((0, -0.40, 1.97)), Vector((0, -0.95, 2.08)), "Hips", "up"),
        ("Chest", Vector((0, -0.95, 2.08)), NECK_BASE, "Spine", "up"),
        ("Neck1", NECK_BASE, NECK_MID, "Chest", "up"),
        ("Neck2", NECK_MID, NAPE, "Neck1", "up"),
        ("Head", NAPE, Vector((0, -3.40, 2.55 + HEAD_LIFT)), "Neck2", "up"),
        ("Jaw", JAW_HINGE, Vector((0, -3.33, 2.30 + HEAD_LIFT)), "Head", "up"),
        ("Tail1", HIP_HEAD, Vector((0, 1.40, 1.80)), "Hips", "up"),  # cauda pelo meio dela medido
        ("Tail2", Vector((0, 1.40, 1.80)), Vector((0, 2.70, 1.85)), "Tail1", "up"),
        ("Tail3", Vector((0, 2.70, 1.85)), Vector((0, 4.00, 1.80)), "Tail2", "up"),
        ("Tail4", Vector((0, 4.00, 1.80)), Vector((0, 5.55, 1.36)), "Tail3", "up"),  # a ponta cai
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
