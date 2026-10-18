"""Malha low-poly da heroína montada por "lofts" (anéis ligados), no jeito dos modelos de PS1.

Cada anel já nasce com UV no atlas e peso de osso (rígido, com mistura só nas juntas).
"""
import math

import bmesh
from mathutils import Matrix, Vector

import atlas
import heroine_spec as S

X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))

MAT_BODY = 0
MAT_HAIR = 1  # material sem backface culling (mechas abertas)


def ring_frame(t, b_hint=None):
    """Eixos do anel: a = lateral (perto de +X), b = profundidade (perto de +Y, as costas)."""
    t = t.normalized()
    a = X - X.dot(t) * t
    a.normalize()
    hint = b_hint if b_hint is not None else Y
    b = hint - hint.dot(t) * t - hint.dot(a) * a
    b.normalize()
    return a, b


class MeshBuilder:
    def __init__(self, bone_names, atlas_module=atlas, remap=None):
        """atlas_module: módulo com uv()/z_to_v() do atlas do personagem (o raptor usa o dele).
        remap(co, pesos) -> co: ajuste de proporção aplicado à posição de cada vértice (o UV continua o original)."""
        self.atlas = atlas_module
        self.remap = remap
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.dl = self.bm.verts.layers.deform.new()
        self.groups = {n: i for i, n in enumerate(bone_names)}

    def _weights(self, v, weights):
        total = sum(weights.values())
        dv = v[self.dl]
        for bone, w in weights.items():
            dv[self.groups[bone]] = w / total

    def _vert(self, co, weights):
        v = self.bm.verts.new(self.remap(co, weights) if self.remap else co)
        self._weights(v, weights)
        return v

    def _face(self, verts, uvs, mat):
        f = self.bm.faces.new(verts)
        f.material_index = mat
        for loop, t in zip(f.loops, uvs):
            loop[self.uv].uv = t
        return f

    def loft(self, rings, rect, sides, caps=(True, True), arc=None, mat=MAT_BODY, b_hint=None, v_by_z=False):
        """Liga anéis consecutivos com quads.

        Cada anel: {"c": centro, "rx", "ry", "w": {osso: peso}, "push": {j: metros}, "arc": (th0, th1)}.
        th = 0 aponta para b (costas), th = pi/2 para a (esquerda), th = pi para a frente.
        """
        n = len(rings)
        frames = []
        for i, r in enumerate(rings):
            if "frame" in r:
                frames.append(r["frame"])
                continue
            p0 = rings[max(0, i - 1)]["c"]
            p1 = rings[min(n - 1, i + 1)]["c"]
            frames.append(ring_frame(p1 - p0, b_hint))

        # v: altura (peças verticais) ou comprimento acumulado normalizado
        if v_by_z:
            vs = [self.atlas.z_to_v(rect, r["c"].z) for r in rings]
        else:
            acc = [0.0]
            for i in range(1, n):
                acc.append(acc[-1] + (rings[i]["c"] - rings[i - 1]["c"]).length)
            vs = [d / acc[-1] for d in acc]

        open_ring = arc is not None or any("arc" in r for r in rings)
        count = sides + 1 if open_ring else sides
        grid = []
        for i, r in enumerate(rings):
            a, b = frames[i]
            th0, th1 = r.get("arc", arc) if open_ring else (0.0, 2 * math.pi)
            row = []
            for j in range(count):
                th = th0 + (th1 - th0) * j / sides
                local = a * (r["rx"] * math.sin(th)) + b * (r["ry"] * math.cos(th))
                p = r["c"] + local
                push = r.get("push", {}).get(j, 0.0)
                if push:
                    p = p + local.normalized() * push
                # "wfn": pesos por vértice (j = índice na volta); senão o anel inteiro usa "w"
                row.append(self._vert(p, r["wfn"](j) if "wfn" in r else r["w"]))
            grid.append(row)

        t0 = (rings[1]["c"] - rings[0]["c"]).normalized()
        a0, b0 = frames[0]
        outward = t0.dot(a0.cross(b0)) > 0
        for i in range(n - 1):
            for j in range(sides):
                j1 = j + 1 if open_ring else (j + 1) % sides
                uj, uj1 = j / sides, (j + 1) / sides
                quad = [(i, j, uj), (i + 1, j, uj), (i + 1, j1, uj1), (i, j1, uj1)]
                if not outward:
                    quad.reverse()
                self._face(
                    [grid[ii][jj] for ii, jj, _ in quad],
                    [self.atlas.uv(rect, u, vs[ii]) for ii, _, u in quad],
                    mat,
                )
        if open_ring:
            return
        for idx, want_start in ((0, True), (n - 1, False)):
            if not caps[0 if want_start else 1]:
                continue
            a, b = frames[idx]
            t = (rings[min(idx + 1, n - 1)]["c"] - rings[max(idx - 1, 0)]["c"]).normalized()
            ring_order = t.dot(a.cross(b)) > 0
            order = list(range(sides))
            if ring_order != want_start:
                order.reverse()
            self._face([grid[idx][j] for j in order], [self.atlas.uv(rect, j / sides, vs[idx]) for j in order], mat)

    def box(self, center, ax, ay, half, rect, weights, mat=MAT_BODY):
        """Caixa orientada (bolsos, coldre, pistola). half = meias-medidas ao longo de ax, ay, ax x ay."""
        ax, ay = ax.normalized(), ay.normalized()
        az = ax.cross(ay).normalized()
        m = Matrix((ax * 2 * half[0], ay * 2 * half[1], az * 2 * half[2])).transposed().to_4x4()
        m.translation = center
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        faces = {f for v in res["verts"] for f in v.link_faces}
        for v in res["verts"]:
            self._weights(v, weights)
            if self.remap:
                v.co = self.remap(v.co, weights)
        corners = [(0, 1), (1, 1), (1, 0), (0, 0)]
        for f in faces:
            f.material_index = mat
            for loop, (u, v) in zip(f.loops, corners):
                loop[self.uv].uv = self.atlas.uv(rect, u, v)


def R(c, rx, ry, w, push=None, **extra):
    d = {"c": Vector(c), "rx": rx, "ry": ry, "w": w}
    if push:
        d["push"] = push
    d.update(extra)
    return d


# ------------------------------------------------------------------ peças
TORSO_SIDES = 16

# (z, centro y, rx, ry, ossos): do gancho até a base do pescoço
TORSO = [
    (0.80, 0.000, 0.110, 0.085, {"Hips": 1}),
    (0.84, 0.000, 0.150, 0.100, {"Hips": 1}),
    (0.88, 0.004, 0.168, 0.110, {"Hips": 1}),
    (0.92, 0.004, 0.176, 0.112, {"Hips": 1}),
    (0.96, 0.000, 0.170, 0.106, {"Hips": 1}),
    (1.00, 0.000, 0.155, 0.098, {"Hips": 0.5, "Spine": 0.5}),
    (1.05, 0.000, 0.135, 0.090, {"Spine": 1}),
    (1.10, -0.003, 0.133, 0.090, {"Spine": 1}),
    (1.15, -0.006, 0.140, 0.094, {"Spine": 0.7, "Chest": 0.3}),
    (1.20, -0.008, 0.150, 0.100, {"Spine": 0.3, "Chest": 0.7}),
    (1.26, -0.008, 0.158, 0.104, {"Chest": 1}),
    (1.32, -0.005, 0.164, 0.102, {"Chest": 1}),
    (1.37, 0.000, 0.160, 0.094, {"Chest": 1}),
    (1.41, 0.000, 0.128, 0.082, {"Chest": 1}),
    (1.44, 0.000, 0.094, 0.068, {"Chest": 1}),
    (1.47, 0.000, 0.068, 0.062, {"Chest": 0.5, "Neck": 0.5}),
]


def _lobe(th, z, th_c, z_c, amp, s_th, s_z):
    d = math.atan2(math.sin(th - th_c), math.cos(th - th_c))
    return amp * math.exp(-(d / s_th) ** 2 - ((z - z_c) / s_z) ** 2)


def torso_volume(th, z):
    """Volume do tronco além da elipse do anel (th: 0 = costas, pi/2 = esquerda dela, pi = frente)."""
    v = 0.0
    for k in (1, -1):
        v += _lobe(th, z, math.pi - k * 0.62, 1.255, 0.05, 0.42, 0.055)  # busto
        v += _lobe(th, z, k * 0.55, 0.885, 0.024, 0.5, 0.06)  # glúteos
        v += _lobe(th, z, k * 0.6, 1.33, 0.01, 0.35, 0.05)  # escápulas
    v -= _lobe(th, z, 0.0, 1.15, 0.006, 0.18, 0.15)  # sulco da coluna
    return v


def _shoulder_share(th, z):
    """Quanto do vértice do tronco segue o braço: lateral do tronco na altura do ombro acompanha o braço
    erguido (senão a manga gira e abre um vão entre ela e o corpo)."""
    zs = [(1.28, 0.0), (1.32, 0.12), (1.37, 0.35), (1.41, 0.45), (1.44, 0.2), (1.47, 0.0)]
    k = 0.0
    for (z0, k0), (z1, k1) in zip(zs, zs[1:]):
        if z0 <= z <= z1:
            k = k0 + (k1 - k0) * (z - z0) / (z1 - z0)
    side = abs(math.atan2(math.sin(th - math.pi / 2), math.cos(th - math.pi / 2)))
    return k * max(0.0, 1 - side / 0.85) ** 1.5


def _torso_weights(base, z):
    def wfn(j):
        th = 2 * math.pi * j / TORSO_SIDES
        w = dict(base)
        for s, center in (("L", th), ("R", th - math.pi)):  # esquerda dela em pi/2, direita em 3pi/2
            a = _shoulder_share(center, z)
            if a > 0:
                w = {b: v * (1 - a) for b, v in w.items()}
                w[f"UpperArm_{s}"] = w.get(f"UpperArm_{s}", 0) + a
        return w
    return wfn


def build_torso(mb):
    rings = []
    for z, y, rx, ry, w in TORSO:
        push = {j: torso_volume(2 * math.pi * j / TORSO_SIDES, z) for j in range(TORSO_SIDES)}
        rings.append(R((0, y, z), rx, ry, w, push, frame=(X, Y), wfn=_torso_weights(w, z)))
    mb.loft(rings, "torso", TORSO_SIDES, v_by_z=True)


def build_neck(mb):
    neck = {"Neck": 1}
    mb.loft([
        R((0, -0.003, 1.43), 0.07, 0.065, {"Chest": 0.5, "Neck": 0.5}),
        R((0, -0.005, 1.47), 0.052, 0.05, neck),
        R((0, -0.008, 1.50), 0.047, 0.047, neck),
        R((0, -0.01, 1.535), 0.045, 0.045, {"Neck": 0.5, "Head": 0.5}),
    ], "neck", 8)


def build_arm(mb, s):
    ua, la, hand, chest = f"UpperArm_{s}", f"LowerArm_{s}", f"Hand_{s}", "Chest"
    p = lambda d: S.arm_point(s, d)
    UA, w0 = S.UPPER_ARM_LEN, S.UPPER_ARM_LEN + S.FOREARM_LEN
    pu = lambda f: p(UA * f)  # fração do braço
    pl = lambda f: p(UA + S.FOREARM_LEN * f)  # fração do antebraço
    # braço fino de mulher (jaqueta justa): deltoide discreto, bíceps e antebraço afinando até o punho
    mb.loft([
        # topo em domo (deltoide): uma tampa chata aqui virava "ombreira"
        R(p(-0.058), 0.014, 0.018, {chest: 0.6, ua: 0.4}),
        R(p(-0.042), 0.030, 0.035, {chest: 0.5, ua: 0.5}),
        R(p(-0.015), 0.041, 0.046, {chest: 0.3, ua: 0.7}),
        R(pu(0.075), 0.045, 0.050, {chest: 0.12, ua: 0.88}),
        R(pu(0.26), 0.044, 0.047, {ua: 1}),
        R(pu(0.53), 0.040, 0.043, {ua: 1}),
        R(pu(0.79), 0.036, 0.039, {ua: 1}),
        R(p(UA + 0.005), 0.034, 0.036, {ua: 0.5, la: 0.5}),
    ], "sleeve_upper", 8)
    mb.loft([
        R(p(UA - 0.005), 0.035, 0.037, {ua: 0.5, la: 0.5}),
        R(pl(0.25), 0.036, 0.039, {la: 1}),
        R(pl(0.58), 0.031, 0.033, {la: 1}),
        R(p(w0 - 0.04), 0.027, 0.029, {la: 1}),
        R(p(w0 - 0.01), 0.032, 0.034, {la: 0.7, hand: 0.3}),
        R(p(w0 + 0.005), 0.026, 0.028, {la: 0.5, hand: 0.5}),
    ], "sleeve_lower", 8)
    # punho fechado (curto): os dedos dobrados terminam a ~9,5 cm do pulso
    mb.loft([
        R(p(w0), 0.022, 0.03, {hand: 0.6, la: 0.4}),
        R(p(w0 + 0.03), 0.026, 0.042, {hand: 1}),
        R(p(w0 + 0.06), 0.028, 0.046, {hand: 1}),
        R(p(w0 + 0.083), 0.025, 0.042, {hand: 1}),
        R(p(w0 + 0.097), 0.015, 0.03, {hand: 1}),
    ], "hand", 6)
    t = S.side(S.ARM_DIR_L, s)
    a, _ = ring_frame(t)
    # polegar na frente do punho fechado
    mb.box(p(w0 + 0.04) + Vector((0, -0.047, 0)), a, Y, (0.013, 0.011, 0.025), "hand", {hand: 1})


def build_leg(mb, s):
    k = 1 if s == "L" else -1
    ul, ll, foot, hips = f"UpperLeg_{s}", f"LowerLeg_{s}", f"Foot_{s}", "Hips"
    # coxa cheia em cima (lado de fora mais largo), afinando devagar até o joelho; panturrilha atrás
    outer = lambda a: {2 if k > 0 else 6: a, 1 if k > 0 else 7: a * 0.6, 3 if k > 0 else 5: a * 0.6}
    mb.loft([
        R((k * 0.085, 0, 0.93), 0.092, 0.100, {hips: 0.5, ul: 0.5}),
        R((k * 0.09, 0, 0.86), 0.093, 0.102, {hips: 0.2, ul: 0.8}, outer(0.022)),
        R((k * 0.092, -0.003, 0.78), 0.088, 0.096, {ul: 1}, outer(0.018)),
        R((k * 0.092, -0.006, 0.69), 0.079, 0.087, {ul: 1}, outer(0.008)),
        R((k * 0.091, -0.008, 0.60), 0.067, 0.073, {ul: 1}),
        R((k * 0.09, -0.01, 0.53), 0.055, 0.060, {ul: 1}),
        R((k * 0.09, -0.01, 0.48), 0.049, 0.053, {ul: 0.5, ll: 0.5}),
    ], "thigh", 8, v_by_z=True)
    calf = {0: 0.012, 1: 0.008, 7: 0.008}
    mb.loft([
        R((k * 0.09, -0.01, 0.51), 0.048, 0.052, {ul: 0.5, ll: 0.5}),
        R((k * 0.09, -0.005, 0.45), 0.050, 0.054, {ll: 1}),
        R((k * 0.09, 0.0, 0.39), 0.050, 0.054, {ll: 1}, calf),
        R((k * 0.09, 0.005, 0.32), 0.046, 0.05, {ll: 1}, calf),
        R((k * 0.09, 0.01, 0.22), 0.042, 0.046, {ll: 1}),
        R((k * 0.09, 0.015, 0.12), 0.04, 0.045, {ll: 0.7, foot: 0.3}),
        R((k * 0.09, 0.02, 0.08), 0.04, 0.046, {ll: 0.5, foot: 0.5}),
    ], "shin", 8, v_by_z=True)
    fr = (X, Z)  # pé: anel em X (largura) e Z (altura)
    mb.loft([
        R((k * 0.09, 0.07, 0.055), 0.04, 0.05, {ll: 0.3, foot: 0.7}, frame=fr),
        R((k * 0.09, 0.0, 0.05), 0.043, 0.05, {foot: 1}, frame=fr),
        R((k * 0.09, -0.09, 0.04), 0.046, 0.04, {foot: 1}, frame=fr),
        R((k * 0.09, -0.17, 0.028), 0.038, 0.028, {foot: 1}, frame=fr),
    ], "foot", 6)


def build_gear(mb):
    sc = {"Spine": 0.4, "Chest": 0.6}
    for k in (1, -1):
        mb.box(Vector((k * 0.075, -0.105, 1.14)), X, Y, (0.035, 0.018, 0.042), "pouch", sc)
        mb.box(Vector((k * 0.15, -0.06, 0.965)), X, Y, (0.025, 0.03, 0.035), "pouch", {"Hips": 1})
    mb.box(Vector((0, 0.12, 0.965)), X, Y, (0.06, 0.02, 0.03), "pouch", {"Hips": 1})
    # coldre na coxa direita e bolsa de pulso no antebraço esquerdo (como na referência)
    mb.box(Vector((-0.188, -0.005, 0.76)), X, Y, (0.018, 0.045, 0.07), "leather", {"UpperLeg_R": 1})
    t = S.ARM_DIR_L
    a, _ = ring_frame(t)
    mb.box(S.arm_point("L", S.UPPER_ARM_LEN + S.FOREARM_LEN * 0.62) + a * 0.042, a, Y, (0.012, 0.03, 0.035), "pouch", {"LowerArm_L": 1})


def pistol_frame():
    """Origem e eixos da pistola na mão direita: t = ao longo da mão (cano), u = lado do polegar (em cima ao mirar)."""
    t = S.side(S.ARM_DIR_L, "R")
    a, _ = ring_frame(t)
    return S.wrist("R"), t, a, -Y


GRIP_RAKE = math.radians(16)  # cabo inclinado para trás, como numa pistola de verdade


def muzzle_position():
    w, t, _, u = pistol_frame()
    return w + t * 0.19 + u * 0.06


def build_pistol(mb):
    w, t, a, u = pistol_frame()
    hand = {"Hand_R": 1}
    # ferrolho por cima do punho, passando bem da mão (cano para a frente)
    mb.box(w + t * 0.10 + u * 0.062, a, u, (0.0125, 0.016, 0.089), "pistol", hand)
    # armação sob o ferrolho, na frente do cabo
    mb.box(w + t * 0.128 + u * 0.038, a, u, (0.011, 0.009, 0.05), "pistol", hand)
    # cabo atravessando o punho, saindo por baixo do dedo mínimo
    down = -(u * math.cos(GRIP_RAKE) + t * math.sin(GRIP_RAKE))
    top = w + t * 0.058 + u * 0.046
    mb.box(top + down * 0.058, a, down, (0.0115, 0.058, 0.024), "pistol", hand)
    # guarda-mato (fundo e frente)
    mb.box(w + t * 0.108 + u * 0.006, a, u, (0.007, 0.004, 0.02), "pistol", hand)
    mb.box(w + t * 0.126 + u * 0.018, a, u, (0.007, 0.012, 0.004), "pistol", hand)


RIGID_UPPER = ("Arm", "Hand", "Neck", "Head")  # braços, pistola e cabeça não passam pelo remap de altura


def _proportion(co, weights):
    if any(part in bone for bone in weights for part in RIGID_UPPER):
        return co
    return S.rz(co)


def build_all(bone_names):
    mb = MeshBuilder(bone_names, remap=_proportion)
    build_torso(mb)
    import heroine_head  # cabeça e cabelo (importado aqui: o módulo usa R e MAT_HAIR daqui)

    build_neck(mb)
    heroine_head.build_head(mb)
    heroine_head.build_hair(mb)
    for s in ("L", "R"):
        build_arm(mb, s)
        build_leg(mb, s)
    build_gear(mb)
    return mb


def build_weapon(bone_names, kind):
    """Pistola, fuzil ou escopeta (sem a telha) numa malha à parte (o Godot mostra só a arma em uso), presa à mão
    direita."""
    mb = MeshBuilder(bone_names)
    if kind == "pistol":
        build_pistol(mb)
    elif kind == "shotgun":
        import heroine_rifle
        import heroine_shotgun

        heroine_shotgun.build_shotgun(mb, heroine_rifle.grip_rest(), {"Hand_R": 1}, pump=False)
    else:
        import heroine_rifle

        heroine_rifle.build_rifle(mb, heroine_rifle.grip_rest(), {"Hand_R": 1})
    return mb
