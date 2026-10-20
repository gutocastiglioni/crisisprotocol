"""Ciclos de passo resolvidos por IK: caminhada, caminhada agachada e passos laterais (em pé e agachada).

Cada pé segue uma trajetória no chão: no apoio ele fica parado em relação ao chão, que passa a `speed` m/s
(o Player do Godot anda nessa mesma velocidade: ver as constantes de lá), e no balanço volta para a frente
num arco baixo. Quadril (altura, gingado, giro) e tronco/braços são desenhados; as pernas saem da IK a cada
quadro, então o pé de apoio não desliza nem afunda. Ciclo de 2 passos (2 * n quadros) com o esquerdo
pousando no quadro 0.
"""
import math
from dataclasses import dataclass, field

from mathutils import Matrix, Vector

import heroine_ik as IK

FPS = 30


@dataclass
class Gait:
    n: int  # quadros por passo
    speed: float  # m/s (velocidade do chão passando)
    travel: tuple = (0.0, -1.0)  # direção do corpo no plano (x esquerda, y): frente = (0, -1)
    stance: float = 0.6  # fração do ciclo com o pé no chão
    hip: float = -0.03  # altura do quadril (loc y)
    bob: float = 0.012  # sobe e desce (mais alto no meio do apoio)
    sway: float = 0.018  # quadril para o lado do pé de apoio
    turn: float = 4.0  # giro do quadril (graus), o peito gira contra
    lift: float = 0.06  # altura do pé no meio do balanço
    width: float = 0.0  # pés mais abertos que o quadril (cada lado)
    heel: float = 12.0  # ponta do pé para cima ao pousar o calcanhar (graus)
    toe_off: float = -22.0  # calcanhar para cima ao sair (graus)
    swing_arm: float = 10.0  # balanço dos braços (graus)
    upper: dict = field(default_factory=dict)  # pose do tronco/braços (e o resto que não é perna)


def _smooth(t):
    return t * t * (3 - 2 * t)


def _foot_targets(g, ankle0, toe0, phase):
    """Tornozelo e direção do pé (espaço do esqueleto) para uma fase do ciclo do pé (0 = pousa o calcanhar)."""
    travel = Vector((g.travel[0], g.travel[1], 0.0)).normalized()
    cycle = 2 * g.n
    D = g.speed * cycle * g.stance / FPS  # quanto o pé anda (para trás) durante o apoio
    ground = Vector((ankle0.x, ankle0.y, 0.0))
    if phase < g.stance:
        q = phase / g.stance
        d = D / 2 - q * D
        h = 0.0
        if q < 0.15:
            pitch = g.heel * (1 - _smooth(q / 0.15))
        elif q > 0.65:
            pitch = g.toe_off * _smooth((q - 0.65) / 0.35)
        else:
            pitch = 0.0
    else:
        q = (phase - g.stance) / (1 - g.stance)
        d = -D / 2 + _smooth(q) * D
        h = g.lift * math.sin(math.pi * q)
        # sai empinado, no meio a ponta sobe um pouco (não raspa) e chega com o calcanhar
        pitch = g.toe_off * (1 - _smooth(min(q / 0.4, 1))) + (g.heel + 4) * _smooth(max((q - 0.4) / 0.6, 0))
    side = 1.0 if ankle0.x > 0 else -1.0
    base = ground + travel * d + Vector((side * g.width, 0, h))
    # pé rígido girando no calcanhar (ponta para cima) ou na ponta (calcanhar para cima)
    foot = toe0 - ankle0
    lateral = Vector((foot.x, foot.y, 0)).normalized().cross(IK.UP)  # ângulo > 0 = ponta para cima
    heel_pt = Vector((ankle0.x, ankle0.y + 0.03, 0.0))
    toe_pt = Vector((toe0.x, toe0.y, 0.0))
    pivot = heel_pt if pitch >= 0 else toe_pt
    rot = Matrix.Rotation(math.radians(pitch), 3, lateral)
    ankle = base + (pivot - ground) + rot @ (ankle0 - pivot)
    return ankle, rot @ foot.normalized()


NECK_NOD = 2.5  # graus


def frame_pose(g, f):
    """Pose do quadro f (sem as pernas resolvidas)."""
    w = math.pi * f / g.n  # meia volta por passo
    pose = dict(g.upper)
    lateral = abs(g.travel[0]) > abs(g.travel[1])
    sway = 0.0 if lateral else g.sway * math.sin(w)
    pose["loc"] = (sway, g.hip - g.bob * math.cos(2 * w), 0.0)
    turn = 0.0 if lateral else g.turn * math.cos(w)
    hx = pose.get("Hips", (0, 0, 0))
    pose["Hips"] = (hx[0], hx[1] - turn, hx[2] + 1.5 * math.sin(w) * (0 if lateral else 1))
    for bone, k in (("Chest", 0.9), ("Head", -0.3)):
        b = pose.get(bone, (0, 0, 0))
        pose[bone] = (b[0], b[1] + turn * k, b[2])
    # pescoço solto: acena com o passo (duas vezes por ciclo, junto do sobe e desce) e a cabeça compensa metade
    nod = NECK_NOD * math.cos(2 * w)
    n = pose.get("Neck", (0, 0, 0))
    pose["Neck"] = (n[0] + nod, n[1] - turn * 0.2, n[2])
    h = pose.get("Head", (0, 0, 0))
    pose["Head"] = (h[0] - nod * 0.5, h[1], h[2])
    for s, sign in (("L", -1.0), ("R", 1.0)):
        b = pose.get(f"UpperArm_{s}", (0, 0, 0))
        pose[f"UpperArm_{s}"] = (b[0] + sign * g.swing_arm * math.cos(w), b[1], b[2])
    return pose


def solve_cycle(sk, g, name):
    """Lista de (quadro, pose) do ciclo inteiro, pernas resolvidas por IK em cada quadro."""
    cycle = 2 * g.n
    rest = {s: IK.foot_rest(sk, s) for s in ("L", "R")}
    keys = []
    prev = None
    worst = 0.0
    for f in range(cycle):
        pose = frame_pose(g, f)
        if prev:
            for s in ("L", "R"):
                for b in (f"UpperLeg_{s}", f"LowerLeg_{s}", f"Foot_{s}"):
                    pose[b] = prev[b]
        else:
            for s in ("L", "R"):
                pose.setdefault(f"LowerLeg_{s}", (-15, 0, 0))
        for s, off in (("L", 0), ("R", g.n)):
            phase = ((f + off) % cycle) / cycle
            ankle_t, dir_t = _foot_targets(g, *rest[s], phase)
            foot_bone = f"Foot_{s}"

            def residual(m, s=s, ankle_t=ankle_t, dir_t=dir_t, foot_bone=foot_bone):
                a = sk.point(m, foot_bone)
                t = sk.point(m, foot_bone, sk.length[foot_bone])
                return list(a - ankle_t) + list(((t - a).normalized() - dir_t) * 0.15)

            pose, err = IK.solve(sk, pose, IK.leg_unknowns(s), residual, IK.leg_bounds(s))
            if err > 0.005:
                print(f"[gait]   {name} quadro {f} perna {s} fase {phase:.2f}: {err * 1000:.0f} mm")
            worst = max(worst, err)
        keys.append((f, pose))
        prev = pose
    keys.append((cycle, keys[0][1]))
    print(f"[gait] {name}: {cycle} quadros, {g.speed:.2f} m/s, erro máx da IK {worst * 1000:.1f} mm")
    return keys


def mirror_lateral(keys):
    """Passo para a direita a partir do passo para a esquerda: espelha pernas e quadril, braços continuam na arma."""
    import heroine_anims as A

    return [(f, A.mirror_aim(p)) for f, p in keys]
