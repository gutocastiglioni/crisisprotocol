"""Pulos e pouso da heroína (o Godot faz a física do pulo): pulo parado (JumpUp), pulo projetado (Jump), queda (Fall) e
pouso parada (Land, pés presos por IK). Usa os blocos de `heroine_moves` (arms/legs, bake, Plant)."""
from mathutils import Vector

import heroine_moves as M

# Braços no ar: um pouco à frente e abertos para o equilíbrio, cotovelos dobrados, quase parados nas três (JumpUp, Jump,
# Fall): a troca de uma para outra no meio do pulo não sacode o braço (antes a Fall cruzava os braços na frente do corpo
# e o salto os levava um à frente e outro atrás, e o braço dava a volta em 0,3 s).
def _air_arms(l=(18, 16, 38), r=(18, 16, 38)):
    return M.arms(l[0], l[1], l[2], r[0], r[1], r[2])


def _air_pose(A, hips, spine, chest, head, leg_l, leg_r, arm_l, arm_r, twist=(0, 0), loc=(0, 0, 0)):
    """Pose no ar com o tronco trabalhando: `hips` inclina o corpo todo a partir do quadril (a raiz; as coxas compensam
    para `leg_*` = (coxa em relação ao chão, joelho, pé) seguir valendo, como a corrida faz com RUN_LEAN); `spine`/`chest`
    curvam o tronco por cima; `twist` = (giro do quadril, giro do peito ao contrário) com a passada."""
    return A.merge(_air_arms(arm_l, arm_r), {
        "loc": loc,
        "Hips": (hips, twist[0], 0), "Spine": (spine, twist[1] * 0.4, 0), "Chest": (chest, twist[1] * 0.6, 0),
        "Neck": (head * 0.4, 0, 0), "Head": (head * 0.6 - hips * 0.5, -twist[1] * 0.5, 0),
        "UpperLeg_L": (leg_l[0] + hips, 0, 3), "LowerLeg_L": (leg_l[1], 0, 0), "Foot_L": (leg_l[2], 0, 0),
        "UpperLeg_R": (leg_r[0] + hips, 0, 3), "LowerLeg_R": (leg_r[1], 0, 0), "Foot_R": (leg_r[2], 0, 0)})


def jump_up_keys(A):
    """Pulo parado (sem direcional): sobe no lugar. Sai do impulso com o tronco dobrado para a frente e os joelhos ainda
    dobrados (braços vindo de trás), estica tudo no alto (tronco arqueado um pouco para trás, pontas dos pés para baixo,
    braços um pouco à frente: balanço curto, sem chicotear) e encolhe para pousar (tronco curvando, joelhos subindo)."""
    push = _air_pose(A, 24, 14, 6, -4, (48, -80, 22), (44, -76, 20), (6, 14, 32), (6, 14, 32), loc=(0, -0.1, 0))
    stretch = _air_pose(A, -4, -6, -6, -6, (6, -8, -30), (2, -6, -32), (26, 18, 30), (26, 18, 30), loc=(0, 0.02, 0))
    tuck = _air_pose(A, 14, 12, 8, -6, (42, -64, -10), (36, -58, -12), (24, 20, 38), (24, 20, 38))
    return [(0, push), (5, stretch), (11, tuck), (16, tuck)]


def jump_keys(A):
    """Pulo projetado (andando/correndo ou com direcional; o Godot dá o embalo): sai empurrando com a perna direita
    esticada para trás e o joelho esquerdo subindo, o corpo inclinado para a frente; a passada abre no alto (esquerda à
    frente, direita dobrada atrás) com o quadril girando com ela e o peito ao contrário (braço direito à frente); as duas
    pernas vêm para a frente para pousar e o tronco segue inclinado."""
    push = _air_pose(A, 20, 14, 6, -6, (55, -85, 5), (-22, -12, -40), (0, 14, 32), (34, 12, 46), twist=(-8, 12),
                     loc=(0, -0.05, 0))
    stride = _air_pose(A, 16, 16, 8, -8, (72, -50, 10), (-36, -80, -25), (-6, 16, 30), (38, 12, 44), twist=(-10, 14),
                       loc=(0, 0.02, 0))
    land = _air_pose(A, 18, 12, 6, -6, (48, -62, 5), (32, -72, 0), (20, 18, 38), (22, 18, 38), twist=(-3, 4))
    return [(0, push), (6, stride), (13, land), (18, land)]


def fall_keys(A):
    """Descendo: corpo um pouco inclinado, pernas dobradas prontas para pousar (balançam um pouco em laço), braços abertos
    quase parados (os mesmos do fim dos pulos)."""
    a = _air_pose(A, 12, 8, 4, -4, (34, -52, -8), (24, -42, -12), (18, 16, 38), (18, 16, 38))
    b = _air_pose(A, 12, 9, 4, -4, (26, -44, -10), (34, -54, -8), (20, 18, 40), (16, 18, 36))
    return [(0, a), (15, b), (30, a)]


LAND_FRAMES = 14


def land_keys(A, sk):
    """Pouso parada (o Godot toca ao chegar no chão vindo do ar, `HeroineModel.land`): os pés ficam presos onde ela fica
    de pé (IK), o quadril desce amortecendo com o tronco inclinado e os braços ainda abertos do ar, e sobe até a Idle."""
    keys = [
        (0, _air_pose(A, 12, 8, 4, -4, (34, -52, -8), (24, -42, -12), (18, 16, 38), (18, 16, 38), loc=(0, -0.1, 0))),
        (3, _air_pose(A, 16, 16, 6, -6, (60, -100, 30), (60, -100, 30), (22, 18, 42), (22, 18, 42), loc=(0, -0.26, 0))),
        (7, _air_pose(A, 8, 9, 3, -3, (36, -60, 18), (36, -60, 18), (14, 10, 30), (14, 10, 30), loc=(0, -0.11, 0))),
        (LAND_FRAMES, A.IDLE),
    ]
    m = sk.matrices(A.IDLE)

    def stand(side):
        a = sk.point(m, f"Foot_{side}")
        return Vector((a.x, a.y, M.ANKLE_Z))

    return M.bake(sk, "Land", keys, [M.Plant("foot", side, 0, LAND_FRAMES, target=stand(side)) for side in ("L", "R")])
