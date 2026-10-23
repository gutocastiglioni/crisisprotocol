"""Sniper: fuzil de precisão com luneta telescópica (caixas, ~108 triângulos no atlas).

O fuzil é rígido na mão direita (Hand_R). Referencial idêntico ao M16 (heroine_rifle.py):
origem no centro do punho no cabo, `fwd` = cano, `up` = eixo da luneta para cima.
Possui luneta telescópica com campânula frontal e traseira, cano longo de precisão,
freio de boca/quebra-chamas tático, carregador destacável e coronha tática.
"""
import math

from mathutils import Matrix, Vector

import heroine_mesh as HM

PARTS = [
    # 1. receptor superior e ferrolho
    ((0, 0.05, 0.075), (0.016, 0.125, 0.032), 0),
    # 2. cano longo pesado de precisão
    ((0, 0.45, 0.075), (0.010, 0.20, 0.010), 0),
    # 3. freio de boca / quebra-chamas tático
    ((0, 0.67, 0.075), (0.014, 0.03, 0.014), 0),
    # 4. luneta telescópica: tubo central e montagem
    ((0, 0.06, 0.138), (0.012, 0.12, 0.012), 0),
    # 5. luneta: campânula frontal da objetiva (lente larga)
    ((0, 0.19, 0.138), (0.018, 0.025, 0.018), 0),
    # 6. luneta: campânula traseira da ocular (olho)
    ((0, -0.07, 0.138), (0.016, 0.02, 0.016), 0),
    # 7. cabo ergonômico
    ((0, -0.01, -0.012), (0.013, 0.02, 0.05), 20),
    # 8. carregador destacável de precisão
    ((0, 0.07, -0.04), (0.012, 0.03, 0.05), -5),
    # 9. coronha de precisão com apoio de bochecha e soleira
    ((0, -0.20, 0.065), (0.018, 0.12, 0.045), 0),
]

MUZZLE = (0, 0.70, 0.075)
HANDGUARD_GRIP = (0, 0.22, 0.03)
LENGTH = 1.05


def frame_matrix(origin, fwd, up):
    """Matriz cujas colunas são (lado, frente, cima, origem)."""
    fwd = Vector(fwd).normalized()
    side = fwd.cross(Vector(up)).normalized()
    up = side.cross(fwd).normalized()
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2], m[i][3] = side[i], fwd[i], up[i], origin[i]
    return m


def grip_rest():
    """Referencial do fuzil sniper na mão direita em repouso."""
    w, t, _, u = HM.pistol_frame()
    return frame_matrix(w + t * 0.05 - u * 0.005, t, u)


def build_sniper(mb, frame, weights):
    """Caixas do sniper no referencial `frame`."""
    side, fwd, up = (frame.col[i].to_3d() for i in range(3))
    for c, half, tilt in PARTS:
        rot = Matrix.Rotation(math.radians(tilt), 3, side)
        center = frame @ Vector(c)
        mb.box(center, side, rot @ fwd, half, "rifle", weights)


def muzzle_position():
    """Posição do cano no referencial do corpo."""
    return grip_rest() @ Vector(MUZZLE)
