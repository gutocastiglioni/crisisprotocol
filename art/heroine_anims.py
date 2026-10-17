"""Animações principais em keyframes (30 fps), estilo PS1: poucas chaves, interpolação suave.

Convenção dos ângulos (graus, euler ZYX local de cada osso):
  X > 0  dobra "para a frente" (coxa à frente, cotovelo dobrando, tronco curvando; no pé, ponta para cima).
         Joelho dobra com X < 0.
  Z > 0  afasta o membro do corpo (abdução); no tronco/cabeça inclina para a direita dela.
  Y > 0  gira o membro para dentro; no tronco/cabeça vira para a esquerda dela.
Os valores dos ossos _R são escritos com o mesmo significado do lado _L; a conversão de sinal é feita aqui.
"""
import math

import bpy

FPS = 30
CENTER = ("Hips", "Spine", "Chest", "Neck", "Head")
# ciclos (o Godot também toca em laço): curvas cíclicas, senão a suavização para no primeiro quadro e dá um tranco
LOOPS = ("Idle", "Walk", "Run", "AimIdle", "Crouch", "StrafeL", "StrafeR")


def merge(*poses):
    out = {}
    for p in poses:
        for k, v in p.items():
            if k == "loc":
                out[k] = v
            else:
                base = out.get(k, (0, 0, 0))
                out[k] = tuple(a + b for a, b in zip(base, v))
    return out


def mirror(pose):
    """Troca esquerda e direita (para gerar a outra metade de um ciclo)."""
    out = {}
    for k, v in pose.items():
        if k == "loc":
            out[k] = (-v[0], v[1], v[2])
        elif k.endswith("_L"):
            out[k[:-2] + "_R"] = v
        elif k.endswith("_R"):
            out[k[:-2] + "_L"] = v
        else:
            out[k] = (v[0], -v[1], -v[2])
    return out


# ------------------------------------------------------------------ poses base
IDLE = {
    "UpperArm_L": (5, 0, -4), "LowerArm_L": (12, 0, 0),
    "UpperArm_R": (14, 0, -2), "LowerArm_R": (28, 0, 0), "Hand_R": (-10, 0, 0),
    "UpperLeg_L": (0, 0, 3), "UpperLeg_R": (0, 0, 3),
}

# empunhadura com as duas mãos: pulso direito à frente do peito, cano reto para a frente, mão esquerda
# envolvendo a direita por baixo (ângulos achados por IK numérico no esqueleto)
AIM = {
    "UpperArm_R": (79.5, -4.5, -17), "LowerArm_R": (19.5, -5, 0), "Hand_R": (-7.5, 0.5, 16.5),
    "UpperArm_L": (67.5, 2, -20.5), "LowerArm_L": (42, 6.5, 0), "Hand_L": (-18, -1.5, -15.5),
    "Head": (6, 0, 0),
    "UpperLeg_L": (12, 0, 4), "LowerLeg_L": (-12, 0, 0),
    "UpperLeg_R": (-6, 0, 6), "LowerLeg_R": (-8, 0, 0), "Foot_R": (6, 0, 0),
}

CROUCH = {
    "loc": (0, -0.355, 0),
    "UpperLeg_L": (70, 0, 8), "LowerLeg_L": (-110, 0, 0), "Foot_L": (40, 0, 0),
    "UpperLeg_R": (70, 0, 8), "LowerLeg_R": (-110, 0, 0), "Foot_R": (40, 0, 0),
    "Spine": (18, 0, 0), "Chest": (5, 0, 0), "Head": (-18, 0, 0),
    "UpperArm_R": (35, 0, -8), "LowerArm_R": (40, 0, 0),
    "UpperArm_L": (30, 0, -10), "LowerArm_L": (50, 0, 0),
}


def walk_contact():
    """Pé esquerdo tocando o chão na frente."""
    return merge(IDLE, {
        "loc": (0, -0.025, 0),
        "Hips": (0, -5, 0), "Chest": (0, 8, 0),
        "UpperLeg_L": (25, 0, 0), "LowerLeg_L": (-5, 0, 0), "Foot_L": (12, 0, 0),
        "UpperLeg_R": (-18, 0, 0), "LowerLeg_R": (-22, 0, 0), "Foot_R": (-18, 0, 0),
        "UpperArm_L": (-15, 0, 0), "LowerArm_L": (5, 0, 0),
        "UpperArm_R": (6, 0, 0),
    })


def walk_pass():
    """Apoio na esquerda, direita passando por baixo do corpo."""
    return merge(IDLE, {
        "loc": (0, 0.012, 0),
        "UpperLeg_L": (2, 0, 0), "LowerLeg_L": (-6, 0, 0),
        "UpperLeg_R": (12, 0, 0), "LowerLeg_R": (-50, 0, 0), "Foot_R": (10, 0, 0),
    })


# Corrida de reação (Regina em Dino Crisis 2 / Syphon Filter): quase em pé, passadas curtas e rápidas, quique
# baixo, braços dobrados junto do corpo balançando pouco (a pistola na direita), quadril que gira, cai do lado da
# perna que balança e escorrega para cima do pé de apoio (o gingado).
RUN_STEP = 8  # quadros por passo (ciclo de 16 = 3,75 passos/s)
RUN_LEAN = 5  # quadril inclinado para a frente; as coxas compensam para os ângulos abaixo serem em relação ao chão
RUN_BODY = {
    "Spine": (6, 0, 0), "Chest": (3, 0, 0), "Neck": (-3, 0, 0), "Head": (-7, 0, 0),
    "Hand_R": (-20, 0, 0), "Hand_L": (-10, 0, 0),
}


def run_key(loc, hips, spine, chest, head, leg_l, leg_r, arm_l, arm_r):
    """Uma pose da metade do ciclo com apoio na esquerda.
    hips/spine/chest/head: (giro Y, inclinação Z); leg: (coxa em relação ao chão, joelho, pé, abertura Z);
    arm: (ombro X, ombro Z, cotovelo)."""
    return merge(RUN_BODY, {
        "loc": loc,
        "Hips": (RUN_LEAN, hips[0], hips[1]),
        "Spine": (0, spine[0], spine[1]), "Chest": (0, chest[0], chest[1]), "Head": (0, head[0], head[1]),
        "UpperLeg_L": (leg_l[0] + RUN_LEAN, 0, leg_l[3]), "LowerLeg_L": (leg_l[1], 0, 0), "Foot_L": (leg_l[2], 0, 0),
        "UpperLeg_R": (leg_r[0] + RUN_LEAN, 0, leg_r[3]), "LowerLeg_R": (leg_r[1], 0, 0), "Foot_R": (leg_r[2], 0, 0),
        # o braço que vai à frente cruza um pouco o corpo (gira para dentro)
        "UpperArm_L": (arm_l[0], max(arm_l[0], 0) * 0.2, arm_l[1]), "LowerArm_L": (arm_l[2], 0, 0),
        "UpperArm_R": (arm_r[0], max(arm_r[0], 0) * 0.2, arm_r[1]), "LowerArm_R": (arm_r[2], 0, 0),
    })


# Metade do ciclo (apoio na esquerda): contato (0), amortece (2), calcanhar sobe (3), sai do chão (4), voo (6). Por quadro:
#   (loc, quadril, coluna, peito, cabeça, perna esquerda, perna direita, braço esquerdo, braço direito)
# As pernas e a altura do quadril saem de art/solve_run.py (rodar de novo ao mudar o resto da pose): deixam o pé
# de apoio parado no chão, na linha dele (sem deslizar de lado, mesmo com o gingado) e indo para trás na
# velocidade da corrida do jogo (Player.RUN_SPEED = 4,4 m/s; 2 * RUN_STEP quadros = 2 passos).
RUN_HALF = [
    (0, ((0.004, -0.04, 0), (-9, 1), (6, -1), (14, -1), (-10, 0), (27, -12, 0, 1), (-15, -65, -15, 2), (-14, 4, 82), (14, 3, 92))),
    (1, ((0.013, -0.044, 0), (-6.5, 3), (4, -2), (9, -1.5), (-6, 0), (24, -26, 1.5, -4), (-2.5, -80, -12.5, 2), (-9, 4, 83.5), (9, 3, 90.5))),
    (2, ((0.022, -0.072, 0), (-4, 5), (2, -3), (4, -2), (-2, 0), (21.5, -40, 18.5, -9), (10, -95, -10, 2.5), (-4, 4, 85), (4, 3, 89))),
    (3, ((0.024, -0.066, 0), (1, 4), (-1, -2), (-3, -2), (3, 0), (9.5, -38, 22.5, -8), (28, -95, -5, -2), (4, 4, 86), (-3, 3, 86))),
    (4, ((0.022, -0.04, 0), (4, 3), (-3, -2), (-7, -1), (6, 0), (-8.5, -24, 11.5, -5), (40, -88, 0, -3), (9, 4, 88), (-8, 3, 85))),
    (6, ((0.008, -0.03, 0), (7, 1), (-5, -1), (-12, -1), (9, 0), (-20, -50, -15, 2), (40, -45, 0, -1.5), (13, 4, 90), (-13, 3, 83))),
]


def run_keys():
    """Ciclo de 2 passos: a metade com apoio na esquerda e o espelho com a direita."""
    half = [(f, run_key(*k)) for f, k in RUN_HALF]
    keys = half + [(f + RUN_STEP, mirror(p)) for f, p in half]
    return keys + [(2 * RUN_STEP, half[0][1])]


def strafe_keys():
    """Passo lateral para a esquerda: abre a perna esquerda, a direita acompanha."""
    together = merge(AIM, {"UpperLeg_L": (-12, 0, -2), "LowerLeg_L": (12, 0, 0),
                           "UpperLeg_R": (6, 0, -4), "LowerLeg_R": (8, 0, 0), "Foot_R": (-6, 0, 0)})
    left_out = merge(together, {"loc": (0, 0.01, 0), "UpperLeg_L": (10, 0, 20), "LowerLeg_L": (-25, 0, 0)})
    wide = merge(together, {"loc": (0, -0.02, 0), "UpperLeg_L": (0, 0, 14), "UpperLeg_R": (0, 0, 12)})
    right_in = merge(together, {"loc": (0, 0.01, 0), "UpperLeg_L": (0, 0, 6),
                                "UpperLeg_R": (10, 0, 2), "LowerLeg_R": (-25, 0, 0)})
    return [(0, together), (6, left_out), (12, wide), (18, right_in), (24, together)]


def roll_keys():
    """Rolamento de combate para a frente, no lugar (o Godot move o corpo)."""
    tuck = {
        "UpperArm_L": (40, 0, -10), "LowerArm_L": (90, 0, 0),
        "UpperArm_R": (40, 0, -10), "LowerArm_R": (90, 0, 0),
    }
    legs = lambda thigh, shin, foot: {
        "UpperLeg_L": (thigh, 0, 4), "LowerLeg_L": (shin, 0, 0), "Foot_L": (foot, 0, 0),
        "UpperLeg_R": (thigh, 0, 4), "LowerLeg_R": (shin, 0, 0), "Foot_R": (foot, 0, 0),
    }
    return [
        (0, merge(IDLE, {"loc": (0, -0.05, 0)})),
        (4, merge(tuck, legs(50, -70, 20), {"loc": (0, -0.22, 0), "Hips": (25, 0, 0), "Spine": (25, 0, 0), "Head": (25, 0, 0)})),
        (8, merge(tuck, legs(100, -130, 30), {"loc": (0, -0.40, 0), "Hips": (90, 0, 0), "Spine": (40, 0, 0), "Chest": (20, 0, 0), "Head": (40, 0, 0)})),
        (12, merge(tuck, legs(105, -135, 30), {"loc": (0, -0.29, 0), "Hips": (180, 0, 0), "Spine": (40, 0, 0), "Chest": (20, 0, 0), "Head": (40, 0, 0)})),
        (16, merge(tuck, legs(100, -130, 30), {"loc": (0, -0.40, 0), "Hips": (270, 0, 0), "Spine": (40, 0, 0), "Chest": (20, 0, 0), "Head": (35, 0, 0)})),
        (21, merge(tuck, legs(70, -110, 40), {"loc": (0, -0.36, 0), "Hips": (350, 0, 0), "Spine": (25, 0, 0), "Head": (0, 0, 0)})),
        (27, merge(IDLE, {"loc": (0, -0.04, 0), "Hips": (360, 0, 0), "Spine": (5, 0, 0),
                          "UpperLeg_L": (15, 0, 0), "LowerLeg_L": (-20, 0, 0),
                          "UpperLeg_R": (15, 0, 0), "LowerLeg_R": (-20, 0, 0)})),
    ]


HIT = merge(IDLE, {
    # o tronco vai para trás (-22°); os braços compensam para não "subirem" junto
    "Spine": (-8, 0, 0), "Chest": (-14, 4, 0), "Head": (-22, 0, 0),
    "UpperArm_L": (-14, 0, 14), "LowerArm_L": (8, 0, 0),
    "UpperArm_R": (-18, 0, 6),
})


def actions():
    """nome -> lista de (frame, pose)."""
    idle_breath = merge(IDLE, {"Chest": (-1.5, 0, 0), "Head": (2, 4, 0), "loc": (0, -0.004, 0)})
    aim_sway = merge(AIM, {"Chest": (0, 1.5, 0), "UpperArm_R": (1, 0, 0), "UpperArm_L": (1, 0, 0)})
    recoil = merge(AIM, {"UpperArm_R": (9, 0, 0), "UpperArm_L": (8, 0, 0), "LowerArm_R": (8, 0, 0), "Chest": (-3, 0, 0)})
    crouch_breath = merge(CROUCH, {"Spine": (2, 0, 0), "loc": (0, -0.36, 0)})
    death_fall = merge(HIT, {
        "loc": (0, -0.12, 0), "Spine": (-10, 0, 0), "Head": (-8, 0, 0),
        "UpperLeg_L": (20, 0, 0), "LowerLeg_L": (-35, 0, 0), "UpperLeg_R": (20, 0, 0), "LowerLeg_R": (-35, 0, 0),
    })
    strafe = strafe_keys()
    return {
        "Idle": [(0, IDLE), (30, idle_breath), (60, IDLE)],
        "Walk": [(0, walk_contact()), (8, walk_pass()), (16, mirror(walk_contact())), (24, mirror(walk_pass())), (32, walk_contact())],
        "Run": run_keys(),
        "AimIdle": [(0, AIM), (30, aim_sway), (60, AIM)],
        "Shoot": [(0, AIM), (2, recoil), (9, AIM)],
        "StrafeL": strafe,
        "StrafeR": [(f, mirror_aim(p)) for f, p in strafe],
        "Crouch": [(0, CROUCH), (30, crouch_breath), (60, CROUCH)],
        "Roll": roll_keys(),
        "Hit": [(0, IDLE), (3, HIT), (14, IDLE)],
        "Death": [(0, IDLE), (4, HIT), (14, death_fall), (20, death_fall)],
    }


def mirror_aim(pose):
    """Espelha só as pernas e o quadril: os braços continuam segurando a arma com a direita."""
    m = mirror(pose)
    for k in list(m):
        if k.startswith(("UpperArm", "LowerArm", "Hand")) or k in ("Chest", "Head", "Neck", "Spine"):
            m[k] = pose.get(k, (0, 0, 0))
    return m


def apply_pose(rig, pose):
    for pb in rig.pose.bones:
        x, y, z = pose.get(pb.name, (0, 0, 0))
        if pb.name.endswith("_R"):
            y, z = -y, -z
        pb.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))
        pb.location = (0, 0, 0)
    loc = pose.get("loc", (0, 0, 0))
    rig.pose.bones["Hips"].location = loc


def make_cyclic(act):
    """Modificador Cycles em cada curva: as alças automáticas passam a enxergar o ciclo fechado."""
    fcurves = act.fcurves if hasattr(act, "fcurves") else act.layers[0].strips[0].channelbags[0].fcurves
    for fc in fcurves:
        fc.modifiers.new("CYCLES")
        fc.update()


def build_actions(rig):
    rig.animation_data_create()
    made = []
    for name, keys in actions().items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        for frame, pose in keys:
            apply_pose(rig, pose)
            for pb in rig.pose.bones:
                pb.keyframe_insert("rotation_euler", frame=frame)
            rig.pose.bones["Hips"].keyframe_insert("location", frame=frame)
        act.use_frame_range = True
        act.frame_range = (keys[0][0], keys[-1][0])
        if name in LOOPS:
            make_cyclic(act)
        made.append(act)
    rig.animation_data.action = None
    apply_pose(rig, {})
    return made
