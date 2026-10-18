"""Escopeta de bombeamento (estilo Remington 870 com cabo de pistola): malha em caixas (~170 triângulos; metal
no retângulo "shotgun" e madeira em "shotgun_wood" do atlas) e a animação de tiro com recuo forte e o bombeamento.

Usa o mesmo referencial do M16 (heroine_rifle): origem no punho fechado no cabo, `fwd` = cano, `up` = em cima.
Os pontos de apoio coincidem com os do fuzil (cabo na origem, soleira em frente -0,355 / cima 0,055, mão esquerda
em HANDGUARD_GRIP por baixo da telha), então as poses RifleHold/RifleAim e a animação Pickup servem para as duas
armas, e no baú ela fica no mesmo RIFLE_CHEST.

A telha (pump) é uma malha à parte presa ao osso Hand_R (o Godot importa como BoneAttachment3D): no tiro o Godot a
desliza para trás e para a frente seguindo PUMP_KEYS, o mesmo caminho que a mão esquerda faz na animação.
"""
import math

from mathutils import Matrix, Vector

import heroine_rifle as RF

# (centro (lado, frente, cima), meias-medidas (lado, frente, cima), inclinação em graus, retângulo)
PARTS = [
    ((0, 0.02, 0.09), (0.017, 0.07, 0.038), 0, "shotgun"),  # caixa da culatra (a telha recua até a frente dela)
    ((0, 0.03, 0.035), (0.014, 0.05, 0.018), 0, "shotgun"),  # armação do gatilho
    ((0, 0.37, 0.112), (0.011, 0.28, 0.011), 0, "shotgun"),  # cano
    ((0, 0.31, 0.072), (0.011, 0.22, 0.011), 0, "shotgun"),  # tubo do carregador (sob o cano)
    ((0, 0.535, 0.072), (0.013, 0.012, 0.013), 0, "shotgun"),  # tampa do tubo
    ((0, 0.50, 0.093), (0.008, 0.008, 0.03), 0, "shotgun"),  # braçadeira cano/tubo
    ((0, 0.643, 0.127), (0.004, 0.004, 0.005), 0, "shotgun"),  # massa de mira (conta)
    ((0, -0.01, -0.012), (0.013, 0.02, 0.05), 20, "shotgun_wood"),  # cabo de pistola
    ((0, 0.03, -0.002), (0.006, 0.03, 0.004), 0, "shotgun"),  # guarda-mato
    ((0, -0.15, 0.075), (0.017, 0.10, 0.03), 0, "shotgun_wood"),  # coronha (frente)
    ((0, -0.30, 0.058), (0.019, 0.055, 0.052), 0, "shotgun_wood"),  # coronha (soleira)
]
PUMP_CENTER = (0, 0.25, 0.072)  # a mão esquerda (HANDGUARD_GRIP, frente 0,21) fica na metade de trás
PUMP_PARTS = [
    ((0, 0, 0), (0.024, 0.075, 0.022), 0, "shotgun_wood"),  # telha de madeira em volta do tubo
    ((0, 0.077, 0), (0.016, 0.004, 0.016), 0, "shotgun"),  # anel da frente
]
MUZZLE = (0, 0.655, 0.112)

FRAMES = 20  # duração do ShotgunShoot (30 fps): cadência da escopeta no jogo
STROKE = 0.085  # curso da telha (m)
# (quadro, recuo da telha para trás em metros): dispara, assenta e bombeia (vai e volta)
PUMP_KEYS = [(0, 0.0), (7, 0.0), (10, STROKE), (12, STROKE), (15, 0.0), (FRAMES, 0.0)]
# (quadro, recuo do corpo da arma em metros, cano subindo em graus)
KICK_KEYS = [(0, 0.0, 0.0), (2, 0.055, 9.0), (6, 0.012, 2.0), (9, 0.0, 0.0), (FRAMES, 0.0, 0.0)]


def _boxes(mb, frame, parts, weights):
    side, fwd, up = (frame.col[i].to_3d() for i in range(3))
    for c, half, tilt, rect in parts:
        rot = Matrix.Rotation(math.radians(tilt), 3, side)
        mb.box(frame @ Vector(c), side, rot @ fwd, half, rect, weights)


def build_shotgun(mb, frame, weights, pump=True):
    """Caixas da escopeta no referencial `frame` (matriz de RF.frame_matrix); `pump` = com a telha."""
    _boxes(mb, frame, PARTS, weights)
    if pump:
        build_pump(mb, frame @ Matrix.Translation(PUMP_CENTER), weights)


def build_pump(mb, frame, weights):
    """Telha em volta de `frame` (origem = centro da telha, mesmos eixos da arma)."""
    _boxes(mb, frame, PUMP_PARTS, weights)


def muzzle_position():
    return RF.grip_rest() @ Vector(MUZZLE)


def pump_rest():
    """Referencial da telha na mão direita em repouso (origem no centro dela)."""
    return RF.grip_rest() @ Matrix.Translation(PUMP_CENTER)


def _at(keys, f, i):
    for k0, k1 in zip(keys, keys[1:]):
        if k0[0] <= f <= k1[0]:
            t = (f - k0[0]) / (k1[0] - k0[0])
            t = t * t * (3 - 2 * t)
            return k0[i] + (k1[i] - k0[i]) * t
    return keys[-1][i]


def pump_at(f):
    """Recuo da telha no quadro f (o Godot interpola igual: smoothstep entre as chaves)."""
    return _at(PUMP_KEYS, f, 1)


def shoot_keys(A, sk, aim):
    """ShotgunShoot: coice forte (arma volta 5,5 cm e o cano sobe 9°, ombro e cabeça vão junto), assenta e a mão
    esquerda bombeia a telha (vai para trás STROKE e volta), resolvida quadro a quadro por IK."""
    target = RF.aim_target(sk, aim)
    side = target.col[0].to_3d()
    out = []
    prev = None
    worst = 0.0
    for f in range(FRAMES + 1):
        back, rise = _at(KICK_KEYS, f, 1), _at(KICK_KEYS, f, 2)
        k = back / KICK_KEYS[1][1]
        body = A.merge(aim, {"Spine": (-2 * k, 0, 0), "Chest": (-5 * k, 0, 0), "Head": (-4 * k, 0, 0)})
        fwd = Matrix.Rotation(math.radians(rise), 3, side) @ target.col[1].to_3d()
        origin = target.col[3].to_3d() - target.col[1].to_3d() * back
        gun = RF.frame_matrix(origin, fwd, Matrix.Rotation(math.radians(rise), 3, side) @ target.col[2].to_3d())
        if prev:
            for b in ("UpperArm_L", "LowerArm_L", "UpperArm_R", "LowerArm_R", "Hand_R"):
                body[b] = prev[b]
        grip = Vector(RF.HANDGUARD_GRIP) - Vector((0, pump_at(f), 0))
        pose, e = RF.solve_rifle(sk, body, gun, grip=grip)
        worst = max(worst, e)
        prev = pose
        out.append((f, pose))
    print(f"[shotgun] ShotgunShoot: {len(out)} quadros, erro máx das mãos {worst * 1000:.1f} mm")
    return out
