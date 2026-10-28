"""Parte de cima do guerrilheiro encapuzado numa pele só (regra do CLAUDE.md, "Modelos de personagem"), no jeito do
raptor: lofts de anéis que se emendam por anéis compartilhados (soldados) e se cruzam onde uma peça sai da outra (braço
do peito, bolsas do colete, cordões do capuz); a união booleana (raptor_mesh._self_union) funde tudo numa superfície e
arredonda as emendas, menos as do equipamento rígido (quinas vivas e sombreado chapado).

Roupa = volume na própria pele: o tronco segue o contorno do colete (placas da frente e de trás largas, lateral
recolhida onde o braço caído passa, sem tocá-lo abaixo da axila) e, fora da cava, o moletom mais para dentro: o degrau é
a borda do colete; o capuz é o anel da cabeça com a frente afundada até o rosto (balaclava). Embaixo o tronco entra na cintura da
calça de antes (art/guerrilla_lower.py), por baixo do cinto. Medidas e cores: art/guerrilla_spec.py. Atlas:
tools/make_guerrilla_texture.py.
"""
import math

import bmesh
import bpy
from mathutils import Vector

import guerrilla_arms
import guerrilla_atlas
import guerrilla_head
import guerrilla_lower
import guerrilla_spec as G
import guerrilla_vest
import heroine_rig
import heroine_spec as S
import raptor_mesh
from heroine_mesh import X, Y, Z, MeshBuilder, R, ring_frame

SHARP = math.radians(40)  # com o colete: quinas acima disso ficam vivas (o resto é liso)
MAT_SKIN, MAT_GEAR = 0, 1  # MAT_GEAR: faces de sombreado chapado (vira o mesmo material no fim)
ARM_MATERIAL = None  # material dos braços do corpo base (índice 2), quando eles entram
HEAD_MATERIALS = []  # rosto (3), olhos (4) e janela dos olhos (5) da cabeça do corpo base, quando ela entra


def _torso_ring(z):
    """Volta do tronco na altura z: onde o colete cobre (abaixo da axila tudo; acima, até a cava), o contorno dele;
    no resto o moletom, mais para dentro (o degrau é a borda do colete). A placa da frente salta PLATE."""
    pts = []
    for j in range(G.TORSO_SIDES):
        th = 2 * math.pi * j / G.TORSO_SIDES
        x, y = G.body_point(z, th)
        v = G.vest_point(z, th)
        if v is not None and G.vest_covers(z, v[0]):
            x, y = v
            if 1.0 <= z <= 1.40 and y < 0 and abs(x) < 0.16:
                y -= G.PLATE * math.cos(abs(x) / 0.16 * math.pi / 2)
        pts.append(Vector((x, y, z)))
    return pts


def _torso_wfn(base, z):
    def wfn(j):
        th = 2 * math.pi * j / G.TORSO_SIDES
        w = dict(base)
        for s, center in (("L", th), ("R", th - math.pi)):  # esquerda em pi/2, direita em 3pi/2
            a = G.shoulder_share(center, z)
            if a > 0:
                w = {b: v * (1 - a) for b, v in w.items()}
                w[f"UpperArm_{s}"] = w.get(f"UpperArm_{s}", 0) + a
        return w
    return wfn


NECK = R((0, G.NECK_RING[1], G.NECK_RING[0]), G.NECK_RING[2], G.NECK_RING[3], {"Chest": 0.5, "Neck": 0.5}, frame=(X, Y))


def build_torso(mb, top_cap=False):
    rings = []
    for z, yc, rx, ryf, ryb in G.BODY:
        w = G.torso_bones(z)
        rings.append(R((0, yc, z), rx, ryf, w, pts=_torso_ring(z), frame=(X, Y), wfn=_torso_wfn(w, z)))
    mb.loft(rings + [NECK], "torso", G.TORSO_SIDES, caps=(True, top_cap), v_by_z=True)


def build_bare_torso(mb, upto=None, close=False):
    """Tronco do personagem sem colete (moletom), do quadril ao pescoço. Sem `upto`: fechado em cima (prévia sem a
    cabeça). Com `upto`: para nesse anel, aberto (`close`: fechado, para a união; a tampa sai depois), e o devolve."""
    rings = []
    for z, yc, rx, ryf, ryb in G.BARE:
        if upto is not None and z > upto + 1e-6:
            continue
        pts = []
        for j in range(G.TORSO_SIDES):
            th = 2 * math.pi * j / G.TORSO_SIDES
            c, sn = math.cos(th), math.sin(th)
            ry = ryb if c > 0 else ryf
            push = G.bare_volume(th, z)
            n = Vector((sn / max(rx, 1e-6), c / max(ry, 1e-6), 0.0)).normalized()  # normal da elipse
            pts.append(Vector((rx * sn, yc + ry * c, z)) + n * push)
        w = G.torso_bones(z) if z < 1.50 else {"Chest": 0.4, "Neck": 0.6}
        rings.append(R((0, yc, z), rx, ryf, w, pts=pts, frame=(X, Y), wfn=_torso_wfn(w, z)))
    mb.loft(rings, "torso", G.TORSO_SIDES, caps=(True, upto is None or close), v_by_z=True)
    return rings[-1]


def build_bare_cords(mb):
    """Cordões do capuz: saem de dentro da gola (na frente do pescoço) e caem sobre o peito do moletom."""
    for x in G.CORDS:
        mb.loft([
            R((x, -0.050, 1.535), 0.006, 0.006, {"Neck": 1}),
            R((x, -0.092, 1.510), 0.0045, 0.0045, {"Neck": 0.5, "Chest": 0.5}),
            R((x, -0.108, 1.470), 0.0045, 0.0045, {"Chest": 1}),
            R((x, -0.124, 1.430), 0.0055, 0.0055, {"Chest": 1}),
        ], "cord", 4, mat=MAT_GEAR)


def _hood_ring(z, yc, rx, ryf, ryb, opening, face_k):
    """Volta do capuz na altura z: elipse (frente ryf, costas ryb) e, onde há abertura, a frente afunda até o rosto
    (FACE: a partir do meio da frente; FACE_RIM = a borda do capuz)."""
    rim_y = yc - ryf
    front = G.HEAD_SIDES // 2
    pts = []
    for j in range(G.HEAD_SIDES):
        th = 2 * math.pi * j / G.HEAD_SIDES
        c = math.cos(th)
        p = Vector((rx * math.sin(th), yc + (ryb if c > 0 else ryf) * c, z))
        k = 1.0 if j < front else -1.0
        off = abs(j - front)
        target = None
        if off == G.FACE_RIM:
            target = Vector((k * G.RIM_X, rim_y, z))
        elif off in G.FACE:
            w, back = G.FACE[off]
            target = Vector((k * w * face_k, rim_y + back, z))  # face_k: o rosto afina no queixo e na testa
        if target is not None and opening > 0:
            p = p.lerp(target, opening)
        pts.append(p)
    return pts


def build_hood(mb, start=None):
    """Capuz a partir do anel `start` (o pescoço do tronco, soldado) ou do NECK do colete."""
    first = start or NECK
    rings = [first]
    for z, yc, rx, ryf, ryb, opening, face_k in G.HOOD:
        if z <= first["c"].z + 1e-6:
            continue
        w = {"Neck": 1} if z < 1.54 else ({"Neck": 0.3, "Head": 0.7} if z < 1.57 else {"Head": 1})
        rings.append(R((0, yc, z), rx, ryf, w, pts=_hood_ring(z, yc, rx, ryf, ryb, opening, face_k)))
    mb.loft(rings, "head", G.HEAD_SIDES, caps=(False, True), v_by_z=True)


def build_arm(mb, s):
    k = 1 if s == "L" else -1
    ua, la, hand = f"UpperArm_{s}", f"LowerArm_{s}", f"Hand_{s}"
    p = lambda t: S.arm_point(s, t)
    frame = ring_frame(S.side(S.ARM_DIR_L, s))
    elbow = R(p(G.UPPER_ARM), *G.ELBOW_R, {ua: 0.5, la: 0.5}, frame=frame)
    wrist = R(p(G.UPPER_ARM + G.FOREARM), *G.WRIST_R, {la: 0.5, hand: 0.5}, frame=frame)
    upper = []
    for t, rx, ry in G.SLEEVE_UPPER:
        w = {"Chest": 0.5, ua: 0.5} if t < 0 else ({"Chest": 0.2, ua: 0.8} if t < 0.05 else {ua: 1})
        upper.append(R(p(t), rx, ry, w, frame=frame))  # anéis ao longo do braço: o alto do ombro é uma cúpula
    mb.loft(upper + [elbow], "sleeve_upper", G.ARM_SIDES, caps=(True, False))
    lower = [R(p(t), rx, ry, {la: 0.7, hand: 0.3} if i == len(G.SLEEVE_LOWER) - 1 else {la: 1})
             for i, (t, rx, ry) in enumerate(G.SLEEVE_LOWER)]
    mb.loft([elbow] + lower + [wrist], "sleeve_lower", G.ARM_SIDES, caps=(False, False))
    # punho fechado; o polegar é o volume do lado de dentro da frente (j = 5 na esquerda, 3 na direita: o eixo a do
    # anel aponta para +X nos dois braços)
    thumb = 5 if s == "L" else 3
    fist = [R(p(t), rx, ry, {hand: 1}, {thumb: G.THUMB} if i < len(G.FIST) - 1 else None) for i, (t, rx, ry) in enumerate(G.FIST)]
    mb.loft([wrist] + fist, "hand", G.ARM_SIDES, caps=(False, True))


def build_arm_stump(mb, s, cut=0.13):
    """Braço cortado no meio do bíceps (corpo revisado sem os braços): nasce de dentro do peito (o ombro é a saída dele
    pelo tronco, soldada pela união) e desce ao longo do braço até `cut`, onde fecha."""
    k = 1 if s == "L" else -1
    ua = f"UpperArm_{s}"
    p = lambda t: S.arm_point(s, t)
    frame = ring_frame(S.side(S.ARM_DIR_L, s))
    rings = [
        R((k * 0.11, 0.0, G.SHOULDER[2] + 0.02), 0.045, 0.050, {"Chest": 1}),  # dentro do peito
        R(p(-0.025), 0.052, 0.056, {"Chest": 0.5, ua: 0.5}),
        R(p(0.030), 0.056, 0.058, {"Chest": 0.15, ua: 0.85}, frame=frame),
        R(p(0.080), 0.055, 0.057, {ua: 1}, frame=frame),
        R(p(cut), 0.052, 0.054, {ua: 1}, frame=frame),
        R(p(cut + 0.012), 0.036, 0.038, {ua: 1}, frame=frame),
    ]
    mb.loft(rings, "sleeve_upper", G.ARM_SIDES, caps=(True, True))


def _in_rect(uv, name):
    x, y, w, h = guerrilla_atlas.RECTS[name]
    size = guerrilla_atlas.SIZE
    return x / size - 1e-4 <= uv.x <= (x + w) / size + 1e-4 and 1 - (y + h) / size - 1e-4 <= uv.y <= 1 - y / size + 1e-4


def shoulder_weights(bm, bone_names, top=0.07, bottom=0.02):
    """Pesos do ombro: os vértices do braço (faces na manga do atlas) seguem o braço conforme a posição ao longo do eixo
    (de `top` acima da junta a `bottom` abaixo, transição suave); os do tronco só cedem um pouco no alto do ombro e
    nunca na lateral (senão ela abre junto com o braço). A emenda fica com a média dos dois lados."""
    dl = bm.verts.layers.deform.active
    uvl = bm.loops.layers.uv.active
    chest = bone_names.index("Chest")
    for s, k in (("L", 1), ("R", -1)):
        ua = bone_names.index(f"UpperArm_{s}")
        joint = S.side(S.SHOULDER_L, s)
        axis = S.side(S.ARM_DIR_L, s).normalized()
        for v in bm.verts:
            if v.co.x * k < 0.05 or v.co.z < 1.20:
                continue
            arm_loops = [_in_rect(l[uvl].uv, "sleeve_upper") for l in v.link_loops]
            if not arm_loops:
                continue
            arm_share = sum(arm_loops) / len(arm_loops)
            d = (v.co - joint).dot(axis)
            t = min(1.0, max(0.0, (d + top) / (top + bottom)))
            w_arm = t * t * (3 - 2 * t)
            tx = min(1.0, max(0.0, (v.co.x * k - 0.12) / 0.06))
            tz = min(1.0, max(0.0, (v.co.z - 1.42) / 0.05))
            w_torso = 0.45 * tx * tz
            w = arm_share * w_arm + (1 - arm_share) * w_torso
            old = dict(v[dl])
            rest = sum(x for g, x in old.items() if g != ua)
            dv = v[dl]
            for g in list(dv.keys()):
                del dv[g]
            if rest > 1e-6:
                for g, x in old.items():
                    if g != ua:
                        dv[g] = x / rest * (1 - w)
            elif w < 1:
                dv[chest] = 1 - w
            if w > 1e-6:
                dv[ua] = w
        # suaviza o peso do braço entre vizinhos na região do ombro (a emenda da união tem triângulos miúdos que,
        # com pesos desencontrados, serrilhavam ao abrir o braço)
        region = [v for v in bm.verts if v.co.x * k > 0.08 and v.co.z > 1.28]
        for _ in range(3):
            new = {}
            for v in region:
                nb = [e.other_vert(v) for e in v.link_edges]
                ws = [n[dl].get(ua, 0.0) for n in nb] + [v[dl].get(ua, 0.0)] * 2
                new[v] = sum(ws) / len(ws)
            for v, w in new.items():
                dv = v[dl]
                rest = {g: x for g, x in dv.items() if g != ua}
                tot = sum(rest.values())
                for g in list(dv.keys()):
                    del dv[g]
                for g, x in rest.items():
                    dv[g] = x / tot * (1 - w) if tot > 1e-6 else 0.0
                if tot <= 1e-6 and w < 1:
                    dv[chest] = 1 - w
                if w > 1e-6:
                    dv[ua] = w


STUB_END, STUB_SIDES = 0.11, 12  # o toco do ombro vai até aqui (anel regular); dali ao corte do braço é a ponte


def build_shoulder_stub(mb, s):
    """Toco do ombro do tronco até STUB_END, fechado (entra limpo na união); a tampa sai depois e o anel é costurado à
    borda do braço do corpo base (_attach_arm)."""
    k = 1 if s == "L" else -1
    ua = f"UpperArm_{s}"
    p = lambda t: S.arm_point(s, t)
    frame = ring_frame(S.side(S.ARM_DIR_L, s))
    mb.loft([  # todos os anéis com os eixos do braço: no braço direito eixos calculados espelhariam a volta (tubo torcido)
        R((k * 0.11, 0.0, G.SHOULDER[2] + 0.02), 0.045, 0.050, {"Chest": 1}, frame=frame),  # dentro do peito
        R(p(-0.025), 0.058, 0.057, {"Chest": 0.5, ua: 0.5}, frame=frame),  # cúpula do ombro cheia (deltoide)
        R(p(0.030), 0.063, 0.060, {"Chest": 0.15, ua: 0.85}, frame=frame),
        R(p(0.080), 0.059, 0.058, {ua: 1}, frame=frame),
        R(p(STUB_END), 0.0545, 0.0565, {ua: 1}, frame=frame),
    ], "sleeve_upper", STUB_SIDES, caps=(True, True))


def _ring_by_angle(verts, center, axis):
    a, b = ring_frame(axis)
    ang = lambda v: math.atan2((v.co - center).dot(a), (v.co - center).dot(b)) % (2 * math.pi)
    return sorted(verts, key=ang), ang


def _attach_arm(mb, s, arm_bm, ring, bone_names):
    """Tira a tampa do toco, copia o braço do corpo base para a pele e costura o anel do toco à borda do corte dele com
    uma faixa de triângulos (pelo ângulo em volta do eixo)."""
    dl, uv = mb.dl, mb.uv
    axis = S.side(S.ARM_DIR_L, s).normalized()
    c = S.arm_point(s, STUB_END)
    stub = [v for v in mb.bm.verts if abs((v.co - c).dot(axis)) < 2e-3 and ((v.co - c) - axis * (v.co - c).dot(axis)).length < 0.09]
    cap = [f for f in mb.bm.faces if all(v in set(stub) for v in f.verts)]
    bmesh.ops.delete(mb.bm, geom=cap, context="FACES_ONLY")
    stub = [v for v in stub if v.link_faces]
    adl, auv = arm_bm.verts.layers.deform.active, arm_bm.loops.layers.uv.active
    new = {}
    for v in arm_bm.verts:
        nv = mb.bm.verts.new(v.co)
        for g, x in v[adl].items():
            nv[dl][g] = x
        new[v] = nv
    for f in arm_bm.faces:
        nf = mb.bm.faces.new([new[v] for v in f.verts])
        nf.material_index = 2
        for l_new, l_old in zip(nf.loops, f.loops):
            l_new[uv].uv = l_old[auv].uv
    arm_bm.free()
    top, ang = _ring_by_angle(stub, c, axis)
    bot, angb = _ring_by_angle([new[v] for v in ring], S.arm_point(s, guerrilla_arms.CUT), axis)
    _zip(mb, top, ang, bot, angb, "sleeve_upper", MAT_SKIN)


def _zip(mb, top, ang, bot, angb, rect, mat):
    """Costura dois anéis (já em ordem de ângulo) com uma faixa de triângulos: avança no anel cujo próximo vértice tem
    o menor ângulo. UV: u = ângulo, v entre 0,45 (anel de cima) e 0,6 no retângulo `rect`."""
    uv = mb.uv
    i = j = 0
    n, m = len(top), len(bot)
    tops = set(top)
    while i < n or j < m:
        a0, b0 = top[i % n], bot[j % m]
        na = ang(top[(i + 1) % n]) + (2 * math.pi if i + 1 >= n else 0)
        nb = angb(bot[(j + 1) % m]) + (2 * math.pi if j + 1 >= m else 0)
        if j >= m or (i < n and na <= nb):
            tri = (a0, top[(i + 1) % n], b0)
            i += 1
        else:
            tri = (a0, bot[(j + 1) % m], b0)
            j += 1
        if len(set(tri)) < 3:
            continue
        try:
            f = mb.bm.faces.new(tri)
        except ValueError:
            continue
        f.material_index = mat
        for l in f.loops:
            a = ang(l.vert) if l.vert in tops else angb(l.vert)
            l[uv].uv = guerrilla_atlas.uv(rect, (a % (2 * math.pi)) / (2 * math.pi), 0.45 if l.vert in tops else 0.6)
    bmesh.ops.recalc_face_normals(mb.bm, faces=list(mb.bm.faces))


NECK_Z = 1.545  # o tronco fecha aqui quando a cabeça do corpo base entra (a tampa sai e a cabeça é costurada)


def _attach_head(mb, head_bm, ring):
    """Tira a tampa do pescoço do tronco, copia a cabeça do corpo base e costura o anel do pescoço à borda dela."""
    dl, uv = mb.dl, mb.uv
    top_v = [v for v in mb.bm.verts if abs(v.co.z - NECK_Z) < 2e-3 and math.hypot(v.co.x, v.co.y) < 0.12]
    tset = set(top_v)
    bmesh.ops.delete(mb.bm, geom=[f for f in mb.bm.faces if all(v in tset for v in f.verts)], context="FACES_ONLY")
    top_v = [v for v in top_v if v.link_faces]
    hdl, huv = head_bm.verts.layers.deform.active, head_bm.loops.layers.uv.active
    new = {}
    for v in head_bm.verts:
        nv = mb.bm.verts.new(v.co)
        for g, x in v[hdl].items():
            nv[dl][g] = x
        new[v] = nv
    for f in head_bm.faces:
        try:
            nf = mb.bm.faces.new([new[v] for v in f.verts])
        except ValueError:
            continue
        nf.material_index = f.material_index
        for l_new, l_old in zip(nf.loops, f.loops):
            l_new[uv].uv = l_old[huv].uv
    head_bm.free()
    Zv = Vector((0, 0, 1))
    ct = sum((v.co for v in top_v), Vector()) / len(top_v)
    cb = sum((new[v].co for v in ring), Vector()) / len(ring)
    top, ang = _ring_by_angle(top_v, ct, Zv)
    bot, angb = _ring_by_angle([new[v] for v in ring], cb, Zv)
    _zip(mb, top, ang, bot, angb, "neck", MAT_SKIN)


def build_shoulder_cap(mb, s, upto=0.0):
    """Só o ombro (cúpula do deltoide e o começo da manga), fechado: o tronco revisado sozinho, como um busto."""
    ua = f"UpperArm_{s}"
    p = lambda t: S.arm_point(s, t)
    frame = ring_frame(S.side(S.ARM_DIR_L, s))
    rings = []
    for t, rx, ry in G.SLEEVE_UPPER:
        if t <= upto:
            w = {"Chest": 0.5, ua: 0.5} if t < 0 else ({"Chest": 0.2, ua: 0.8} if t < 0.05 else {ua: 1})
            rings.append(R(p(t), rx, ry, w, frame=frame))
    for dt, k in ((0.03, 0.8), (0.05, 0.45)):  # fecha arredondado (sem tampa chata)
        rings.append(R(p(upto + dt), rings[-1]["rx"] * k, rings[-1]["ry"] * k, {ua: 1}, frame=frame))
    mb.loft(rings, "sleeve_upper", G.ARM_SIDES, caps=(True, True))


def _front_y(z, x):
    """y da frente do colete (com a placa) no anel z, em x."""
    best = min((G.vest_point(z, math.pi + d) for d in [i * 0.01 - 1.2 for i in range(241)]), key=lambda p: abs(p[0] - x))
    y = best[1]
    if abs(x) < 0.16:
        y -= G.PLATE * math.cos(abs(x) / 0.16 * math.pi / 2)
    return y


def build_gear(mb, cords=True):
    hx, hy, hz = G.MAG_HALF
    fx, fy, fz = G.MAG_FLAP
    for x, z in G.MAG_POUCHES:
        y = _front_y(1.270, x)
        c = Vector((x, y - hy * 0.6, z))  # metade da profundidade entra no colete (a união solda)
        mb.box(c, X, Y, G.MAG_HALF, "pouch", {"Chest": 1}, MAT_GEAR)
        mb.box(Vector((x, c.y - hy - fy + 0.004, z + hz - fz)), X, Y, G.MAG_FLAP, "pouch", {"Chest": 1}, MAT_GEAR)
    for x in (G.CORDS if cords else ()):  # cordões: saem de dentro da gola do capuz e caem por fora do colete
        mb.loft([
            R((x, -0.080, 1.520), 0.006, 0.006, {"Neck": 1}),
            R((x, -0.118, 1.495), 0.0045, 0.0045, {"Neck": 0.5, "Chest": 0.5}),
            R((x, -0.142, 1.455), 0.0045, 0.0045, {"Chest": 1}),
            R((x, -0.152, 1.425), 0.0055, 0.0055, {"Chest": 1}),
        ], "cord", 4, mat=MAT_GEAR)


PARTS = ("bare", "basearms", "basehead", "vest")  # o aprovado: corpo de moletom, braços e cabeça do modelo padrão, colete
# (as partes antigas "torso", "hood", "arms" = colete pintado no tronco e capuz, ainda montáveis para comparar)


def build_all(bone_names, parts=PARTS):
    """`parts`: o que montar (prévia por partes: só "torso" = tronco com as bolsas, gola fechada em cima)."""
    mb = MeshBuilder(bone_names, guerrilla_atlas)
    if "bare" in parts:  # o personagem sem colete (revisão do corpo antes da roupa por cima)
        global ARM_MATERIAL
        basehead = "basehead" in parts
        top = build_bare_torso(mb, upto=NECK_Z if basehead else (1.52 if "head" in parts else None), close=basehead)
        if "head" in parts and not basehead:  # capuz soldado no pescoço e os cordões
            build_hood(mb, start=top)
            build_bare_cords(mb)
        arms = None
        if "basearms" in parts:  # braços do corpo base (modelo padrão), soldados no ombro
            arms, ARM_MATERIAL = guerrilla_arms.base_arms(bone_names)
            for s, _, ring in arms:
                build_shoulder_stub(mb, s)
        else:
            for s in ("L", "R"):
                build_arm_stump(mb, s)
        if "vest" in parts:  # o colete por cima do moletom: peças que a união solda na pele
            guerrilla_vest.build_vest(mb)
        bmesh.ops.remove_doubles(mb.bm, verts=mb.bm.verts, dist=1e-5)
        def stub_tip(v):  # a ponta do toco não é arredondada: o anel dela é costurado ao braço depois
            return arms is not None and any((v.co - S.side(S.SHOULDER_L, sd)).dot(S.side(S.ARM_DIR_L, sd).normalized()) > 0.06
                                            and v.co.x * kk > 0.12 for sd, kk in (("L", 1), ("R", -1)))
        mb.bm = raptor_mesh._self_union(  # a ponta do toco, o pescoço (costurados depois) e o equipamento sem arredondar
            mb.bm, bone_names, skip=lambda v: stub_tip(v) or (basehead and v.co.z > NECK_Z - 0.02)
            or any(f.material_index == MAT_GEAR for f in v.link_faces))
        mb.uv = mb.bm.loops.layers.uv.active
        mb.dl = mb.bm.verts.layers.deform.active
        shoulder_weights(mb.bm, bone_names)
        for s, arm_bm, ring in arms or ():
            _attach_arm(mb, s, arm_bm, ring, bone_names)
        if basehead:
            head_bm, ring, HEAD_MATERIALS[:] = guerrilla_head.base_head(bone_names)
            _attach_head(mb, head_bm, ring)
        if arms:  # frestas que sobraram na axila do braço do corpo base: solda e fecha (pele sem furo)
            open_edges = lambda: [e for e in mb.bm.edges if len(e.link_faces) == 1]
            bmesh.ops.remove_doubles(mb.bm, verts=list({v for e in open_edges() for v in e.verts}), dist=0.012)
            bmesh.ops.holes_fill(mb.bm, edges=open_edges(), sides=0)
        return mb
    build_torso(mb, top_cap="hood" not in parts)
    if "hood" in parts:
        build_hood(mb)
    for s in ("L", "R"):
        if "arms" in parts:
            build_arm(mb, s)
        else:
            build_shoulder_cap(mb, s)
    build_gear(mb, cords="hood" in parts)
    bmesh.ops.remove_doubles(mb.bm, verts=mb.bm.verts, dist=1e-5)  # solda os anéis das emendas
    # uma união só (uma segunda picotaria a pele já fundida); as quinas do equipamento não são arredondadas
    mb.bm = raptor_mesh._self_union(mb.bm, bone_names, skip=lambda v: any(f.material_index == MAT_GEAR for f in v.link_faces))
    mb.uv = mb.bm.loops.layers.uv.active
    mb.dl = mb.bm.verts.layers.deform.active
    return mb


def make_body(rig, atlas_path, parts=PARTS):
    """Objeto "Guerrilla" (a pele inteira) preso ao esqueleto, com o atlas do guerrilheiro."""
    image = bpy.data.images.load(str(atlas_path))
    image.pack()
    mat = heroine_rig.make_material("GuerrillaBody", image, double_sided=False)
    mb = build_all(S.BONE_NAMES, parts)
    extra = [ARM_MATERIAL or mat] + HEAD_MATERIALS if HEAD_MATERIALS else ([ARM_MATERIAL] if ARM_MATERIAL else [])
    obj = heroine_rig._skinned_object(rig, "Guerrilla", mb, [mat, mat] + extra)
    if "vest" in parts:  # liso, com quina viva onde as faces dobram (bordas do colete, bolsas, encontro com o moletom)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        for e in bm.edges:
            fs = e.link_faces
            if len(fs) == 2 and all(f.material_index < 2 for f in fs) and fs[0].normal.angle(fs[1].normal, 0.0) > SHARP:
                e.smooth = False
        bm.to_mesh(obj.data)
        bm.free()
    for poly in obj.data.polygons:
        if poly.material_index >= 2:  # braço (2) e cabeça (3 rosto, 4 olhos, 5 janela) do corpo base, com os materiais dele
            continue
        poly.use_smooth = "vest" in parts or poly.material_index == MAT_SKIN
        poly.material_index = 0
    # calça, cinto, coldre e coturnos de antes (material próprio "Body_pants"), no mesmo objeto
    lower = guerrilla_lower.import_lower(G.joints())
    for o in bpy.context.scene.objects:
        o.select_set(o in (obj, lower))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    return obj
