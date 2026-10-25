"""Animações principais em keyframes (30 fps), estilo PS1: poucas chaves, interpolação suave.

Convenção dos ângulos (graus, euler ZYX local de cada osso):
  X > 0  dobra "para a frente" (coxa à frente, cotovelo dobrando, tronco curvando; no pé, ponta para cima).
         Joelho dobra com X < 0.
  Z > 0  afasta o membro do corpo (abdução); no tronco/cabeça inclina para a direita dela.
  Y > 0  gira o membro para dentro; no tronco/cabeça vira para a esquerda dela.
Os valores dos ossos _R são escritos com o mesmo significado do lado _L; a conversão de sinal é feita aqui.
"""
import math
import sys

import bpy

FPS = 30
CENTER = ("Hips", "Spine", "Chest", "Neck", "Head")
# ciclos (o Godot também toca em laço): curvas cíclicas, senão a suavização para no primeiro quadro e dá um tranco
LOOPS = ("Idle", "Walk", "Run", "AimIdle", "Crouch", "Dazed", "StrafeL", "StrafeR", "CrouchWalk", "CrouchStrafeL",
         "CrouchStrafeR", "Fall", "Hang", "RifleHold", "RifleAim", "LadderUp", "LadderDown", "LadderIdle")


def merge(*poses):
    out = {}
    for p in poses:
        for k, v in p.items():
            if k == "loc" or not isinstance(v, tuple):
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
    # o braço direito (o da pistola) igual ao esquerdo: solto ao lado do corpo, pistola apontada para baixo
    "UpperArm_L": (5, 0, -4), "LowerArm_L": (12, 0, 0),
    "UpperArm_R": (5, 0, -4), "LowerArm_R": (12, 0, 0), "Hand_R": (-10, 0, 0),
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


# Atordoada pelo rugido do alossauro: curvada, joelhos dobrados, mãos tapando os ouvidos, cambaleando de um lado
# para o outro (ciclo de 40 quadros).
DAZED = {
    "loc": (0, -0.10, 0),
    "UpperLeg_L": (22, 0, 6), "LowerLeg_L": (-40, 0, 0), "Foot_L": (18, 0, 0),
    "UpperLeg_R": (16, 0, 8), "LowerLeg_R": (-30, 0, 0), "Foot_R": (14, 0, 0),
    "Spine": (16, 0, 0), "Chest": (8, 0, 0), "Neck": (6, 0, 0), "Head": (14, 0, 0),
    "UpperArm_L": (62, 0, 44), "LowerArm_L": (132, 0, 0), "Hand_L": (-10, 0, 0),
    "UpperArm_R": (64, 0, 38), "LowerArm_R": (136, 0, 0), "Hand_R": (-20, 0, 0),
}


def dazed_keys():
    sway = lambda k: merge(DAZED, {"Spine": (0, 0, 4 * k), "Chest": (0, 0, 3 * k), "Head": (0, 10 * k, 4 * k)})
    return [(0, sway(1)), (20, sway(-1)), (40, sway(1))]


# Corrida de reação (Regina em Dino Crisis 2 / Syphon Filter): quase em pé, passadas curtas e rápidas, quique
# baixo, braços dobrados junto do corpo balançando pouco (a pistola na direita), quadril que gira, cai do lado da
# perna que balança e escorrega para cima do pé de apoio (o gingado).
RUN_STEP = 8  # quadros por passo (ciclo de 16 = 3,75 passos/s)
RUN_LEAN = 5  # quadril inclinado para a frente; as coxas compensam para os ângulos abaixo serem em relação ao chão
RUN_BODY = {
    "Spine": (6, 0, 0), "Chest": (3, 0, 0), "Neck": (-3, 0, 0), "Head": (-7, 0, 0),
    "Hand_R": (-20, 0, 0), "Hand_L": (-10, 0, 0),
}


GUARD_PITCH = 34  # pistola em guarda: cano inclinado para baixo (graus)
GUARD_WRIST = (0.03, 0.12, -0.13)  # pulso direito em relação ao da mira, no espaço do Blender: para dentro, para trás, para baixo


def pistol_guard(sk, body):
    """Guarda baixa com as duas mãos: a mesma pegada da mira (mão esquerda envolvendo a direita), com o cano
    inclinado GUARD_PITCH para baixo e o pulso mais perto do corpo. Resolvida por IK sobre o tronco de `body`
    (os braços acompanham o peito, então serve agachada ou em pé)."""
    import heroine_ik as IK
    from mathutils import Matrix, Vector

    aim_m = sk.matrices(AIM)
    hand = aim_m["Hand_R"]
    support = hand.inverted() @ IK.palm(sk, aim_m, "L")  # mão esquerda no referencial da direita
    # alvo no referencial do peito da mira; depois levado para o peito de `body`
    target = Matrix.Translation(hand.translation + Vector(GUARD_WRIST))         @ Matrix.Rotation(math.radians(GUARD_PITCH), 4, "X") @ hand.to_3x3().to_4x4()
    pose = merge(body, {k: v for k, v in AIM.items() if k.startswith(("UpperArm", "LowerArm", "Hand"))})
    target = sk.matrices(pose)["Chest"] @ aim_m["Chest"].inverted() @ target

    def res(m):
        h = m["Hand_R"]
        e = list(h.translation - target.translation)
        for i in (1, 2):
            e += list((h.col[i].to_3d() - target.col[i].to_3d()) * 0.3)
        return e

    pose, e1 = IK.solve(sk, pose, IK.arm_unknowns("R"), res, IK.arm_bounds("R"))
    grip = target @ support
    pose, e2 = IK.solve(sk, pose, IK.arm_unknowns("L", hand=False), lambda m: list(IK.palm(sk, m, "L") - grip),
                        IK.arm_bounds("L"))
    print(f"[guard] pistola em guarda: erro mão direita {e1 * 1000:.1f} mm, esquerda {e2 * 1000:.1f} mm")
    return {k: v for k, v in pose.items() if k.startswith(("UpperArm", "LowerArm", "Hand"))}


def run_key(loc, hips, spine, chest, head, leg_l, leg_r, arm_l, arm_r):
    """Uma pose da metade do ciclo com apoio na esquerda.
    hips/spine/chest/head: (giro Y, inclinação Z); leg: (coxa em relação ao chão, joelho, pé, abertura Z);
    arm: (ombro X, ombro Z, cotovelo)."""
    return merge(RUN_BODY, {
        "loc": loc,
        "Hips": (RUN_LEAN, hips[0], hips[1]),
        "Spine": (0, spine[0], spine[1]), "Chest": (0, chest[0], chest[1]),
        # pescoço solto: metade do giro e da inclinação da cabeça vai para ele (não gira só a cabeça, dura)
        "Neck": (RUN_BODY["Neck"][0], head[0] * 0.5, head[1] * 0.5), "Head": (0, head[0] * 0.5, head[1] * 0.5),
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
    (0, ((0.004, -0.034, 0), (-9, 1), (6, -1), (14, -1), (-10, 0), (27, -12, 5.5, 1.5), (-15, -65, -15, 4), (-20, 4, 58), (20, 3, 64))),
    (1, ((0.013, -0.042, 0), (-6.5, 3), (4, -2), (9, -1.5), (-6, 0), (25, -26, 1, -3), (-2.5, -80, -12.5, 4.5), (-13, 4, 59), (13, 3, 63))),
    (2, ((0.022, -0.069, 0), (-4, 5), (2, -3), (4, -2), (-2, 0), (23.5, -40, 17, -7.5), (10, -95, -10, 6), (-6, 4, 60), (6, 3, 62))),
    (3, ((0.024, -0.061, 0), (1, 4), (-1, -2), (-3, -2), (3, 0), (12.5, -38, 15, -6.5), (28, -95, -5, 1.5), (6, 4, 61), (-4, 3, 60))),
    (4, ((0.022, -0.029, 0), (4, 3), (-3, -2), (-7, -1), (6, 0), (-4, -24, -10.5, -4.5), (40, -88, 0, 0), (13, 4, 62), (-11, 3, 58))),
    (6, ((0.008, -0.03, 0), (7, 1), (-5, -1), (-12, -1), (9, 0), (-20, -50, -15, 3.5), (40, -45, 0, -0.5), (19, 4, 64), (-18, 3, 56))),
]


def run_keys():
    """Ciclo de 2 passos: a metade com apoio na esquerda e o espelho com a direita."""
    half = [(f, run_key(*k)) for f, k in RUN_HALF]
    keys = half + [(f + RUN_STEP, mirror(p)) for f, p in half]
    return keys + [(2 * RUN_STEP, half[0][1])]


HIT = merge(IDLE, {
    # o tronco vai para trás (-22°); os braços compensam para não "subirem" junto
    "Spine": (-8, 0, 0), "Chest": (-14, 4, 0), "Head": (-22, 0, 0),
    "UpperArm_L": (-14, 0, 14), "LowerArm_L": (8, 0, 0),
    "UpperArm_R": (-18, 0, 6),
})


def ladder_actions(sk):
    """Gera ciclos de subir (LadderUp), descer (LadderDown) e repouso (LadderIdle) na escada
    com as mãos segurando firmemente os degraus e os pés pisando exatamente no topo dos degraus horizontais."""
    import heroine_ik as IK
    from mathutils import Vector

    RUNG_Y = -0.22
    HAND_X = 0.17
    FOOT_X = 0.14

    def solve_ladder_pose(base_pose, hl_pos, hr_pos, fl_pos, fr_pos):
        pose = dict(base_pose)
        def solve_h(p, s, tgt):
            unk = IK.arm_unknowns(s, hand=True)
            def res(m):
                return list(IK.palm(sk, m, s) - tgt)
            return IK.solve(sk, p, unk, res, IK.arm_bounds(s))

        def solve_f(p, s, tgt):
            unk = IK.leg_unknowns(s)
            def res(m):
                pt = sk.point(m, f"Foot_{s}", 0.08)
                toe = sk.point(m, f"Foot_{s}", sk.length[f"Foot_{s}"])
                return list(pt - tgt) + [(toe.z - tgt.z) * 0.4]
            return IK.solve(sk, p, unk, res, IK.leg_bounds(s))

        pose, _ = solve_h(pose, "L", hl_pos)
        pose, _ = solve_h(pose, "R", hr_pos)
        pose, _ = solve_f(pose, "L", fl_pos)
        pose, _ = solve_f(pose, "R", fr_pos)
        return pose

    frames = 24
    half = 12
    up_keys = []
    down_keys = []

    for f in range(frames + 1):
        # 1. LadderUp: subindo os degraus (mãos seguram rungs a 1.65 e 1.35; pés pisam rungs a 0.47 e 0.17)
        if f <= half:
            t = f / float(half)
            s = t * t * (3.0 - 2.0 * t)
            hl_z = 1.65 - 0.30 * s
            hl_y = RUNG_Y
            fr_z = 0.47 - 0.30 * s
            fr_y = RUNG_Y

            hr_z = 1.35 + 0.30 * s
            hr_y = RUNG_Y + 0.07 * math.sin(math.pi * t)
            fl_z = 0.17 + 0.30 * s
            fl_y = RUNG_Y + 0.07 * math.sin(math.pi * t)
            sway_x = 0.015 * math.cos(math.pi * t)
        else:
            t = (f - half) / float(half)
            s = t * t * (3.0 - 2.0 * t)
            hr_z = 1.65 - 0.30 * s
            hr_y = RUNG_Y
            fl_z = 0.47 - 0.30 * s
            fl_y = RUNG_Y

            hl_z = 1.35 + 0.30 * s
            hl_y = RUNG_Y + 0.07 * math.sin(math.pi * t)
            fr_z = 0.17 + 0.30 * s
            fr_y = RUNG_Y
            sway_x = -0.015 * math.cos(math.pi * t)

        base_up = {
            "loc": (sway_x, 0, 0),
            "Hips": (3, 0, -sway_x * 100),
            "Spine": (5, 0, sway_x * 60),
            "Chest": (6, 0, sway_x * 40),
            "Neck": (12, 0, 0),
            "Head": (18, 0, 0),
            "UpperArm_L": (85, 0, -10), "LowerArm_L": (55, 0, 0), "Hand_L": (-25, 0, 0),
            "UpperArm_R": (85, 0, -10), "LowerArm_R": (55, 0, 0), "Hand_R": (-25, 0, 0),
            "UpperLeg_L": (35, 0, 4), "LowerLeg_L": (-50, 0, 0), "Foot_L": (15, 0, 0),
            "UpperLeg_R": (35, 0, 4), "LowerLeg_R": (-50, 0, 0), "Foot_R": (15, 0, 0),
        }
        hl = Vector((HAND_X, hl_y, hl_z))
        hr = Vector((-HAND_X, hr_y, hr_z))
        fl = Vector((FOOT_X, fl_y, fl_z))
        fr = Vector((-FOOT_X, fr_y, fr_z))
        up_keys.append((f, solve_ladder_pose(base_up, hl, hr, fl, fr)))

        # 2. LadderDown: descendo os degraus
        if f <= half:
            t = f / float(half)
            s = t * t * (3.0 - 2.0 * t)
            hr_z = 1.35 + 0.30 * s
            hr_y = RUNG_Y
            fl_z = 0.17 + 0.30 * s
            fl_y = RUNG_Y

            hl_z = 1.65 - 0.30 * s
            hl_y = RUNG_Y + 0.07 * math.sin(math.pi * t)
            fr_z = 0.47 - 0.30 * s
            fr_y = RUNG_Y + 0.07 * math.sin(math.pi * t)
            sway_x = -0.015 * math.cos(math.pi * t)
        else:
            t = (f - half) / float(half)
            s = t * t * (3.0 - 2.0 * t)
            hl_z = 1.35 + 0.30 * s
            hl_y = RUNG_Y
            fr_z = 0.17 + 0.30 * s
            fr_y = RUNG_Y

            hr_z = 1.65 - 0.30 * s
            hr_y = RUNG_Y + 0.07 * math.sin(math.pi * t)
            fl_z = 0.47 - 0.30 * s
            fl_y = RUNG_Y + 0.07 * math.sin(math.pi * t)
            sway_x = 0.015 * math.cos(math.pi * t)

        base_down = {
            "loc": (sway_x, 0, 0),
            "Hips": (3, 0, -sway_x * 100),
            "Spine": (5, 0, sway_x * 60),
            "Chest": (6, 0, sway_x * 40),
            "Neck": (12, 0, 0),
            "Head": (10, 0, 0),
            "UpperArm_L": (85, 0, -10), "LowerArm_L": (55, 0, 0), "Hand_L": (-25, 0, 0),
            "UpperArm_R": (85, 0, -10), "LowerArm_R": (55, 0, 0), "Hand_R": (-25, 0, 0),
            "UpperLeg_L": (35, 0, 4), "LowerLeg_L": (-50, 0, 0), "Foot_L": (15, 0, 0),
            "UpperLeg_R": (35, 0, 4), "LowerLeg_R": (-50, 0, 0), "Foot_R": (15, 0, 0),
        }
        hl = Vector((HAND_X, hl_y, hl_z))
        hr = Vector((-HAND_X, hr_y, hr_z))
        fl = Vector((FOOT_X, fl_y, fl_z))
        fr = Vector((-FOOT_X, fr_y, fr_z))
        down_keys.append((f, solve_ladder_pose(base_down, hl, hr, fl, fr)))

    # 3. LadderIdle: repouso estático firme nos degraus com respiração sutil
    base_idle = {
        "Hips": (3, 0, 0), "Spine": (5, 0, 0), "Chest": (6, 0, 0), "Neck": (12, 0, 0), "Head": (18, 0, 0),
        "UpperArm_L": (85, 0, -10), "LowerArm_L": (55, 0, 0), "Hand_L": (-25, 0, 0),
        "UpperArm_R": (85, 0, -10), "LowerArm_R": (55, 0, 0), "Hand_R": (-25, 0, 0),
        "UpperLeg_L": (35, 0, 4), "LowerLeg_L": (-50, 0, 0), "Foot_L": (15, 0, 0),
        "UpperLeg_R": (35, 0, 4), "LowerLeg_R": (-50, 0, 0), "Foot_R": (15, 0, 0),
    }
    hl = Vector((HAND_X, RUNG_Y, 1.65))
    hr = Vector((-HAND_X, RUNG_Y, 1.35))
    fl = Vector((FOOT_X, RUNG_Y, 0.17))
    fr = Vector((-FOOT_X, RUNG_Y, 0.47))
    pose_idle_a = solve_ladder_pose(base_idle, hl, hr, fl, fr)
    base_idle_b = dict(base_idle, Chest=(8, 0, 0), Spine=(6, 0, 0))
    pose_idle_b = solve_ladder_pose(base_idle_b, hl, hr, fl, fr)
    idle_keys = [(0, pose_idle_a), (30, pose_idle_b), (60, pose_idle_a)]

    return up_keys, down_keys, idle_keys


def actions(sk):
    """nome -> lista de (frame, pose). Caminhadas, cambalhota, escalada e fuzil saem por IK (sk = esqueleto)."""
    import heroine_cutscene as CS
    import heroine_drop as DR
    import heroine_gait as G
    import heroine_hurt as HU
    import heroine_moves as M
    import heroine_m79 as GL
    import heroine_rifle as RF
    import heroine_shotgun as SG
    import heroine_strike as ST

    idle_breath = merge(IDLE, {"Chest": (-1.5, 0, 0), "Head": (2, 4, 0), "loc": (0, -0.004, 0)})
    aim_sway = merge(AIM, {"Chest": (0, 1.5, 0), "UpperArm_R": (1, 0, 0), "UpperArm_L": (1, 0, 0)})
    recoil = merge(AIM, {"UpperArm_R": (9, 0, 0), "UpperArm_L": (8, 0, 0), "LowerArm_R": (8, 0, 0), "Chest": (-3, 0, 0)})
    # agachada com a pistola em guarda nas duas mãos (com arma longa, a parte de cima vem do RifleHold)
    crouch = dict(CROUCH, **pistol_guard(sk, CROUCH))
    crouch_breath = merge(crouch, {"Spine": (2, 0, 0), "loc": (0, -0.36, 0)})
    death_fall = merge(HIT, {
        "loc": (0, -0.12, 0), "Spine": (-10, 0, 0), "Head": (-8, 0, 0),
        "UpperLeg_L": (20, 0, 0), "LowerLeg_L": (-35, 0, 0), "UpperLeg_R": (20, 0, 0), "LowerLeg_R": (-35, 0, 0),
    })
    A = sys.modules[__name__]
    g = M.gaits(A, pistol_guard(sk, M.crouch_walk_body(A)))
    strafe = G.solve_cycle(sk, g["strafe"], "StrafeL")
    crouch_strafe = G.solve_cycle(sk, g["crouch_strafe"], "CrouchStrafeL")
    hold, rifle_aim, rifle_recoil = RF.rifle_poses(A, sk)
    hold_breath = merge(hold, {"Chest": (-1, 0, 0)})
    dodge_l = M.dodge_side_keys(A, sk)
    ladder_up_keys, ladder_down_keys, ladder_idle_keys = ladder_actions(sk)
    # sair pelo topo: beirada do alçapão (rebordo) ou do mezanino (piso); entrar = o mesmo ao contrário
    ladder_out = M.ladder_out_keys(A, sk, ladder_idle_keys[0][1], M.LADDER_LIP)
    ladder_out_low = M.ladder_out_keys(A, sk, ladder_idle_keys[0][1], 0.0, "LadderOutLow")
    return {
        "Idle": [(0, IDLE), (30, idle_breath), (60, IDLE)],
        "Walk": G.solve_cycle(sk, g["walk"], "Walk"),
        "Run": run_keys(),
        "AimIdle": [(0, AIM), (30, aim_sway), (60, AIM)],
        "Shoot": [(0, AIM), (2, recoil), (9, AIM)],
        "StrafeL": strafe,
        "StrafeR": G.mirror_lateral(strafe),
        "Crouch": [(0, crouch), (30, crouch_breath), (60, crouch)],
        "CrouchWalk": G.solve_cycle(sk, g["crouch_walk"], "CrouchWalk"),
        "CrouchStrafeL": crouch_strafe,
        "CrouchStrafeR": G.mirror_lateral(crouch_strafe),
        "Roll": M.roll_keys(A, sk),
        "DodgeL": dodge_l,
        "DodgeR": [(f, mirror(p)) for f, p in dodge_l],
        "DodgeBack": M.dodge_back_keys(A, sk),
        "Jump": M.jump_keys(A),
        "Fall": M.fall_keys(A),
        "Hang": M.hang_keys(A, sk),
        "LadderUp": ladder_up_keys,
        "LadderDown": ladder_down_keys,
        "LadderIdle": ladder_idle_keys,
        "LadderOut": ladder_out,
        "LadderIn": M.reverse(ladder_out),
        "LadderOutLow": ladder_out_low,
        "LadderInLow": M.reverse(ladder_out_low),
        "ClimbUp": M.climb_keys(A, sk),
        "Mantle": M.mantle_keys(A, sk),
        "RifleHold": [(0, hold), (30, hold_breath), (60, hold)],
        "RifleAim": [(0, rifle_aim), (60, rifle_aim)],
        "RifleShoot": [(0, rifle_aim), (2, rifle_recoil), (4, rifle_aim)],
        "ShotgunShoot": SG.shoot_keys(A, sk, rifle_aim),
        "M79Shoot": GL.shoot_keys(A, sk, rifle_aim),
        "Pickup": RF.pickup_keys(A, sk, hold),
        "PickupPistol": DR.pickup_keys(A, sk),
        "Assassinate": ST.assassinate_keys(A, sk),
        "CritStrike": ST.crit_strike_keys(A, sk),
        "Hit": [(0, IDLE), (3, HIT), (14, IDLE)],
        **HU.hit_keys(A),
        "StaggerBack": HU.stagger_back_keys(A, sk),
        "StaggerFwd": HU.stagger_fwd_keys(A, sk),
        "GetUpFront": HU.getup_front_keys(A, sk),
        "GetUpBack": HU.getup_back_keys(A, sk),
        "Dazed": dazed_keys(),
        "HatchOpen": CS.hatch_open_keys(A, sk),
        "Shocked": CS.shocked_keys(A),
        "Death": [(0, IDLE), (4, HIT), (14, death_fall), (20, death_fall)],
    }


def mirror_aim(pose):
    """Espelha só as pernas e o quadril: os braços continuam segurando a arma com a direita."""
    m = mirror(pose)
    for k in list(m):
        if k.startswith(("UpperArm", "LowerArm", "Hand")) or k in ("Chest", "Head", "Neck", "Spine"):
            m[k] = pose.get(k, (0, 0, 0))
    return m


# Os deslocamentos do quadril ("loc") das poses foram desenhados para a perna de 0,834 m (quadril ao tornozelo); com
# outro corpo (a heroína com o modelo base, art/heroine_body.py) o build põe aqui a razão entre as pernas, então agachar, ajoelhar e
# rolar continuam com os pés no chão.
LOC_SCALE = 1.0
LEG_DESIGN = 0.834


def leg_scale(hip_z, ankle_z):
    return (hip_z - ankle_z) / LEG_DESIGN


def apply_pose(rig, pose):
    for pb in rig.pose.bones:
        x, y, z = pose.get(pb.name, (0, 0, 0))
        if pb.name.endswith("_R"):
            y, z = -y, -z
        pb.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))
        pb.location = (0, 0, 0)
    loc = pose.get("loc", (0, 0, 0))
    rig.pose.bones["Hips"].location = tuple(c * LOC_SCALE for c in loc)


def make_cyclic(act):
    """Modificador Cycles em cada curva: as alças automáticas passam a enxergar o ciclo fechado."""
    fcurves = act.fcurves if hasattr(act, "fcurves") else act.layers[0].strips[0].channelbags[0].fcurves
    for fc in fcurves:
        fc.modifiers.new("CYCLES")
        fc.update()


def build_actions(rig):
    import heroine_ik

    rig.animation_data_create()
    made = []
    for name, keys in actions(heroine_ik.Skeleton(rig)).items():
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
