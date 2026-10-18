"""Cinemática do esqueleto da heroína fora da cena: FK pelas matrizes de repouso e IK numérica.

As poses são dicionários como os de heroine_anims (graus na convenção do cabeçalho de lá, valores dos ossos _R
escritos com o significado do lado _L; "loc" = deslocamento do quadril em (esquerda, cima, frente)).
O build usa isto para resolver as pernas das caminhadas (pé parado no chão), os braços nas armas, na escalada e
ao pegar o fuzil. Coordenadas do Blender: X = esquerda dela, -Y = frente, Z = cima, raiz no chão em (0, 0, 0).
"""
import math

import numpy as np
from mathutils import Euler, Matrix, Vector

FWD = Vector((0, -1, 0))
LEFT = Vector((1, 0, 0))
UP = Vector((0, 0, 1))


class Skeleton:
    def __init__(self, rig):
        bones = rig.data.bones
        self.names = [b.name for b in bones]  # pais antes dos filhos (ordem de criação)
        self.parent = {b.name: b.parent.name if b.parent else None for b in bones}
        rest = {b.name: b.matrix_local.copy() for b in bones}
        self.rest = rest
        self.rel = {n: (rest[p].inverted() @ rest[n] if p else rest[n]) for n, p in self.parent.items()}
        self.length = {b.name: b.length for b in bones}

    @staticmethod
    def basis(name, pose):
        x, y, z = pose.get(name, (0, 0, 0))
        if name.endswith("_R"):
            y, z = -y, -z
        m = Euler((math.radians(x), math.radians(y), math.radians(z)), "ZYX").to_matrix().to_4x4()
        if name == "Hips":
            m = Matrix.Translation(pose.get("loc", (0, 0, 0))) @ m
        return m

    def matrices(self, pose):
        """Matriz de pose (espaço do esqueleto) de cada osso, igual a pose_bone.matrix do Blender."""
        out = {}
        for n in self.names:
            p = self.parent[n]
            out[n] = (out[p] @ self.rel[n] if p else self.rel[n]) @ self.basis(n, pose)
        return out

    def point(self, m, bone, along=0.0, offset=None):
        """Ponto a `along` metros da cabeça do osso, ao longo dele (+ `offset` no espaço de repouso do osso)."""
        local = Vector((0, along, 0))
        if offset is not None:
            local = local + self.rest[bone].to_3x3().inverted() @ Vector(offset)
        return m[bone] @ local

    def axis(self, m, bone, rest_dir):
        """Direção `rest_dir` (espaço do esqueleto, em repouso) carregada pela rotação atual do osso."""
        rot = m[bone].to_3x3() @ self.rest[bone].to_3x3().inverted()
        return (rot @ Vector(rest_dir)).normalized()


def _get(pose, u):
    bone, i = u
    return pose.get(bone, (0, 0, 0))[i]


def _set(pose, u, v):
    bone, i = u
    t = list(pose.get(bone, (0, 0, 0)))
    t[i] = v
    pose[bone] = tuple(t)


def solve(sk, pose, unknowns, residual, bounds=None, iters=80, tol=1e-4):
    """Ajusta as incógnitas (lista de (osso, eixo) ou ("loc", eixo)) de `pose` para zerar residual(matrizes).

    Levenberg-Marquardt com jacobiano numérico: com incógnitas sobrando, muda o mínimo a partir da pose dada
    (o chute inicial decide o jeito da pose). Ângulos em graus, `bounds` = {incógnita: (mín, máx)}.
    Devolve (pose, erro máximo)."""
    pose = dict(pose)
    bounds = bounds or {}
    e = np.array(residual(sk.matrices(pose)), dtype=float)
    lam = 1e-4
    for _ in range(iters):
        if np.max(np.abs(e)) < tol:
            break
        J = np.zeros((len(e), len(unknowns)))
        for k, u in enumerate(unknowns):
            h = 1e-3 if u[0] == "loc" else 0.05
            v0 = _get(pose, u)
            _set(pose, u, v0 + h)
            J[:, k] = (np.array(residual(sk.matrices(pose))) - e) / h
            _set(pose, u, v0)
        # amortecimento: 1 m de loc custa como 60° de ângulo
        scale = np.array([60.0 if u[0] == "loc" else 1.0 for u in unknowns])
        JtJ = J.T @ J
        g = J.T @ e
        while True:
            dx = -np.linalg.solve(JtJ + lam * np.diag(scale ** 2), g)
            trial = dict(pose)
            for u, d in zip(unknowns, dx):
                lo, hi = bounds.get(u, (-1e9, 1e9))
                _set(trial, u, min(max(_get(trial, u) + float(d), lo), hi))
            e2 = np.array(residual(sk.matrices(trial)), dtype=float)
            if e2 @ e2 < e @ e or lam > 1e8:
                break
            lam *= 8.0
        pose, e = trial, e2
        lam = max(lam / 4.0, 1e-6)
    return pose, float(np.max(np.abs(e))) if len(e) else 0.0


def leg_unknowns(s):
    return [(f"UpperLeg_{s}", 0), (f"UpperLeg_{s}", 1), (f"UpperLeg_{s}", 2), (f"LowerLeg_{s}", 0), (f"Foot_{s}", 0)]


def leg_bounds(s):
    return {(f"LowerLeg_{s}", 0): (-150.0, -2.0), (f"UpperLeg_{s}", 1): (-25.0, 25.0)}


def arm_unknowns(s, hand=True):
    out = [(f"UpperArm_{s}", 0), (f"UpperArm_{s}", 1), (f"UpperArm_{s}", 2), (f"LowerArm_{s}", 0)]
    if hand:
        out += [(f"LowerArm_{s}", 1), (f"Hand_{s}", 0), (f"Hand_{s}", 2)]
    return out


def arm_bounds(s):
    return {(f"LowerArm_{s}", 0): (2.0, 150.0), (f"LowerArm_{s}", 1): (-80.0, 80.0)}


def palm(sk, m, s):
    """Centro do punho fechado (onde a mão segura: borda, cabo da arma)."""
    return sk.point(m, f"Hand_{s}", 0.05)


def foot_rest(sk, s):
    """Tornozelo e ponta do pé em repouso (o pé chato no chão)."""
    m = sk.matrices({})
    return sk.point(m, f"Foot_{s}"), sk.point(m, f"Foot_{s}", sk.length[f"Foot_{s}"])
