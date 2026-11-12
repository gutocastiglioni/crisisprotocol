"""Animações do raptor para o build (`build_raptor.py`): as da referência passadas quadro a quadro para o esqueleto
novo (`Frames`), as que ele não tem montadas em cima delas (`composed`), a regra dos braços (`hands_down`), a gravação
das ações e as medidas que o jogo usa (`measure`).
"""
import math

import bpy
from mathutils import Matrix, Vector

from raptor_import import clean, goto, set_action

FPS = 30
REST = ("Idle_01", 0)  # pose de descanso: o primeiro quadro do Idle_01 (em pé, boca fechada)
# animações do jogo: nome -> (animação dele, velocidade). As que ele não tem (Stalk, Study, Shake, TailWhip/R, e a pose
# Embryo dos clones dos tubos) são as nossas, refeitas em cima do corpo dele em `composed`. A mordida dele é lenta para
# o jogo (a boca fechava em 0,93 s): 2x, fecha em ~0,47 s, perto dos 0,4 s de antes.
DIRECT = {"Idle": ("Idle_02", 1.0), "Walk": ("Walk", 1.0), "Run": ("Sprint", 1.0), "Jog": ("Jog", 1.0),
          "Roar": ("Roar_02", 1.0), "Bite": ("Bite_02", 2.0), "Hit": ("Hurt_01", 1.0), "Death": ("Death_01", 1.0),
          "CallAlert": ("Call_Alert", 1.0), "Sniff": ("Sniff", 1.0)}
STRIP = {"Roar", "Death", "Hit", "Bite"}  # tira o deslocamento de lado/frente (o jogo move o corpo)
STALK_SLOW = 1.6  # espreita = o andar dele 1,6x mais lento, baixo e varrendo


# ------------------------------------------------------------------ animações
class Frames:
    """Quadros de uma animação no nosso espaço: lista de {osso: matriz no mundo} (sem escala)."""

    def __init__(self, keep, rig, C):
        self.keep, self.C = keep, C
        self.L = {n: rig.data.bones[n].matrix_local.copy() for n in keep}
        self.Li = {n: m.inverted() for n, m in self.L.items()}
        self.rest_inv = {n: info.M.inverted() for n, info in keep.items()}
        self.children = {n: [] for n in keep}
        for n, info in keep.items():
            if info.parent:
                self.children[info.parent].append(n)

    def sample(self, arm, scene, action, speed=1.0, frames=None):
        """Quadros a 30 fps; `speed` < 1 = mais lenta (mais quadros); `frames` = quantos, repetindo o ciclo dela."""
        act = set_action(arm, action)
        f0, f1 = act.frame_range
        ref_fps = scene.render.fps
        count = frames if frames is not None else round((f1 - f0) / ref_fps * FPS / speed)
        out = []
        for k in range(count + 1):
            ff = f0 + (k / FPS) * ref_fps * speed
            if frames is not None:
                ff = f0 + ((k / FPS) * ref_fps * speed) % (f1 - f0)
            goto(scene, min(ff, f1))
            W = arm.matrix_world
            out.append({n: clean(self.C @ W @ info.src.matrix @ self.rest_inv[n] @ self.L[n]) for n, info in self.keep.items()})
        # o quadril começa em cima do ponto de descanso (de lado e para a frente); o resto do caminho fica
        d = out[0]["Hips"].translation - self.L["Hips"].translation
        for fr in out:
            self.shift(fr, Vector((-d.x, -d.y, 0.0)))
        return out

    def subtree(self, b):
        out, stack = [], [b]
        while stack:
            n = stack.pop()
            out.append(n)
            stack.extend(self.children[n])
        return out

    def turn(self, fr, b, rot3, pivot=None):
        """Gira o osso `b` e tudo abaixo dele por `rot3` (no mundo) em volta da cabeça dele."""
        p = fr[b].translation.copy() if pivot is None else pivot
        T = Matrix.Translation(p) @ rot3.to_4x4() @ Matrix.Translation(-p)
        for n in self.subtree(b):
            fr[n] = T @ fr[n]

    def axis(self, fr, b):
        return (fr[b].to_3x3() @ Vector((0, 1, 0))).normalized()

    def pitch(self, fr, b, deg):
        """Levanta (deg > 0) ou abaixa a ponta do osso `b`, em volta do eixo de lado dele."""
        d = self.axis(fr, b)
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            return
        self.turn(fr, b, Matrix.Rotation(math.radians(deg), 3, side.normalized()))

    def yaw(self, fr, b, deg):
        """Vira o osso `b` para a esquerda dele (deg > 0), em volta da vertical."""
        self.turn(fr, b, Matrix.Rotation(math.radians(deg), 3, "Z"))

    def roll(self, fr, b, deg):
        self.turn(fr, b, Matrix.Rotation(math.radians(deg), 3, self.axis(fr, b)))

    def close_jaw(self, fr):
        """Boca fechada como no descanso (a mandíbula volta à posição de repouso em relação à cabeça)."""
        want = fr["Head"] @ self.Li["Head"] @ self.L["Jaw"]
        T = want @ fr["Jaw"].inverted()
        for n in self.subtree("Jaw"):
            fr[n] = T @ fr[n]

    def open_jaw(self, fr, deg):
        if deg:
            d = self.axis(fr, "Head")
            side = d.cross(Vector((0, 0, 1))).normalized()
            self.turn(fr, "Jaw", Matrix.Rotation(math.radians(-deg), 3, side))

    def shift(self, fr, v):
        T = Matrix.Translation(v)
        for n in fr:
            fr[n] = T @ fr[n]

    def basis(self, fr, n):
        info = self.keep[n]
        if info.parent:
            return self.Li[n] @ self.L[info.parent] @ fr[info.parent].inverted() @ fr[n]
        return self.Li[n] @ fr[n]


def ease(f, keys):
    """Valor no quadro f entre chaves (quadro, valor), com suavização."""
    if f <= keys[0][0]:
        return keys[0][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            t = (f - f0) / max(f1 - f0, 1e-6)
            t = t * t * (3 - 2 * t)
            return v0 + (v1 - v0) * t
    return keys[-1][1]


def strip_travel(F, frames, keep_z=True):
    """Tira o deslocamento do quadril em relação ao primeiro quadro (de lado e para a frente; com keep_z, só)."""
    h0 = frames[0]["Hips"].translation.copy()
    for fr in frames:
        d = fr["Hips"].translation - h0
        F.shift(fr, Vector((-d.x, -d.y, 0.0 if keep_z else -d.z)))
    return frames


def composed(F, arm, scene):
    out = {}
    # espreita: o andar dele mais lento, peito e pescoço baixos com a cabeça nivelada, varrendo os lados
    walk = F.sample(arm, scene, "Walk", speed=1.0 / STALK_SLOW)
    n = len(walk) - 1
    for k, fr in enumerate(walk):
        F.pitch(fr, "Chest", -6)
        F.pitch(fr, "Neck1", -16)
        F.pitch(fr, "Head", 14)
        F.pitch(fr, "Hand_L", -30)  # garras prontas, apontadas para baixo (nunca para cima)
        F.pitch(fr, "Hand_R", -30)
        F.yaw(fr, "Neck1", 9 * math.sin(2 * math.pi * k / n))
        F.open_jaw(fr, 3)
    out["Stalk"] = walk
    # estudo (72 quadros, ciclo): parado alerta, inclina a cabeça de um lado, vira de estalo para o outro, abaixa e
    # fareja, ergue-se para medir a presa; a boca estala
    idle = F.sample(arm, scene, "Idle_01", frames=72)
    tilt = [(0, 0), (10, 24), (24, 28), (28, -24), (42, -28), (50, -6), (56, 4), (63, 0), (72, 0)]
    turn = [(0, 0), (10, 12), (24, 14), (28, -16), (42, -18), (50, -4), (56, 3), (63, 0), (72, 0)]
    nod = [(0, 0), (42, -2), (50, -18), (56, -20), (63, 9), (72, 0)]
    snap = [(0, 0), (44, 0), (46, 14), (47, 0), (51, 0), (53, 5), (55, 0), (57, 0), (59, 5), (61, 0), (72, 0)]
    for k, fr in enumerate(idle):
        F.pitch(fr, "Neck1", ease(k, nod))
        F.yaw(fr, "Neck1", ease(k, turn) * 0.6)
        F.yaw(fr, "Neck3", ease(k, turn) * 0.4)
        F.roll(fr, "Head", ease(k, tilt))
        F.open_jaw(fr, ease(k, snap))
    out["Study"] = idle
    # sacudir a presa (ciclo de 12 quadros): o bote dele parado no ponto mais à frente, corpo de volta em cima da cápsula,
    # boca fechada e baixa (a ~0,7 m: ela se debate perto do chão, como no raptor de antes), pescoço e cabeça sacudindo de
    # lado, cauda contrabalançando
    bite = F.sample(arm, scene, "Bite_02")
    # quadro do bote com a cabeça a ~0,3 m à frente do repouso (o mais esticado deixava a boca longe demais do corpo)
    top = min(range(len(bite)), key=lambda i: bite[i]["Head"].translation.y)
    want = bite[0]["Head"].translation.y - 0.3
    hold = min(range(top + 1), key=lambda i: abs(bite[i]["Head"].translation.y - want))
    shake = []
    for k in range(13):
        fr = {b: m.copy() for b, m in bite[hold].items()}
        a = math.sin(2 * math.pi * k / 12)
        F.close_jaw(fr)
        F.pitch(fr, "Neck1", -40)
        F.pitch(fr, "Head", 20)
        F.yaw(fr, "Chest", -6 * a)
        F.yaw(fr, "Neck1", 16 * a)
        F.yaw(fr, "Neck3", 10 * a)
        F.roll(fr, "Head", 14 * a)
        F.yaw(fr, "Tail1", -10 * a)
        F.yaw(fr, "Tail4", -12 * a)
        shake.append(fr)
    d = shake[0]["Hips"].translation - F.L["Hips"].translation
    for fr in shake:
        F.shift(fr, Vector((-d.x, -d.y, 0.0)))
    out["Shake"] = shake
    # rabada (26 quadros): carrega a cauda para um lado e varre o outro; o corpo gira junto e a cabeça olha por cima do
    # ombro para onde a cauda bate. TailWhip varre para a esquerda dele; TailWhipR, a mesma espelhada
    for name, k_ in (("TailWhip", 1), ("TailWhipR", -1)):
        base = F.sample(arm, scene, "Idle_01", frames=26)
        tail = [(0, 0), (7, 18), (12, -28), (16, -32), (26, 0)]
        body = [(0, 0), (7, 10), (12, -12), (16, -8), (26, 0)]
        look = [(0, 0), (7, 16), (12, 34), (16, 26), (26, 0)]
        jaw = [(0, 0), (7, 4), (12, 20), (16, 14), (26, 0)]
        for k, fr in enumerate(base):
            F.yaw(fr, "Spine", k_ * ease(k, body))
            F.yaw(fr, "Tail1", -k_ * ease(k, tail) * 0.55)
            F.yaw(fr, "Tail4", -k_ * ease(k, tail) * 0.45)
            F.yaw(fr, "Neck1", k_ * ease(k, look))
            F.open_jaw(fr, ease(k, jaw))
        out[name] = base
    # bote: agacha (LeapPrep) até o quadro em que os pés saem do chão; no ar (LeapAir) do impulso ao alto do salto,
    # parado lá (o jogo leva o corpo pelo ar). Sem o deslocamento dele.
    leap = F.sample(arm, scene, "Leap_01")
    g = min(min(fr["Toe_L"].translation.z, fr["Toe_R"].translation.z) for fr in leap[:3])
    off = next(i for i, fr in enumerate(leap) if min(fr["Toe_L"].translation.z, fr["Toe_R"].translation.z) > g + 0.06)
    top = max(range(off, len(leap)), key=lambda i: leap[i]["Hips"].translation.z)
    prep = strip_travel(F, [dict(fr) for fr in leap[:off]])
    air = [dict(fr) for fr in leap[off:top + 1]]
    strip_travel(F, air, keep_z=False)
    lift = prep[-1]["Hips"].translation.z - air[0]["Hips"].translation.z
    d = air[0]["Hips"].translation - F.L["Hips"].translation  # no ar o corpo fica em cima da cápsula (o jogo o leva)
    for fr in air:
        F.shift(fr, Vector((-d.x, -d.y, lift)))
    air += [dict(air[-1]) for _ in range(4)]
    out["LeapPrep"], out["LeapAir"] = prep, air
    # embrião (clones dos tubos, pose parada): costas arqueadas, pescoço e cabeça dobrados até os joelhos, pernas
    # recolhidas contra a barriga, braços encolhidos, cauda enrolada por baixo e em volta do lado do corpo
    fr = F.sample(arm, scene, REST[0], frames=0)[0]
    for b, deg in (("Spine", -18), ("Chest", -22), ("Neck1", -42), ("Neck2", -32), ("Neck3", -20), ("Head", -22),
                   ("Tail1", -22)):
        F.pitch(fr, b, deg)
    for b, deg in (("Tail2", 25), ("Tail4", 40), ("Tail6", 45), ("Tail8", 45)):
        F.yaw(fr, b, deg)
    for s in ("L", "R"):
        # pernas dobradas para a frente (giro em volta do eixo de lado do mundo: < 0 leva a ponta para a frente)
        for b, deg in (("Thigh", -75), ("Shin", 120), ("Meta", -80)):
            F.turn(fr, f"{b}_{s}", Matrix.Rotation(math.radians(deg), 3, "X"))
        for b, deg in (("Forearm", 35), ("Hand", 30)):
            F.pitch(fr, f"{b}_{s}", deg)
    out["Embryo"] = [fr, {b: m.copy() for b, m in fr.items()}]
    return out


def hands_down(F, frames, fore_max=8.0, hand_max=-2.0):
    """Regra do jogo para os braços (teste raptor_tests.test_arms_down): o antebraço não sobe acima da horizontal e a
    mão nunca aponta para cima ("braço fazendo muque"). Medido como o teste: a direção do osso em relação ao peito,
    posta no peito em repouso; o que passar é girado para baixo."""
    chest_rest = F.L["Chest"].to_3x3()
    for fr in frames:
        for s in ("L", "R"):
            for bone, top in ((f"Forearm_{s}", fore_max), (f"Hand_{s}", hand_max)):
                for _ in range(3):
                    d = chest_rest @ (fr["Chest"].to_3x3().inverted() @ F.axis(fr, bone))
                    elev = math.degrees(math.atan2(d.z, -d.y))
                    if elev <= top:
                        break
                    F.pitch(fr, bone, -(elev - top) - 0.5)
    return frames


def write_actions(rig, F, actions):
    """Grava as animações: rotação de todos os ossos, posição do quadril (e de quem se desloca em alguma)."""
    moving = {"Hips"}
    for frames in actions.values():
        for fr in frames:
            for n in F.keep:
                if F.keep[n].parent and F.basis(fr, n).translation.length > 1e-4:
                    moving.add(n)
    rig.animation_data_create()
    made = []
    for name, frames in actions.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        last = {}
        for k, fr in enumerate(frames):
            for n in F.keep:
                loc, q, _ = F.basis(fr, n).decompose()
                if n in last and last[n].dot(q) < 0:
                    q.negate()
                last[n] = q
                pb = rig.pose.bones[n]
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=k)
                if n in moving:
                    pb.location = loc
                    pb.keyframe_insert("location", frame=k)
        act.use_frame_range = True
        act.frame_range = (0, max(1, len(frames) - 1))
        made.append(act)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return made, moving


def measure(F, actions):
    """Números que o jogo usa (velocidade dos ciclos, quadros da boca): impressos e gravados em raptor_build.json."""
    def foot_speed(frames):
        sp = []
        for s in ("L", "R"):
            z = [fr["Toe_" + s].translation.z for fr in frames]
            g = min(z)
            for i in range(1, len(frames)):
                if z[i] < g + 0.025 and z[i - 1] < g + 0.025:
                    sp.append((frames[i]["Toe_" + s].translation - frames[i - 1]["Toe_" + s].translation).xy.length * FPS)
        sp.sort()
        return sp[len(sp) // 2] if sp else 0.0

    def jaw(fr):
        rest = F.Li["Head"] @ F.L["Jaw"]
        rel = fr["Head"].inverted() @ fr["Jaw"]
        return math.degrees(rest.to_quaternion().rotation_difference(rel.to_quaternion()).angle)

    out = {"fps": FPS}
    for n in ("Walk", "Run", "Stalk", "Jog"):
        out[f"{n.lower()}_speed"] = round(foot_speed(actions[n]), 3)
    for n, frames in actions.items():
        out[f"{n}_length"] = round((len(frames) - 1) / FPS, 3)
        j = [jaw(fr) for fr in frames]
        peak = max(range(len(j)), key=lambda i: j[i])
        out[f"{n}_jaw_max"] = [round(j[peak], 1), round(peak / FPS, 3)]
        shut = next((i for i in range(peak, len(j)) if j[i] < j[peak] * 0.3), None)
        out[f"{n}_jaw_shut"] = round(shut / FPS, 3) if shut is not None else None
        out[f"{n}_jaw_first"] = round(j[0], 1)
    return out
