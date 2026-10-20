"""Lança-granadas M79 ("Thumper"): malha em caixas (~200 triângulos; metal no retângulo "m79" e madeira em
"m79_wood" do atlas) e a animação de tiro com coice forte.

Usa o mesmo referencial do M16 (heroine_rifle): origem no punho fechado no punho da coronha, `fwd` = cano, `up` =
em cima. Os pontos de apoio coincidem com os do fuzil (punho na origem, soleira em frente -0,355 / cima 0,055, mão
esquerda em HANDGUARD_GRIP por baixo da telha de madeira), então as poses RifleHold/RifleAim e a animação Pickup
servem para ele, e no baú ele fica no mesmo RIFLE_CHEST.

Arma de um tiro só, de quebrar (a recarga fica implícita na cadência do jogo: Player.WEAPON_STATS "m79").
O cano de 40 mm é um octógono (duas caixas, uma girada 45° em volta do cano).
"""
import math

from mathutils import Matrix, Vector

import heroine_rifle as RF

# (centro (lado, frente, cima), meias-medidas (lado, frente, cima), inclinação em graus em volta do lado,
#  giro em graus em volta do cano, retângulo)
PARTS = [
    ((0, 0.25, 0.085), (0.025, 0.165, 0.025), 0, 0, "m79"),  # cano de 40 mm (octógono: esta caixa...)
    ((0, 0.25, 0.085), (0.025, 0.165, 0.025), 0, 45, "m79"),  # ... e a mesma girada 45°
    ((0, 0.412, 0.085), (0.028, 0.008, 0.028), 0, 0, "m79"),  # anel da boca
    ((0, 0.035, 0.075), (0.022, 0.055, 0.032), 0, 0, "m79"),  # caixa da culatra
    ((0, -0.005, 0.113), (0.007, 0.03, 0.007), -15, 0, "m79"),  # alavanca de abrir o cano
    ((0, 0.13, 0.112), (0.018, 0.012, 0.004), 0, 0, "m79"),  # base da alça de mira
    ((0.016, 0.13, 0.138), (0.003, 0.005, 0.026), 0, 0, "m79"),  # alça de mira levantada (lado)
    ((-0.016, 0.13, 0.138), (0.003, 0.005, 0.026), 0, 0, "m79"),  # (outro lado)
    ((0, 0.13, 0.163), (0.019, 0.005, 0.003), 0, 0, "m79"),  # (travessa de cima)
    ((0, 0.392, 0.117), (0.003, 0.006, 0.008), 0, 0, "m79"),  # massa de mira
    ((0, 0.20, 0.051), (0.024, 0.1, 0.017), 0, 0, "m79_wood"),  # telha de madeira sob o cano
    ((0, 0.03, 0.035), (0.013, 0.04, 0.016), 0, 0, "m79"),  # armação do gatilho
    ((0, 0.03, -0.002), (0.006, 0.03, 0.004), 0, 0, "m79"),  # guarda-mato
    ((0, -0.01, -0.012), (0.014, 0.022, 0.05), 20, 0, "m79_wood"),  # punho da coronha
    ((0, -0.13, 0.062), (0.018, 0.09, 0.03), 0, 0, "m79_wood"),  # coronha (frente)
    ((0, -0.28, 0.055), (0.021, 0.06, 0.052), 0, 0, "m79_wood"),  # coronha (soleira larga)
    ((0, -0.347, 0.055), (0.022, 0.008, 0.054), 0, 0, "m79"),  # chapa de borracha da soleira
]
MUZZLE = (0, 0.425, 0.085)

FRAMES = 24  # duração do M79Shoot (30 fps)
# (quadro, recuo do corpo da arma em metros, cano subindo em graus): coice forte e o cano sobe bastante
KICK_KEYS = [(0, 0.0, 0.0), (2, 0.07, 12.0), (7, 0.02, 4.0), (13, 0.0, 0.0), (FRAMES, 0.0, 0.0)]


def build_m79(mb, frame, weights):
    """Caixas da M79 no referencial `frame` (matriz de RF.frame_matrix)."""
    side, fwd, up = (frame.col[i].to_3d() for i in range(3))
    for c, half, tilt, roll, rect in PARTS:
        tilt_m = Matrix.Rotation(math.radians(tilt), 3, side)
        roll_m = Matrix.Rotation(math.radians(roll), 3, fwd)
        mb.box(frame @ Vector(c), roll_m @ side, tilt_m @ fwd, half, rect, weights)


def muzzle_position():
    return RF.grip_rest() @ Vector(MUZZLE)


def _at(keys, f, i):
    for k0, k1 in zip(keys, keys[1:]):
        if k0[0] <= f <= k1[0]:
            t = (f - k0[0]) / (k1[0] - k0[0])
            t = t * t * (3 - 2 * t)
            return k0[i] + (k1[i] - k0[i]) * t
    return keys[-1][i]


def shoot_keys(A, sk, aim):
    """M79Shoot: coice forte (a arma volta 7 cm e o cano sobe 12°, ombro e cabeça vão junto) e assenta, com as duas
    mãos presas à arma (IK quadro a quadro)."""
    target = RF.aim_target(sk, aim)
    side = target.col[0].to_3d()
    out = []
    prev = None
    worst = 0.0
    for f in range(FRAMES + 1):
        back, rise = _at(KICK_KEYS, f, 1), _at(KICK_KEYS, f, 2)
        k = back / KICK_KEYS[1][1]
        body = A.merge(aim, {"Spine": (-3 * k, 0, 0), "Chest": (-6 * k, 0, 0), "Head": (-5 * k, 0, 0)})
        tilt = Matrix.Rotation(math.radians(rise), 3, side)
        origin = target.col[3].to_3d() - target.col[1].to_3d() * back
        gun = RF.frame_matrix(origin, tilt @ target.col[1].to_3d(), tilt @ target.col[2].to_3d())
        if prev:
            for b in ("UpperArm_L", "LowerArm_L", "UpperArm_R", "LowerArm_R", "Hand_R"):
                body[b] = prev[b]
        pose, e = RF.solve_rifle(sk, body, gun)
        worst = max(worst, e)
        prev = pose
        out.append((f, pose))
    print(f"[m79] M79Shoot: {len(out)} quadros, erro máx das mãos {worst * 1000:.1f} mm")
    return out
