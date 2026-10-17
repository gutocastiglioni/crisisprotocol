"""Animações do velociraptor em keyframes (30 fps), com IK nas pernas para os pés ficarem plantados.

Convenção dos ângulos (graus, euler ZYX local de cada osso):
  Corpo, pescoço, cabeça, mandíbula, cauda e dedos (Z local para cima):
    X > 0  levanta a ponta do osso (cabeça para cima, cauda para cima). Mandíbula abre com X < 0.
    Z > 0  gira no sentido anti-horário visto de cima (cabeça para a esquerda dele, cauda para a direita).
    Y > 0  rola em torno do próprio osso.
  Pernas e braços (Z local para a frente):
    X > 0  leva a ponta do osso para a frente. Z > 0 afasta do corpo.
Os ossos _R são escritos com o mesmo significado do lado _L; a conversão de sinal é feita no apply_pose.
"loc" move o quadril: (0, frente, cima) em metros.

Perna no plano sagital (f = frente = -Y do Blender, u = altura): todos os ossos da perna e o quadril
giram em torno de -X do mundo, então +X = anti-horário no plano (f, u) e os ângulos se somam na cadeia.
"""
import math

import bpy

import raptor_spec as S
from heroine_anims import apply_pose, merge, mirror

FPS = 30


def _fu(v):
    return (-v.y, v.z)


def _ang(a, b):
    return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))


def _dist(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])


HIP_HEAD, HIP, KNEE, ANKLE, BALL, TOE = (_fu(p) for p in (S.HIP_HEAD, S.HIP_JOINT, S.KNEE, S.ANKLE, S.BALL, S.TOE_TIP))
L_THIGH, L_SHIN, L_META = _dist(HIP, KNEE), _dist(KNEE, ANKLE), _dist(ANKLE, BALL)
REST = {
    "thigh": _ang(HIP, KNEE),
    "shin": _ang(KNEE, ANKLE),
    "meta": _ang(ANKLE, BALL),
    "toe": _ang(BALL, TOE),
}
GROUND = BALL[1]  # altura da bola do pé apoiada


def leg_ik(pose, s, ball, meta=None, toe=None):
    """Ângulos X da perna `s` para a bola do pé ficar em `ball` (f, u), com o metatarso e os dedos
    nos ângulos de mundo `meta` e `toe` (graus; None = os da pose de descanso)."""
    meta = REST["meta"] if meta is None else meta
    toe = REST["toe"] if toe is None else toe
    _, df, du = pose.get("loc", (0, 0, 0))
    pitch = pose.get("Hips", (0, 0, 0))[0]
    p = math.radians(pitch)
    rx, ru = HIP[0] - HIP_HEAD[0], HIP[1] - HIP_HEAD[1]
    hip = (HIP_HEAD[0] + df + rx * math.cos(p) - ru * math.sin(p), HIP_HEAD[1] + du + rx * math.sin(p) + ru * math.cos(p))
    m = math.radians(meta)
    ankle = (ball[0] - L_META * math.cos(m), ball[1] - L_META * math.sin(m))
    d = min(max(_dist(hip, ankle), abs(L_THIGH - L_SHIN) + 1e-3), L_THIGH + L_SHIN - 1e-4)
    alpha = math.degrees(math.acos((L_THIGH ** 2 + d ** 2 - L_SHIN ** 2) / (2 * L_THIGH * d)))
    thigh = _ang(hip, ankle) + alpha  # joelho para a frente
    knee = (hip[0] + L_THIGH * math.cos(math.radians(thigh)), hip[1] + L_THIGH * math.sin(math.radians(thigh)))
    shin = _ang(knee, ankle)
    return {
        f"Thigh_{s}": (thigh - REST["thigh"] - pitch, 0, 0),
        f"Shin_{s}": ((shin - thigh) - (REST["shin"] - REST["thigh"]), 0, 0),
        f"Meta_{s}": ((meta - shin) - (REST["meta"] - REST["shin"]), 0, 0),
        f"Toe_{s}": ((toe - meta) - (REST["toe"] - REST["meta"]), 0, 0),
    }


def ground(pose, feet=None):
    """Planta os dois pés (bola do pé em `feet[s]` = (f, u[, meta, toe])) e devolve a pose com as pernas."""
    feet = feet or STANCE
    out = dict(pose)
    for s in ("L", "R"):
        out.update(leg_ik(pose, s, *_foot(feet[s])))
    return out


def _foot(spec):
    f, u = spec[0], spec[1]
    rest = spec[2:] + (None,) * (4 - len(spec))
    return ((f, u),) + tuple(rest[:2])


STANCE = {"L": (BALL[0] + 0.08, GROUND), "R": (BALL[0] - 0.12, GROUND)}
FEET_TOGETHER = {"L": (BALL[0] + 0.02, GROUND), "R": (BALL[0] - 0.06, GROUND)}

ARMS_TUCKED = {
    "Arm_L": (20, 0, 8), "Forearm_L": (40, 0, 0), "Hand_L": (-20, 0, 0),
    "Arm_R": (20, 0, 8), "Forearm_R": (40, 0, 0), "Hand_R": (-20, 0, 0),
}
ARMS_OUT = {
    "Arm_L": (60, 0, 35), "Forearm_L": (10, 0, 0), "Hand_L": (-10, 0, 0),
    "Arm_R": (60, 0, 35), "Forearm_R": (10, 0, 0), "Hand_R": (-10, 0, 0),
}
IDLE = merge(ARMS_TUCKED, {
    "loc": (0, 0, -0.03),
    "Neck1": (-6, 0, 0), "Neck2": (-4, 0, 0), "Head": (6, 0, 0),
    "Tail1": (3, 0, 0), "Tail2": (2, 0, 0),
})


def tail_wave(amp, phase, lag=0.12):
    """Balanço lateral da cauda, cada segmento atrasado em relação ao anterior."""
    return {f"Tail{i + 1}": (0, 0, amp * (0.6 + 0.25 * i) * math.sin(2 * math.pi * (phase - lag * i))) for i in range(4)}


def gait(frames, step, stride, duty, lift, height, bob, upper, pitch=0.0, sway=5.0):
    """Ciclo de passos gerado: os pés deslizam para trás no apoio e voltam pelo ar no balanço."""
    keys = []
    for k in range(0, frames + 1, step):
        ph = (k / frames) % 1.0
        pose = merge(upper, tail_wave(sway, ph), {
            "loc": (0, 0, height + bob * math.cos(4 * math.pi * ph)),
            "Hips": (pitch, 0, 1.5 * math.sin(2 * math.pi * ph)),
        })
        feet = {}
        for s, off in (("L", 0.0), ("R", 0.5)):
            q = (ph + off) % 1.0
            front, back = BALL[0] + stride * 0.5, BALL[0] - stride * 0.5
            if q < duty:
                feet[s] = (front + (back - front) * q / duty, GROUND)
            else:
                t = (q - duty) / (1 - duty)
                e = t * t * (3 - 2 * t)
                arc = math.sin(math.pi * t)
                feet[s] = (back + (front - back) * e, GROUND + lift * arc, REST["meta"] - 40 * arc, REST["toe"] - 50 * arc)
        keys.append((k, ground(pose, feet)))
    return keys


def roar_keys():
    antic = ground(merge(IDLE, {"loc": (0, 0, -0.09), "Neck1": (-18, 0, 0), "Neck2": (-8, 0, 0), "Head": (-8, 0, 0), "Chest": (-4, 0, 0)}))
    roar = merge(ARMS_OUT, {
        "loc": (0, -0.03, 0.02), "Hips": (6, 0, 0), "Spine": (6, 0, 0), "Chest": (8, 0, 0),
        "Neck1": (22, 0, 0), "Neck2": (10, 0, 0), "Head": (0, 0, 0), "Jaw": (-36, 0, 0),
        "Tail1": (10, 0, 0), "Tail2": (8, 0, 0), "Tail3": (6, 0, 0),
    })
    shake = lambda z, jaw: ground(merge(roar, {"Head": (0, 0, z), "Neck2": (0, 0, z * 0.5), "Jaw": (jaw + 36, 0, 0)}))
    return [
        (0, ground(IDLE)), (8, antic), (16, ground(roar)),
        (20, shake(5, -31)), (24, shake(-5, -39)), (28, shake(5, -31)), (32, shake(-5, -39)),
        (37, ground(roar)), (46, ground(merge(IDLE, {"Jaw": (-10, 0, 0)}))), (54, ground(IDLE)),
    ]


def study_keys():
    """Análise do oponente: inclina a cabeça para um lado e para o outro, fareja o chão."""
    look = lambda k: ground(merge(IDLE, {"Neck2": (0, 0, 18 * k), "Head": (0, 22 * k, 12 * k), "Neck1": (-4, 0, 0), "Jaw": (-6, 0, 0)}))
    sniff = ground(merge(IDLE, {"loc": (0, 0.0, -0.06), "Chest": (-5, 0, 0), "Neck1": (-22, 0, 0), "Neck2": (-6, 0, 0), "Head": (-4, 0, 0), "Jaw": (-4, 0, 0)}))
    return [(0, ground(IDLE)), (14, look(1)), (26, look(0.85)), (38, sniff), (50, look(-1)), (62, look(-0.85)), (72, ground(IDLE))]


CROUCH = merge(ARMS_TUCKED, {
    "loc": (0, 0.02, -0.22), "Hips": (-10, 0, 0), "Neck1": (-15, 0, 0), "Head": (10, 0, 0),
    "Tail1": (8, 0, 0), "Jaw": (-15, 0, 0), "Arm_L": (30, 0, 7), "Arm_R": (30, 0, 7),
})
POUNCE = merge(ARMS_OUT, {
    "Hips": (10, 0, 0), "Neck1": (-10, 0, 0), "Jaw": (-45, 0, 0), "Tail1": (-5, 0, 0),
    "Arm_L": (10, 0, -10), "Arm_R": (10, 0, -10),
    "Thigh_L": (55, 0, 6), "Shin_L": (-40, 0, 0), "Meta_L": (60, 0, 0), "Toe_L": (-30, 0, 0),
    "Thigh_R": (50, 0, 6), "Shin_R": (-35, 0, 0), "Meta_R": (55, 0, 0), "Toe_R": (-30, 0, 0),
})
PUSH = merge(ARMS_OUT, {
    "Hips": (-4, 0, 0), "Neck1": (-12, 0, 0), "Jaw": (-30, 0, 0),
    "Thigh_L": (-25, 0, 0), "Shin_L": (25, 0, 0), "Meta_L": (-10, 0, 0), "Toe_L": (-30, 0, 0),
    "Thigh_R": (-20, 0, 0), "Shin_R": (20, 0, 0), "Meta_R": (-10, 0, 0), "Toe_R": (-30, 0, 0),
})

LUNGE = merge(ARMS_TUCKED, {
    "loc": (0, 0.18, -0.08), "Hips": (-4, 0, 0), "Chest": (-4, 0, 0),
    "Neck1": (-24, 0, 0), "Neck2": (-6, 0, 0), "Head": (20, 0, 0), "Jaw": (-42, 0, 0),
    "Arm_L": (60, 0, 15), "Arm_R": (60, 0, 15),
})


def bite_keys():
    wind = ground(merge(IDLE, {"loc": (0, -0.06, -0.05), "Hips": (4, 0, 0), "Neck1": (12, 0, 0), "Neck2": (6, 0, 0), "Head": (8, 0, 0), "Jaw": (-12, 0, 0)}))
    snap = ground(merge(LUNGE, {"Jaw": (42, 0, 0), "Head": (-4, 0, 0)}), FEET_TOGETHER)
    return [(0, ground(IDLE)), (5, wind), (9, ground(LUNGE, FEET_TOGETHER)), (12, snap), (16, snap), (24, ground(IDLE))]


def shake_keys():
    """Segura a presa na boca e sacode a cabeça de um lado para o outro."""
    hold = merge(LUNGE, {"Jaw": (38, 0, 0), "loc": (0, 0.12, -0.1)})
    side = lambda k: ground(merge(hold, {
        "Chest": (0, 0, 10 * k), "Neck1": (0, 0, 18 * k), "Neck2": (0, 0, 14 * k), "Head": (0, 12 * k, 10 * k),
        "Tail2": (0, 0, -10 * k), "Tail3": (0, 0, -12 * k),
    }), FEET_TOGETHER)
    return [(0, side(1)), (3, side(0)), (6, side(-1)), (9, side(0)), (12, side(1))]


def tail_whip_keys():
    """Rabada: a cauda carrega para um lado e varre o outro (o jogo gira o corpo junto)."""
    tail = lambda z, x=0: {f"Tail{i + 1}": (x, 0, z * (0.8 + 0.12 * i)) for i in range(4)}
    wind = ground(merge(IDLE, tail(14), {"loc": (0, 0, -0.08), "Hips": (-6, 0, 0), "Spine": (0, 0, 10), "Chest": (0, 0, 12), "Neck1": (0, 0, 10)}))
    whip = ground(merge(IDLE, tail(-22, 6), {"loc": (0, 0, -0.06), "Spine": (0, 0, -12), "Chest": (0, 0, -10), "Neck1": (0, 0, -8), "Jaw": (-20, 0, 0)}))
    follow = ground(merge(IDLE, tail(-26, 3), {"loc": (0, 0, -0.05), "Spine": (0, 0, -8), "Chest": (0, 0, -6), "Jaw": (-14, 0, 0)}))
    return [(0, ground(IDLE)), (7, wind), (12, whip), (16, follow), (26, ground(IDLE))]


def death_keys():
    rear = ground(merge(IDLE, {"Hips": (10, 0, 0), "Neck1": (25, 0, 0), "Head": (20, 0, 0), "Jaw": (-40, 0, 0)}))
    legs = lambda k: {f"{b}_{s}": (a * k, 0, 0) for s in ("L", "R") for b, a in (("Thigh", 30), ("Shin", -35), ("Meta", 25), ("Toe", -20))}
    falling = merge(IDLE, legs(0.5), {"loc": (0, 0, -0.35), "Hips": (0, 40, 0), "Neck1": (-10, 0, 0), "Jaw": (-30, 0, 0)})
    down = merge(ARMS_TUCKED, legs(1), {
        "loc": (0, 0, -0.71), "Hips": (0, 84, 0), "Neck1": (-25, 0, 0), "Neck2": (-15, 0, 0), "Head": (-10, 0, 0),
        "Jaw": (-25, 0, 0), "Tail1": (8, 0, 0), "Tail2": (10, 0, 0),
    })
    return [(0, ground(IDLE)), (6, rear), (16, falling), (26, down), (36, merge(down, {"Head": (-4, 0, 0)}))]


def actions():
    """nome -> lista de (frame, pose)."""
    walk_up = merge(ARMS_TUCKED, {"Neck1": (-12, 0, 0), "Head": (10, 0, 0), "Tail1": (2, 0, 0)})
    run_up = merge(ARMS_TUCKED, {
        "Neck1": (-20, 0, 0), "Neck2": (-5, 0, 0), "Head": (18, 0, 0), "Jaw": (-10, 0, 0),
        "Tail1": (6, 0, 0), "Arm_L": (40, 0, 8), "Arm_R": (40, 0, 8), "Forearm_L": (60, 0, 0), "Forearm_R": (60, 0, 0),
    })
    breath = ground(merge(IDLE, tail_wave(4, 0.25), {"loc": (0, 0, -0.035), "Chest": (2, 0, 0), "Neck1": (3, 0, 0), "Head": (-3, 0, 0)}))
    return {
        "Idle": [(0, ground(IDLE)), (30, breath), (60, ground(IDLE))],
        "Walk": gait(36, 3, stride=0.8, duty=0.62, lift=0.12, height=-0.04, bob=0.012, upper=walk_up),
        "Run": gait(18, 2, stride=1.0, duty=0.4, lift=0.18, height=-0.07, bob=0.03, upper=run_up, pitch=-6, sway=3),
        "Roar": roar_keys(),
        "Study": study_keys(),
        "LeapPrep": [(0, ground(IDLE)), (9, ground(CROUCH, FEET_TOGETHER))],
        "LeapAir": [(0, ground(CROUCH, FEET_TOGETHER)), (3, PUSH), (10, POUNCE), (14, POUNCE)],
        "Bite": bite_keys(),
        "Shake": shake_keys(),
        "TailWhip": tail_whip_keys(),  # cauda varre para a esquerda dele
        "TailWhipR": [(f, mirror(p)) for f, p in tail_whip_keys()],
        "Hit": [(0, ground(IDLE)), (3, ground(merge(IDLE, {"loc": (0, -0.07, -0.02), "Chest": (-8, 0, 0), "Neck1": (16, 0, 0), "Neck2": (8, 0, 0), "Head": (14, 0, 0), "Jaw": (-26, 0, 0)}))), (14, ground(IDLE))],
        "Death": death_keys(),
    }


def build_actions(rig):
    rig.animation_data_create()
    made = []
    for name, keys in actions().items():
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
        made.append(act)
    rig.animation_data.action = None
    apply_pose(rig, {})
    return made
