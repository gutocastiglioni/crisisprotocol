"""Texturas da cabeça do guerrilheiro pintadas sobre as do modelo base (art/base_body/): a balaclava de malha
(`paint_balaclava`), a janela dos olhos com a bainha, a pele e as sobrancelhas (material "Body_window", projetado de
frente) e a amêndoa do olho no globo (`paint_eyes`). Chamado por art/guerrilla_head.base_head."""
import math

import bpy
from mathutils import Vector


def paint_balaclava(mesh):
    """Balaclava preta tática cobrindo boca e queixo, com a janela dos olhos (_eye_window) em volta dos olhos 3D."""
    import numpy as np

    me = mesh.data
    uvl = me.uv_layers.active.data
    eye_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name.split(".")[0] == "Body_eye")
    face_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name.split(".")[0] == "Body_face")
    eye_l = _eye_line(mesh, eye_slot)

    node = next(n for n in mesh.material_slots[face_slot].material.node_tree.nodes if n.type == "TEX_IMAGE")
    img = node.image
    w, h = img.size
    src = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    lum = src[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    mean = max(float(lum.mean()), 1e-3)

    yy, xx = np.mgrid[0:h, 0:w]
    knit = np.full((h, w, 3), (24 / 255.0, 24 / 255.0, 27 / 255.0), dtype=np.float32)
    v_stitch = ((xx + (yy // 2)) % 4 == 0)
    knit[v_stitch] = (18 / 255.0, 18 / 255.0, 20 / 255.0)
    knit[(yy % 6 == 0) & ~v_stitch] = (33 / 255.0, 33 / 255.0, 37 / 255.0)
    shade = np.clip(0.82 + 0.30 * (lum - mean) / mean, 0.68, 1.22)[..., None]
    out = src.copy()
    out[..., :3] = np.clip(knit * shade, 0.0, 1.0)

    new = bpy.data.images.new("face_guerrilla", w, h, alpha=True)
    new.pixels = out.ravel().tolist()
    new.pack()
    node.image = new
    _window_material(mesh, face_slot, eye_l)


def _eye_line(mesh, eye_slot):
    """Meio dos vértices do olho esquerdo (x > 0): a linha dos olhos da pintura da janela."""
    me = mesh.data
    el = [me.vertices[vi].co for p in me.polygons if p.material_index == eye_slot for vi in p.vertices
          if me.vertices[vi].co.x > 0]
    return sum(el, Vector()) / max(len(el), 1)


# formato do olho (amêndoa de homem, como no painel do usuário), em volta do meio do globo; dx > 0 para fora do rosto
ALMOND_W = 0.0140  # meia-largura, do meio ao canto (2,8 cm de olho; o globo tem 3,2: o vão não passa dele)
ALMOND_UP, ALMOND_LOW = 0.0058, 0.0042  # altura da pálpebra de cima e de baixo no meio
ALMOND_TILT = 0.0012  # o canto de fora mais alto que o de dentro
ALMOND_ANGRY = 0.35  # a pálpebra de cima desce para o canto de dentro (raiva)
LASH, LOWER_LID = (30, 22, 18), (120, 84, 66)  # linha dos cílios em cima e a borda da pálpebra de baixo
LASH_W, LOWER_W = 0.0007, 0.0004  # grossura delas (m)
EYE_SKIN = 0.86  # a pele pintada no globo, em relação à da janela


def almond(dx, margin=0.0):
    """(alto, baixo) da abertura do olho em dx (z em volta do meio do globo), ou None fora dos cantos."""
    u = dx / (ALMOND_W + margin)
    if abs(u) >= 1:
        return None
    base = 1 - u * u
    top = ALMOND_UP * base ** 0.75 * (1 - ALMOND_ANGRY * max(-u, 0.0)) + ALMOND_TILT * u
    return top + margin, -ALMOND_LOW * base ** 0.9 + ALMOND_TILT * u - margin


def paint_eyes(mesh, img):
    """Pinta a amêndoa no globo (os dois olhos usam a mesma textura, espelhados): dentro, o olho com a sombra da
    pálpebra de cima e as linhas dos cílios e da pálpebra de baixo; fora, a pele da janela (_eye_window), sem emenda."""
    import numpy as np

    me = mesh.data
    uvl = me.uv_layers.active.data
    eye_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name.split(".")[0] == "Body_eye")
    eye_l = _eye_line(mesh, eye_slot)
    E = [me.vertices[vi].co for p in me.polygons if p.material_index == eye_slot and p.center.x > 0 for vi in p.vertices]
    cx = (min(c.x for c in E) + max(c.x for c in E)) / 2
    cz = (min(c.z for c in E) + max(c.z for c in E)) / 2
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    src = px.copy()
    for tri in me.loop_triangles:
        P = [me.vertices[i].co for i in tri.vertices]
        if tri.material_index != eye_slot or sum(c.x for c in P) < 0:
            continue
        raw = np.array([[uvl[li].uv.x, uvl[li].uv.y] for li in tri.loops])
        pts = (raw - np.floor(raw.mean(axis=0))) * np.array([w, h])
        (ax, ay), (bx, by), (qx, qy) = pts
        dd = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
        if abs(dd) < 1e-9:
            continue
        x0, y0 = np.floor(pts.min(axis=0)).astype(int)
        x1, y1 = np.ceil(pts.max(axis=0)).astype(int)
        for j in range(y0, y1 + 1):
            for i in range(x0, x1 + 1):
                l1 = ((by - qy) * (i + 0.5 - qx) + (qx - bx) * (j + 0.5 - qy)) / dd
                l2 = ((qy - ay) * (i + 0.5 - qx) + (ax - qx) * (j + 0.5 - qy)) / dd
                if l1 < -0.02 or l2 < -0.02 or 1 - l1 - l2 < -0.02:
                    continue
                q = P[0] * l1 + P[1] * l2 + P[2] * (1 - l1 - l2)
                dz = q.z - cz
                lim = almond(q.x - cx)
                jj, ii = j % h, i % w
                if lim is not None and lim[1] < dz < lim[0]:
                    shade = 0.50 + 0.50 * min(1.0, (lim[0] - dz) / 0.0020)  # sombra da pálpebra de cima no olho
                    col = src[jj, ii, :3] * shade
                    if lim[0] - dz < LASH_W:
                        col = np.array(LASH, np.float32) / 255.0
                    elif dz - lim[1] < LOWER_W:
                        col = np.array(LOWER_LID, np.float32) / 255.0
                    px[jj, ii, :3] = col
                else:
                    near = lim is not None and 0 <= dz - lim[0] < LASH_W * 0.8 and q.x - cx > -0.8 * ALMOND_W
                    c = LASH if near else _eye_window(q.x, q.z - eye_l.z, eye_l.x, ii * 7 + jj * 13)
                    # a pele no globo fica mais funda que a do rosto: um pouco mais escura, para não fazer halo
                    px[jj, ii, :3] = np.array(c, np.float32) / 255.0 if near else np.array(c, np.float32) * EYE_SKIN
    img.pixels = px.ravel().tolist()


def _window_material(mesh, face_slot, eye):
    """A janela dos olhos com textura própria, projetada de frente: o UV do rosto dela é espelhado e dobra no meio (a
    sobrancelha esticava por cima do nariz). Os triângulos da frente em volta dos olhos passam para o material
    "Body_window", com UV = posição (x, z) deles; a textura tem a janela, a bainha e a malha em volta."""
    import numpy as np

    me = mesh.data
    uvl = me.uv_layers.active.data
    W, H = WIN_PX
    xs, z0, z1 = WIN_SPAN
    px = np.ones((H, W, 4), np.float32)
    for j in range(H):  # linha 0 da imagem do Blender = embaixo
        dz = z0 + (j + 0.5) / H * (z1 - z0)
        for i in range(W):
            c = _eye_window(-xs + (i + 0.5) / W * 2 * xs, dz, eye.x, i * 7 + j * 13)
            px[j, i, :3] = c if c is not None else _knit(i, j)
    img = bpy.data.images.new("guerrilla_eyes", W, H, alpha=True)
    img.pixels = px.ravel().tolist()
    img.pack()
    mat = mesh.material_slots[face_slot].material.copy()
    mat.name = "Body_window"
    next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE").image = img
    me.materials.append(mat)
    slot = len(me.materials) - 1
    sx, sz0, sz1 = WIN_SEL
    win_d = lambda co: ((abs(co.x) / WIN_A) ** 4 + ((co.z - eye.z - WIN_C) / WIN_B) ** 4) ** 0.25
    for p in me.polygons:
        dz = p.center.z - eye.z
        d = min(win_d(me.vertices[i].co) for i in p.vertices)  # algum canto dele na janela ou na bainha
        if (p.material_index == face_slot and abs(p.center.x) < sx and sz0 < dz < sz1 and p.normal.y < 0.1
                and d < WIN_HEM + 0.1):
            p.material_index = slot
            for li in p.loop_indices:
                v = me.vertices[me.loops[li].vertex_index].co
                uvl[li].uv = ((v.x + xs) / (2 * xs), (v.z - eye.z - z0) / (z1 - z0))
    return mat


def _knit(i, j):
    """A malha da balaclava (o mesmo ponto do resto do rosto) fora da janela, na textura dela."""
    if (i + j // 2) % 4 == 0:
        c = (18, 18, 20)
    elif j % 6 == 0:
        c = (33, 33, 37)
    else:
        c = (24, 24, 27)
    return tuple(v / 255.0 * KNIT_SHADE for v in c)


# janela dos olhos da balaclava (como a do segundo painel que o usuário mandou): retângulo de cantos redondos da testa
# acima da sobrancelha até embaixo do olho, com bainha costurada; dentro, pele de homem com o olhar fechado (sobrancelha
# grossa descendo para o meio, sombra na pálpebra de cima)
WIN_A, WIN_C, WIN_B = 0.056, 0.002, 0.023  # meia-largura, meio (acima do olho) e meia-altura da janela (m)
WIN_HEM = 1.14  # a bainha vai da borda da janela até WIN_HEM vezes ela
WIN_PX = (256, 160)  # textura própria da janela (~1,5 px por mm)
WIN_SPAN = (0.085, -0.045, 0.060)  # o que ela cobre: meia-largura e z de baixo/cima em volta da linha dos olhos (m)
WIN_SEL = (0.075, -0.035, 0.050)  # triângulos da frente com o meio dentro disso usam a textura da janela
KNIT_SHADE = 0.85  # a malha em volta da janela no tom médio da do rosto (que é sombreada pela textura dela)
SKIN = (184, 142, 116)
BROW = (36, 27, 21)
HEM, HEM_FOLD, HEM_STITCH = (54, 54, 58), (22, 22, 25), (84, 84, 90)
# sobrancelha (x a partir do meio do rosto; z acima da linha dos olhos): ponta de dentro mais baixa = cenho fechado
BROW_X = (0.011, 0.054)
BROW_Z = (0.0050, 0.0150, 0.0145)  # dentro, no meio (40%), fora: desce forte para o meio (raiva)
BROW_T = (0.0055, 0.0024)  # meia-grossura dentro e fora (grossa, a cabeça dela mais ainda)


def _ramp(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def _eye_window(x, dz, eye_x, seed):
    """Cor do ponto (x, z - linha dos olhos) na janela dos olhos ou na bainha dela; None fora (fica a malha)."""
    X = abs(x)
    d = ((X / WIN_A) ** 4 + ((dz - WIN_C) / WIN_B) ** 4) ** 0.25
    if d >= WIN_HEM:
        return None
    noise = ((seed * 2654435761) % 1000) / 1000.0
    if d >= 1.0:
        if d < 1.035:
            col = HEM_FOLD  # a dobra da bainha faz sombra na borda
        elif abs(d - 1.10) < 0.012 and seed % 3:
            col = HEM_STITCH  # a costura
        else:
            col = HEM
        return tuple(min(1.0, v / 255.0 * (0.92 + 0.12 * noise)) for v in col)
    ex = X - abs(eye_x)
    s = 1.0 - 0.38 * _ramp(0.80, 1.0, d)  # sombra do pano na borda
    s *= 1 - 0.45 * math.exp(-((ex / 0.016) ** 2 + ((dz - 0.005) / 0.006) ** 2))  # pálpebra de cima funda, na sombra
    if abs(X - (0.0055 - 0.10 * (dz - 0.006))) < 0.0008 and 0.003 < dz < 0.013:
        s *= 0.86  # vincos do cenho entre as sobrancelhas, fechando para baixo
    s *= 1 - 0.14 * math.exp(-((X / 0.009) ** 2 + ((dz + 0.001) / 0.0016) ** 2))  # ruga na raiz do nariz
    s *= 1 - 0.14 * math.exp(-((ex / 0.015) ** 2 + ((dz + 0.009) / 0.004) ** 2))  # olheira
    s *= 1 + 0.10 * math.exp(-((ex / 0.026) ** 2 + ((dz - 0.025) / 0.006) ** 2))  # arco da sobrancelha
    s *= 1 + 0.12 * math.exp(-((X / 0.006) ** 2 + ((dz + 0.006) / 0.012) ** 2))  # dorso do nariz
    s *= 0.96 + 0.08 * noise
    col = [v / 255.0 * s for v in SKIN]
    u = (X - BROW_X[0]) / (BROW_X[1] - BROW_X[0])
    if -0.05 <= u <= 1.0:
        u = max(u, 0.0)
        zi, zm, zo = BROW_Z
        zc = zi + (zm - zi) * u / 0.4 if u < 0.4 else zm + (zo - zm) * (u - 0.4) / 0.6
        t = BROW_T[0] + (BROW_T[1] - BROW_T[0]) * u
        tips = _ramp(-0.04, 0.10, u) * (1 - _ramp(0.80, 1.0, u))  # pontas afinando
        hair = 0.70 + 0.30 * (((seed // 3) * 40503) % 100) / 100.0  # fios: falhas claras no meio do escuro
        a = (1 - _ramp(t * 0.45, t, abs(dz - zc))) * hair * tips
        col = [c * (1 - a) + b / 255.0 * a for c, b in zip(col, BROW)]
    return tuple(min(1.0, max(0.0, v)) for v in col)
