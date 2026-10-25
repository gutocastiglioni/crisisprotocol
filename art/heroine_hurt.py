"""Golpes na heroína: reação a tiro/dano (aditiva), cambaleio do empurrão e levantar do chão.

HitFront/HitBack/HitL/HitR são *aditivas*: as poses guardam só o desvio do repouso (osso sem chave = 0), e o Godot
soma por cima do que ela estiver fazendo (andando, agachada, mirando). Nada de pose inteira em pé: o golpe não
endireita o corpo. Front = acertada na frente (tronco e cabeça vão para trás), Back = nas costas (curva para a
frente), L/R = no lado esquerdo/direito dela (o tronco dobra e gira para o outro lado).

StaggerBack/StaggerFwd: empurrada (Player.knockback), cambaleia dois passos para trás/para a frente com os braços
equilibrando; o Godot faz o corpo deslizar.

GetUpFront: de bruços (cabeça para a frente) faz a flexão, vem para os quatro apoios, põe o pé direito à frente
(ajoelhada na esquerda), empurra e traz o pé esquerdo para o lado do direito. GetUpBack: de costas (cabeça para a
frente) gira o corpo de lado até ficar de bruços e segue igual. As mãos, o joelho e os pés ficam presos no chão por
IK (heroine_moves.bake): um pé de cada vez, sem pulo. Fica em pé na origem olhando para a frente (-Y); o Godot
vira a cápsula para a direção quadril -> cabeça do ragdoll e encaixa o quadril do quadro 0 no do ragdoll.
"""
from mathutils import Vector

import heroine_moves as M

# ------------------------------------------------------------------ reação a tiro (aditivas)
HIT_FRAMES = 16


def _hit(peak, rebound):
    return [(0, {}), (3, peak), (8, rebound), (HIT_FRAMES, {})]


def hit_keys(A):
    """nome -> chaves das quatro reações (desvio do repouso; o Godot soma por cima da pose atual)."""
    # joelhos cedem um pouco (quadril baixa e as coxas compensam a inclinação do quadril: os pés não saem do lugar)
    knees = M.legs(7, -13, 6, spread=0)
    front = A.merge(knees, {
        "loc": (0, -0.025, 0.02), "Hips": (-4, 0, 0),
        "Spine": (-7, 0, 0), "Chest": (-11, 0, 0), "Neck": (-6, 0, 0), "Head": (-14, 0, 0),
        "UpperArm_L": (-10, 0, 9), "UpperArm_R": (-10, 0, 9), "LowerArm_L": (8, 0, 0), "LowerArm_R": (8, 0, 0),
    })
    front_back = {"Spine": (2, 0, 0), "Chest": (3, 0, 0), "Head": (6, 0, 0), "loc": (0, -0.01, 0),
                  **M.legs(3, -5, 2, spread=0)}
    back = A.merge(knees, {
        "loc": (0, -0.03, -0.02), "Hips": (5, 0, 0),
        "Spine": (9, 0, 0), "Chest": (11, 0, 0), "Neck": (8, 0, 0), "Head": (12, 0, 0),
        "UpperArm_L": (12, 0, 10), "UpperArm_R": (12, 0, 10), "LowerArm_L": (14, 0, 0), "LowerArm_R": (14, 0, 0),
    })
    back["UpperLeg_L"] = (2, 0, 0)
    back["UpperLeg_R"] = (2, 0, 0)
    back_back = {"Spine": (-2, 0, 0), "Chest": (-3, 0, 0), "Head": (-5, 0, 0), "loc": (0, -0.01, 0)}
    # no lado esquerdo dela: tronco inclina para a direita e o ombro esquerdo vai para trás (gira para a esquerda);
    # a cabeça fica um instante para trás do tronco; a perna esquerda cede
    left = {
        "loc": (-0.02, -0.02, 0), "Hips": (0, 3, 3),
        "Spine": (0, 5, 7), "Chest": (-3, 9, 9), "Neck": (0, 3, -4), "Head": (-4, 5, -8),
        "UpperArm_L": (-6, 0, 16), "LowerArm_L": (10, 0, 0), "UpperArm_R": (4, 0, -6),
        "UpperLeg_L": (8, 0, -3), "LowerLeg_L": (-15, 0, 0), "Foot_L": (7, 0, 0),
        "UpperLeg_R": (0, 0, -3),
    }
    left_back = {"Spine": (0, -2, -2), "Chest": (0, -3, -3), "Head": (0, -2, 3)}
    return {
        "HitFront": _hit(front, front_back),
        "HitBack": _hit(back, back_back),
        "HitL": _hit(left, left_back),
        "HitR": [(f, A.mirror(p)) for f, p in _hit(left, left_back)],
    }


# ------------------------------------------------------------------ cambaleio (empurrão)
STAGGER_FRAMES = 20


def stagger_back_keys(A, sk):
    """Empurrada para trás: o tronco joga para trás, os braços abrem para a frente e ela recua o pé direito, depois o
    esquerdo, e se reequilibra curvando o tronco para a frente."""
    keys = [
        (0, A.IDLE),
        (3, A.merge(M.arms(42, 22, 38, 36, 26, 30), M.legs(14, -22, 8, -12, -48, 14),
                    {"loc": (0, -0.05, 0.02), "Hips": (-6, 0, 0), "Spine": (-9, 0, 0), "Chest": (-10, 0, 0),
                     "Neck": (-6, 0, 0), "Head": (-12, 0, 0)})),
        (8, A.merge(M.arms(34, 26, 52, 30, 30, 44), M.legs(-4, -46, 10, -18, -16, 22),
                    {"loc": (0, -0.07, -0.02), "Hips": (-3, 0, 0), "Spine": (-4, 0, 0), "Chest": (-4, 0, 0),
                     "Head": (-4, 0, 0)})),
        (13, A.merge(M.arms(24, 16, 46), M.legs(-12, -16, 18, 18, -30, 10),
                     {"loc": (0, -0.08, -0.03), "Hips": (4, 0, 0), "Spine": (8, 0, 0), "Chest": (4, 0, 0),
                      "Head": (-4, 0, 0)})),
        (STAGGER_FRAMES, A.merge(A.IDLE, {"loc": (0, -0.02, 0), "Spine": (2, 0, 0)})),
    ]
    return keys


def stagger_fwd_keys(A, sk):
    """Empurrada pelas costas: curva para a frente, braços para trás e para os lados, dois passos à frente."""
    keys = [
        (0, A.IDLE),
        (3, A.merge(M.arms(-24, 26, 30, -20, 30, 26), M.legs(-6, -20, 6, 30, -60, 10),
                    {"loc": (0, -0.05, -0.02), "Hips": (8, 0, 0), "Spine": (10, 0, 0), "Chest": (8, 0, 0),
                     "Neck": (8, 0, 0), "Head": (10, 0, 0)})),
        (8, A.merge(M.arms(-10, 30, 40, -14, 28, 36), M.legs(34, -52, 16, 16, -20, 4),
                    {"loc": (0, -0.08, 0.03), "Hips": (5, 0, 0), "Spine": (6, 0, 0), "Chest": (4, 0, 0),
                     "Head": (2, 0, 0)})),
        (13, A.merge(M.arms(10, 18, 40), M.legs(16, -24, 8, -10, -28, 14),
                     {"loc": (0, -0.07, 0.02), "Hips": (-2, 0, 0), "Spine": (-4, 0, 0), "Head": (-4, 0, 0)})),
        (STAGGER_FRAMES, A.merge(A.IDLE, {"loc": (0, -0.02, 0)})),
    ]
    return keys


# ------------------------------------------------------------------ levantar do chão
# Pontos de apoio (Blender: X = esquerda dela, -Y = frente, Z = cima; em pé no fim na origem)
PALM_Y = 0.0  # mãos no chão embaixo dos ombros nos quatro apoios (e ao lado do peito, de bruços)
PALM_X = 0.19
KNEE_Y = 0.44  # joelhos nos quatro apoios; o esquerdo fica ali até ela levantar
KNEE_X = 0.11
FOOT_X = 0.131
FOOT_Y = 0.043
GETUP_FRONT_FRAMES = 64
ROLL_FRAMES = 18  # GetUpBack: o giro de costas para de bruços antes de seguir igual ao GetUpFront
GETUP_BACK_FRAMES = GETUP_FRONT_FRAMES + ROLL_FRAMES - 4  # o giro termina já na flexão (quadro 4 do de bruços)


def _hip(sk, y, z, x=0.0):
    """loc que põe a cabeça do osso Hips no ponto (x, y, z) do mundo."""
    return tuple(sk.rest["Hips"].inverted() @ Vector((x, y, z)))


def _front_keys(A, sk):
    """De bruços até em pé. Quadros a partir do 0 (de bruços, mãos já ao lado do peito)."""
    prone = A.merge(M.arms(40, 55, 110), M.legs(7, -9, -70, spread=5), {
        "loc": _hip(sk, 0.40, 0.11), "Hips": (90, 0, 0),
        "Spine": (-4, 0, 0), "Chest": (-6, 0, 0), "Neck": (-12, 0, 0), "Head": (-22, 0, 0),
        "Hand_L": (-40, 0, 0), "Hand_R": (-40, 0, 0),
    })
    push = A.merge(M.arms(55, 40, 60), M.legs(8, -16, -70, spread=5), {
        "loc": _hip(sk, 0.42, 0.15), "Hips": (84, 0, 0),
        "Spine": (-10, 0, 0), "Chest": (-12, 0, 0), "Neck": (-10, 0, 0), "Head": (-18, 0, 0),
        "Hand_L": (-50, 0, 0), "Hand_R": (-50, 0, 0),
    })
    draw = A.merge(M.arms(70, 20, 20), M.legs(31, -40, -50, spread=5), {
        "loc": _hip(sk, 0.50, 0.32), "Hips": (82, 0, 0),
        "Spine": (-6, 0, 0), "Chest": (-6, 0, 0), "Neck": (-8, 0, 0), "Head": (-22, 0, 0),
        "Hand_L": (-60, 0, 0), "Hand_R": (-60, 0, 0),
    })
    fours = A.merge(M.arms(80, 10, 8), M.legs(85, -95, -55, spread=4), {
        "loc": _hip(sk, 0.53, 0.47), "Hips": (85, 0, 0),
        "Spine": (6, 0, 0), "Chest": (6, 0, 0), "Neck": (-14, 0, 0), "Head": (-28, 0, 0),
        "Hand_L": (-70, 0, 0), "Hand_R": (-70, 0, 0),
    })
    # o joelho direito vem para a frente por baixo da barriga (a canela arrasta no chão); o tronco começa a subir
    step = A.merge(M.arms(60, 12, 30), M.legs(70, -90, -55, 95, -115, -50, spread=4), {
        "loc": _hip(sk, 0.50, 0.44, 0.02), "Hips": (70, 0, 0),
        "Spine": (4, 0, 0), "Chest": (2, 0, 0), "Neck": (-8, 0, 0), "Head": (-20, 0, 0),
        "Hand_L": (-40, 0, 0), "Hand_R": (-40, 0, 0),
    })
    # tronco de pé, joelho direito alto e o pé dobrado embaixo dele, no ar
    tuck = A.merge(M.arms(40, 12, 40), M.legs(35, -92, -50, 120, -145, 20, spread=4), {
        "loc": _hip(sk, 0.47, 0.42, 0.01), "Hips": (35, 0, 0),
        "Spine": (6, 0, 0), "Chest": (2, 0, 0), "Neck": (-4, 0, 0), "Head": (-12, 0, 0),
    })
    # ajoelhada na esquerda, pé direito no chão à frente, mão direita no joelho direito
    kneel = A.merge(M.arms(30, 10, 45, 50, 8, 40), M.legs(-5, -95, -50, 82, -88, 4, spread=4), {
        "loc": _hip(sk, 0.46, 0.40), "Hips": (14, 0, 0),
        "Spine": (8, 0, 0), "Chest": (4, 0, 0), "Neck": (0, 0, 0), "Head": (-6, 0, 0),
    })
    # empurra no pé direito: o quadril vai para a frente e para cima, o joelho esquerdo sai do chão
    rise = A.merge(M.arms(30, 12, 40, 40, 10, 50), M.legs(-10, -60, -40, 70, -80, 8, spread=4), {
        "loc": _hip(sk, 0.22, 0.60), "Hips": (24, 0, 0),
        "Spine": (14, 0, 0), "Chest": (6, 0, 0), "Head": (-10, 0, 0),
    })
    # a perna esquerda passa para a frente, no ar
    swing = A.merge(M.arms(18, 8, 30), M.legs(40, -80, 10, 30, -50, 10, spread=4), {
        "loc": _hip(sk, 0.08, 0.78), "Hips": (12, 0, 0),
        "Spine": (8, 0, 0), "Chest": (4, 0, 0), "Head": (-6, 0, 0),
    })
    # o pé esquerdo pousa ao lado do direito, ainda com os joelhos dobrados
    plant = A.merge(A.IDLE, M.legs(14, -26, 12, spread=3), {
        "loc": _hip(sk, 0.03, 0.85), "Hips": (5, 0, 0), "Spine": (4, 0, 0), "Head": (-2, 0, 0),
    })
    return [
        (0, prone),
        (8, push),
        (15, draw),
        (22, fours),
        (28, step),
        (32, tuck),
        (36, kneel),
        (43, rise),
        (49, swing),
        (55, plant),
        (GETUP_FRONT_FRAMES, A.IDLE),
    ]


def _front_plants(o):
    """Apoios do levantar de bruços com os quadros deslocados de `o`."""
    palms = [M.Plant("palm", s, o + 0, o + 25, Vector((PALM_X * k, PALM_Y, 0.035))) for s, k in (("L", 1), ("R", -1))]
    knees = [M.Plant("knee", "L", o + 22, o + 37, Vector((KNEE_X, KNEE_Y, 0.06))),
             M.Plant("knee", "R", o + 22, o + 25, Vector((-KNEE_X, KNEE_Y, 0.06)))]
    feet = [M.Plant("foot", "R", o + 36, o + GETUP_FRONT_FRAMES, Vector((-FOOT_X, FOOT_Y, M.ANKLE_Z))),
            M.Plant("foot", "L", o + 55, o + GETUP_FRONT_FRAMES, Vector((FOOT_X, FOOT_Y, M.ANKLE_Z)))]
    return palms + knees + feet


def _real_loc(A, keys):
    """O build multiplica "loc" por LOC_SCALE (medidas de projeto); aqui o loc já é o do corpo dela."""
    out = []
    for f, p in keys:
        p = dict(p)
        if "loc" in p:
            p["loc"] = tuple(c / A.LOC_SCALE for c in p["loc"])
        out.append((f, p))
    return out


def getup_front_keys(A, sk):
    return _real_loc(A, M.bake(sk, "GetUpFront", _front_keys(A, sk), _front_plants(0)))


def getup_back_keys(A, sk):
    """De costas: gira de lado (perna e braço de cima cruzam por cima do corpo e empurram) até ficar de bruços."""
    front = _front_keys(A, sk)
    supine = A.merge(M.arms(-10, 14, 10), M.legs(2, -5, -20, spread=6), {
        "loc": _hip(sk, 0.40, 0.10), "Hips": (90, 180, 0),
        "Spine": (0, 0, 0), "Chest": (0, 0, 0), "Neck": (6, 0, 0), "Head": (10, 0, 0),
    })
    # o joelho esquerdo dobra e o braço esquerdo cruza o peito: o lado esquerdo vai por cima; o direito (o de baixo)
    # estica por cima da cabeça e a perna direita fica reta, encostada na outra, para não entrar no chão
    turn = A.merge(M.arms(70, -10, 40, 150, 12, 15), M.legs(50, -80, -30, 0, -8, -30, spread=6),
                   {"UpperLeg_R": (0, 0, -12)}, {
        "loc": _hip(sk, 0.40, 0.13), "Hips": (90, 135, 0),
        "Spine": (0, -10, 0), "Chest": (0, -12, 0), "Neck": (0, -10, 0), "Head": (0, -20, 0),
    })
    side = A.merge(M.arms(80, 10, 60, 165, 18, 20), M.legs(60, -90, -40, 6, -16, -50, spread=6),
                   {"UpperLeg_R": (0, 0, -14)}, {
        "loc": _hip(sk, 0.40, 0.19), "Hips": (90, 90, 0),
        "Spine": (0, -12, 0), "Chest": (-4, -14, 0), "Neck": (0, -10, 0), "Head": (-10, -16, 0),
    })
    over = A.merge(M.arms(50, 45, 90, 110, 40, 60), M.legs(30, -50, -60, 5, -15, -60, spread=6), {
        "loc": _hip(sk, 0.40, 0.13), "Hips": (90, 35, 0),
        "Spine": (-2, -6, 0), "Chest": (-4, -6, 0), "Neck": (-8, -4, 0), "Head": (-18, -8, 0),
    })
    o = ROLL_FRAMES - 4
    keys = [(0, supine), (6, turn), (11, side), (15, over)] + [(f + o, p) for f, p in front if f >= 8]
    plants = [p for p in _front_plants(o) if p.kind != "palm"]
    # a mão esquerda (a de cima) apoia já no fim do giro; a direita quando o peito vira para o chão
    plants += [M.Plant("palm", s, start, o + 25, Vector((PALM_X * k, PALM_Y, 0.035)))
               for s, k, start in (("L", 1, 13), ("R", -1, 15))]
    return _real_loc(A, M.bake(sk, "GetUpBack", keys, plants))
