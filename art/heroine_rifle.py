"""M16: malha (caixas, ~150 triângulos, no retângulo "rifle" do atlas), poses com o fuzil (carregando, mirando,
recuo) e a animação de pegar o fuzil no baú ajoelhada (estilo Syphon Filter).

O fuzil é rígido na mão direita (pesos 100% em Hand_R, como a pistola). Referencial do fuzil: origem no centro do
punho fechado no cabo, `fwd` = cano (o mesmo eixo da pistola na mão), `up` = alça de transporte; o Godot troca a
arma escondendo a malha da outra. As poses põem o fuzil num referencial-alvo e resolvem os braços por IK: a mão
direita (posição + giro) no cabo e a esquerda por baixo da telha. No baú o fuzil fica em RIFLE_CHEST (em relação à
raiz dela ajoelhada na frente do baú): o build exporta m16.glb já nessa posição e o Godot põe no baú.
"""
import math

from mathutils import Matrix, Vector

import heroine_ik as IK
import heroine_mesh as HM
import heroine_moves as M

# (centro (lado, frente, cima), meias-medidas (lado, frente, cima), inclinação em graus em volta do lado)
PARTS = [
    ((0, 0.04, 0.075), (0.016, 0.115, 0.03), 0),  # receptor superior
    ((0, 0.07, 0.03), (0.015, 0.06, 0.02), 0),  # receptor inferior / alojamento do carregador
    ((0, 0.02, 0.125), (0.009, 0.075, 0.018), 0),  # alça de transporte
    ((0, 0.29, 0.075), (0.026, 0.135, 0.026), 0),  # telha
    ((0, 0.515, 0.075), (0.008, 0.09, 0.008), 0),  # cano
    ((0, 0.44, 0.12), (0.006, 0.012, 0.04), 0),  # massa de mira
    ((0, 0.625, 0.075), (0.011, 0.02, 0.011), 0),  # quebra-chamas
    ((0, 0.085, -0.055), (0.012, 0.034, 0.085), -12),  # carregador (curvo: fundo para a frente)
    ((0, -0.01, -0.012), (0.013, 0.02, 0.05), 20),  # cabo (para trás, como na pistola)
    ((0, 0.03, -0.002), (0.006, 0.03, 0.004), 0),  # guarda-mato
    ((0, -0.16, 0.07), (0.017, 0.085, 0.032), 0),  # coronha (frente)
    ((0, -0.3, 0.055), (0.019, 0.055, 0.055), 0),  # coronha (soleira)
]
MUZZLE = (0, 0.645, 0.075)
HANDGUARD_GRIP = (0, 0.21, 0.03)  # onde fica o punho esquerdo (por baixo da telha)
LENGTH = 1.0


def frame_matrix(origin, fwd, up):
    """Matriz cujas colunas são (lado, frente, cima, origem): ponto local (s, f, u) -> espaço do esqueleto."""
    fwd = Vector(fwd).normalized()
    side = fwd.cross(Vector(up)).normalized()
    up = side.cross(fwd).normalized()
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2], m[i][3] = side[i], fwd[i], up[i], origin[i]
    return m


def grip_rest():
    """Referencial do fuzil na mão direita em repouso (o mesmo eixo da pistola)."""
    w, t, _, u = HM.pistol_frame()
    return frame_matrix(w + t * 0.05 - u * 0.005, t, u)


def build_rifle(mb, frame, weights):
    """Caixas do fuzil no referencial `frame` (matriz de frame_matrix)."""
    side, fwd, up = (frame.col[i].to_3d() for i in range(3))
    for c, half, tilt in PARTS:
        rot = Matrix.Rotation(math.radians(tilt), 3, side)
        center = frame @ Vector(c)
        mb.box(center, side, rot @ fwd, half, "rifle", weights)


def muzzle_position():
    return grip_rest() @ Vector(MUZZLE)


# ------------------------------------------------------------------ poses com o fuzil
RIFLE_CHEST = frame_matrix((-0.14, -0.40, 0.34), (1, 0, 0), (0, 0, 1))  # deitado no baú, cano para a esquerda
KNEEL_DIST = 0.32  # da raiz dela até a frente do baú (o Godot põe o baú nessa distância)
HOLD_Z = 1.02  # altura do cabo carregando (pronto baixo): 0,10 acima da junta do quadril
AIM_TWIST = 0.0  # giro extra do peito mirando (braço mais curto: o ombro esquerdo vai à frente para a mão chegar)
ARM_DESIGN, HIP_DESIGN = 0.485, 0.919  # braço (ombro ao punho) e quadril para que as medidas acima foram feitas


def adapt(spec):
    """Medidas do fuzil para outro corpo (heroine_spec.use_joints): cabo carregando na altura do quadril, giro na mira
    e baú mais perto na medida do braço (as mãos alcançam o fuzil deitado)."""
    global RIFLE_CHEST, KNEEL_DIST, HOLD_Z, AIM_TWIST
    da = spec.UPPER_ARM_LEN + spec.FOREARM_LEN - ARM_DESIGN
    HOLD_Z = 1.02 + spec.HIP_L.z - HIP_DESIGN
    AIM_TWIST = max(0.0, -da) * 250.0  # graus: ~10 para 4 cm a menos
    KNEEL_DIST = 0.32 + da
    RIFLE_CHEST = frame_matrix((-0.14, -0.40 - da, 0.34), (1, 0, 0), (0, 0, 1))
GRAB_FRAME = 26
PICKUP_FRAMES = 54


def rifle_now(sk, m):
    return m["Hand_R"] @ sk.rest["Hand_R"].inverted() @ grip_rest()


def solve_rifle(sk, pose, target, torso=(), grip=HANDGUARD_GRIP):
    """Mão direita segurando o fuzil em `target` e a esquerda na telha (`grip`, no referencial da arma);
    `torso` = incógnitas extras (giro)."""
    def res(m):
        cur = rifle_now(sk, m)
        e = list(cur.col[3].to_3d() - target.col[3].to_3d())
        e += list((cur.col[1].to_3d() - target.col[1].to_3d()) * 0.3)
        e += list((cur.col[2].to_3d() - target.col[2].to_3d()) * 0.3)
        return e

    pose, e1 = IK.solve(sk, pose, IK.arm_unknowns("R") + list(torso), res, IK.arm_bounds("R"))
    grip = target @ Vector(grip)
    pose, e2 = IK.solve(sk, pose, IK.arm_unknowns("L", hand=False), lambda m: list(IK.palm(sk, m, "L") - grip),
                        IK.arm_bounds("L"))
    if max(e1, e2) > 0.005:
        print(f"[rifle]   mão direita {e1 * 1000:.1f} mm, esquerda {e2 * 1000:.1f} mm")
    return pose, max(e1, e2)


def aim_target(sk, pose):
    """Mirando: soleira no "bolso" do ombro direito (girado com o tronco), cano reto para a frente."""
    m = sk.matrices(pose)
    chest = m["Chest"].to_3x3() @ sk.rest["Chest"].to_3x3().inverted()
    pocket = sk.point(m, "UpperArm_R") + chest @ Vector((0.06, -0.07, -0.01))
    fwd, up = IK.FWD, IK.UP
    origin = pocket + fwd * 0.355 - up * 0.055  # soleira em (frente -0,355, cima 0,055) do fuzil
    return frame_matrix(origin, fwd, up)


def rifle_poses(A, sk):
    """(carregando, mirando, recuo): poses da parte de cima com o fuzil."""
    aim_body = A.merge(A.AIM, {"Spine": (2, -15, 0), "Chest": (0, -22 - AIM_TWIST, 0), "Neck": (0, 18 + AIM_TWIST, 0),
                               "Head": (10, 18, 8)})
    for k in ("UpperArm_L", "LowerArm_L", "Hand_L", "UpperArm_R", "LowerArm_R", "Hand_R"):
        aim_body.pop(k, None)
    aim_body.update(M.arms(70, -20, 40, 80, -30, 60))
    target = aim_target(sk, aim_body)
    aim, e_aim = solve_rifle(sk, aim_body, target)
    # recuo: o fuzil volta 2,5 cm e o cano sobe 3°
    kick = Matrix.Translation(-target.col[1].to_3d() * 0.025) @ target
    kick = frame_matrix(kick.col[3].to_3d(), Matrix.Rotation(math.radians(3), 3, target.col[0].to_3d()) @ IK.FWD, IK.UP)
    recoil, e_rec = solve_rifle(sk, A.merge(aim, {"Chest": (-2, 0, 0)}), kick)
    hold_body = A.merge(A.IDLE, {"Spine": (2, -8, 0), "Chest": (0, -12, 0), "Head": (0, 14, 0)})
    hold_body.update(M.arms(30, -15, 60, 20, -20, 70))
    hold, e_hold = solve_rifle(sk, hold_body, hold_target())
    print(f"[rifle] erro IK: mirando {e_aim * 1000:.1f} mm, recuo {e_rec * 1000:.1f} mm, carregando {e_hold * 1000:.1f} mm")
    return hold, aim, recoil


def hold_target():
    """Carregando (pronto baixo): cabo na frente do quadril direito, cano para a frente, baixo e para a esquerda."""
    return frame_matrix((-0.12, -0.2, HOLD_Z), (0.55, -0.6, -0.25), (0.15, -0.2, 0.95))


def _lerp_frame(a, b, t):
    qa, qb = a.to_quaternion(), b.to_quaternion()
    m = qa.slerp(qb, t).to_matrix().to_4x4()
    m.translation = a.translation.lerp(b.translation, t)
    return m


def pickup_keys(A, sk, hold):
    """Ajoelha (perna direita no chão), pega o fuzil no baú com as duas mãos (quadro GRAB_FRAME), levanta
    trazendo para a posição de carregar."""
    kneel_body = {"loc": (0, -0.47, 0), "Hips": (8, 0, 0), "Spine": (8, -6, 0), "Chest": (4, -4, 0), "Neck": (6, 0, 0),
                  "Head": (18, 0, 0)}
    kneel = A.merge(kneel_body, M.legs(80, -95, 10, 0, -95, -40), M.arms(30, -10, 40))
    kneel = _kneel_legs(sk, kneel)
    reach = A.merge(kneel, {"Hips": (14, 0, 0), "Spine": (24, -8, 0), "Chest": (12, -6, 0), "Head": (10, 0, 0)},
                    M.arms(55, -10, 30))
    lift = A.merge(kneel, {"Spine": (12, -8, 0), "Chest": (8, -8, 0), "Head": (6, 6, 0)})
    keys = [
        (0, A.IDLE),
        (14, kneel),
        (22, reach),
        (GRAB_FRAME, reach),
        (34, lift),
        (44, hold),
        (PICKUP_FRAMES, hold),
    ]
    lift_t = frame_matrix((-0.1, -0.4, 0.64), (0.75, -0.55, 0.1), (0.0, 0.2, 1.0))
    rifle_keys = [(22, RIFLE_CHEST), (GRAB_FRAME, RIFLE_CHEST), (34, lift_t), (44, hold_target()), (PICKUP_FRAMES, hold_target())]

    def rifle_at(f):
        for (f0, a), (f1, b) in zip(rifle_keys, rifle_keys[1:]):
            if f0 <= f <= f1:
                t = (f - f0) / (f1 - f0)
                return _lerp_frame(a, b, t * t * (3 - 2 * t))
        return rifle_keys[-1][1]

    out = []
    worst = 0.0
    prev = None
    for f in range(PICKUP_FRAMES + 1):
        pose = M.interp_pose(keys, f)
        if f >= 22:
            if prev:
                for k in ("UpperArm_L", "LowerArm_L", "UpperArm_R", "LowerArm_R", "Hand_R"):
                    pose[k] = prev[k]
            pose, e = solve_rifle(sk, pose, rifle_at(f))
            worst = max(worst, e)
            prev = pose
        out.append((f, pose))
    print(f"[rifle] Pickup: {len(out)} quadros, erro máx das mãos {worst * 1000:.1f} mm")
    return out


def _kneel_legs(sk, pose):
    """Joelho direito no chão (canela deitada, ponta do pé apoiada) e pé esquerdo chato à frente, para o lado."""
    pose, _ = M._solve_plant(sk, pose, M.Plant("foot", "L", 0, 0), Vector((0.22, -0.12, M.ANKLE_Z)), Vector())

    def res(m):
        knee = sk.point(m, "LowerLeg_R")
        ankle = sk.point(m, "Foot_R")
        toe = sk.point(m, "Foot_R", sk.length["Foot_R"])
        return list(knee - Vector((-0.1, 0.06, 0.06))) + [ankle.z - 0.13, toe.z - 0.025, (ankle.x - knee.x) * 0.5]

    unk = IK.leg_unknowns("R")
    pose, e = IK.solve(sk, pose, unk, res, IK.leg_bounds("R"))
    print(f"[rifle] ajoelhada: erro {e * 1000:.1f} mm")
    return pose
