"""Animações das cenas do começo da fase e da sala dos clones (poses em keyframes, mesma convenção de heroine_anims).

HatchOpen: ajoelha na beira do alçapão do telhado, pega a tampa pela alça, levanta e empurra até ela ficar em pé
(o Godot gira a tampa entre HATCH_GRAB e HATCH_UP; ver game/scripts/hatch.gd).
Shocked: o "O QUE...?!" na frente dos tanques: recua um passo com as mãos para cima, cabeça para trás, olha de um
tanque para o outro e fica parada no fim (não é ciclo).
"""
import math

from mathutils import Vector

import heroine_ik as IK
import heroine_moves as M
import heroine_rifle as RF

HATCH_GRAB = 26  # mãos na alça: a tampa começa a subir
HATCH_UP = 50  # tampa em pé
HATCH_FRAMES = 66
HATCH_LET_GO = 38  # a tampa passou de ~45°: as mãos soltam a alça e empurram, ela termina de subir sozinha
HATCH_HANDS_FREE = 46  # daqui as mãos voltam à pose desenhada
SHOCK_FRAMES = 56

# Alça da tampa em relação à raiz dela ajoelhada (= game/scripts/hatch.gd): a dobradiça fica HOLE.y - LADDER_INSET +
# KNEEL_DIST à frente e CURB_H + LID_T/2 acima da laje; a alça, LID_T/2 + 0.03 acima da tampa e 0.08 antes da beira
# de quem chega (a tampa tem HOLE.y + CURB_T); barra de 0,36 m.
HINGE_FWD = 1.05 - 0.07 + 0.5
HINGE_UP = 0.12 + 0.03
HANDLE_BACK = 1.05 + 0.12 - 0.08
HANDLE_UP = 0.03 + 0.03
HANDLE_X = 0.12
LID_OPEN = 88.0  # = Hatch.OPEN_ANGLE; o Godot gira de HATCH_GRAB a HATCH_UP com tween seno entra-e-sai


def lid_angle(f):
    s = min(max((f - HATCH_GRAB) / (HATCH_UP - HATCH_GRAB), 0.0), 1.0)
    return math.radians(LID_OPEN) * (1.0 - math.cos(math.pi * s)) * 0.5


def handle_at(f, x):
    """Ponto da alça no quadro f (a tampa girando em volta da dobradiça), no espaço da raiz dela."""
    a = lid_angle(f)
    toward = HANDLE_BACK * math.cos(a) - HANDLE_UP * math.sin(a)
    up = HANDLE_UP * math.cos(a) + HANDLE_BACK * math.sin(a)
    return Vector((x, -(HINGE_FWD - toward), HINGE_UP + up))


def _smooth(a, b, f0, f1, f):
    s = min(max((f - f0) / (f1 - f0), 0.0), 1.0)
    return a.lerp(b, s * s * (3.0 - 2.0 * s))


def hatch_open_keys(A, sk):
    kneel_body = {"loc": (0, -0.47, 0), "Hips": (8, 0, 0), "Spine": (10, 0, 0), "Chest": (4, 0, 0), "Neck": (6, 0, 0),
                  "Head": (16, 0, 0)}
    kneel = A.merge(kneel_body, M.legs(80, -95, 10, 0, -95, -40), M.arms(30, -6, 40))
    kneel = RF._kneel_legs(sk, kneel)
    # curvada para a frente, as duas mãos na alça (beira da tampa, a ~20 cm do chão)
    reach = A.merge(kneel, {"Hips": (12, 0, 0), "Spine": (22, 0, 0), "Chest": (10, 0, 0), "Head": (2, 0, 0)},
                    M.arms(40, -4, 14))
    grip = A.merge(reach, {"Spine": (28, 0, 0), "Chest": (12, 0, 0), "Hand_L": (-14, 0, 0), "Hand_R": (-14, 0, 0)})
    # a tampa descola: o tronco já começa a endireitar e a cabeça sobe (não fica por cima da tampa subindo)
    pull = A.merge(kneel, {"Hips": (10, 0, 0), "Spine": (16, 0, 0), "Chest": (4, 0, 0), "Neck": (0, 0, 0),
                           "Head": (-16, 0, 0)}, M.arms(55, -4, 16))
    # puxa: o tronco ainda inclinado para a frente acompanhando a alça, os braços sobem trazendo a tampa
    lift = A.merge(kneel, {"Hips": (14, 0, 0), "Spine": (12, 0, 0), "Chest": (2, 0, 0), "Head": (-10, 0, 0)},
                   M.arms(75, -6, 20))
    # meio de pé, empurrando a tampa por cima da cabeça até ela ficar em pé
    push = A.merge({"loc": (0, -0.2, 0), "Spine": (-6, 0, 0), "Chest": (-6, 0, 0), "Head": (-10, 0, 0)},
                   M.legs(38, -62, 22, 8, -40, 26), M.arms(100, -10, 14))
    stand = A.merge(A.IDLE, {"Head": (8, 0, 0)})
    keys = [
        (0, A.IDLE),
        (12, kneel),
        (20, reach),
        (HATCH_GRAB, grip),
        (32, pull),
        (HATCH_LET_GO, lift),
        (HATCH_UP, push),
        (HATCH_FRAMES, stand),
    ]
    # as palmas vão até a alça (20-26), seguram nela enquanto a tampa gira (26-38) e voltam à pose desenhada (38-46)
    plants = []
    for s, x in (("L", HANDLE_X), ("R", -HANDLE_X)):
        start = IK.palm(sk, sk.matrices(reach), s)
        free = IK.palm(sk, sk.matrices(M.interp_pose(keys, HATCH_HANDS_FREE)), s)

        def target(f, s=s, x=x, start=start, free=free):
            if f <= HATCH_GRAB:
                return _smooth(start, handle_at(HATCH_GRAB, x), 20, HATCH_GRAB, f)
            if f <= HATCH_LET_GO:
                return handle_at(f, x)
            return _smooth(handle_at(HATCH_LET_GO, x), free, HATCH_LET_GO, HATCH_HANDS_FREE, f)

        plants.append(M.Plant("palm", s, 20, HATCH_HANDS_FREE, target=target))
    return M.bake(sk, "HatchOpen", keys, plants)


def shocked_keys(A):
    legs_back = {
        "UpperLeg_L": (10, 0, 5), "LowerLeg_L": (-18, 0, 0), "Foot_L": (6, 0, 0),
        "UpperLeg_R": (-16, 0, 6), "LowerLeg_R": (-10, 0, 0), "Foot_R": (10, 0, 0),
    }
    # mãos abertas na frente do peito, cotovelos dobrados, defensiva
    guard = {
        "UpperArm_L": (48, 0, 18), "LowerArm_L": (112, 0, 0), "Hand_L": (-30, 0, 0),
        "UpperArm_R": (44, 0, 20), "LowerArm_R": (108, 0, 0), "Hand_R": (-30, 0, 0),
    }
    flinch = A.merge(legs_back, guard, {"loc": (0, -0.05, 0), "Spine": (-10, 0, 0), "Chest": (-10, 0, 0),
                                        "Neck": (-6, 0, 0), "Head": (-16, 0, 0)})
    peak = A.merge(flinch, {"Spine": (-3, 0, 0), "Head": (-6, 0, 0), "UpperArm_L": (8, 0, 0), "UpperArm_R": (8, 0, 0)})
    look_l = A.merge(flinch, {"Head": (4, 22, 4), "Chest": (0, 6, 0), "UpperArm_L": (-14, 0, 0), "UpperArm_R": (-14, 0, 0),
                              "LowerArm_L": (-20, 0, 0), "LowerArm_R": (-20, 0, 0)})
    look_r = A.merge(flinch, {"Head": (4, -22, -4), "Chest": (0, -6, 0), "UpperArm_L": (-14, 0, 0), "UpperArm_R": (-14, 0, 0),
                              "LowerArm_L": (-20, 0, 0), "LowerArm_R": (-20, 0, 0)})
    # fica: um pouco curvada, mãos baixando, ainda olhando para cima (os tanques são altos)
    hold = A.merge(legs_back, {
        "loc": (0, -0.04, 0), "Spine": (-4, 0, 0), "Chest": (-4, 0, 0), "Head": (-14, 0, 0),
        "UpperArm_L": (24, 0, 10), "LowerArm_L": (70, 0, 0), "UpperArm_R": (22, 0, 12), "LowerArm_R": (64, 0, 0),
        "Hand_L": (-16, 0, 0), "Hand_R": (-16, 0, 0),
    })
    return [
        (0, A.IDLE),
        (5, flinch),
        (12, peak),
        (24, look_l),
        (36, look_r),
        (46, hold),
        (SHOCK_FRAMES, hold),
    ]
