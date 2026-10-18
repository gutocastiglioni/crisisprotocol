"""Animações do alossauro em keyframes (30 fps), mesma convenção de ângulos de `raptor_anims.py` (ver o cabeçalho de lá).
Parado, andar, correr, rugido (o de quando a vê, cabeça para cima), rugido na batalha (abaixado, voltado para ela),
farejar, pisada, mordida (bote baixo até a altura de uma pessoa), sacudir a presa, arremesso, cabeçada e rabada (dos dois
lados) e reação a tiro. A morte é ragdoll (Godot). Os quadros que o jogo usa estão nas constantes abaixo.

O IK das pernas e o ciclo de passos são os do raptor: `base` é uma cópia de `raptor_anims` carregada com as medidas do
alossauro no lugar de `raptor_spec` (mesmos nomes de ossos), então `ground`/`leg_ik`/`gait` plantam os pés dele.
"""
import importlib.util
import sys
from pathlib import Path

import bpy

import allosaurus_spec
from heroine_anims import apply_pose, merge, mirror

FPS = 30


def _load_base():
    saved = sys.modules.get("raptor_spec")
    sys.modules["raptor_spec"] = allosaurus_spec
    try:
        spec = importlib.util.spec_from_file_location("allosaurus_ik", Path(__file__).with_name("raptor_anims.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    finally:
        if saved is None:
            sys.modules.pop("raptor_spec", None)
        else:
            sys.modules["raptor_spec"] = saved
    return mod


base = _load_base()
BALL, GROUND = base.BALL, base.GROUND
STANCE = {"L": (BALL[0] + 0.22, GROUND), "R": (BALL[0] - 0.30, GROUND)}

ARMS = {
    "Arm_L": (25, 0, 6), "Forearm_L": (35, 0, 0), "Hand_L": (-15, 0, 0),
    "Arm_R": (25, 0, 6), "Forearm_R": (35, 0, 0), "Hand_R": (-15, 0, 0),
}
IDLE = merge(ARMS, {
    "loc": (0, 0, -0.06),
    "Neck1": (-4, 0, 0), "Neck2": (-3, 0, 0), "Head": (4, 0, 0),
    "Tail1": (2, 0, 0), "Tail2": (2, 0, 0),
})


def ground(pose, feet=None):
    return base.ground(pose, feet or STANCE)


# tempos usados pelo jogo (quadro / 30): o golpe da pisada, o fechar da boca, a soltura do arremesso e o pico do rugido
STOMP_HIT = 20
BITE_SNAP = 15
THROW_RELEASE = 10
ROAR_PEAK = 20
ROAR_AT_PEAK = 16  # rugido na batalha, abaixado e voltado para ela
HEAD_HIT = 12  # cabeçada: a cabeça passa pelo lado
TAIL_HIT = 16  # rabada: a cauda passa por trás
WALK = dict(frames=48, step=3, stride=2.0, duty=0.62, lift=0.30, height=-0.10, bob=0.04, sway=4.0)
RUN = dict(frames=28, step=2, stride=2.6, duty=0.45, lift=0.50, height=-0.18, bob=0.08, sway=3.0, pitch=-5.0)


def anim_speed(g):
    """m/s que um ciclo representa em velocidade 1 (a passada inteira no tempo de apoio): o pé não patina."""
    return g["stride"] / (g["duty"] * g["frames"] / FPS)


def roar_keys():
    antic = ground(merge(IDLE, {"loc": (0, -0.10, -0.12), "Chest": (-4, 0, 0), "Neck1": (-14, 0, 0), "Neck2": (-6, 0, 0),
                                "Head": (-6, 0, 0)}))
    roar = merge(ARMS, {
        "loc": (0, -0.05, 0.05), "Hips": (5, 0, 0), "Spine": (4, 0, 0), "Chest": (6, 0, 0),
        "Neck1": (18, 0, 0), "Neck2": (8, 0, 0), "Head": (-4, 0, 0), "Jaw": (-42, 0, 0),
        "Tail1": (8, 0, 0), "Tail2": (6, 0, 0), "Tail3": (4, 0, 0),
        "Arm_L": (45, 0, 25), "Arm_R": (45, 0, 25), "Forearm_L": (15, 0, 0), "Forearm_R": (15, 0, 0),
    })
    shake = lambda z, jaw: ground(merge(roar, {"Head": (0, 0, z), "Neck2": (0, 0, z * 0.6), "Jaw": (jaw + 42, 0, 0)}))
    return [
        (0, ground(IDLE)), (10, antic), (ROAR_PEAK, ground(roar)),
        (25, shake(6, -38)), (30, shake(-6, -46)), (35, shake(6, -38)), (40, shake(-6, -46)),
        (46, ground(roar)), (54, ground(merge(IDLE, {"Jaw": (-8, 0, 0)}))), (60, ground(IDLE)),
    ]


def stomp_keys():
    """Ergue o pé direito bem alto olhando para baixo e esmaga à frente (o golpe é no quadro STOMP_HIT)."""
    meta, toe = base.REST["meta"], base.REST["toe"]
    look = {"Neck1": (-12, 0, 0), "Neck2": (-6, 0, 0), "Head": (-14, 0, 0), "Jaw": (-14, 0, 0)}
    lift = merge(IDLE, look, {"loc": (0, -0.15, 0.06), "Hips": (6, 0, 0), "Tail1": (-6, 0, 0), "Tail2": (-4, 0, 0)})
    slam = merge(IDLE, look, {"loc": (0, 0.20, -0.16), "Hips": (-5, 0, 0), "Tail1": (8, 0, 0), "Jaw": (-24, 0, 0)})
    up = {"L": STANCE["L"], "R": (BALL[0] + 0.55, GROUND + 0.75, meta - 35, toe - 35)}
    peak = {"L": STANCE["L"], "R": (BALL[0] + 0.65, GROUND + 0.95, meta - 45, toe - 40)}
    down = {"L": STANCE["L"], "R": (BALL[0] + 0.85, GROUND)}
    return [
        (0, ground(IDLE)), (10, ground(lift, up)), (16, ground(lift, peak)), (STOMP_HIT, ground(slam, down)),
        (30, ground(slam, down)), (44, ground(IDLE)),
    ]


BITE_LUNGE = merge(ARMS, {
    "loc": (0, 0.60, -0.30), "Hips": (-9, 0, 0), "Spine": (-5, 0, 0), "Chest": (-5, 0, 0),
    "Neck1": (-16, 0, 0), "Neck2": (-10, 0, 0), "Head": (-4, 0, 0), "Jaw": (-48, 0, 0),
    "Tail1": (10, 0, 0), "Tail2": (6, 0, 0), "Arm_L": (55, 0, 12), "Arm_R": (55, 0, 12),
})
FEET_WIDE = {"L": (BALL[0] + 0.55, GROUND), "R": (BALL[0] - 0.45, GROUND)}


def bite_keys():
    """Bote baixo, até a altura de uma pessoa: prepara (cabeça para trás), avança abaixando e fecha a boca."""
    wind = ground(merge(IDLE, {"loc": (0, -0.20, 0), "Hips": (4, 0, 0), "Neck1": (12, 0, 0), "Neck2": (6, 0, 0),
                               "Head": (8, 0, 0), "Jaw": (-15, 0, 0)}))
    snap = ground(merge(BITE_LUNGE, {"Jaw": (48, 0, 0)}), FEET_WIDE)
    return [(0, ground(IDLE)), (6, wind), (12, ground(BITE_LUNGE, FEET_WIDE)), (BITE_SNAP, snap), (20, snap),
            (32, ground(IDLE))]


HOLD = merge(ARMS, {"loc": (0, 0.30, -0.12), "Hips": (-4, 0, 0), "Neck1": (6, 0, 0), "Head": (-4, 0, 0)})


def _shake(k):
    return ground(merge(HOLD, {
        "Chest": (0, 0, 8 * k), "Neck1": (0, 0, 16 * k), "Neck2": (0, 0, 12 * k), "Head": (0, 10 * k, 10 * k),
        "Tail2": (0, 0, -8 * k), "Tail3": (0, 0, -10 * k),
    }))


def shake_keys():
    """Presa na boca: sacode a cabeça de um lado para o outro (ciclo de 0,5 s)."""
    return [(0, _shake(1)), (4, _shake(0)), (8, _shake(-1)), (12, _shake(0)), (16, _shake(1))]


def throw_keys():
    """Arremesso: leva a cabeça para a direita e chicoteia para a esquerda e para cima, abrindo a boca no meio do
    movimento (THROW_RELEASE) para soltar a presa."""
    wind = ground(merge(HOLD, {"Chest": (0, 0, -10), "Neck1": (6, 0, -26), "Neck2": (4, 0, -16), "Head": (6, -10, -12)}))
    whip = ground(merge(HOLD, {"Chest": (4, 0, 12), "Neck1": (16, 0, 30), "Neck2": (8, 0, 18), "Head": (14, 12, 14),
                               "Jaw": (-40, 0, 0)}))
    return [(0, _shake(0)), (6, wind), (THROW_RELEASE, whip), (14, ground(merge(whip, {"Jaw": (-20, 0, 0)}))),
            (24, ground(IDLE))]


def roar_at_keys():
    """Rugido na batalha: abaixa o corpo e estica o pescoço na direção dela, com a boca bem aberta na altura dela."""
    antic = ground(merge(IDLE, {"loc": (0, -0.15, 0.05), "Neck1": (10, 0, 0), "Head": (6, 0, 0), "Jaw": (-10, 0, 0)}))
    roar = merge(ARMS, {
        "loc": (0, 0.45, -0.30), "Hips": (-10, 0, 0), "Spine": (-5, 0, 0), "Chest": (-4, 0, 0),
        "Neck1": (-20, 0, 0), "Neck2": (-6, 0, 0), "Head": (14, 0, 0), "Jaw": (-55, 0, 0),
        "Tail1": (-2, 0, 0), "Tail2": (2, 0, 0), "Arm_L": (55, 0, 20), "Arm_R": (55, 0, 20),
    })
    shake = lambda z, jaw: ground(merge(roar, {"Head": (0, 0, z), "Neck2": (0, 0, z * 0.5), "Jaw": (jaw + 55, 0, 0)}),
                                  FEET_WIDE)
    return [
        (0, ground(IDLE)), (8, antic), (ROAR_AT_PEAK, ground(roar, FEET_WIDE)),
        (22, shake(5, -50)), (28, shake(-5, -58)), (34, shake(5, -50)), (40, shake(-5, -58)),
        (46, ground(merge(roar, {"Jaw": (35, 0, 0)}), FEET_WIDE)), (56, ground(IDLE)),
    ]


def headbutt_keys():
    """Cabeçada para a esquerda dele: leva a cabeça baixa para a direita e varre para a esquerda (HEAD_HIT)."""
    wind = ground(merge(IDLE, {
        "loc": (0, -0.10, -0.15), "Hips": (-5, 0, 0), "Spine": (0, 0, -8), "Chest": (0, 0, -10),
        "Neck1": (-20, 0, -22), "Neck2": (-4, 0, -14), "Head": (-4, 0, -10), "Jaw": (-10, 0, 0),
    }))
    hit = merge(IDLE, {
        "loc": (0, 0.15, -0.25), "Hips": (-8, 0, 0), "Spine": (0, 0, 10), "Chest": (0, 0, 12),
        "Neck1": (-26, 0, 28), "Neck2": (-6, 0, 18), "Head": (-2, -15, 14), "Jaw": (-6, 0, 0),
        "Tail2": (0, 0, 8), "Tail3": (0, 0, 10),
    })
    follow = merge(hit, {"Neck1": (0, 0, -6), "Neck2": (0, 0, -4)})
    return [(0, ground(IDLE)), (8, wind), (HEAD_HIT, ground(hit, FEET_WIDE)), (18, ground(follow, FEET_WIDE)),
            (30, ground(IDLE))]


def tail_whip_keys():
    """Rabada: a cauda carrega para a direita e varre para a esquerda dele (o jogo gira o corpo junto)."""
    tail = lambda z, x=0: {f"Tail{i + 1}": (x, 0, z * (0.8 + 0.12 * i)) for i in range(4)}
    wind = ground(merge(IDLE, tail(16, -4), {"loc": (0, 0, -0.12), "Hips": (-5, 0, 0), "Spine": (0, 0, 10),
                                             "Chest": (0, 0, 12), "Neck1": (0, 0, 10)}))
    whip = ground(merge(IDLE, tail(-26, -9), {"loc": (0, 0, -0.10), "Spine": (0, 0, -12), "Chest": (0, 0, -10),
                                              "Neck1": (0, 0, -8), "Jaw": (-20, 0, 0)}))
    follow = ground(merge(IDLE, tail(-30, -6), {"loc": (0, 0, -0.08), "Spine": (0, 0, -8), "Chest": (0, 0, -6),
                                               "Jaw": (-14, 0, 0)}))
    return [(0, ground(IDLE)), (10, wind), (TAIL_HIT, whip), (22, follow), (36, ground(IDLE))]


def study_keys():
    """Fareja e olha em volta: cabeça para um lado e para o outro, depois baixa."""
    look = lambda k: ground(merge(IDLE, {"Neck2": (0, 0, 14 * k), "Head": (0, 16 * k, 10 * k), "Neck1": (-4, 0, 0),
                                         "Jaw": (-6, 0, 0)}))
    sniff = ground(merge(IDLE, {"loc": (0, 0.05, -0.10), "Chest": (-5, 0, 0), "Neck1": (-20, 0, 0), "Neck2": (-6, 0, 0),
                                "Head": (-4, 0, 0), "Jaw": (-4, 0, 0)}))
    return [(0, ground(IDLE)), (18, look(1)), (32, look(0.8)), (48, sniff), (64, look(-1)), (78, look(-0.8)),
            (90, ground(IDLE))]


def actions():
    """nome -> lista de (frame, pose)."""
    walk_up = merge(ARMS, {"Neck1": (-6, 0, 0), "Head": (5, 0, 0), "Tail1": (2, 0, 0)})
    run_up = merge(ARMS, {"Neck1": (-12, 0, 0), "Neck2": (-4, 0, 0), "Head": (10, 0, 0), "Jaw": (-10, 0, 0),
                          "Tail1": (5, 0, 0)})
    breath = ground(merge(IDLE, base.tail_wave(3, 0.25), {"loc": (0, 0, -0.08), "Chest": (2, 0, 0), "Neck1": (2, 0, 0),
                                                          "Head": (-2, 0, 0)}))
    hit = ground(merge(IDLE, {"loc": (0, -0.12, -0.04), "Chest": (-8, 0, 0), "Neck1": (14, 0, 0), "Neck2": (6, 0, 0),
                              "Head": (10, 0, 0), "Jaw": (-30, 0, 0)}))
    w, r = WALK, RUN
    return {
        "Idle": [(0, ground(IDLE)), (40, breath), (80, ground(IDLE))],
        "Walk": base.gait(w["frames"], w["step"], stride=w["stride"], duty=w["duty"], lift=w["lift"],
                          height=w["height"], bob=w["bob"], upper=walk_up, sway=w["sway"]),
        "Run": base.gait(r["frames"], r["step"], stride=r["stride"], duty=r["duty"], lift=r["lift"],
                         height=r["height"], bob=r["bob"], upper=run_up, pitch=r["pitch"], sway=r["sway"]),
        "Roar": roar_keys(),
        "Study": study_keys(),
        "Stomp": stomp_keys(),
        "Bite": bite_keys(),
        "Shake": shake_keys(),
        "Throw": throw_keys(),
        "Hit": [(0, ground(IDLE)), (3, hit), (14, ground(IDLE))],
        "RoarAt": roar_at_keys(),
        "Headbutt": headbutt_keys(),  # varre para a esquerda dele
        "HeadbuttR": [(f, mirror(p)) for f, p in headbutt_keys()],
        "TailWhip": tail_whip_keys(),  # cauda varre para a esquerda dele
        "TailWhipR": [(f, mirror(p)) for f, p in tail_whip_keys()],
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
