"""Mede o alossauro de referência ("Alice", `possible_models/land_of_the_lost_2009_alice.glb`, fora do git) e grava a
tabela `art/allosaurus_ref.py` que o gerador usa. Nada da malha de lá entra no jogo: só os pontos medidos.

Uso:
  blender --background --factory-startup --python tools/measure_allosaurus.py [-- --check <pasta>]
  (--check renderiza a referência de boca fechada, no nosso espaço, para conferir o fechamento da boca)

A Alice está na pose de modelagem com a boca aberta; a amarração da malha aos ossos veio torta da conversão (girar o
osso da mandíbula estica a malha toda), então a boca é fechada girando direto os vértices da mandíbula e da língua em
volta da junta (JAW_HINGE, JAW_CLOSE). Ela é levada ao nosso espaço (frente -Y, esquerda +X, Z para cima) com a escala
dos 9 m do nosso (SCALE) e o focinho em y = TIP_Y. Cada fatia é um corte por y = constante nos triângulos dos ossos da
peça, lidos por raios a cada 360/n graus em volta do meio da fatia (o ponto mais longe em cada direção), espelhados
(média dos dois lados). Esses pontos-chave dão só a estrutura (onde ficam alto, crista, bochecha, lábio, céu da boca);
a forma vem da retopologia: os nossos anéis densos encaixados no ponto mais perto da superfície real (HEAD_DENSE,
JAW_DENSE).
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "possible_models/land_of_the_lost_2009_alice.glb"
OUT = ROOT / "art/allosaurus_ref.py"
LENGTH = 9.0
TIP_Y = -3.45
JAW_HINGE = Vector((3.55, 0.0, 3.08))  # espaço da Alice (frente +X): fim de cima da mandíbula, dentro da bochecha
JAW_CLOSE = math.radians(36.0)  # quanto girar a mandíbula para os dentes se encontrarem (conferido: 30 ainda abre)
SKULL = {"Head_01", "UEyelidL", "UEyelidR", "LEyelidL", "LEyelidR"}
JAW = {"Jaw_01"}
DROP = {"EyeLT_01", "EyeRT_01", "Tongue1_01", "Tongue2_01", "Tongue3_01"}  # olhos (globos) e língua ficam de fora
# fatias (y, do focinho para trás); a cabeça fecha embaixo (garganta) atrás da boca; a última é a emenda com o pescoço
HEAD_Y = [-3.44, -3.40, -3.35, -3.29, -3.22, -3.15, -3.08, -3.01, -2.94, -2.87, -2.80, -2.73, -2.66, -2.59, -2.52,
          -2.45, -2.38, -2.30]
CLOSED_FROM = -2.62
NECK_Y = [-1.85, -1.90, -1.95, -2.00, -2.05, -2.10, -2.15, -2.20, -2.27]  # pescoço que sai da nuca (o resto é nosso)
NECK = {"NeckA_01", "NeckB_01"}
# atrás da boca (do canto até onde o bloco bochecha-mandíbula cai no pescoço, y -2,35): o casco de fora inteiro, com a
# mandíbula, 36 raios por fatia (mesmos pontos dos anéis do crânio)
HULL_Y = [round(-2.62 + 0.03 * i, 2) for i in range(12)]
# tronco e cauda (da base do pescoço medido à ponta da cauda): 16 raios por fatia; mais denso no tronco
TORSO = {"TorsoA_01", "TorsoB_01", "HipMaster_01", "Tail01_01", "Tail02_01", "Tail03_01", "Tail04_01"}
BODY_Y = [round(-1.95 + 0.10 * i, 2) for i in range(30)] + [round(1.10 + 0.25 * i, 2) for i in range(18)] + [5.55]
JAW_Y = [-3.37, -3.32, -3.26, -3.19, -3.12, -3.05, -2.98, -2.91, -2.84, -2.77, -2.70, -2.63, -2.56, -2.50, -2.46]


XF = []  # (escala, ponta) do último load(): leva pontos da referência ao nosso espaço


def ours(p):
    s, tip = XF
    return Vector((p.y * s, -(p.x - tip) * s + TIP_Y, p.z * s))


def joints(data):
    """Juntas dos membros (nosso espaço, lado esquerdo): o meio da borda onde a pele de um osso encontra a do próximo
    (faces com vértices dos dois); a ponta = o vértice do último osso mais longe da junta de antes. O esqueleto que vem
    no arquivo da referência está torto (conversão), não serve."""
    _, me, pts, bone = data

    def border(a, b):
        ps = []
        for f in me.data.polygons:
            vs = list(f.vertices)
            if any(bone[i] in a for i in vs) and any(bone[i] in b for i in vs):
                ps += [pts[i] for i in vs if pts[i].x > 0.05]
        return sum(ps, Vector()) / len(ps)

    def far(group, frm):
        return max((p for p, b in zip(pts, bone) if b in group and p.x > 0.05), key=lambda p: (p - frm).length)

    body = {"HipMaster_01", "TorsoA_01", "TorsoB_01", "Tail01_01"}
    chest = {"TorsoA_01", "TorsoB_01", "NeckA_01"}
    toes = {"ToeLT_01", "Toes01.L", "Toes02.L", "Toes03.L", "Toes04.L", "Toes05.L", "Toes06.L"}
    j = {"hip": border(body, {"HipLT_01"}), "knee": border({"HipLT_01"}, {"KneeLT_01"}),
         "ankle": border({"KneeLT_01"}, {"FootLT_01"}), "ball": border({"FootLT_01"}, toes),
         "shoulder": border(chest, {"ShoulderLT_01"}), "elbow": border({"ShoulderLT_01"}, {"ElbowLT_01"}),
         "wrist": border({"ElbowLT_01"}, {"HandLT_01", "PinkyALT_01"})}
    j["hand_tip"] = far({"HandLT_01", "PinkyALT_01"}, j["wrist"])
    return j


# membros: (nome nosso, osso da referência, junta de começo, junta de fim (ou ponta: (junta, vetor))), lado esquerdo
LIMBS = [("thigh", {"HipLT_01"}, "hip", "knee"), ("shin", {"KneeLT_01"}, "knee", "ankle"),
         ("meta", {"FootLT_01"}, "ankle", "ball"),
         ("arm", {"ShoulderLT_01"}, "shoulder", "elbow"), ("forearm", {"ElbowLT_01"}, "elbow", "wrist"),
         ("hand", {"HandLT_01", "PinkyALT_01"}, "wrist", "hand_tip")]
LIMB_T = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0]


def limb(data, group, a, b, n=12):
    """Anéis do membro: cortes perpendiculares ao eixo a->b nas frações LIMB_T, n raios em volta do eixo no referencial
    (lado = +X sem a parte do eixo, fundo = eixo x lado); devolve [(t, ((lado, fundo) por raio))] e o comprimento."""
    tris = data[0]
    axis = (b - a).normalized()
    side = (Vector((1, 0, 0)) - axis * axis.x).normalized()
    dep = axis.cross(side)
    loc = [([Vector(((p - a).dot(side), (p - a).dot(axis), (p - a).dot(dep))) for p in t], bn)
           for t, bn in tris if sum(1 for x in bn if x in group) >= 2 and min(p.x for p in t) > 0]
    length = (b - a).length
    rows = []
    for t in LIMB_T:
        segs = cut(loc, t * length * 0.999, group)
        if not segs:
            rows.append((t, [None] * (n // 2 + 1)))
            continue
        segs = [sg for sg in segs[:len(segs) // 2]]  # sem o espelho (cut espelha em x)
        out = []
        for j in range(n):
            th = 2 * math.pi * j / n
            r = ray(segs, (0.0, 0.0), th)
            out.append((r * math.sin(th), r * math.cos(th)) if r > 0 else None)
        rows.append((t, out))
    for j in range(n):  # raio sem pele: o mesmo raio da fração vizinha
        got = [(t, r[j]) for t, r in rows if r[j] is not None]
        for t, r in rows:
            if r[j] is None and got:
                r[j] = min(got, key=lambda g: abs(g[0] - t))[1]
    return [(t, tuple((round(x, 4), round(z, 4)) for x, z in r)) for t, r in rows], round(length, 4)


def short(name):
    return name.replace("joint_", "").rsplit("_0", 1)[0] if name.startswith("joint_") else name


def load():
    """(triângulos [(pontos, ossos)], escala, desloc.) já no nosso espaço, de boca fechada."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(REF))
    me = next(o for o in bpy.data.objects if o.type == "MESH" and o.name != "Icosphere")
    ev = me.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    names = {g.index: short(g.name) for g in me.vertex_groups}
    co = [me.matrix_world @ v.co for v in ev.vertices]
    bone = [names[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in me.data.vertices]
    rot = Matrix.Rotation(-JAW_CLOSE, 3, "Y")  # +X para a frente: girar em -Y leva a ponta da mandíbula para cima
    for i, b in enumerate(bone):
        if b in JAW or b.startswith("Tongue"):
            co[i] = JAW_HINGE + rot @ (co[i] - JAW_HINGE)
    tip = max(p.x for p in co)
    length = tip - min(p.x for p in co)
    s = LENGTH / length
    XF[:] = [s, tip]
    pts = [Vector((p.y * s, -(p.x - tip) * s + TIP_Y, p.z * s)) for p in co]
    tris = []
    for f in ev.polygons:
        vs = list(f.vertices)
        for t in range(1, len(vs) - 1):
            ids = (vs[0], vs[t], vs[t + 1])
            tris.append(([pts[i] for i in ids], [bone[i] for i in ids]))
    return tris, me, pts, bone


def cut(tris, y, keep):
    """Segmentos (x, z) do corte y = constante nos triângulos com 2+ vértices nos ossos `keep`; espelhados."""
    segs = []
    for pts, bones in tris:
        if sum(1 for b in bones if b in keep) < 2:
            continue
        d = [p.y - y for p in pts]
        hits = []
        for i in range(3):
            j = (i + 1) % 3
            if (d[i] > 0) != (d[j] > 0):
                p = pts[i].lerp(pts[j], d[i] / (d[i] - d[j]))
                hits.append((p.x, p.z))
        if len(hits) == 2:
            segs.append(hits)
    return segs + [((-a[0], a[1]), (-b[0], b[1])) for a, b in segs]


def ray(segs, c, th):
    """Distância ao ponto mais longe do contorno na direção (sen th, cos th) a partir de c (0 se nenhum)."""
    dx, dz = math.sin(th), math.cos(th)
    best = 0.0
    for (x0, z0), (x1, z1) in segs:
        ex, ez = x1 - x0, z1 - z0
        den = dx * ez - dz * ex
        if abs(den) < 1e-12:
            continue
        t = ((x0 - c[0]) * ez - (z0 - c[1]) * ex) / den
        u = ((x0 - c[0]) * dz - (z0 - c[1]) * dx) / den
        if t > 0 and 0 <= u <= 1:
            best = max(best, t)
    return best


def at_x(segs, x):
    out = []
    for (x0, z0), (x1, z1) in segs:
        if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
            out.append(z0 + (z1 - z0) * (x - x0) / (x1 - x0))
    return sorted(out)


def at_z(segs, z):
    out = []
    for (x0, z0), (x1, z1) in segs:
        if (z0 - z) * (z1 - z) <= 0 and z0 != z1:
            out.append(x0 + (x1 - x0) * (z - z0) / (z1 - z0))
    return out


def rays(segs, n):
    """Lado esquerdo (+x) de uma fatia fechada: n/2 + 1 pontos (x, z), do alto (j = 0) até embaixo, por raios a cada
    360/n graus em volta do meio dela."""
    zs = [p[1] for s in segs for p in s]
    c = (0.0, (max(zs) + min(zs)) / 2)
    out = []
    for j in range(n // 2 + 1):
        th = 2 * math.pi * j / n
        r = ray(segs, c, th)
        out.append((r * math.sin(th), c[1] + r * math.cos(th)))
    return out


def skull(segs):
    """Crânio aberto embaixo (boca): alto, base de dentro da crista, quina/ponta da crista, bochecha (o mais largo nos 70%
    de baixo da parede), lábio (fim
    da saia que desce por fora da mandíbula), borda e meio do céu da boca. Fechado (garganta, atrás da boca): raios."""
    pts = [p for s in segs for p in s]
    zs0 = at_x(segs, 0.0)
    ztop = zs0[-1]
    hw = max(p[0] for p in pts)
    lip = min((p for p in pts if p[0] > 0.55 * hw), key=lambda p: p[1])
    roofs = [z for z in zs0 if lip[1] + 0.03 < z < ztop - 0.05]
    if not roofs:
        return rays(segs, 12)

    def top_at(x):
        z = at_x(segs, x)
        return z[-1] if z else None

    tip = max((p for p in pts if p[0] > 0.35 * hw), key=lambda p: p[1] + 0.3 * p[0])
    xs = [tip[0] * f for f in (0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9)]
    inner = min(((x, top_at(x)) for x in xs if top_at(x) is not None), key=lambda p: p[1])
    band = [p for p in pts if lip[1] + 0.02 < p[1] < tip[1] - 0.3 * (tip[1] - lip[1])]  # 70% de baixo da parede
    wide = max(band, key=lambda p: p[0]) if band else ((tip[0] + lip[0]) / 2, (tip[1] + lip[1]) / 2)
    roof = max(roofs)
    xi = [x for x in at_z(segs, roof - 0.004) if 0 < x < lip[0]]
    edge = (min(xi) if xi else 0.85 * lip[0], roof)
    return [(0.0, ztop), inner, tip, wide, lip, edge, (0.0, roof)]


def rays_open(segs, n):
    """Como `rays`, mas o raio que não acha pele (fatia aberta onde entra perna ou braço) fica None."""
    zs = [p[1] for s in segs for p in s]
    c = (0.0, (max(zs) + min(zs)) / 2)
    out = []
    for j in range(n // 2 + 1):
        th = 2 * math.pi * j / n
        r = ray(segs, c, th)
        out.append((r * math.sin(th), c[1] + r * math.cos(th)) if r > 0 else None)
    return out


def fill_along(rows):
    """Pontos None: interpolados pelo mesmo ponto das fatias da frente e de trás que acharam pele (ao longo de y)."""
    for j in range(len(rows[0][1])):
        found = [(y, half[j]) for y, half in rows if half[j] is not None]
        for y, half in rows:
            if half[j] is not None:
                continue
            a = max((f for f in found if f[0] < y), default=None, key=lambda f: f[0])
            b = min((f for f in found if f[0] > y), default=None, key=lambda f: f[0])
            if a and b:
                t = (y - a[0]) / (b[0] - a[0])
                half[j] = tuple(a[1][k] + (b[1][k] - a[1][k]) * t for k in range(2))
            else:
                half[j] = (a or b)[1]
    return rows


def jaw(segs):
    """Mandíbula em calha (U com espessura): língua (fundo de dentro), alto do braço, lado (o mais largo), quina de
    baixo (no contorno: o lado pode ser uma diagonal sem vértice), fundo."""
    pts = [p for s in segs for p in s]
    if not pts:
        return None
    zs0 = at_x(segs, 0.0)
    wide = max(pts, key=lambda p: p[0])
    arm = max((p for p in pts if p[0] > 0.4 * wide[0]), key=lambda p: p[1])  # borda do braço (não peças do meio da boca)
    floor = zs0[0] if zs0 else min(p[1] for p in pts)
    tongue = zs0[-1] if zs0 and zs0[-1] > floor + 0.03 else arm[1]
    tongue = min(tongue, arm[1])
    zl = at_x(segs, 0.55 * wide[0])
    low = (0.55 * wide[0], zl[0]) if zl else min(pts, key=lambda p: p[1])
    side = wide if wide[1] > low[1] + 0.02 else (wide[0], low[1] + 0.02)
    return [(0.0, tongue), (abs(arm[0]), arm[1]), side, low, (0.0, floor)]


def snap(data, rings, keep):
    """Retopologia: os pontos dos nossos anéis (lista de (y, [(x, z) da volta inteira])) vão para o ponto mais perto da
    superfície da referência (só as faces dos ossos `keep`); os dois lados são espelhados (média). Devolve, por anel,
    (y, metade esquerda (x, z) do alto até embaixo)."""
    _, me, pts, bone = data
    faces = []
    for f in me.data.polygons:
        vs = list(f.vertices)
        if sum(1 for i in vs if bone[i] in keep) * 2 >= len(vs):
            faces.append(vs)
    tgt_me = bpy.data.meshes.new("alvo")
    tgt_me.from_pydata([tuple(p) for p in pts], [], faces)
    tgt = bpy.data.objects.new("alvo", tgt_me)
    bpy.context.scene.collection.objects.link(tgt)
    flat = [Vector((x, y, z)) for y, full in rings for x, z in full]
    src_me = bpy.data.meshes.new("nosso")
    src_me.from_pydata([tuple(p) for p in flat], [], [])
    src = bpy.data.objects.new("nosso", src_me)
    bpy.context.scene.collection.objects.link(src)
    mod = src.modifiers.new("encaixe", "SHRINKWRAP")
    mod.target, mod.wrap_method = tgt, "NEAREST_SURFACEPOINT"
    ev = src.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    snapped = [v.co.copy() for v in ev.vertices]
    out, k = [], 0
    for y, full in rings:
        n = len(full)
        ring = snapped[k:k + n]
        k += n
        half = []
        for j in range(n // 2 + 1):
            a, b = ring[j], ring[(n - j) % n]
            half.append((round((abs(a.x) + abs(b.x)) / 2 if 0 < j < n // 2 else 0.0, 4), round((a.z + b.z) / 2, 4)))
        out.append((round(y, 4), tuple(half)))
    bpy.data.objects.remove(src)
    bpy.data.objects.remove(tgt)
    return out


def dense(table, y0, y1, per, step=0.03):
    """Anéis-guia lisos (da tabela de pontos-chave, como em allosaurus_head) de y0 a y1, para o encaixe."""
    sys.path.insert(0, str(ROOT / "art"))
    import importlib
    import allosaurus_head as H
    importlib.reload(H)
    n = max(2, round(abs(y1 - y0) / step))
    rings = []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        half = H._smooth_half(H._keys_at(table, y), per)
        rings.append((y, half + [(-x, z) for x, z in reversed(half[1:-1])]))
    return rings


def check(tris_me, folder):
    """Render da referência de boca fechada no nosso espaço (lado e 3/4), para conferir o fechamento."""
    _, me, pts, _ = tris_me
    mesh = me.data
    for v, p in zip(mesh.vertices, pts):
        v.co = me.matrix_world.inverted() @ Vector((p.x, p.y, p.z))  # aproximação: só para a conferência
    for m in me.modifiers:
        m.show_render = m.show_viewport = False
    out = Path(folder)
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = 700
    sh = scene.display.shading
    sh.light, sh.color_type, sh.show_specular_highlight = "STUDIO", "TEXTURE", False
    world = bpy.data.worlds.new("w")
    scene.world, world.color, sh.background_type = world, (0.3, 0.3, 0.32), "WORLD"
    for o in bpy.data.objects:
        if o.name == "Icosphere":
            o.hide_render = True
    cd = bpy.data.cameras.new("c")
    cd.type, cd.clip_end, cd.ortho_scale = "ORTHO", 500, 1.6
    cam = bpy.data.objects.new("c", cd)
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = Vector((0, TIP_Y + 0.6, 2.75))
    for name, d in (("side", (-1, 0, 0)), ("q", (-0.7, -0.7, 0.25))):
        pos = target + Vector(d).normalized() * 60
        cam.location, cam.rotation_euler = pos, (target - pos).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out / f"ref_{name}.png")
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    data = load()
    if "--check" in argv:
        check(data, argv[argv.index("--check") + 1])
        return
    tris = data[0]
    head = []
    for y in HEAD_Y:
        closed = y > CLOSED_FROM
        segs = cut(tris, y, SKULL | NECK if closed else SKULL)  # garganta sem a mandíbula: o fim dela aparece por baixo
        side = rays(segs, 12) if closed else skull(segs)
        head.append((round(y, 4), tuple((round(x, 4), round(z, 4)) for x, z in side)))
    jaws = []
    for y in JAW_Y:
        side = jaw(cut(tris, y, JAW))
        if side is None:
            print(f"[medida] mandíbula vazia em y = {y}")
            continue
        jaws.append((round(y, 4), tuple((round(x, 4), round(z, 4)) for x, z in side)))
    necks = []
    for y in NECK_Y:
        side = rays(cut(tris, y, SKULL | NECK), 12)
        necks.append((round(y, 4), tuple((round(x, 4), round(z, 4)) for x, z in side)))
    hull = []
    for y in HULL_Y:
        side = rays(cut(tris, y, SKULL | JAW | NECK), 36)
        hull.append((round(y, 4), tuple((round(x, 4), round(z, 4)) for x, z in side)))
    rows = []
    for y in BODY_Y:
        segs = cut(tris, y, TORSO | NECK)
        if segs:
            rows.append((y, rays_open(segs, 16)))
    body = [(round(y, 4), tuple((round(x, 4), round(z, 4)) for x, z in half)) for y, half in fill_along(rows)]
    jp = [p for p, b in zip(data[2], data[3]) if b in JAW]
    print(f"[medida] mandíbula de y {min(p.y for p in jp):.3f} a {max(p.y for p in jp):.3f}")
    lines = [
        '"""Alossauro medido na referência (Alice) por `tools/measure_allosaurus.py`: não editar à mão.',
        "",
        "Fatias da nuca para a ponta do focinho: (y, pontos (x, z) do lado esquerdo, +x, do alto para baixo). Crânio:",
        "alto, base da crista, quina/crista, meio da parede, lábio, borda e meio do céu da boca (atrás da boca, fechado:",
        'raios a cada 30°). Mandíbula, da traseira para a frente: língua, alto do braço, lado, quina de baixo, fundo.',
        'Pescoço (NECK), da base para a nuca: raios a cada 30° (no espaço da referência; o gerador o sobe com a cabeça)."""',
        "",
        "HEAD = [",
    ]
    lines += [f"    ({y}, {p})," for y, p in reversed(head)]
    lines += ["]", "JAW = ["]
    lines += [f"    ({y}, {p})," for y, p in reversed(jaws)]
    lines += ["]", "HULL = [  # casco de fora atrás da boca (com a mandíbula), de trás para a frente, 36 raios"]
    lines += [f"    ({y}, {p})," for y, p in reversed(hull)]
    lines += ["]", "BODY = [  # tronco e cauda, da base do pescoço à ponta da cauda, 16 raios (meia volta: 9 pontos)"]
    lines += [f"    ({y}, {p})," for y, p in body]
    lines += ["]", "# membros (lado esquerdo): comprimento na referência e anéis (fração do eixo, (lado, fundo) de 12 raios)",
              "LIMBS = {"]
    jt = joints(data)
    lines.insert(-1, "JOINTS = {" + ", ".join(f"{k!r}: {tuple(round(x, 4) for x in v)}" for k, v in jt.items()) + "}")
    for name, group, ja, jb in LIMBS:
        rings, length = limb(data, group, jt[ja], jt[jb])
        lines.append(f"    {name!r}: ({length}, [")
        lines += [f"        ({t}, {r})," for t, r in rings]
        lines.append("    ]),")
    lines += ["}", "NECK = ["]
    lines += [f"    ({y}, {p})," for y, p in necks]
    lines += ["]", ""]
    # retopologia: nossos anéis (36 pontos no crânio, 24 na mandíbula, um a cada 3 cm) encaixados na superfície real
    sys.path.insert(0, str(ROOT / "art"))
    import types
    keys = types.SimpleNamespace(HEAD=list(reversed(head)), JAW=list(reversed(jaws)))
    head_d = snap(data, dense(keys.HEAD, keys.HEAD[0][0], keys.HEAD[-1][0], 3), SKULL | NECK)
    neck_d = snap(data, dense(necks, NECK_Y[0], NECK_Y[-1], 3, step=0.05), SKULL | JAW | NECK)
    jaw_d = snap(data, dense(keys.JAW, keys.JAW[0][0], keys.JAW[-1][0], 3), JAW)
    lines += ["# retopologia: anéis densos encaixados na superfície da referência (metade esquerda, do alto para baixo)",
              "HEAD_DENSE = ["]
    lines += [f"    ({y}, {p})," for y, p in head_d]
    lines += ["]", "NECK_DENSE = [  # da base para a nuca; continua em HEAD_DENSE (mesmos pontos por anel)"]
    lines += [f"    ({y}, {p})," for y, p in neck_d]
    lines += ["]", "JAW_DENSE = ["]
    lines += [f"    ({y}, {p})," for y, p in jaw_d]
    lines += ["]", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"[medida] {OUT}")


main()
