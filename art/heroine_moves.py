"""Movimentos com deslocamento: cambalhota, pulo/queda, pendurar, subir da borda e escalar
obstáculos baixos, além dos ciclos de passo (heroine_gait).

Quem anda é o Godot: a cápsula segue o mesmo caminho da raiz (`*_PATH`: (quadro, frente, cima) em metros,
interpolado por `hermite`, igual em game/scripts/moves.gd). As poses são desenhadas por quadros-chave e os
pontos de apoio (pés no chão, mãos na borda, joelho no topo) ficam presos no mundo por IK, descontando o caminho
da raiz: nada escorrega. O build grava os caminhos e as medidas em game/assets/characters/heroine_moves.json.
"""
import math
from dataclasses import dataclass

from mathutils import Euler, Vector

import heroine_gait as G
import heroine_ik as IK

FPS = 30
ANKLE_Z = 0.085  # tornozelo com o pé chato no chão


# ------------------------------------------------------------------ interpolação (igual no Godot)
def _slopes(fr, vals):
    """Inclinações tipo Fritsch-Carlson: sem passar do valor (sem "voltar") entre chaves monótonas."""
    n = len(vals)
    s = [0.0] * n
    for i in range(1, n - 1):
        d0 = (vals[i] - vals[i - 1]) / (fr[i] - fr[i - 1])
        d1 = (vals[i + 1] - vals[i]) / (fr[i + 1] - fr[i])
        if d0 * d1 > 0:
            s[i] = max(min((vals[i + 1] - vals[i - 1]) / (fr[i + 1] - fr[i - 1]), 3 * min(abs(d0), abs(d1))),
                       -3 * min(abs(d0), abs(d1)))
    return s


def hermite(fr, vals, f):
    if f <= fr[0]:
        return vals[0]
    if f >= fr[-1]:
        return vals[-1]
    i = max(k for k in range(len(fr) - 1) if fr[k] <= f)
    h = fr[i + 1] - fr[i]
    t = (f - fr[i]) / h
    s = _slopes(fr, vals)
    t2, t3 = t * t, t * t * t
    return ((2 * t3 - 3 * t2 + 1) * vals[i] + (t3 - 2 * t2 + t) * h * s[i]
            + (-2 * t3 + 3 * t2) * vals[i + 1] + (t3 - t2) * h * s[i + 1])


def path_offset(path, f, along=None):
    """Deslocamento da raiz no quadro f, no espaço do Blender (frente = -Y; `along` = outra direção no chão)."""
    if not path:
        return Vector((0, 0, 0))
    fr = [k[0] for k in path]
    d = hermite(fr, [k[1] for k in path], f)
    up = Vector((0.0, 0.0, hermite(fr, [k[2] for k in path], f)))
    return (along if along is not None else Vector((0.0, -1.0, 0.0))) * d + up


def interp_pose(keys, f):
    fr = [k[0] for k in keys]
    names = sorted({n for _, p in keys for n in p})
    out = {}
    for n in names:
        if n.startswith("_"):
            out[n] = hermite(fr, [p.get(n, 0.0) for _, p in keys], f)
            continue
        comps = [p.get(n, (0, 0, 0)) for _, p in keys]
        out[n] = tuple(hermite(fr, [c[i] for c in comps], f) for i in range(3))
    return out


# ------------------------------------------------------------------ apoios presos por IK
@dataclass
class Plant:
    kind: str  # "foot" (tornozelo + pé chato), "palm" (punho), "knee" (joelho no apoio)
    side: str
    start: int
    end: int
    target: object = None  # None = prende onde a pose desenhada estiver no quadro `start`
    ground: float = 0.0  # altura do apoio quando capturado (chão ou topo do obstáculo)


def _foot_dir(sk, s):
    a, t = IK.foot_rest(sk, s)
    return (t - a).normalized()


def _capture(sk, pose, pl, off):
    m = sk.matrices(pose)
    if pl.kind == "foot":
        a = sk.point(m, f"Foot_{pl.side}") + off
        return Vector((a.x, a.y, pl.ground + ANKLE_Z))
    if pl.kind == "knee":
        k = sk.point(m, f"LowerLeg_{pl.side}") + off
        return Vector((k.x, k.y, pl.ground + 0.06))
    return IK.palm(sk, m, pl.side) + off


def _solve_plant(sk, pose, pl, tgt, off):
    s = pl.side
    local = tgt - off
    if pl.kind == "foot":
        d = _foot_dir(sk, s)

        def res(m):
            a = sk.point(m, f"Foot_{s}")
            t = sk.point(m, f"Foot_{s}", sk.length[f"Foot_{s}"])
            return list(a - local) + list(((t - a).normalized() - d) * 0.15)

        return IK.solve(sk, pose, IK.leg_unknowns(s), res, IK.leg_bounds(s))
    if pl.kind == "knee":
        unk = [(f"UpperLeg_{s}", 0), (f"UpperLeg_{s}", 1), (f"UpperLeg_{s}", 2)]
        return IK.solve(sk, pose, unk, lambda m: list(sk.point(m, f"LowerLeg_{s}") - local))
    return IK.solve(sk, pose, IK.arm_unknowns(s, hand=False), lambda m: list(IK.palm(sk, m, s) - local),
                    IK.arm_bounds(s))


PLANT_BONES = {"foot": ("UpperLeg", "LowerLeg", "Foot"), "knee": ("UpperLeg",), "palm": ("UpperArm", "LowerArm")}


def bake(sk, name, keys, plants=(), path=None, fix=None, along=None):
    """Um quadro-chave por quadro: pose desenhada interpolada, ajuste `fix(pose, f)` e apoios resolvidos
    (cada apoio parte da solução do quadro anterior: sem saltos de um quadro para o outro).
    `along` = direção do caminho no chão (padrão: frente)."""
    held = {}
    out = []
    worst, where = 0.0, ""
    for f in range(keys[-1][0] + 1):
        pose = interp_pose(keys, f)
        if fix:
            pose = fix(pose, f)
        off = path_offset(path, f, along)
        for pl in plants:
            if not pl.start <= f <= pl.end:
                continue
            if f > pl.start:
                for b in PLANT_BONES[pl.kind]:
                    pose[f"{b}_{pl.side}"] = out[-1][1][f"{b}_{pl.side}"]
            if pl.target is None:
                key = (pl.kind, pl.side, pl.start)
                if key not in held:
                    held[key] = _capture(sk, pose, pl, off)
                tgt = held[key]
            else:
                tgt = pl.target(f) if callable(pl.target) else pl.target
            pose, err = _solve_plant(sk, pose, pl, tgt, off)
            if err > 0.005:
                where += f" {pl.kind}_{pl.side}@{f}={err * 1000:.0f}"
            worst = max(worst, err)
        out.append((f, {k: v for k, v in pose.items() if not k.startswith("_")}))
    print(f"[moves] {name}: {len(out)} quadros, erro máx dos apoios {worst * 1000:.1f} mm{where}")
    return out


def legs(thigh_l, knee_l, foot_l, thigh_r=None, knee_r=None, foot_r=None, spread=3):
    thigh_r = thigh_l if thigh_r is None else thigh_r
    knee_r = knee_l if knee_r is None else knee_r
    foot_r = foot_l if foot_r is None else foot_r
    return {"UpperLeg_L": (thigh_l, 0, spread), "LowerLeg_L": (knee_l, 0, 0), "Foot_L": (foot_l, 0, 0),
            "UpperLeg_R": (thigh_r, 0, spread), "LowerLeg_R": (knee_r, 0, 0), "Foot_R": (foot_r, 0, 0)}


def arms(x, z, elbow, xr=None, zr=None, elbow_r=None):
    xr = x if xr is None else xr
    zr = z if zr is None else zr
    elbow_r = elbow if elbow_r is None else elbow_r
    return {"UpperArm_L": (x, 0, z), "LowerArm_L": (elbow, 0, 0), "UpperArm_R": (xr, 0, zr), "LowerArm_R": (elbow_r, 0, 0)}


def no_legs(pose):
    return {k: v for k, v in pose.items() if not k.startswith(("UpperLeg", "LowerLeg", "Foot"))}


# ------------------------------------------------------------------ ciclos de passo
def crouch_walk_body(A):
    """Tronco da caminhada agachada (os braços vêm da guarda da pistola, ver heroine_anims.pistol_guard)."""
    return A.merge(A.CROUCH, {"Spine": (-4, 0, 0), "Head": (4, 0, 0)})


def gaits(A, crouch_guard=None):
    """Caminhada lenta e sutil, agachada (pistola em guarda nas duas mãos), e passos laterais mirando.
    `crouch_guard` = braços da guarda (sem ele, só as velocidades valem: o build lê daqui para o json)."""
    walk_upper = A.merge(no_legs(A.IDLE), {"Spine": (2, 0, 0), "Head": (-2, 0, 0)})
    crouch_upper = dict(crouch_walk_body(A), **(crouch_guard or {}))
    crouch_aim = A.merge({k: v for k, v in A.CROUCH.items() if k.startswith(("Upper", "Lower", "Foot", "loc"))},
                         {"UpperArm_L": (0, 0, 0)}, no_legs(A.AIM))
    for k in ("UpperArm_R", "LowerArm_R", "UpperArm_L", "LowerArm_L"):
        crouch_aim[k] = A.AIM[k]
    return {
        "walk": G.Gait(n=15, speed=0.9, stance=0.58, hip=-0.04, upper=walk_upper),
        "crouch_walk": G.Gait(n=11, speed=1.4, stance=0.62, hip=-0.33, bob=0.01, sway=0.015, turn=3.0,
                              lift=0.07, heel=6.0, toe_off=-14.0, swing_arm=0.0, upper=crouch_upper),
        "strafe": G.Gait(n=10, speed=0.75, travel=(1.0, 0.0), stance=0.5, hip=-0.04, bob=0.008, lift=0.05,
                         width=0.08, heel=0.0, toe_off=0.0, swing_arm=0.0, upper=no_legs(A.AIM)),
        # passo lateral largo mirando em pé no survival (a pistola anda de lado a até 1,35 m/s): passada de ~0,55 m a 2,5
        # passos/s, quadril um pouco mais baixo para as pernas abrirem; o StrafeL/R curto tocado a 1,8x virava trotinho
        "strafe_fast": G.Gait(n=12, speed=1.35, travel=(1.0, 0.0), stance=0.5, hip=-0.07, bob=0.014, lift=0.07,
                              width=0.08, heel=0.0, toe_off=0.0, swing_arm=0.0, upper=no_legs(A.AIM)),
        "crouch_strafe": G.Gait(n=14, speed=0.45, travel=(1.0, 0.0), stance=0.55, hip=-0.33, bob=0.006,
                                lift=0.06, width=0.1, heel=0.0, toe_off=0.0, swing_arm=0.0, upper=crouch_aim),
    }



# ------------------------------------------------------------------ cambalhota de mergulho
# Passada de impulso: a esquerda dá um passo à frente com os braços indo para trás (0-4), o pé apoia, ela abaixa e
# empurra com essa perna enquanto a direita sobe atrás e os braços vêm para a frente (4-5), e mergulha num arco: o corpo
# sobe e desce como um projétil enquanto gira de inclinado para cima até de cabeça para baixo, braços esticados (5-10);
# as mãos tocam o chão bem à frente (10), o embalo leva o corpo por cima delas dobrando os cotovelos e encaixando o
# queixo (10-12), e ela segue rolando para a frente sem frear sobre as costas (12-21), pés no chão agachada (24) e levanta (27-30).
# O quadril nunca sobe acima do de pé. O corpo gira em volta do centro do "novelo" (ROLL_C), não do quadril, e o
# caminho da raiz acompanha o giro (centro anda giro x raio nos quadros com as costas no chão): rola sem patinar.
ROLL_FRAMES = 30
ROLL_HANDS = (10, 12)  # mãos presas no chão
ROLL_STEP = (4, 5)  # pé esquerdo da passada de impulso preso no chão
ROLL_LAND = 22  # pés presos de novo, já onde ela fica de pé
ROLL_PATH = [(0, 0.0, 0.0), (2, 0.14, 0.0), (4, 0.38, 0.0), (5, 0.56, 0.0), (6, 0.74, 0.0), (7, 0.92, 0.0),
             (8, 1.1, 0.0), (9, 1.28, 0.0), (10, 1.46, 0.0), (11, 1.62, 0.0), (12, 1.76, 0.0), (14, 1.92, 0.0),
             (16, 2.07, 0.0), (18, 2.21, 0.0), (20, 2.36, 0.0), (21, 2.43, 0.0), (24, 2.54, 0.0), (27, 2.57, 0.0),
             (30, 2.58, 0.0)]
ROLL_C = Vector((0.0, 0.26, 0.08))  # centro do corpo encolhido no espaço do quadril (esquerda, cima, frente)
ROLL_STAND = 1.147  # altura desse centro de pé (pés no chão)


def roll_keys(A, sk):
    tuck = A.merge(arms(40, -10, 95), {"Hand_L": (-20, 0, 0), "Hand_R": (-20, 0, 0)})
    tucked_legs = legs(110, -138, 30)
    curl = {"Spine": (45, 0, 0), "Chest": (25, 0, 0), "Neck": (30, 0, 0), "Head": (55, 0, 0)}
    line = {"Spine": (-4, 0, 0), "Neck": (-8, 0, 0), "Head": (-12, 0, 0)}  # corpo estendido numa linha
    keys = [
        (0, A.merge(A.IDLE, {"_th": 0, "_ch": ROLL_STAND, "_cf": 0.08})),
        # passada: a esquerda vai à frente, os braços vão para trás
        (2, A.merge(arms(-30, -10, 15), legs(38, -55, 12, -6, -12, -10), {"Spine": (6, 0, 0),
                                                                           "_th": 12, "_ch": 1.08, "_cf": 0.1})),
        # o pé esquerdo apoia à frente e ela abaixa sobre ele, a direita atrás com o calcanhar no ar, braços no fundo
        (4, A.merge(arms(-45, -10, 15), legs(58, -85, 22, -22, -38, -25), {"Spine": (14, 0, 0), "Head": (-10, 0, 0),
                                                                            "_th": 30, "_ch": 0.86, "_cf": 0.2})),
        # impulso: a esquerda estende, a direita sobe atrás, os braços vêm esticados para a frente
        (5, A.merge(arms(125, -10, 0), legs(18, -22, -35, -30, -12, -20), {"Spine": (4, 0, 0), "Head": (-16, 0, 0),
                                                                            "_th": 44, "_ch": 0.92, "_cf": 0.32})),
        # arco: sobe inclinada para a frente, passa deitada no alto e desce de cabeça; os braços já saem apontando o chão
        # lá na frente (de ~10° abaixo da horizontal no impulso a ~30° perto do toque), não alinhados com o corpo
        (6, A.merge(arms(128, -8, 4), legs(-4, -6, -35), line, {"_th": 58, "_ch": 1.0, "_cf": 0.42})),
        (7, A.merge(arms(138, -8, 4), legs(-2, -6, -35), line, {"_th": 74, "_ch": 1.02, "_cf": 0.45})),
        (8, A.merge(arms(146, -8, 4), legs(2, -8, -32), line, {"_th": 88, "_ch": 0.96, "_cf": 0.45})),
        (9, A.merge(arms(146, -10, 4), legs(8, -12, -28), {"Spine": (2, 0, 0), "Neck": (-2, 0, 0), "Head": (0, 0, 0),
                                                           "_th": 100, "_ch": 0.82, "_cf": 0.42})),
        # mãos tocam o chão à frente, braços ainda longos
        (10, A.merge(arms(142, -12, 5), legs(14, -20, -20), {"Spine": (8, 0, 0), "Neck": (12, 0, 0), "Head": (25, 0, 0),
                                                            "_th": 110, "_ch": 0.52, "_cf": 0.38})),
        # o embalo leva o corpo por cima das mãos: cotovelos dobram, queixo no peito, joelhos vindo
        (11, A.merge(arms(132, -12, 45), legs(45, -70, 0), {"Spine": (30, 0, 0), "Neck": (40, 0, 0), "Head": (70, 0, 0),
                                                           "_th": 124, "_ch": 0.56, "_cf": 0.3})),
        # o peso passa para os ombros (nunca para a cabeça), as pernas empurram
        (12, A.merge(arms(125, -12, 70), legs(85, -125, 20), curl, {"Neck": (40, 0, 0), "Head": (75, 0, 0),
                                                                    "_th": 142, "_ch": 0.46, "_cf": 0.22})),
        (14, A.merge(tuck, tucked_legs, curl, {"_th": 185, "_ch": 0.19, "_cf": 0.13})),
        (16, A.merge(tuck, tucked_legs, curl, {"_th": 225, "_ch": 0.11, "_cf": 0.1})),
        (18, A.merge(tuck, tucked_legs, curl, {"Neck": (15, 0, 0), "Head": (40, 0, 0),
                                               "_th": 262, "_ch": 0.17, "_cf": 0.08})),
        (20, A.merge(tuck, legs(105, -134, 32), curl, {"Neck": (10, 0, 0), "Head": (34, 0, 0),
                                                       "_th": 292, "_ch": 0.31, "_cf": 0.07})),
        (21, A.merge(tuck, legs(100, -130, 35), {"Spine": (35, 0, 0), "Chest": (15, 0, 0), "Head": (30, 0, 0),
                                                 "_th": 308, "_ch": 0.35, "_cf": 0.06})),
        (24, A.merge(A.CROUCH, {"Spine": (30, 0, 0), "_th": 357, "_ch": 0.77, "_cf": 0.08})),
        (27, A.merge(A.CROUCH, {"Spine": (14, 0, 0), "_th": 361, "_ch": 0.97, "_cf": 0.07})),
        (ROLL_FRAMES, A.merge(A.IDLE, {"_th": 360, "_ch": ROLL_STAND, "_cf": 0.08})),
    ]
    rest = sk.rest["Hips"]

    def fix(pose, f):
        # gira o quadril e põe o centro do novelo na altura/frente desenhadas: loc = alvo - R * c
        th = pose.pop("_th")
        target = Vector((0.0, -pose.pop("_cf"), pose.pop("_ch")))
        hx = pose.get("Hips", (0, 0, 0))
        rot = Euler((math.radians(th + hx[0]), math.radians(hx[1]), math.radians(hx[2])), "ZYX").to_matrix()
        loc = rest.inverted() @ target - rot @ ROLL_C
        pose["Hips"] = (th + hx[0], hx[1], hx[2])
        pose["loc"] = tuple(loc)
        return pose

    # mãos: onde a pose do quadro em que tocam as leva, baixadas até o chão
    f0 = ROLL_HANDS[0]
    m0 = sk.matrices(fix(interp_pose(keys, f0), f0))
    off0 = path_offset(ROLL_PATH, f0)

    def on_floor(s):
        p = IK.palm(sk, m0, s) + off0
        return Vector((p.x, p.y, 0.05))

    # pés: pousam já onde ela fica de pé no fim
    m1 = sk.matrices(fix(interp_pose(keys, ROLL_FRAMES), ROLL_FRAMES))
    off1 = path_offset(ROLL_PATH, ROLL_FRAMES)

    def stand(s):
        a = sk.point(m1, f"Foot_{s}") + off1
        return Vector((a.x, a.y, ANKLE_Z))

    plants = [Plant("foot", "R", 0, 3), Plant("foot", "L", 0, 1), Plant("foot", "L", *ROLL_STEP)]
    plants += [Plant("palm", s, *ROLL_HANDS, target=on_floor(s)) for s in ("L", "R")]
    plants += [Plant("foot", s, ROLL_LAND, ROLL_FRAMES, target=stand(s)) for s in ("L", "R")]
    return bake(sk, "Roll", keys, plants, ROLL_PATH, fix)


# ------------------------------------------------------------------ pendurada e subindo
# Pendurada: punhos HANG_REACH acima dos pés, HANG_FWD à frente; a parede fica HANG_WALL à frente da raiz
# (a borda passa entre os punhos e o corpo). O Godot posiciona a raiz por essas medidas.
HANG_REACH = 1.84
HANG_FWD = 0.2
HANG_WALL = 0.16
HANG_TOP = HANG_REACH - 0.03  # superfície do topo (o punho fechado fica por cima dela)
HAND_X = 0.19

# Subir da borda: puxa até o peito passar da borda (0-14), joga o tronco por cima com os braços esticados
# empurrando (14-22), põe o joelho direito no topo (27-32), sobe agachada (36) e fica de pé (44).
# Caminho relativo à raiz pendurada (as pernas ficam penduradas junto da parede até o joelho subir).
CLIMB_FRAMES = 44
CLIMB_HANDS_UNTIL = 28
CLIMB_PATH = [(0, 0.0, 0.0), (6, 0.0, 0.2), (14, 0.0, 0.75), (22, -0.05, 1.0), (28, -0.1, 1.06),
              (36, 0.36, HANG_TOP), (44, 0.46, HANG_TOP)]


def hang_pose(A, sway=0.0):
    return A.merge(arms(160, 8, 20), legs(8 + sway, -14 - sway, -35, 4 - sway, -10 + sway, -38, spread=2),
                   {"Hips": (-3, 0, 0), "Spine": (-4, 0, 0), "Chest": (-6, 0, 0), "Neck": (-6, 0, 0),
                    "Head": (-14, 0, 0), "Hand_L": (-25, 0, 0), "Hand_R": (-25, 0, 0)})


def _palms_at(base, up, fwd, start, end):
    return [Plant("palm", s, start, end, target=base + Vector((x * HAND_X, -fwd, up))) for s, x in (("L", 1), ("R", -1))]


def hang_keys(A, sk):
    keys = [(0, hang_pose(A)), (30, hang_pose(A, 6)), (60, hang_pose(A))]
    return bake(sk, "Hang", keys, _palms_at(Vector(), HANG_REACH, HANG_FWD, 0, 60))


def _knee_up(A, arm_pose, left=(40, -55, -15)):
    """Joelho direito subindo para o topo, perna esquerda pendurada junto da parede (coxa quase na vertical,
    joelho dobrado: o quadril inclinado já leva a perna para trás), tronco por cima da borda."""
    return A.merge(arm_pose, legs(*left, 75, -120, 10),
                   {"loc": (0, -0.04, 0), "Hips": (32, 0, 0), "Spine": (12, 0, 0), "Head": (-20, 0, 0), "Neck": (-5, 0, 0)})


def climb_keys(A, sk):
    lean = {"Head": (-20, 0, 0), "Neck": (-5, 0, 0)}
    keys = [
        (0, hang_pose(A)),
        (6, A.merge(hang_pose(A), legs(2, -44, -25, 6, -36, -25), {"Spine": (4, 0, 0), "Head": (-8, 0, 0)})),
        (14, A.merge(hang_pose(A), legs(4, -72, -15, 6, -64, -15), {"Spine": (10, 0, 0), "Chest": (6, 0, 0),
                                                                     "Head": (0, 0, 0)})),
        (22, A.merge(hang_pose(A), legs(34, -55, -15, 8, -65, -15), lean,
                     {"Hips": (30, 0, 0), "Spine": (10, 0, 0), "Chest": (4, 0, 0)})),
        (28, _knee_up(A, hang_pose(A))),
        (32, _knee_up(A, arms(-10, -15, 30), left=(40, -110, -10))),
        (36, A.merge(A.CROUCH, {"Spine": (24, 0, 0)})),
        (44, A.IDLE),
    ]
    palms = _palms_at(Vector(), HANG_REACH, HANG_FWD, 0, CLIMB_HANDS_UNTIL)
    knee = [Plant("knee", "R", 27, 30, target=Vector((-0.1, -(HANG_WALL + 0.12), HANG_TOP + 0.06)))]
    feet = [Plant("foot", s, 36, 44, ground=HANG_TOP) for s in ("L", "R")]
    return bake(sk, "ClimbUp", keys, palms + knee + feet, CLIMB_PATH)


# Escalar obstáculo baixo (MANTLE_MIN..MANTLE_MAX acima dos pés): agacha (0-3), salta (3-7) até a raiz de contato
# K (punhos MANTLE_PALM_UP acima e MANTLE_PALM_FWD à frente dela, parede a MANTLE_WALL), empurra (7-12), joelho
# direito no topo (17-22), agachada (24) e de pé (30). O caminho do salto depende da altura e da distância (o
# Godot monta); daqui em diante é relativo a K. Para o build, o salto desenhado é o de um obstáculo de 1,1 m.
MANTLE_FRAMES = 30
MANTLE_HOP = (3, 7)
MANTLE_HANDS = (7, 18)
MANTLE_PALM_UP = 0.85
MANTLE_PALM_FWD = 0.32
MANTLE_WALL = 0.28
MANTLE_TOP = MANTLE_PALM_UP - 0.03
MANTLE_MIN, MANTLE_MAX = 0.8, 1.6
MANTLE_REL = [(7, 0.0, 0.0), (12, 0.02, 0.1), (18, 0.03, 0.12), (24, 0.42, MANTLE_TOP), (30, 0.5, MANTLE_TOP)]


def mantle_path(hop_fwd, hop_up):
    return [(0, 0.0, 0.0), (MANTLE_HOP[0], 0.0, 0.0)] + [(f, a + hop_fwd, b + hop_up) for f, a, b in MANTLE_REL]


def mantle_keys(A, sk):
    hop = (0.1, 1.1 - MANTLE_TOP)
    lean = {"Head": (-15, 0, 0)}
    reach = arms(50, -10, 40)
    keys = [
        (0, A.IDLE),
        (3, A.merge(arms(55, -10, 30), legs(42, -75, 22), {"loc": (0, -0.16, 0), "Spine": (18, 0, 0)})),
        (7, A.merge(reach, legs(40, -80, -10, 30, -60, -10), lean, {"Hips": (15, 0, 0), "Spine": (16, 0, 0)})),
        (12, A.merge(reach, legs(38, -55, -15, 20, -70, -15), lean, {"Hips": (30, 0, 0), "Spine": (10, 0, 0)})),
        (18, _knee_up(A, reach)),
        (21, _knee_up(A, arms(-10, -15, 30), left=(40, -110, -10))),
        (24, A.merge(A.CROUCH, {"Spine": (24, 0, 0)})),
        (30, A.IDLE),
    ]
    path = mantle_path(*hop)
    k = path_offset(path, MANTLE_HANDS[0])
    plants = [Plant("foot", s, 0, MANTLE_HOP[0]) for s in ("L", "R")]
    plants += _palms_at(k, MANTLE_PALM_UP, MANTLE_PALM_FWD, *MANTLE_HANDS)
    plants.append(Plant("knee", "R", 17, 20, target=k + Vector((-0.1, -(MANTLE_WALL + 0.12), MANTLE_TOP + 0.06))))
    plants += [Plant("foot", s, 24, 30, ground=k.z + MANTLE_TOP) for s in ("L", "R")]
    return bake(sk, "Mantle", keys, plants, path)


# ------------------------------------------------------------------ abate furtivo e golpe crítico
# Sair da escada pelo topo: do LadderIdle (raiz LADDER_RISE abaixo do piso de cima) a mão direita e depois a
# esquerda vão para a beirada (LADDER_EDGE à frente da escada, no topo do rebordo `lip`), os pés sobem os degraus
# e o corpo sobe puxando (até 26); depois se projeta por cima da beira com os braços esticados, apoia o joelho
# direito na beirada com a canela para dentro do furo (30-37), passa para agachada no piso (44) e fica de pé (54).
# Entrar pelo topo (LadderIn) é a mesma animação de trás para a frente: o Godot segue o mesmo caminho ao contrário.
# Caminho relativo à raiz na escada (os degraus LADDER_REACH à frente).
LADDER_FRAMES = 54
LADDER_RISE = 1.58  # da raiz no ciclo até o piso de cima: a mão esquerda do LadderIdle na barra do topo
LADDER_REACH = 0.22  # = RUNG_Y de heroine_anims.ladder_actions
LADDER_EDGE = 0.17  # da escada até as mãos (no alçapão: em cima do rebordo, perto da quina de fora)
LADDER_KNEE = 0.15  # da escada até o joelho (no alçapão: em cima do rebordo)
LADDER_LIP = 0.12  # = Hatch.CURB_H; no mezanino a beirada é o próprio piso (0)
LADDER_PATH = [(0, 0.0, 0.0), (10, 0.0, 0.02), (18, 0.0, 0.2), (22, 0.0, 0.45), (26, 0.0, 0.72),
               (30, -0.08, 0.98), (37, -0.05, 1.0), (44, 0.6, LADDER_RISE), (54, 0.72, LADDER_RISE)]
LADDER_HAND_X = 0.24  # mãos mais abertas: o joelho direito apoia entre elas


def ladder_path(lip):
    """Caminho da saída para uma beirada `lip` acima do piso: com as mãos e o joelho mais baixos, o corpo também."""
    return [(f, a, b - (LADDER_LIP - lip) if 22 <= f <= 37 else b) for f, a, b in LADDER_PATH]


def _track(keys, lift=0.0, back=0.0):
    """Alvo que passa de um apoio para o outro: [(quadro, ponto), ...]; no meio de cada troca sobe `lift` e
    afasta `back` da escada (a mão/o pé contorna o degrau)."""
    def at(f):
        if f <= keys[0][0]:
            return keys[0][1]
        for (f0, a), (f1, b) in zip(keys, keys[1:]):
            if f <= f1:
                s = (f - f0) / (f1 - f0)
                bump = math.sin(math.pi * s) if (b - a).length > 1e-4 else 0.0
                return a.lerp(b, s * s * (3.0 - 2.0 * s)) + Vector((0.0, back * bump, lift * bump))
        return keys[-1][1]
    return at


def ladder_out_keys(A, sk, idle, lip, name="LadderOut"):
    m = sk.matrices(idle)
    hl, hr = IK.palm(sk, m, "L"), IK.palm(sk, m, "R")
    fl, fr = sk.point(m, "Foot_L"), sk.point(m, "Foot_R")
    edge_y = -(LADDER_REACH + LADDER_EDGE)
    edge_z = LADDER_RISE + lip + 0.03  # o punho fechado fica por cima da beirada
    step = Vector((0.0, 0.0, 0.3))
    lean = {"Hips": (34, 0, 0), "Spine": (18, 0, 0), "Chest": (8, 0, 0), "Neck": (-10, 0, 0), "Head": (-30, 0, 0)}
    keys = [
        (0, idle),
        (8, idle),
        (14, A.merge(idle, {"Spine": (4, 0, 0), "Head": (-6, 0, 0)})),
        (22, A.merge(idle, {"Head": (-10, 0, 0)})),
        # puxando, o tronco começa a passar da beira
        (26, A.merge(idle, {"Hips": (10, 0, 0), "Spine": (8, 0, 0), "Chest": (4, 0, 0), "Head": (-14, 0, 0)})),
        # por cima da beira, braços esticados empurrando; o joelho direito sobe para a beirada, canela para dentro
        (30, A.merge(no_legs(idle), lean, legs(0, -30, 0, 70, -90, 0))),
        # mãos soltam e vão para a frente; o peso passa para o joelho
        (37, A.merge(lean, {"Hips": (10, 0, 0), "Spine": (5, 0, 0)}, arms(45, -12, 25), legs(0, -40, 0, 60, -80, 0))),
        (44, A.merge(A.CROUCH, {"Spine": (24, 0, 0)})),
        (LADDER_FRAMES, A.IDLE),
    ]
    hand_l = Vector((LADDER_HAND_X, edge_y, edge_z))
    hand_r = Vector((-LADDER_HAND_X, edge_y, edge_z))
    plants = [
        Plant("palm", "R", 0, 34, target=_track([(0, hr), (10, hand_r)], 0.08, 0.06)),
        Plant("palm", "L", 0, 34, target=_track([(6, hl), (14, hand_l)], 0.06, 0.06)),
        Plant("foot", "R", 0, 22, target=_track([(4, fr), (10, fr + step)], 0.06, 0.08)),
        Plant("foot", "L", 0, 38, target=_track([(10, fl), (17, fl + step * 2), (21, fl + step * 2),
                                                 (26, fl + step * 3 + Vector((0.0, 0.0, 0.08)))], 0.06, 0.08)),
        Plant("knee", "R", 30, 37, target=Vector((-0.08, -(LADDER_REACH + LADDER_KNEE), LADDER_RISE + lip + 0.06))),
    ]
    plants += [Plant("foot", s, 44, LADDER_FRAMES, ground=LADDER_RISE) for s in ("L", "R")]
    return _hands_on_edge(sk, bake(sk, name, keys, plants, ladder_path(lip)))


LADDER_HAND_DIR = Vector((0.0, -1.0, -0.45)).normalized()  # mão na beirada: para a frente (lado da escada), descendo
# mão de cada lado: (começa a girar, já apoiada, solta da beirada, volta ao que a pose desenha)
LADDER_HAND_TURN = {"R": (6, 10, 34, 38), "L": (10, 14, 34, 38)}


def _hands_on_edge(sk, keys):
    """Mãos apoiadas na beirada viradas para a frente, em vez do punho dobrado de quem segura o degrau: gira a mão
    (e o antebraço) com o punho preso onde a IK dos apoios deixou."""
    out = []
    worst = 0.0
    for f, pose in keys:
        for s, (a, b, c, d) in LADDER_HAND_TURN.items():
            w = min(max((f - a) / (b - a), 0.0), 1.0) * min(max((d - f) / (d - c), 0.0), 1.0)
            if w <= 0.0:
                continue
            m = sk.matrices(pose)
            at = IK.palm(sk, m, s)
            now = (IK.palm(sk, m, s) - sk.point(m, f"Hand_{s}")).normalized()
            want = now.lerp(LADDER_HAND_DIR, w * w * (3.0 - 2.0 * w)).normalized()

            def res(mm, s=s, at=at, want=want):
                tip = sk.point(mm, f"Hand_{s}")
                return list(IK.palm(sk, mm, s) - at) + list(((IK.palm(sk, mm, s) - tip).normalized() - want) * 0.2)

            pose, _ = IK.solve(sk, pose, IK.arm_unknowns(s, hand=True), res, IK.arm_bounds(s))
            worst = max(worst, (IK.palm(sk, sk.matrices(pose), s) - at).length)
        out.append((f, pose))
    print(f"[moves] mãos na beirada: punho saiu do lugar no máximo {worst * 1000:.1f} mm")
    return out


def reverse(keys):
    """A animação de trás para a frente (entrar na escada pelo topo = sair ao contrário)."""
    n = keys[-1][0]
    return [(n - f, pose) for f, pose in reversed(keys)]


def data(gait_defs):
    """Medidas que o Godot usa (heroine_moves.json)."""
    import heroine_strike as ST
    return {
        "fps": FPS,
        "speeds": {k: g.speed for k, g in gait_defs.items()},
        "roll": {"frames": ROLL_FRAMES, "path": ROLL_PATH},
        "hang": {"reach": HANG_REACH, "fwd": HANG_FWD, "wall": HANG_WALL, "top": HANG_TOP},
        "climb": {"frames": CLIMB_FRAMES, "hands_until": CLIMB_HANDS_UNTIL, "path": CLIMB_PATH},
        "mantle": {"frames": MANTLE_FRAMES, "hop": list(MANTLE_HOP), "hands": list(MANTLE_HANDS), "rel": MANTLE_REL,
                   "palm_up": MANTLE_PALM_UP, "palm_fwd": MANTLE_PALM_FWD, "wall": MANTLE_WALL, "top": MANTLE_TOP,
                   "min": MANTLE_MIN, "max": MANTLE_MAX},
        "ladder": {"frames": LADDER_FRAMES, "rise": LADDER_RISE, "reach": LADDER_REACH, "lip": LADDER_LIP,
                   "path": ladder_path(LADDER_LIP), "path_low": ladder_path(0.0)},
        "assassinate": {"frames": ST.ASSASSINATE_FRAMES, "hit": ST.ASSASSINATE_HIT, "path": ST.ASSASSINATE_PATH},
        "crit_strike": {"frames": ST.CRIT_FRAMES, "hit": ST.CRIT_HIT, "path": ST.CRIT_PATH},
    }


SHOULDER_DESIGN, ARM_DESIGN = 1.385, 0.485  # ombro (altura) e braço (ombro ao punho) das medidas acima


def adapt(spec):
    """Borda e obstáculo para outro corpo (heroine_spec.use_joints): as mãos ficam onde o braço dele alcança.
    Pendurada, o punho fica a ombro + braço (menos a mesma folga) acima dos pés; subindo, o corpo só vai até onde o
    braço ainda segura a borda; escalando, o punho no topo fica a ombro - braço acima da raiz."""
    global HANG_REACH, HANG_TOP, HANG_FWD, HANG_WALL, CLIMB_PATH, MANTLE_PALM_UP, MANTLE_TOP, MANTLE_REL
    ds = spec.SHOULDER_L.z - SHOULDER_DESIGN
    da = spec.UPPER_ARM_LEN + spec.FOREARM_LEN - ARM_DESIGN
    reach_old = HANG_REACH
    HANG_REACH = reach_old + ds + da - 0.02  # 2 cm de folga: o braço não fica esticado no limite
    HANG_TOP = HANG_REACH - 0.03
    # ombro mais para trás (y do repouso): o corpo pendura mais perto da parede, a mão fica no mesmo lugar da borda
    back = max(0.0, spec.SHOULDER_L.y) + 0.02
    HANG_FWD -= back
    HANG_WALL -= back
    # subida máxima com as mãos na borda: ombro ao punho no máximo braço + mão (0,06)
    k = (ARM_DESIGN + da + 0.06 - SHOULDER_DESIGN - ds + HANG_REACH) / (ARM_DESIGN + 0.06 - SHOULDER_DESIGN + reach_old)
    globals()["_K"] = k
    CLIMB_PATH = [(f, a, b * k if f <= CLIMB_HANDS_UNTIL else HANG_TOP) for f, a, b in CLIMB_PATH]
    MANTLE_PALM_UP = MANTLE_PALM_UP + ds - da
    MANTLE_TOP = MANTLE_PALM_UP - 0.03
    MANTLE_REL = [(f, a, MANTLE_TOP if f >= 24 else b) for f, a, b in MANTLE_REL]
