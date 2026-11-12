"""Recarga da pistola e do M16 (ReloadPistol / ReloadRifle), só a parte de cima (o Godot toca por cima da locomoção).

A mão direita leva a arma para a frente do peito, deitada para o lado dela (o pente fica à vista), e a mão esquerda
faz o caminho do pente: solta o vazio embaixo da arma, vai à bolsa do cinto do lado esquerdo, volta com o cheio, enfia,
bate e puxa o ferrolho / a alavanca de manejo. Tudo por IK quadro a quadro (mão direita no referencial da arma, palma
esquerda num ponto do caminho), como a telha da escopeta (heroine_shotgun.shoot_keys).

Quadros dos sons (`OUT` solta o pente, `IN` encaixa o novo, `RACK` ferrolho) vão para o heroine_moves.json "reload".
"""
import math

from mathutils import Matrix, Vector

import heroine_ik as IK
import heroine_rifle as RF

# ---------------------------------------------------------------- pistola (30 fps)
PISTOL_FRAMES = 45
PISTOL = {"out": 7, "in": 30, "rack": 37}
# caminho da palma esquerda: (quadro, onde, ponto). "gun" = referencial da pistola (lado, cano, em cima); "belt" =
# referencial do quadril (esquerda, frente, cima, X = esquerda dela)
PISTOL_LEFT = [
    (0, "grip", None),
    (5, "gun", (0.0, 0.01, -0.12)),  # embaixo do cabo: solta o pente vazio
    (9, "gun", (0.02, 0.01, -0.2)),
    (16, "belt", (0.15, 0.1, 0.02)),  # bolsa do cinto, à esquerda e um pouco à frente
    (20, "belt", (0.15, 0.1, -0.01)),  # pega o pente cheio
    (26, "gun", (0.0, 0.01, -0.17)),
    (30, "gun", (0.0, 0.01, -0.09)),  # encaixa
    (32, "gun", (0.0, 0.01, -0.105)),  # bate com a palma
    (35, "gun", (0.03, 0.02, 0.07)),  # em cima do ferrolho, atrás
    (38, "gun", (0.03, -0.06, 0.07)),  # puxa o ferrolho
    (PISTOL_FRAMES, "grip", None),
]
# a pistola: em guarda (0) -> na frente do peito deitada (de 5 a 37) -> em guarda
PISTOL_GUN = [(0, 0.0), (5, 1.0), (37, 1.0), (PISTOL_FRAMES, 0.0)]
PISTOL_LIFT = (0.04, -0.03, 0.1)  # do pulso da guarda: para o meio, um pouco à frente e mais alto (Blender: X esquerda, -Y frente)
PISTOL_ROLL = 35.0  # deita a pistola para dentro (o cabo vira para a esquerda dela)
PISTOL_PITCH = 18.0  # cano um pouco para cima

# ---------------------------------------------------------------- M16
RIFLE_FRAMES = 66
RIFLE = {"out": 10, "in": 42, "rack": 56}
RIFLE_LEFT = [
    (0, "grip", None),
    (7, "gun", (0.0, 0.085, -0.13)),  # no pente
    (12, "gun", (0.0, 0.1, -0.26)),  # tira o vazio
    (20, "belt", (0.16, 0.08, 0.02)),
    (25, "belt", (0.16, 0.08, -0.01)),  # pega o cheio
    (35, "gun", (0.0, 0.1, -0.27)),
    (42, "gun", (0.0, 0.085, -0.13)),  # encaixa
    (44, "gun", (0.0, 0.085, -0.15)),  # bate
    (51, "gun", (0.02, -0.05, 0.12)),  # alavanca de manejo (atrás, em cima)
    (56, "gun", (0.02, -0.13, 0.12)),  # puxa
    (RIFLE_FRAMES, "grip", None),
]
RIFLE_GUN = [(0, 0.0), (7, 1.0), (56, 1.0), (RIFLE_FRAMES, 0.0)]
RIFLE_LIFT = (0.02, -0.02, 0.06)
RIFLE_ROLL = 28.0
RIFLE_PITCH = 8.0


def _smooth(keys, f):
    """Valor no quadro f entre as chaves (quadro, valor), com smoothstep."""
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            t = (f - f0) / (f1 - f0)
            t = t * t * (3 - 2 * t)
            return v0 + (v1 - v0) * t
    return keys[-1][1]


def _tilted(frame, lift, roll, pitch, k):
    """A arma (`frame`, colunas lado/frente/cima/origem) levada `lift` e girada `roll` em volta do cano e `pitch` para
    cima, na fração k."""
    side, fwd, up = (frame.col[i].to_3d() for i in range(3))
    rot = Matrix.Rotation(math.radians(roll * k), 3, fwd) @ Matrix.Rotation(math.radians(pitch * k), 3, side)
    origin = frame.col[3].to_3d() + Vector(lift) * k
    return RF.frame_matrix(origin, rot @ fwd, rot @ up)


def _left_points(keys, belt, gun_at, rest_grip):
    """Pontos da palma esquerda (no espaço do esqueleto) de cada chave, para o quadro f usando a arma do quadro."""
    def at(f):
        for (f0, w0, p0), (f1, w1, p1) in zip(keys, keys[1:]):
            if f0 <= f <= f1:
                t = (f - f0) / (f1 - f0)
                t = t * t * (3 - 2 * t)
                return _point(w0, p0, f, belt, gun_at, rest_grip).lerp(_point(w1, p1, f, belt, gun_at, rest_grip), t)
        return _point(keys[-1][1], keys[-1][2], f, belt, gun_at, rest_grip)
    return at


def _point(where, p, f, belt, gun_at, rest_grip):
    if where == "grip":
        return gun_at(f) @ rest_grip
    if where == "gun":
        return gun_at(f) @ Vector(p)
    return belt @ Vector(p)


def _solve(sk, body, gun, palm, wrist_frame):
    """Mão direita segurando a arma em `gun` (referencial `wrist_frame` na mão) e a palma esquerda em `palm`."""
    def res(m):
        cur = m["Hand_R"] @ sk.rest["Hand_R"].inverted() @ wrist_frame
        e = list(cur.col[3].to_3d() - gun.col[3].to_3d())
        e += list((cur.col[1].to_3d() - gun.col[1].to_3d()) * 0.3)
        e += list((cur.col[2].to_3d() - gun.col[2].to_3d()) * 0.3)
        return e

    pose, e1 = IK.solve(sk, body, IK.arm_unknowns("R"), res, IK.arm_bounds("R"))
    pose, e2 = IK.solve(sk, pose, IK.arm_unknowns("L", hand=False), lambda m: list(IK.palm(sk, m, "L") - palm),
                        IK.arm_bounds("L"))
    return pose, max(e1, e2)


def _keys(name, sk, start, frames, gun_keys, left_keys, lift, roll, pitch):
    wrist_frame = RF.grip_rest()  # pistola e fuzil no mesmo eixo da mão
    m0 = sk.matrices(start)
    gun0 = m0["Hand_R"] @ sk.rest["Hand_R"].inverted() @ wrist_frame
    rest_grip = gun0.inverted() @ IK.palm(sk, m0, "L")  # onde a palma esquerda fica na pose de partida
    hips = m0["Hips"]
    belt = Matrix.Translation(hips.translation) @ Matrix(((1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))

    def gun_at(f):
        return _tilted(gun0, lift, roll, pitch, _smooth(gun_keys, f))

    left_at = _left_points(left_keys, belt, gun_at, rest_grip)
    out = [(0, start)]
    prev = start
    worst = 0.0
    for f in range(1, frames):
        body = dict(start)
        for b in ("UpperArm_L", "LowerArm_L", "Hand_L", "UpperArm_R", "LowerArm_R", "Hand_R"):
            body[b] = prev.get(b, start.get(b, (0, 0, 0)))
        # o peito acompanha um pouco (olha para a arma)
        k = _smooth(gun_keys, f)
        body = dict(body, Head=tuple(a + b for a, b in zip(start.get("Head", (0, 0, 0)), (14 * k, 0, 0))))
        pose, e = _solve(sk, body, gun_at(f), left_at(f), wrist_frame)
        worst = max(worst, e)
        prev = pose
        out.append((f, pose))
    out.append((frames, start))
    print(f"[reload] {name}: {len(out)} quadros, erro máx das mãos {worst * 1000:.1f} mm")
    return out


def pistol_keys(A, sk, guard):
    """ReloadPistol: parte de `guard` (a pistola em guarda nas duas mãos, pose inteira de cima) e volta a ela."""
    return _keys("ReloadPistol", sk, guard, PISTOL_FRAMES, PISTOL_GUN, PISTOL_LEFT, PISTOL_LIFT, PISTOL_ROLL, PISTOL_PITCH)


def rifle_keys(A, sk, hold):
    """ReloadRifle: parte do RifleHold e volta a ele."""
    return _keys("ReloadRifle", sk, hold, RIFLE_FRAMES, RIFLE_GUN, RIFLE_LEFT, RIFLE_LIFT, RIFLE_ROLL, RIFLE_PITCH)


def data():
    """Para o heroine_moves.json: duração e quadros dos sons de cada recarga."""
    return {"pistol": dict(PISTOL, frames=PISTOL_FRAMES), "m16": dict(RIFLE, frames=RIFLE_FRAMES)}
