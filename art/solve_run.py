"""Resolve as pernas e a altura do quadril da corrida para o pé de apoio ficar parado no chão.

Uso: blender --background art/heroine.blend --python art/solve_run.py
Imprime RUN_HALF para colar em heroine_anims.py. O resto da pose (quadril, tronco, braços, joelhos) vem daqui.

Alvos, por quadro da metade com apoio na esquerda (contato 0, amortece 2, calcanhar sobe 3, sai do chão 4, voo 6;
o quadro 1 também é resolvido):
  - pé de apoio na linha dele (x fixo) mesmo com o quadril balançando de lado: sem deslize lateral;
  - pé de apoio indo para trás na velocidade do jogo (Player.RUN_SPEED / 30 por quadro): sem patinar;
  - calcanhar no chão no contato, pé chato ao amortecer, ponta no chão ao sair; no voo, os dois pés no ar;
  - pé que balança passando na linha dele (não cruza para o meio).
"""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(bpy.data.filepath).parent if bpy.data.filepath else Path(__file__).parent))
import heroine_anims as A  # noqa: E402

RUN_SPEED = 4.4
STEP = RUN_SPEED / A.FPS  # quanto o chão anda (para trás, +Y) por quadro
TRACK_L, TRACK_R = 0.07, -0.02  # linha do pé de apoio e do pé que balança (x; este um pouco para dentro)
Y0 = -0.28  # pé de apoio no contato, à frente do quadril (pousa perto do corpo e empurra lá atrás)
FLAT_DROP = 0.055  # ponta abaixo do tornozelo com o pé chato (repouso)
FLIGHT_Y = -0.03  # quadril no voo: o alto do quique (baixo: corrida de reação, não de atleta)

# quadro: (loc x, quadril, coluna, peito, cabeça, joelho E, perna D (coxa, joelho, pé), braço E, braço D, alvo)
# ombros, peito e costas giram contra o quadril e levam os braços junto (o peito gira ~11° em relação ao chão;
# a cabeça desconta e continua olhando para a frente); os braços em si balançam pouco (±14°), cotovelo perto de 90°
DESIGN = [
    (0, (0.004, (-9, 1), (6, -1), (14, -1), (-10, 0), -12, (-15, -65, -15), (-14, 4, 82), (14, 3, 92), "heel")),
    (2, (0.022, (-4, 5), (2, -3), (4, -2), (-2, 0), -40, (10, -95, -10), (-4, 4, 85), (4, 3, 89), "flat")),
    (3, (0.024, (1, 4), (-1, -2), (-3, -2), (3, 0), -38, (28, -95, -5), (4, 4, 86), (-3, 3, 86), "ball")),
    (4, (0.022, (4, 3), (-3, -2), (-7, -1), (6, 0), -24, (40, -88, 0), (9, 4, 88), (-8, 3, 85), "toe")),
    (6, (0.008, (7, 1), (-5, -1), (-12, -1), (9, 0), -50, (40, -45, 0), (13, 4, 90), (-13, 3, 83), "air")),
]
AIR_LEG_L = (-20, -15)  # coxa e pé da esquerda no voo (já fora do chão, dobrando)
# quadros do apoio entre as poses de desenho: o resto da pose é interpolado e as pernas resolvidas também,
# senão a curva entre duas chaves faz o pé escorregar
IN_BETWEEN = {1: "flat"}


def lerp(a, b, t):
    if isinstance(a, tuple):
        return tuple(lerp(x, y, t) for x, y in zip(a, b))
    if isinstance(a, str):
        return a
    return round(a + (b - a) * t, 3)


def frames():
    out = dict(DESIGN)
    keys = sorted(out)
    for f, kind in IN_BETWEEN.items():
        f0 = max(k for k in keys if k < f)
        f1 = min(k for k in keys if k > f)
        out[f] = lerp(out[f0], out[f1], (f - f0) / (f1 - f0))[:-1] + (kind,)
    return sorted(out.items())

rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
rig.animation_data_create()
rig.animation_data.action = None


def points(s):
    bpy.context.view_layer.update()
    pb = rig.pose.bones["Foot_" + s]
    return rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail


def key_args(d, v):
    locx, hips, spine, chest, head, knee_l, leg_r, arm_l, arm_r, _ = d
    return ((locx, v["y"], 0), hips, spine, chest, head,
            (v["th"], knee_l, v["foot"], v["zl"]), (*leg_r, v["zr"]), arm_l, arm_r)


def errors(f, d, v):
    A.apply_pose(rig, A.run_key(*key_args(d, v)))
    (al, tl), (ar, tr) = points("L"), points("R")
    kind = d[-1]
    e = {"zl": al.x - TRACK_L, "zr": ar.x - TRACK_R}
    if kind != "air":
        e["th"] = al.y - (Y0 + STEP * f)
        if kind == "heel":
            e["y"], e["foot"] = al.z - 0.10, tl.z - (al.z - FLAT_DROP + 0.04)
        elif kind == "flat":
            e["y"], e["foot"] = al.z - 0.085, tl.z - (al.z - FLAT_DROP)
        elif kind == "ball":  # calcanhar subindo
            e["y"], e["foot"] = tl.z - 0.03, al.z - 0.10
        else:  # ponta: dedos no chão, pé bem empinado
            e["y"], e["foot"] = tl.z - 0.03, tl.z - (al.z - 0.105)
    return e


def solve(f, d):
    v = {"y": -0.06, "th": 0.0, "foot": 0.0, "zl": 0.0, "zr": 0.0}
    if d[-1] == "air":
        v["th"], v["foot"] = AIR_LEG_L
        v["y"] = FLIGHT_Y
    names = list(errors(f, d, v))
    for _ in range(40):  # Newton com jacobiano numérico
        e = errors(f, d, v)
        if max(abs(x) for x in e.values()) < 1e-4:
            break
        J = []
        for n in names:
            h = 1e-3 if n == "y" else 0.2
            v[n] += h
            e2 = errors(f, d, v)
            v[n] -= h
            J.append([(e2[m] - e[m]) / h for m in names])
        # resolve J^T dx = -e (J[n][m] = d e_m / d v_n)
        import numpy as np
        dx = np.linalg.solve(np.array(J).T, -np.array([e[m] for m in names]))
        for n, x in zip(names, dx):
            v[n] += float(x)
    e = errors(f, d, v)
    (al, tl), (ar, tr) = points("L"), points("R")
    print(f"[run] quadro {f}: erro máx {max(abs(x) for x in e.values()):.5f}, pé mais baixo {min(al.z, tl.z, ar.z, tr.z):.3f}")
    return v


def fmt(t):
    return "(" + ", ".join(fmt(x) if isinstance(x, tuple) else f"{x:g}" for x in t) + ")"


rows = []
for f, d in frames():
    v = solve(f, d)
    v = {k: (round(x, 3) if k == "y" else round(x * 2) / 2) for k, x in v.items()}
    rows.append(f"    ({f}, {fmt(key_args(d, v))}),")
print("RUN_HALF = [\n" + "\n".join(rows) + "\n]")
