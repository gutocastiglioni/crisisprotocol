"""Movimentos com deslocamento: cambalhota com projeção, pulo/queda, pendurar, subir da borda e escalar
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


def path_offset(path, f):
    """Deslocamento da raiz no quadro f, no espaço do Blender (frente = -Y)."""
    if not path:
        return Vector((0, 0, 0))
    fr = [k[0] for k in path]
    return Vector((0.0, -hermite(fr, [k[1] for k in path], f), hermite(fr, [k[2] for k in path], f)))


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


def bake(sk, name, keys, plants=(), path=None, fix=None):
    """Um quadro-chave por quadro: pose desenhada interpolada, ajuste `fix(pose, f)` e apoios resolvidos
    (cada apoio parte da solução do quadro anterior: sem saltos de um quadro para o outro)."""
    held = {}
    out = []
    worst, where = 0.0, ""
    for f in range(keys[-1][0] + 1):
        pose = interp_pose(keys, f)
        if fix:
            pose = fix(pose, f)
        off = path_offset(path, f)
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
        "crouch_walk": G.Gait(n=16, speed=0.8, stance=0.65, hip=-0.33, bob=0.01, sway=0.015, turn=3.0,
                              lift=0.07, heel=6.0, toe_off=-14.0, swing_arm=0.0, upper=crouch_upper),
        "strafe": G.Gait(n=10, speed=0.75, travel=(1.0, 0.0), stance=0.5, hip=-0.04, bob=0.008, lift=0.05,
                         width=0.08, heel=0.0, toe_off=0.0, swing_arm=0.0, upper=no_legs(A.AIM)),
        "crouch_strafe": G.Gait(n=14, speed=0.45, travel=(1.0, 0.0), stance=0.55, hip=-0.33, bob=0.006,
                                lift=0.06, width=0.1, heel=0.0, toe_off=0.0, swing_arm=0.0, upper=crouch_aim),
    }



# ------------------------------------------------------------------ cambalhota com projeção
# já sai andando no primeiro quadro (sem preparar parada no lugar): mergulha o tronco e empurra (0-5), voa na
# horizontal com os braços à frente (5-12), mãos no chão (13), rola encolhida sobre as costas (13-25), pés no chão
# e levanta (28-34). O corpo gira em volta do centro do "novelo" (ROLL_C), não do quadril, e o caminho da raiz
# acompanha o giro (centro anda giro x raio): rola sem patinar e sai lá na frente.
ROLL_FRAMES = 34
ROLL_PATH = [(0, 0.0, 0.0), (1, 0.1, 0.0), (2, 0.22, 0.0), (5, 0.75, 0.0), (10, 1.65, 0.0), (13, 2.1, 0.0),
             (25, 4.0, 0.0), (28, 4.12, 0.0), (34, 4.18, 0.0)]
ROLL_C = Vector((0.0, 0.26, 0.08))  # centro do corpo encolhido no espaço do quadril (esquerda, cima, frente)


def roll_keys(A, sk):
    tuck = A.merge(arms(40, -10, 95), {"Hand_L": (-20, 0, 0), "Hand_R": (-20, 0, 0)})
    tucked_legs = legs(105, -135, 30)
    keys = [
        (0, A.merge(A.IDLE, {"_th": 0, "_ch": 1.215, "_cf": 0.08})),
        # mergulha o tronco já indo para a frente, braços lançando
        (2, A.merge(arms(40, -8, 25), legs(40, -60, 10), {"Spine": (12, 0, 0), "Head": (-12, 0, 0),
                                                         "_th": 25, "_ch": 0.98, "_cf": 0.26})),
        (5, A.merge(arms(120, -10, 15), legs(12, -25, -20, -15, -40, -10), {"Spine": (5, 0, 0), "Head": (-30, 0, 0),
                                                                           "_th": 52, "_ch": 1.04, "_cf": 0.44})),
        (10, A.merge(arms(165, -8, 10), legs(-6, -10, -30, -14, -20, -30), {"Spine": (-4, 0, 0), "Head": (-45, 0, 0),
                                                                           "_th": 85, "_ch": 0.88, "_cf": 0.55})),
        # mãos no chão, queixo no peito: rola por cima dos ombros e das costas, nunca da cabeça
        (13, A.merge(arms(150, -12, 45), legs(30, -60, -10), {"Spine": (25, 0, 0), "Neck": (20, 0, 0),
                                                             "Head": (55, 0, 0), "_th": 112, "_ch": 0.66, "_cf": 0.45})),
        (16, A.merge(tuck, tucked_legs, {"Spine": (40, 0, 0), "Chest": (20, 0, 0), "Neck": (30, 0, 0), "Head": (60, 0, 0),
                                         "_th": 165, "_ch": 0.46, "_cf": 0.32})),
        (21, A.merge(tuck, tucked_legs, {"Spine": (40, 0, 0), "Chest": (20, 0, 0), "Neck": (15, 0, 0), "Head": (40, 0, 0),
                                         "_th": 245, "_ch": 0.42, "_cf": 0.18})),
        (25, A.merge(tuck, legs(100, -130, 35), {"Spine": (35, 0, 0), "Chest": (15, 0, 0), "Head": (30, 0, 0),
                                                 "_th": 318, "_ch": 0.5, "_cf": 0.1})),
        (28, A.merge(A.CROUCH, {"Spine": (30, 0, 0), "_th": 362, "_ch": 0.84, "_cf": 0.08})),
        (31, A.merge(A.CROUCH, {"loc": (0, -0.2, 0), "Spine": (14, 0, 0), "_th": 361, "_ch": 1.02, "_cf": 0.07})),
        (34, A.merge(A.IDLE, {"_th": 360, "_ch": 1.215, "_cf": 0.08})),
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

    plants = [Plant("foot", s, 0, 1) for s in ("L", "R")]
    plants += [Plant("palm", s, 12, 15, ground=0.0) for s in ("L", "R")]
    plants += [Plant("foot", s, 28, 34) for s in ("L", "R")]
    return bake(sk, "Roll", keys, plants, ROLL_PATH, fix)


# ------------------------------------------------------------------ pulo e queda (o Godot faz a física)
def jump_keys(A):
    takeoff = A.merge(A.IDLE, arms(-20, -6, 25), legs(35, -60, 18), {"loc": (0, -0.1, 0), "Spine": (10, 0, 0)})
    stretch = A.merge(arms(50, -15, 20), legs(5, -6, -30, 0, -4, -35), {"loc": (0, 0.02, 0), "Spine": (-4, 0, 0),
                                                                      "Head": (-6, 0, 0)})
    tuck = A.merge(arms(30, -35, 40), legs(42, -72, -12, 26, -50, -18), {"Spine": (6, 0, 0), "Head": (4, 0, 0)})
    return [(0, takeoff), (3, stretch), (9, tuck), (14, tuck)]


def fall_keys(A):
    a = A.merge(arms(22, -45, 30), legs(25, -45, -15, 10, -30, -20), {"Spine": (4, 0, 0), "Head": (6, 0, 0)})
    b = A.merge(arms(18, -50, 35), legs(12, -32, -20, 28, -50, -15), {"Spine": (4, 0, 0), "Head": (6, 0, 0)})
    return [(0, a), (15, b), (30, a)]


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


def _knee_up(A, arm_pose):
    """Joelho direito subindo para o topo, perna esquerda pendurada, tronco por cima da borda."""
    return A.merge(arm_pose, legs(-30, -20, -20, 75, -120, 10),
                   {"loc": (0, -0.04, 0), "Hips": (32, 0, 0), "Spine": (12, 0, 0), "Head": (-20, 0, 0), "Neck": (-5, 0, 0)})


def climb_keys(A, sk):
    lean = {"Head": (-20, 0, 0), "Neck": (-5, 0, 0)}
    keys = [
        (0, hang_pose(A)),
        (6, A.merge(hang_pose(A), legs(24, -40, -30, 14, -30, -30), {"Spine": (4, 0, 0), "Head": (-8, 0, 0)})),
        (14, A.merge(hang_pose(A), legs(36, -62, -25, 24, -50, -25), {"Spine": (10, 0, 0), "Chest": (6, 0, 0),
                                                                     "Head": (0, 0, 0)})),
        (22, A.merge(hang_pose(A), legs(-28, -20, -20, -32, -16, -20), lean,
                     {"Hips": (30, 0, 0), "Spine": (10, 0, 0), "Chest": (4, 0, 0)})),
        (28, _knee_up(A, hang_pose(A))),
        (32, _knee_up(A, arms(-10, -15, 30))),
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
        (12, A.merge(reach, legs(-20, -30, -15, -24, -25, -15), lean, {"Hips": (30, 0, 0), "Spine": (10, 0, 0)})),
        (18, _knee_up(A, reach)),
        (21, _knee_up(A, arms(-10, -15, 30))),
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

def data(gait_defs):
    """Medidas que o Godot usa (heroine_moves.json)."""
    return {
        "fps": FPS,
        "speeds": {k: g.speed for k, g in gait_defs.items()},
        "roll": {"frames": ROLL_FRAMES, "path": ROLL_PATH},
        "hang": {"reach": HANG_REACH, "fwd": HANG_FWD, "wall": HANG_WALL, "top": HANG_TOP},
        "climb": {"frames": CLIMB_FRAMES, "hands_until": CLIMB_HANDS_UNTIL, "path": CLIMB_PATH},
        "mantle": {"frames": MANTLE_FRAMES, "hop": list(MANTLE_HOP), "hands": list(MANTLE_HANDS), "rel": MANTLE_REL,
                   "palm_up": MANTLE_PALM_UP, "palm_fwd": MANTLE_PALM_FWD, "wall": MANTLE_WALL, "top": MANTLE_TOP,
                   "min": MANTLE_MIN, "max": MANTLE_MAX},
    }
