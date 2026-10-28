"""Cabeça do guerrilheiro tirada do corpo base (art/base_body/Mesh.fbx, o "modelo padrão", como os braços em
art/guerrilla_arms.py): o rosto esculpido e os olhos dele, sem cabelo nem cílios, coberto pela balaclava de malha com a
fresta dos olhos (guerrilla_paint.paint_balaclava, pintada nítida na textura do rosto). Escalada para homem, com os
olhos onde o corte do pescoço cai no tronco, sem as orelhas (a malha passa lisa) e o pescoço engrossado até o do tronco; a borda volta para
art/guerrilla_body.py, que a costura ao anel de cima do tronco (pele única).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import guerrilla_arms
import guerrilla_paint
import guerrilla_spec as G

HEAD_TRIS = 900  # o rosto dela tem ~5900 triângulos: reduzido para isto (os globos dos olhos à parte)
SCALE = 1.12  # um fator só nos três eixos: a cabeça dela fica do tamanho da de homem com as proporções dela (crescer cada
# eixo de um jeito achatava a cabeça e alongava a testa)
WIDEN = 1.05  # só a largura, um pouco mais: crânio de homem (com a malha: 17 cm sem orelha)
EYE_Z = 1.684  # linha dos olhos: com FACE_K, o corte do pescoço cai em 1,546, no anel de cima do tronco
# proporção de homem (a dela é cabeçuda: 12,8 cm do olho ao alto e 10,3 cm do olho ao queixo)
FACE_K = 1.12  # do olho para baixo: 11,5 cm até o queixo
CRANIUM_K = 0.92  # do olho para cima: 11,8 cm até o alto
NECK_FIT_H = (0.018, 0.018)  # o pescoço dela é cortado torto (frente 2,5 cm abaixo da nuca) e 2,7 cm à frente do do tronco:
# o anel vai para o anel do tronco e a correção some até essa altura acima dele (a curva da nuca fica como é)
CHIN_TOP = 0.075  # o queixo é alisado do anel do pescoço até EYE_Z - CHIN_TOP (abaixo da boca): sem a quina pontuda
CHIN_SMOOTH = 8  # passadas de suavização no queixo
CHIN_R = 0.022  # raio da quina de baixo do queixo, de lado (a ponta dele vira esse arco)
MOUTH_TOP = 0.050  # abaixo do nariz (EYE_Z - MOUTH_TOP) a malha passa por cima da boca: o vão dos lábios é preenchido
MOUTH_FILL = 12  # passadas que só enchem o que está afundado (a boca), sem encolher o queixo
# olhar fechado (o do segundo painel do usuário): o olho é uma amêndoa pintada no globo (guerrilla_paint.paint_eyes), o
# arco da sobrancelha desce no meio e vem para a frente (a pintura da janela está em guerrilla_paint._eye_window)
EYE_OPEN_MARGIN, EYE_OPEN_DEPTH = 0.0010, 0.0015  # folga do vão em volta da amêndoa e quanto o rosto fica atrás do globo
BROW_DROP, BROW_FWD = 0.0025, 0.002  # cenho: a ponta de dentro da sobrancelha desce e o arco vem para a frente (m)
IRIS = ((46, 29, 16), (28, 18, 11))  # íris castanho-escura: em volta da pupila e na borda
OCCIPUT_K = 0.92  # a parte de trás do crânio, sem o pescoço (a nuca não sai em balanço por cima das costas)
NECK_R = 0.064  # meia-largura do pescoço do tronco onde a cabeça é costurada (art/guerrilla_spec.BARE em 1,545)
NECK_FROM = 0.022  # o pescoço engrossa só nos últimos NECK_FROM metros acima do corte (a mandíbula fica como está)
BACK = 0.012  # a cabeça vai para trás até ficar em cima do pescoço do tronco (o meio dele fica em y = +0,01)
GROW_FROM = 0.035  # largura e BACK entram do corte do pescoço (parado: costura) até GROW_FROM metros acima
# orelhas: debaixo da balaclava não aparecem; a faixa delas volta para a elipse do crânio
EAR_Z = (EYE_Z - 0.066, EYE_Z + 0.051)  # antes de FACE_K/CRANIUM_K
SKULL_HALF = 0.080  # meia-largura do crânio
SKULL_CY, SKULL_HALF_D = -0.015, 0.101  # meio e meia-profundidade do crânio no eixo Y
EAR_SMOOTH = 3  # passadas de suavização na faixa (sem dobras de orelha amassada)


def _reduce(obj, tris):
    n = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if n <= tris:
        return
    mod = obj.modifiers.new("Dec", "DECIMATE")
    mod.ratio = tris / n
    mod.use_collapse_triangulate = True
    mod.use_symmetry, mod.symmetry_axis = True, "X"  # os dois olhos (e as duas pálpebras) iguais
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _skull_k(x, y, z):
    """>1 fora da elipse do crânio na altura z (afina para a nuca abaixo da orelha)."""
    t = min(1.0, max(0.0, (z - EAR_Z[0]) / 0.05))
    a = SKULL_HALF * (0.85 + 0.15 * t)
    return (x / a) ** 2 + ((y - SKULL_CY) / SKULL_HALF_D) ** 2


def _ramp(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def _ear_w(x, y, z):
    """Quanto o vértice está na faixa da orelha (1 no meio, 0 fora; as bordas passam suave)."""
    return (_ramp(EAR_Z[0] - 0.015, EAR_Z[0], z) * (1 - _ramp(EAR_Z[1], EAR_Z[1] + 0.015, z))
            * _ramp(0.043, 0.059, abs(x)) * _ramp(-0.063, -0.047, y) * (1 - _ramp(0.037, 0.053, y)))


def _hide_ears(bm):
    """A faixa da orelha vira a superfície lisa do crânio (para fora e para dentro: concha, lóbulo e o vão atrás dela);
    a malha da balaclava passa lisa por cima."""
    w = {}
    for v in bm.verts:
        x, y, z = v.co
        wv = _ear_w(x, y, z)
        if wv <= 0:
            continue
        f = 1 / math.sqrt(_skull_k(x, y, z))
        v.co.x = x + (x * f - x) * wv
        v.co.y = y + ((SKULL_CY + (y - SKULL_CY) * f) - y) * wv
        w[v] = wv
    for _ in range(EAR_SMOOTH):
        avg = {v: sum((n.co for e in v.link_edges for n in e.verts if n is not v), Vector()) / len(v.link_edges)
               for v in w if v.link_edges}
        for v, c in avg.items():
            v.co = v.co.lerp(c, 0.5 * w[v])


def _widen(bm, bottom):
    """Crânio de homem (WIDEN) e cabeça em cima do pescoço do tronco (BACK); o corte do pescoço fica parado (costura)."""
    for v in bm.verts:
        g = _ramp(bottom, bottom + GROW_FROM, v.co.z)
        v.co.x *= 1 + (WIDEN - 1) * g
        v.co.y += BACK * g


def _proportions(bm, bottom):
    """Rosto mais longo, crânio mais baixo e nuca menos saliente (em volta da linha dos olhos; o pescoço desce junto)."""
    yc = SKULL_CY + BACK
    for v in bm.verts:
        z = v.co.z
        g = _ramp(bottom + 0.03, bottom + 0.07, z)  # o pescoço fica com o raio do tronco
        if v.co.y > yc:
            v.co.y = yc + (v.co.y - yc) * (1 + (OCCIPUT_K - 1) * g)
        v.co.z = EYE_Z + (z - EYE_Z) * (FACE_K if z < EYE_Z else CRANIUM_K)


def _neck_target(phi):
    """Ponto do anel de cima do tronco (art/guerrilla_spec.BARE em 1,545) na direção phi (0 = costas) a partir do meio dele."""
    z, yc, rx, ryf, ryb = G.BARE[-1]
    ry = ryb if math.cos(phi) > 0 else ryf
    th = math.atan2(math.sin(phi) / rx, math.cos(phi) / ry)
    return Vector((rx * math.sin(th), yc + ry * math.cos(th), z))


def _fit_neck(bm):
    """O anel do pescoço vai para cima do anel do tronco (reto, mesma forma, mesmo meio) e a correção some subindo: na
    frente logo abaixo do queixo, atrás até a nuca. Sem o degrau na frente do pescoço nem o vão atrás."""
    bottom = min(v.co.z for v in bm.verts)
    ring = list({v for e in bm.edges if len(e.link_faces) == 1 and all(u.co.z < bottom + 0.04 for u in e.verts)
                 for v in e.verts})
    c = sum((v.co for v in ring), Vector()) / len(ring)
    ang = lambda co: math.atan2(co.x - c.x, co.y - c.y)
    keys = sorted((ang(v.co), v.co.copy(), _neck_target(math.atan2(v.co.x, v.co.y - c.y)) - v.co) for v in ring)
    keys = [(a - 2 * math.pi, p, d) for a, p, d in keys[-1:]] + keys + [(a + 2 * math.pi, p, d) for a, p, d in keys[:1]]

    def at(a):
        for (a0, p0, d0), (a1, p1, d1) in zip(keys, keys[1:]):
            if a0 <= a <= a1:
                t = (a - a0) / max(a1 - a0, 1e-9)
                return p0.lerp(p1, t), d0.lerp(d1, t)
        return keys[0][1], keys[0][2]
    for v in bm.verts:
        a = ang(v.co)
        p, d = at(a)
        hf, hb = NECK_FIT_H
        H = hf + (hb - hf) * (1 + math.cos(a)) / 2
        w = 1 - _ramp(0.0, H, v.co.z - p.z)
        if w > 0:
            v.co += d * w


def _round_chin(bm):
    """Queixo redondo debaixo da malha: a ponta e a quina de baixo dele (que o rosto mais longo deixou em bico) são
    alisadas; o anel do pescoço e a boca ficam onde estão."""
    bottom = min(v.co.z for v in bm.verts)
    w = {}
    for v in bm.verts:
        x, y, z = v.co
        wv = (_ramp(bottom + 0.004, bottom + 0.012, z) * (1 - _ramp(EYE_Z - CHIN_TOP - 0.02, EYE_Z - CHIN_TOP, z))
              * (1 - _ramp(-0.06, -0.04, y)))
        if wv > 0 and v.link_edges:
            w[v] = wv
    for _ in range(CHIN_SMOOTH):
        avg = {v: sum((n.co for e in v.link_edges for n in e.verts if n is not v), Vector()) / len(v.link_edges)
               for v in w}
        for v, c in avg.items():
            v.co = v.co.lerp(c, 0.5 * w[v])
    # a boca debaixo da malha: só o que está mais fundo que os vizinhos da frente sobe (o vão dos lábios e a boca aberta
    # somem; o queixo e o lábio não encolhem). Os vértices de dentro da boca (virados para trás) não contam.
    bm.normal_update()
    front = {v for v in bm.verts if v.normal.y < -0.2 and bottom + 0.01 < v.co.z < EYE_Z - MOUTH_TOP
             and abs(v.co.x) < 0.05}
    for _ in range(MOUTH_FILL):
        moves = {}
        for v in front:
            nb = [n for e in v.link_edges for n in e.verts if n is not v and n.normal.y < -0.2]
            if not nb:
                continue
            c = sum((n.co for n in nb), Vector()) / len(nb)
            if c.y < v.co.y:  # os vizinhos estão mais à frente: aqui é uma dobra para dentro
                moves[v] = c.y
        for v, y in moves.items():
            v.co.y = y
    # a quina (ponta para a frente + fundo do queixo) vira um arco de CHIN_R visto de lado
    low = [v.co for v in bm.verts if bottom + 0.004 < v.co.z < EYE_Z - CHIN_TOP]
    tip = min(c.y for c in low)
    under = min(c.z for c in low if c.y < tip + 0.012)
    cy, cz = tip + CHIN_R, under + CHIN_R
    for v in bm.verts:
        y, z = v.co.y, v.co.z
        if bottom + 0.004 < z < cz and y < cy:
            d = math.hypot(y - cy, z - cz)
            if d > CHIN_R:
                v.co.y = cy + (y - cy) * CHIN_R / d
                v.co.z = cz + (z - cz) * CHIN_R / d


def _open_eyes(bm, eye_slot):
    """O vão do olho no rosto passa a conter a amêndoa inteira (guerrilla_paint.almond, com folga): o que do rosto fica
    na frente do globo dentro dela vai para trás dele. O formato exato do olho é pintado no globo
    (guerrilla_paint.paint_eyes); o vão só precisa ser maior que ele."""
    import numpy as np

    for k in (1, -1):
        E = np.array([tuple(v.co) for f in bm.faces if f.material_index == eye_slot and f.calc_center_median().x * k > 0
                      for v in f.verts])
        sol = np.linalg.lstsq(np.c_[2 * E, np.ones(len(E))], (E ** 2).sum(axis=1), rcond=None)[0]
        c, r = sol[:3], float(np.sqrt(sol[3] + (sol[:3] ** 2).sum()))
        cx, cz = (E[:, 0].min() + E[:, 0].max()) / 2, (E[:, 2].min() + E[:, 2].max()) / 2
        for v in bm.verts:
            if v.co.x * k <= 0 or any(f.material_index == eye_slot for f in v.link_faces):
                continue
            lim = guerrilla_paint.almond((v.co.x - cx) * k, EYE_OPEN_MARGIN)
            if lim is None or not lim[1] < v.co.z - cz < lim[0]:
                continue
            q = r * r - (v.co.x - c[0]) ** 2 - (v.co.z - c[2]) ** 2
            behind = c[1] - math.sqrt(max(q, 0.0)) + EYE_OPEN_DEPTH
            if v.co.y < behind:
                v.co.y = behind


def _frown(bm, eye_slot):
    """Arco da sobrancelha do olhar fechado: desce do lado de dentro (cenho) e vem para a frente."""
    eyes = [v.co for f in bm.faces if f.material_index == eye_slot for v in f.verts]
    ez, ey = sum(c.z for c in eyes) / len(eyes), max(c.y for c in eyes)
    for v in bm.verts:
        band = _ramp(ez + 0.004, ez + 0.012, v.co.z) * (1 - _ramp(ez + 0.024, ez + 0.034, v.co.z))
        band *= (1 - _ramp(0.055, 0.065, abs(v.co.x))) * (v.co.y < ey)
        if band > 0 and not any(f.material_index == eye_slot for f in v.link_faces):
            v.co.z -= BROW_DROP * band * (1 - _ramp(0.012, 0.035, abs(v.co.x)))
            v.co.y -= BROW_FWD * band


def _iris(img):
    """Íris castanho-escura na textura realista (íris de raio 49 e pupila de 18 px no meio da imagem de 256)."""
    import numpy as np

    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    yy, xx = np.mgrid[0:h, 0:w]
    rr = np.hypot(xx - w / 2, yy - h / 2) / (w / 256)
    iris = (rr > 18) & (rr < 49)
    t = np.clip((rr - 18) / 31, 0, 1)[..., None] ** 0.7
    col = (np.array(IRIS[0], np.float32) * (1 - t) + np.array(IRIS[1], np.float32) * t) / 255.0
    lum = px[..., :3].mean(axis=2, keepdims=True)
    fib = np.clip(lum / max(float(lum[iris].mean()), 1e-3), 0.6, 1.4)  # as fibras da íris dela
    edge = 1 - 0.55 * np.clip((rr - 44) / 5, 0, 1)[..., None]  # anel escuro na borda
    px[..., :3] = np.where(iris[..., None], np.clip(col * fib * edge, 0, 1), px[..., :3])
    img.pixels = px.ravel().tolist()


def base_head(bone_names):
    """(bmesh da cabeça, anel do pescoço em volta do eixo vertical, materiais [rosto, olhos, janela dos olhos]). Os
    índices de material no bmesh são 3 (rosto), 4 (olhos) e 5 (janela)."""
    old = guerrilla_arms.ARM_TRIS
    guerrilla_arms.ARM_TRIS = 10 ** 6  # sem reduzir o corpo todo: só a cabeça é reduzida, depois
    try:
        mesh, J = guerrilla_arms._base_body()
    finally:
        guerrilla_arms.ARM_TRIS = old
    names = {g.index: g.name for g in mesh.vertex_groups}
    me = mesh.data
    keep_mats = {i for i, sl in enumerate(mesh.material_slots) if sl.material.name.split(".")[0] in ("Body_face", "Body_eye")}
    head_w = [sum(g.weight for g in v.groups if names[g.group] in ("Head", "Neck")) for v in me.vertices]
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in keep_mats
                               or not all(head_w[v.index] > 0.5 for v in f.verts)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # olhos na altura da referência, cabeça de homem; pescoço engrossado até o do tronco
    eye_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name.split(".")[0] == "Body_eye")
    eyes = [v.co.copy() for f in bm.faces if f.material_index == eye_slot for v in f.verts]
    pivot = sum(eyes, Vector()) / len(eyes)
    # a metade de trás de cada globo nunca aparece e furava a têmpora quando ela entra no lugar da orelha
    back = []
    for k in (1, -1):
        mine = [f for f in bm.faces if f.material_index == eye_slot and f.calc_center_median().x * k > 0]
        cy = sum((f.calc_center_median().y for f in mine)) / len(mine)
        back += [f for f in mine if f.calc_center_median().y > cy]
    bmesh.ops.delete(bm, geom=back, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bottom = min(v.co.z for v in bm.verts)
    neck = [v for v in bm.verts if v.co.z < bottom + 0.012]
    nc = sum((v.co for v in neck), Vector()) / len(neck)
    nr = sum(math.hypot(v.co.x - nc.x, v.co.y - nc.y) for v in neck) / len(neck)
    for v in bm.verts:
        h = v.co.z - bottom
        if h < NECK_FROM:
            t = 1 - h / NECK_FROM
            f = 1 + (NECK_R / (nr * SCALE) - 1) * t * t * (3 - 2 * t)
            v.co.x = nc.x + (v.co.x - nc.x) * f
            v.co.y = nc.y + (v.co.y - nc.y) * f
        v.co = Vector((0.0, pivot.y, EYE_Z)) + (v.co - pivot) * SCALE
    _hide_ears(bm)
    bottom = min(v.co.z for v in bm.verts)
    _widen(bm, bottom)
    _proportions(bm, bottom)
    _fit_neck(bm)
    _round_chin(bm)
    _open_eyes(bm, eye_slot)
    _frown(bm, eye_slot)
    me2 = bpy.data.meshes.new("GuerrillaHeadTmp")
    bm.to_mesh(me2)
    bm.free()
    obj = bpy.data.objects.new("GuerrillaHeadTmp", me2)
    bpy.context.scene.collection.objects.link(obj)
    for sl in mesh.material_slots:
        obj.data.materials.append(sl.material)
    for g in mesh.vertex_groups:
        obj.vertex_groups.new(name=g.name)
    _reduce(obj, HEAD_TRIS)
    obj.data.calc_loop_triangles()
    guerrilla_paint.paint_balaclava(obj)  # nítida: pixel a pixel na textura do rosto (filtro "nearest")
    face_mat = next(sl.material for sl in obj.material_slots if sl.material.name.startswith("Body_face"))
    eye_mat = next(sl.material for sl in obj.material_slots if sl.material.name.startswith("Body_eye"))
    win_mat = next(sl.material for sl in obj.material_slots if sl.material.name.startswith("Body_window"))
    # olhos castanhos (a textura realista do corpo base), não os verdes da heroína
    eye_img = bpy.data.images.load(str(guerrilla_arms.HB.SRC / "guerrilla_eye_realistic.png"))
    _iris(eye_img)
    guerrilla_paint.paint_eyes(obj, eye_img)  # a amêndoa: pálpebras, cílios e a pele em volta, no globo
    eye_img.pack()
    next(n for n in eye_mat.node_tree.nodes if n.type == "TEX_IMAGE").image = eye_img
    out = bmesh.new()
    out.from_mesh(obj.data)
    dl = out.verts.layers.deform.active
    gnames = {g.index: g.name for g in obj.vertex_groups}
    for v in out.verts:  # pesos nos índices do nosso esqueleto
        old = dict(v[dl])
        for g in list(v[dl].keys()):
            del v[dl][g]
        for g, x in old.items():
            v[dl][bone_names.index(gnames[g])] = x
    for f in out.faces:
        m = obj.material_slots[f.material_index].material
        f.material_index = 4 if m is eye_mat else 5 if m is win_mat else 3
    bottom = min(v.co.z for v in out.verts)
    edge = [e for e in out.edges if len(e.link_faces) == 1 and all(v.co.z < bottom + 0.03 for v in e.verts)]
    ring = list({v for e in edge for v in e.verts})
    c = sum((v.co for v in ring), Vector()) / len(ring)
    ring.sort(key=lambda v: math.atan2(v.co.x - c.x, v.co.y - c.y) % (2 * math.pi))
    for o in (obj, mesh):
        data = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(data)
    return out, ring, [face_mat, eye_mat, win_mat]
