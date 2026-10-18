"""Malha low-poly do velociraptor (mesmo construtor por anéis da heroína, com o atlas do raptor).

Uma pele só, não peças coladas:
- cadeias contínuas: cauda -> tronco -> pescoço -> cabeça, coxa -> canela -> metatarso e braço -> antebraço são lofts
  que compartilham o anel da emenda (mesmo centro, raios, eixos e pesos; sem tampa no meio) e depois têm os vértices
  soldados (remove_doubles);
- onde uma peça sai de outra (coxa e braço do tronco, dedos do pé), uma união booleana do Blender ("self union")
  funde tudo numa superfície fechada, então a sombra passa lisa pela junta;
- ficam soltas só as peças que precisam: mandíbula (abre), dentes (triângulos) e garras.
Peças horizontais usam b_hint = Z: u = 0 no dorso, u = 0.5 na barriga.
Proporções medidas contra a referência (na mesma escala): tronco em cunha, mais fundo no peito e afinando para o
quadril, sem pança; coxa forte mas estreita vista de cima; braço comprido; cabeça longa e baixa com arco ósseo sobre o
olho. A mandíbula entra por dentro do crânio (o topo dela passa da borda de baixo da cabeça em todo o comprimento).
"""
import bmesh
import bpy
from mathutils import Vector, kdtree

import raptor_atlas
import raptor_spec as S
from heroine_mesh import MeshBuilder, R, ring_frame

X = Vector((1, 0, 0))
Z = Vector((0, 0, 1))

MAT_SKIN = 0
MAT_TEETH = 1  # sem backface culling (dente é um triângulo só)

HEAD_RINGS = [
    # (centro, rx, ry): nuca -> focinho. Alto da cabeça curvo, mais alto logo atrás do olho; a nuca cai para o
    # pescoço; focinho rombudo e largo. A borda de baixo (linha do lábio) fica quase reta em ~1,14 m.
    ((0, -0.72, 1.215), 0.097, 0.097),  # nuca: tão larga quanto a cabeça e o pescoço, sem cintura entre eles
    ((0, -0.80, 1.2425), 0.10, 0.1025),
    ((0, -0.90, 1.2425), 0.095, 0.0975),
    ((0, -1.01, 1.2325), 0.085, 0.0875),
    ((0, -1.12, 1.215), 0.064, 0.075),
    ((0, -1.21, 1.195), 0.05, 0.062),
    ((0, -1.27, 1.178), 0.036, 0.05),
    ((0, -1.295, 1.17), 0.026, 0.038),  # ponta reta (cunha), não uma bola
]
JAW_RINGS = [
    # quase da largura da cabeça e com o topo bem dentro dela: de boca fechada só sobra a linha do lábio
    ((0, -0.73, 1.14), 0.09, 0.085),  # canto da boca: a mandíbula sai por fora e a linha do lábio sobe para o olho
    ((0, -0.82, 1.125), 0.095, 0.06),
    ((0, -0.91, 1.1225), 0.085, 0.0425),
    ((0, -1.01, 1.125), 0.075, 0.035),
    ((0, -1.12, 1.1275), 0.054, 0.0275),
    ((0, -1.22, 1.13), 0.036, 0.022),
    ((0, -1.28, 1.135), 0.02, 0.016),  # vai até quase a ponta: o lábio de cima passa só um pouco por cima
]
# cabeça mais larga embaixo (bochecha/mandíbula) e mais estreita em cima, por cima da mandíbula
LIP = {4: 0.016, 5: 0.018, 7: 0.018, 8: 0.016, 1: -0.008, 11: -0.008}
SPINE_SIDES = 12  # cauda, tronco, pescoço e cabeça: mesmo número de lados para os anéis da emenda baterem
LEG_SIDES = 8
ARM_SIDES = 6


def _interp(rings, y):
    """Centro e raios do anel na profundidade y (interpolação linear entre anéis)."""
    for (c0, rx0, ry0), (c1, rx1, ry1) in zip(rings, rings[1:]):
        if c1[1] <= y <= c0[1]:
            t = (c0[1] - y) / (c0[1] - c1[1])
            c = Vector(c0).lerp(Vector(c1), t)
            return c, rx0 + (rx1 - rx0) * t, ry0 + (ry1 - ry0) * t
    c, rx, ry = rings[-1]
    return Vector(c), rx, ry


def joint(c, rx, ry, w, prev, nxt, push=None, b_hint=None):
    """Anel de emenda entre dois lofts: eixos fixos (tangente de `prev` para `nxt`), para os dois lofts gerarem
    exatamente os mesmos vértices."""
    return R(c, rx, ry, w, push, frame=ring_frame(Vector(nxt) - Vector(prev), b_hint))


# ------------------------------------------------------------------ cadeia da coluna
RIDGE = {0: 0.014, 1: 0.005, 11: 0.005}
KEEL = {6: 0.025, 5: 0.01, 7: 0.01, 0: 0.012}  # quilha do peito
HUMP = {0: 0.035, 1: 0.016, 11: 0.016, 6: 0.025, 5: 0.01, 7: 0.01}  # corcova sobre os ombros + quilha

J_TAIL = joint((0, 0.20, 0.965), 0.125, 0.145, {"Hips": 0.5, "Tail1": 0.5}, (0, 0.36, 0.975), (0, 0.06, 0.96), RIDGE, Z)
J_NECK = joint((0, -0.52, 0.985), 0.12, 0.135, {"Chest": 0.5, "Neck1": 0.5}, (0, -0.40, 0.985), (0, -0.565, 1.03), None, Z)
J_HEAD = joint(HEAD_RINGS[0][0], HEAD_RINGS[0][1], HEAD_RINGS[0][2], {"Head": 1}, (0, -0.69, 1.20), HEAD_RINGS[1][0], None, Z)


def build_tail(mb):
    """Raiz grossa, mais alta que larga, afinando até a ponta; sobe um pouco."""
    mb.loft([
        J_TAIL,
        R((0, 0.36, 0.975), 0.10, 0.122, {"Hips": 0.2, "Tail1": 0.8}, RIDGE),
        R((0, 0.55, 0.99), 0.08, 0.098, {"Tail1": 0.5, "Tail2": 0.5}, RIDGE),
        R((0, 0.80, 1.015), 0.064, 0.079, {"Tail2": 0.6, "Tail3": 0.4}),
        R((0, 1.05, 1.032), 0.052, 0.064, {"Tail3": 1}),
        R((0, 1.30, 1.04), 0.042, 0.05, {"Tail3": 0.4, "Tail4": 0.6}),
        R((0, 1.60, 1.04), 0.03, 0.035, {"Tail4": 1}),
        R((0, 1.99, 1.04), 0.006, 0.006, {"Tail4": 1}),
    ], "tail", SPINE_SIDES, caps=(False, True), b_hint=Z)


def build_body(mb):
    mb.loft([
        J_TAIL,
        R((0, 0.06, 0.96), 0.15, 0.17, {"Hips": 1}, RIDGE),
        R((0, -0.10, 0.952), 0.16, 0.19, {"Hips": 0.5, "Spine": 0.5}, RIDGE),
        R((0, -0.26, 0.945), 0.158, 0.205, {"Spine": 0.5, "Chest": 0.5}, {**KEEL, 0: 0.025, 1: 0.01, 11: 0.01}),
        R((0, -0.40, 0.985), 0.14, 0.19, {"Chest": 1}, HUMP),
        J_NECK,
    ], "body", SPINE_SIDES, caps=(False, False), b_hint=Z)


def build_neck(mb):
    """Pescoço curto: sai do peito e sobe para a frente até a nuca, com a cabeça baixa."""
    mb.loft([
        J_NECK,
        R((0, -0.565, 1.03), 0.105, 0.13, {"Neck1": 1}),
        R((0, -0.61, 1.09), 0.094, 0.115, {"Neck1": 0.5, "Neck2": 0.5}),
        R((0, -0.65, 1.15), 0.092, 0.108, {"Neck2": 1}),
        R((0, -0.69, 1.20), 0.095, 0.104, {"Neck2": 0.5, "Head": 0.5}),
        J_HEAD,
    ], "neck", SPINE_SIDES, caps=(False, False), b_hint=Z)


def build_head(mb):
    head = {"Head": 1}
    # 12 lados: 0 = alto da cabeça, 3 = lado esquerdo, 6 = embaixo
    shape = {
        1: {2: 0.008, 10: 0.008},
        2: {2: 0.032, 10: 0.032, 3: -0.01, 9: -0.01},  # arco ósseo pesado sobre o olho, órbita funda embaixo
        3: {2: 0.028, 10: 0.028, 3: -0.008, 9: -0.008},
        4: {0: 0.006, 1: -0.012, 11: -0.012, 2: 0.008, 10: 0.008},  # crista do focinho; o arco desce até aqui
        5: {0: 0.005, 1: -0.012, 11: -0.012, 2: -0.006, 10: -0.006},
        6: {0: 0.004, 1: -0.01, 11: -0.01, 2: -0.005, 10: -0.005},
        7: {1: -0.006, 11: -0.006},
    }
    tip_lip = {4: 0.008, 5: 0.01, 7: 0.01, 8: 0.008}
    rings = [J_HEAD]
    for i, (c, rx, ry) in enumerate(HEAD_RINGS[1:], start=1):
        push = dict(LIP) if i <= 5 else dict(tip_lip)
        push.update(shape.get(i, {}))
        rings.append(R(c, rx, ry, head, push))
    mb.loft(rings, "head", SPINE_SIDES, caps=(False, True), b_hint=Z)


def build_jaw(mb):
    jaw = []
    for i, (c, rx, ry) in enumerate(JAW_RINGS):
        jaw.append(R(c, rx, ry, {"Jaw": 0.6, "Head": 0.4} if i == 0 else {"Jaw": 1}))
    mb.loft(jaw, "jaw", 8, b_hint=Z)


def _tooth(mb, base_a, base_b, tip, bone):
    w = {bone: 1}
    verts = [mb._vert(base_a, w), mb._vert(base_b, w), mb._vert(tip, w)]
    uvs = [raptor_atlas.uv("teeth", 0.1, 0.1), raptor_atlas.uv("teeth", 0.9, 0.1), raptor_atlas.uv("teeth", 0.5, 0.9)]
    mb._face(verts, uvs, MAT_TEETH)


def build_teeth(mb):
    """Fileira de dentes nas bordas das duas arcadas (aparecem de boca fechada, como na referência)."""
    for k in (1, -1):
        n = 11
        for i in range(n):
            y = -0.85 - i * (0.37 / (n - 1))
            c, rx, ry = _interp(HEAD_RINGS, y)
            base = c + X * (k * rx * 0.86) - Z * (ry * 0.52)
            half = Vector((0, 0.016, 0))
            length = 0.018 - 0.005 * i / n  # de boca fechada quase some atrás do lábio
            _tooth(mb, base - half, base + half, base - Z * length - Vector((0, 0.004, 0)), "Head")
        for i in range(9):
            y = -0.87 - i * (0.31 / 8)
            c, rx, ry = _interp(JAW_RINGS, y)
            base = c + X * (k * rx * 0.80) + Z * (ry * 0.6)
            half = Vector((0, 0.014, 0))
            _tooth(mb, base - half, base + half, base + Z * 0.016, "Jaw")


# ------------------------------------------------------------------ pernas e braços
def build_leg(mb, s):
    k = 1 if s == "L" else -1
    x = k * S.LEG_X
    th, sh, mt, toe = f"Thigh_{s}", f"Shin_{s}", f"Meta_{s}", f"Toe_{s}"
    knee = joint((x, -0.20, 0.56), 0.06, 0.066, {th: 0.5, sh: 0.5}, (k * 0.175, -0.13, 0.65), (x, -0.12, 0.48))
    ankle = joint((x, 0.12, 0.20), 0.04, 0.042, {sh: 0.5, mt: 0.5}, (x, -0.03, 0.36), (x, 0.08, 0.12))
    # coxa: nasce de dentro do quadril (o primeiro anel fica escondido no tronco, então a junta é só a linha onde a
    # coxa sai da pele), larga no alto e afinando rápido até o joelho
    mb.loft([
        R((k * 0.08, 0.05, 1.0), 0.06, 0.09, {"Hips": 1}),
        R((x, 0.03, 0.93), 0.10, 0.19, {"Hips": 0.5, th: 0.5}),
        R((k * 0.175, 0.0, 0.85), 0.108, 0.215, {th: 1}),
        R((k * 0.175, -0.06, 0.75), 0.098, 0.18, {th: 1}),
        R((k * 0.175, -0.13, 0.65), 0.078, 0.12, {th: 1}),
        knee,
    ], "thigh", LEG_SIDES, caps=(True, False))
    # canela com panturrilha atrás (j = 0 aponta para trás)
    mb.loft([
        knee,
        R((x, -0.12, 0.48), 0.072, 0.085, {sh: 1}, {0: 0.045, 1: 0.022, 7: 0.022}),
        R((x, -0.03, 0.36), 0.054, 0.062, {sh: 1}, {0: 0.02}),
        ankle,
    ], "shin", LEG_SIDES, caps=(False, False))
    mb.loft([
        ankle,
        R((x, 0.08, 0.12), 0.034, 0.036, {mt: 1}),
        R((x, 0.04, 0.05), 0.04, 0.036, {mt: 0.5, toe: 0.5}),
    ], "meta", LEG_SIDES, caps=(False, True))
    # dedos III e IV no chão (fundidos ao pé) e dedo II levantado
    for dx, reach in ((0.0, 0.0), (k * 0.045, 0.05)):
        tx = x + dx
        mb.loft([
            R((tx, 0.05, 0.04), 0.026, 0.026, {toe: 1}),
            R((tx, -0.07 + reach, 0.032), 0.021, 0.019, {toe: 1}),
            R((tx, -0.15 + reach, 0.022), 0.011, 0.01, {toe: 1}),
        ], "toe", 4, b_hint=Z)
    ix = x - k * 0.035
    mb.loft([
        R((ix, 0.04, 0.05), 0.016, 0.016, {mt: 0.5, toe: 0.5}),
        R((ix, -0.02, 0.05), 0.014, 0.014, {toe: 1}),
    ], "toe", 4, b_hint=Z)


def build_foot_claws(mb, s):
    k = 1 if s == "L" else -1
    x = k * S.LEG_X
    toe = f"Toe_{s}"
    for dx, reach in ((0.0, 0.0), (k * 0.045, 0.05)):
        tx = x + dx
        mb.loft([
            R((tx, -0.145 + reach, 0.024), 0.008, 0.008, {toe: 1}),
            R((tx, -0.19 + reach, 0.012), 0.004, 0.004, {toe: 1}),
            R((tx, -0.205 + reach, 0.0), 0.001, 0.001, {toe: 1}),
        ], "claw", 4, b_hint=Z)
    # garra em foice do dedo II
    ix = x - k * 0.035
    mb.loft([
        R((ix, -0.015, 0.06), 0.013, 0.015, {toe: 1}),
        R((ix, -0.05, 0.105), 0.01, 0.012, {toe: 1}),
        R((ix, -0.105, 0.10), 0.006, 0.007, {toe: 1}),
        R((ix, -0.135, 0.06), 0.001, 0.001, {toe: 1}),
    ], "claw", 4, b_hint=Z)


def build_arm(mb, s):
    arm, fore, hand = f"Arm_{s}", f"Forearm_{s}", f"Hand_{s}"
    sh, el, wr = S.side(S.SHOULDER, s), S.side(S.ELBOW, s), S.side(S.WRIST, s)
    mid_a, mid_f = sh.lerp(el, 0.4), el.lerp(wr, 0.5)
    elbow = joint(el, 0.048, 0.052, {arm: 0.5, fore: 0.5}, mid_a, mid_f)
    mb.loft([
        R(Vector((sh.x * 0.45, sh.y + 0.02, sh.z + 0.03)), 0.05, 0.055, {"Chest": 1}),  # dentro do peito
        R(sh, 0.075, 0.082, {"Chest": 0.5, arm: 0.5}),
        R(mid_a, 0.066, 0.072, {arm: 1}),
        elbow,
    ], "arm", ARM_SIDES, caps=(True, False))
    mb.loft([
        elbow,
        R(mid_f, 0.044, 0.048, {fore: 1}),
        R(wr, 0.034, 0.036, {fore: 0.5, hand: 0.5}),
    ], "arm", ARM_SIDES, caps=(False, True))


def build_hand_claws(mb, s):
    """Três dedos relaxados (juntos, curvados para baixo, garra voltada para trás). Nascem de dentro do antebraço
    (entram na união com a pele), então a mão não termina numa tampa com os dedos espetados."""
    k = 1 if s == "L" else -1
    hand = f"Hand_{s}"
    el, wr = S.side(S.ELBOW, s), S.side(S.WRIST, s)
    root = wr.lerp(el, 0.15)
    for dx, reach in ((-0.016, 0.85), (0.0, 1.0), (0.016, 0.9)):
        base = wr + Vector((k * dx, 0, 0))
        knuckle = base + Vector((k * dx * 0.3, -0.06 * reach, -0.025))
        bend = knuckle + Vector((-k * dx * 0.2, -0.03 * reach, -0.06 * reach))
        tip = bend + Vector((0, 0.02, -0.045 * reach))
        mb.loft([
            R(root + Vector((k * dx * 0.4, 0, 0)), 0.014, 0.014, {"Forearm_" + s: 0.5, hand: 0.5}),
            R(base, 0.017, 0.017, {hand: 1}),
            R(knuckle, 0.013, 0.013, {hand: 1}),
            R(bend, 0.008, 0.008, {hand: 1}),
            R(tip, 0.002, 0.002, {hand: 1}),
        ], "claw", 4)


# ------------------------------------------------------------------ montagem
def _self_union(bm, bone_names, keep_bones=()):
    """Funde as peças que se cruzam (coxa no tronco, braço no peito, dedos no pé) numa superfície só: booleana
    exata do Blender em modo "self" (sem operando). UV, materiais e pesos dos ossos são carregados para a malha nova.
    `keep_bones`: vértices presos só a esses ossos não são suavizados nas juntas (detalhe pequeno, como as cristas
    da cabeça do alossauro, sumiria)."""
    me = bpy.data.meshes.new("RaptorFuse")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("RaptorFuse", me)
    bpy.context.scene.collection.objects.link(obj)
    for n in bone_names:
        obj.vertex_groups.new(name=n)
    empty = bpy.data.collections.new("RaptorFuseEmpty")
    mod = obj.modifiers.new("Fuse", "BOOLEAN")
    mod.operation = "UNION"
    mod.solver = "EXACT"
    mod.operand_type = "COLLECTION"
    mod.collection = empty
    mod.use_self = True
    dg = bpy.context.evaluated_depsgraph_get()
    fused = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    out = bmesh.new()
    out.from_mesh(fused)
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(fused)
    bpy.data.collections.remove(empty)
    seam = _fill_weights(out)
    keep = [bone_names.index(b) for b in keep_bones]
    dl = out.verts.layers.deform.active
    _round_seams(out, seam, skip=lambda v: any(v[dl].get(g, 0.0) >= 0.99 for g in keep))
    return out


def _round_seams(bm, seam, rings=2, passes=4, skip=None):
    """Arredonda a quina viva onde uma peça sai da outra: suaviza os vértices da linha de encontro e mais `rings`
    voltas de vizinhos (puxa a quina para fora, como um filete de pele), e deixa as normais lisas em tudo."""
    sel = set(seam)
    edge = set(seam)
    for _ in range(rings):
        edge = {o for v in edge for e in v.link_edges for o in (e.other_vert(v),)} - sel
        sel |= edge
    if skip:
        sel = {v for v in sel if not skip(v)}
    for _ in range(passes):
        bmesh.ops.smooth_vert(bm, verts=list(sel), factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    for e in bm.edges:
        e.smooth = True
    for f in bm.faces:
        f.smooth = True


def _fill_weights(bm):
    """Os vértices que a união cria na linha das juntas vêm sem peso: recebem a média dos 3 vizinhos com peso
    mais próximos (pela distância), então a junta dobra junto com as duas peças."""
    dl = bm.verts.layers.deform.active
    done = [v for v in bm.verts if len(v[dl]) > 0]
    tree = kdtree.KDTree(len(done))
    for i, v in enumerate(done):
        tree.insert(v.co, i)
    tree.balance()
    seam = [v for v in bm.verts if len(v[dl]) == 0]
    for v in seam:
        acc = {}
        near = tree.find_n(v.co, 3)
        total = sum(1.0 / max(d, 1e-4) for _, _, d in near)
        for _, i, d in near:
            for g, w in done[i][dl].items():
                acc[g] = acc.get(g, 0.0) + w * (1.0 / max(d, 1e-4)) / total
        for g, w in acc.items():
            v[dl][g] = w
    return seam


def build_all(bone_names):
    skin = MeshBuilder(bone_names, raptor_atlas)
    build_tail(skin)
    build_body(skin)
    build_neck(skin)
    build_head(skin)
    for s in ("L", "R"):
        build_leg(skin, s)
        build_arm(skin, s)
        build_hand_claws(skin, s)
    bmesh.ops.remove_doubles(skin.bm, verts=skin.bm.verts, dist=1e-5)  # solda os anéis das emendas
    # o resto entra no mesmo bmesh, depois da fusão
    mb = MeshBuilder(bone_names, raptor_atlas)
    mb.bm.free()
    mb.bm = _self_union(skin.bm, bone_names)
    mb.uv = mb.bm.loops.layers.uv.active
    mb.dl = mb.bm.verts.layers.deform.active
    build_jaw(mb)
    build_teeth(mb)
    for s in ("L", "R"):
        build_foot_claws(mb, s)
    return mb
