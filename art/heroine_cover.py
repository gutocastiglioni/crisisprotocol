"""Encostada de costas na caixa/parede (PlayerCover no jogo): parada perto de uma cobertura, ela vira de costas para
ela, apoia o quadril e as omoplatas e olha para um lado, a pistola em guarda nas duas mãos. Quatro ciclos de
respiração: CoverL / CoverR (em pé, olhando para a esquerda / direita dela) e CoverCrouchL / CoverCrouchR (agachada).
Andando de lado colada na parede o jogo usa os passos laterais de sempre.

Geometria (a mesma do Godot, lida do heroine_moves.json "cover"): a parede é um plano vertical `WALL` metros atrás da
raiz (a cápsula do jogo tem raio 0,28). Os pés ficam embaixo da raiz e o corpo reclina até o glúteo e as omoplatas
(`BACK`, pontos de trás da malha medidos em repouso) tocarem o plano: é o jeito de quem se escora, pés à frente.
"""
from mathutils import Vector

import heroine_ik as IK
import heroine_moves as M

WALL = 0.30  # da raiz ao plano da parede, atrás dela
TOUCH = 0.008  # folga entre a pele e a parede
# pontos mais de trás da malha em repouso (espaço do Blender: X esquerda, +Y trás, Z cima), medidos no heroine.blend:
# glúteo (osso Hips) e omoplatas (Chest); a cabeça (Head) não pode passar da parede
BACK = {"Hips": Vector((0.0, 0.115, 0.959)), "Chest": Vector((0.0, 0.092, 1.355))}
HEAD_BACK = Vector((0.0, 0.104, 1.579))
FRAMES = 80  # ciclo de respiração
DATA = None  # medidas para o heroine_moves.json (preenchidas por cover_keys, durante o build das animações)

# olhando para a esquerda dela (o lado R é o espelho): cabeça e pescoço virados, peito acompanha um pouco
LOOK_L = {"Chest": (0, 8, 0), "Neck": (4, 18, 0), "Head": (2, 42, 0)}
# quadril um pouco abaixo do de pé: os joelhos dobram de leve (escorada, não tábua); o IK prende os pés
STAND_LEGS = {"loc": (0, -0.035, 0), "UpperLeg_L": (6, 0, 5), "UpperLeg_R": (6, 0, 5), "LowerLeg_L": (-12, 0, 0),
              "LowerLeg_R": (-12, 0, 0)}
FEET = {"stand": (0.105, -0.04), "crouch": (0.13, -0.02)}  # tornozelo: abertura (cada lado) e frente (m, -Y = frente)


def _back_points(sk, m):
    return [m[bone] @ (sk.rest[bone].inverted() @ p) for bone, p in BACK.items()]


def _head_back(sk, m):
    return m["Head"] @ (sk.rest["Head"].inverted() @ HEAD_BACK)


def _feet(sk, pose, spread, fwd):
    """Pés chatos no chão, abertos `spread` (cada lado) e `fwd` à frente da raiz."""
    pose = dict(pose)
    for s in ("L", "R"):
        ankle, toe = IK.foot_rest(sk, s)
        tgt = Vector((spread if s == "L" else -spread, fwd, M.ANKLE_Z))
        d = (toe - ankle).normalized()

        def res(m, s=s, tgt=tgt, d=d):
            a = sk.point(m, f"Foot_{s}")
            t = sk.point(m, f"Foot_{s}", sk.length[f"Foot_{s}"])
            return list(a - tgt) + list(((t - a).normalized() - d) * 0.15)

        pose, err = IK.solve(sk, pose, IK.leg_unknowns(s), res, IK.leg_bounds(s))
        if err > 0.01:
            print(f"[cover] pé {s} longe do chão: {err * 1000:.0f} mm")
    return pose


def lean_back(sk, pose, tag):
    """Reclina o corpo (quadril para trás, coluna e peito) até glúteo e omoplatas tocarem a parede."""
    plane = WALL - TOUCH
    unk = [("loc", 2), ("Spine", 0), ("Chest", 0)]

    def res(m):
        return [p.y - plane for p in _back_points(sk, m)]

    pose, err = IK.solve(sk, pose, unk, res, {("Spine", 0): (-30.0, 30.0), ("Chest", 0): (-25.0, 25.0)})
    if _head_back(sk, sk.matrices(pose)).y > plane:  # cabeça passando da parede: o pescoço dobra para a frente
        pose["Neck"] = tuple(a + b for a, b in zip(pose.get("Neck", (0, 0, 0)), (8, 0, 0)))
    if err > 0.01:
        print(f"[cover] {tag}: costas longe da parede ({err * 1000:.0f} mm)")
    return pose


def _pose(A, sk, base, feet, look, tag):
    # o IK (heroine_ik) usa o "loc" como está e o build o multiplica por LOC_SCALE: resolve no tamanho real e devolve
    # dividido, para o corpo do Blender ficar onde o IK calculou
    k = A.LOC_SCALE
    base = dict(base)
    base["loc"] = tuple(c * k for c in base.get("loc", (0, 0, 0)))
    pose = lean_back(sk, base, tag)
    pose = _feet(sk, pose, *feet)
    pose = A.merge(pose, look)
    pose.update(A.pistol_guard(sk, pose))  # guarda baixa nas duas mãos, sobre o tronco já reclinado
    pose["loc"] = tuple(c / k for c in pose["loc"])
    return pose


def cover_keys(A, sk):
    """Os quatro ciclos: nome -> lista de (quadro, pose)."""
    global DATA
    arms = ("UpperArm", "LowerArm", "Hand")
    stand = {k: v for k, v in A.merge(A.IDLE, STAND_LEGS).items() if not k.startswith(arms)}
    crouch = {k: v for k, v in A.CROUCH.items() if not k.startswith(arms)}
    crouch["Spine"] = (6, 0, 0)  # mais em pé que a agachada solta: as costas vão na parede
    crouch["Head"] = (-6, 0, 0)
    out = {}
    for name, base, feet in (("Cover", stand, FEET["stand"]), ("CoverCrouch", crouch, FEET["crouch"])):
        for s, look in (("L", LOOK_L), ("R", A.mirror(LOOK_L))):
            pose = _pose(A, sk, base, feet, look, name + s)
            breath = A.merge(pose, {"Chest": (-1.2, 0, 0), "Head": (1.5, 4 if s == "L" else -4, 0)})
            out[name + s] = [(0, pose), (FRAMES // 2, breath), (FRAMES, pose)]
    def real(pose):
        return dict(pose, loc=tuple(c * A.LOC_SCALE for c in pose["loc"]))

    stand_m = sk.matrices(real(out["CoverL"][0][1]))
    crouch_m = sk.matrices(real(out["CoverCrouchL"][0][1]))
    DATA = {
        "wall": WALL,
        # alturas do glúteo e das omoplatas (a parede tem que existir ali), em pé e agachada
        "back_stand": [round(p.z, 3) for p in _back_points(sk, stand_m)],
        "back_crouch": [round(p.z, 3) for p in _back_points(sk, crouch_m)],
    }
    print(f"[cover] LOC_SCALE {A.LOC_SCALE:.3f}; costas em pé {DATA['back_stand']}, agachada {DATA['back_crouch']}")
    return out
