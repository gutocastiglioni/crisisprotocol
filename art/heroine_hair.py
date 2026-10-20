"""Cabelo da heroína sobre o corpo do modelo base (art/heroine_body.py): superfícies dela (crânio e costas),
a nossa calota puxada com franja (heroine_head) projetada no crânio dela e a trança única com ossos próprios
(Braid1..N), que o Godot balança com mola (HeroineModel._setup_braid).
"""
import math

import bmesh
import bpy
from mathutils import Vector

import heroine_spec as S


SCALP_LIFT, SCALP_EDGE = 0.016, 0.008  # calota afastada do crânio dela (o couro escuro da textura não aparece)
SURF = {}  # superfícies dela (antes de reduzir) para pôr o cabelo: cabeça e costas


def _surfaces(mesh):
    from mathutils.bvhtree import BVHTree

    names = {i: sl.material.name.removeprefix("Body_") for i, sl in enumerate(mesh.material_slots)}
    for key, mats in (("head", ("face",)), ("body", ("skin", "costume"))):
        bm = bmesh.new()
        bm.from_mesh(mesh.data)
        bm.transform(mesh.matrix_world)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if names[f.material_index] not in mats], context="FACES")
        SURF[key] = BVHTree.FromBMesh(bm)
        if key == "head":
            zs = [v.co.z for v in bm.verts]
            top = max(zs)
            cran = [v.co for v in bm.verts if top - 0.12 < v.co.z < top - 0.05]
            SURF["top"] = top
            SURF["yc"] = sum(c.y for c in cran) / len(cran)
        bm.free()


def _head_point(th, z, off=0.0):
    """Ponto no crânio dela com a mesma convenção de heroine_head.head_point (th: 0 = nuca, pi = frente; z na
    altura da nossa cabeça antiga, levada para a dela pelo topo do crânio), afastado `off` para fora."""
    import heroine_head as H

    zs = [r[0] for r in H.HEAD]
    zm = SURF["top"] - (zs[-1] - min(max(z, zs[0]), zs[-1]))
    zm = min(zm, SURF["top"] - 0.004)
    # do centro do crânio, na direção do ponto (perto do topo o raio sobe: um raio deitado passaria raspando)
    c = Vector((0.0, SURF["yc"], SURF["top"] - 0.09))
    d = Vector((math.sin(th) * 0.08, math.cos(th) * 0.09, zm - c.z)).normalized()
    hit = SURF["head"].ray_cast(c, d, 0.3)[0]
    if hit is None:
        hit = c + d * 0.09
    return hit + d * off


# ------------------------------------------------------------------ trança com ossos (balança no Godot)
BRAID_BONES = 4


def _braid_path():
    """Caminho da trança: da nuca dela (heroine_head.BRAID_PATH levado para o crânio dela) e descendo encostada na
    camada de fora das costas (o colete por cima da pele)."""
    import heroine_head as H

    old_path = H.BRAID_PATH
    path = []
    for z, y in old_path:
        if z >= 1.5:
            p = _head_point(0.0, z, 0.0)
            path.append(Vector((0.0, p.y + (y - H.head_point(0.0, z, 0.0).y), p.z)))
        else:
            t = (old_path[0][0] - z) / (old_path[0][0] - old_path[-1][0])
            half = 0.72 * (0.012 + 0.022 * (1 - t) ** 1.2)
            hit = SURF["body"].ray_cast(Vector((0.0, 0.4, z)), Vector((0, -1, 0)), 0.6)[0]
            back = hit.y if hit is not None else y - half
            path.append(Vector((0.0, back + half + 0.006, z)))
    return path


def braid_bones(path):
    """Ossos da trança (Braid1..BRAID_BONES): o caminho dividido em partes iguais; o primeiro sai da cabeça."""
    total = sum((b - a).length for a, b in zip(path, path[1:]))
    pts = [_along(path, total * i / BRAID_BONES) for i in range(BRAID_BONES + 1)]
    return [(f"Braid{i + 1}", pts[i], pts[i + 1], "Head" if i == 0 else f"Braid{i}") for i in range(BRAID_BONES)]


def _along(path, d):
    for a, b in zip(path, path[1:]):
        seg = (b - a).length
        if d <= seg:
            return a.lerp(b, d / seg)
        d -= seg
    return path[-1].copy()


def make_hair(rig, atlas_path):
    """A nossa trança (heroine_head: calota puxada, franja e trança única) na cabeça dela: o código do cabelo mede a
    cabeça por head_point, trocado aqui pelo crânio dela; a trança desce encostada nas costas da jaqueta."""
    import heroine_head as H
    import heroine_mesh as HM
    import heroine_rig

    old_point, old_path = H.head_point, H.BRAID_PATH
    path = _braid_path()
    H.head_point = _head_point
    H.BRAID_PATH = [(p.z, p.y) for p in path]
    braid_names = [b[0] for b in braid_bones(path)]
    try:
        mb = HM.MeshBuilder(S.BONE_NAMES)
        H.build_scalp(mb, lift=SCALP_LIFT, edge_lift=SCALP_EDGE, line=H._hairline_pulled, v_end=0.78)
        H.build_fringe(mb)
        names = list(S.BONE_NAMES) + braid_names
        mb_braid = HM.MeshBuilder(names)
        H.build_braid(mb_braid)
    finally:
        H.head_point, H.BRAID_PATH = old_point, old_path
    _braid_weights(mb_braid, path, names)
    # o topo da calota é uma altura fixa da cabeça antiga (heroine_head.build_scalp): assenta no topo do crânio dela
    cap = SURF["top"] + SCALP_LIFT
    for v in mb.bm.verts:
        if v.co.z > cap:
            v.co.z = cap
    image = bpy.data.images.load(str(atlas_path))
    image.pack()
    hair = heroine_rig.make_material("HeroineHair", image, double_sided=True)
    obj = heroine_rig._skinned_object(rig, "HeroineHair", mb, [hair, hair])
    braid = _skinned(rig, "HeroineBraid", mb_braid, names, [hair, hair])
    tris = sum(len(p.vertices) - 2 for o in (obj, braid) for p in o.data.polygons)
    print(f"[corpo] cabelo: {tris} triângulos (calota, franja e trança em {len(braid_names)} ossos)")
    return obj


def _braid_weights(mb, path, names):
    """Cada vértice da trança dividido entre os dois ossos da trança mais perto (pela posição ao longo do caminho);
    a raiz, junto da nuca, ainda com um pouco da cabeça."""
    total = sum((b - a).length for a, b in zip(path, path[1:]))
    groups = {n: i for i, n in enumerate(names)}
    dl = mb.dl
    for v in mb.bm.verts:
        best, acc, d0 = None, 0.0, 0.0
        for a, b in zip(path, path[1:]):
            seg = b - a
            t = max(0.0, min(1.0, (v.co - a).dot(seg) / seg.length_squared))
            dist = (v.co - (a + seg * t)).length
            if best is None or dist < best:
                best, d0 = dist, acc + seg.length * t
            acc += seg.length
        u = d0 / total * BRAID_BONES - 0.5  # centro de cada osso
        i = max(0, min(BRAID_BONES - 1, int(math.floor(u))))
        f = max(0.0, min(1.0, u - i))
        w = {f"Braid{i + 1}": 1 - f, f"Braid{min(BRAID_BONES, i + 2)}": f}
        if d0 < 0.03:
            w = {"Head": 0.5, "Braid1": 0.5}
        dv = v[dl]
        dv.clear()
        total_w = sum(w.values())
        for n, x in w.items():
            dv[groups[n]] = dv.get(groups[n], 0.0) + x / total_w


def _skinned(rig, name, mb, names, materials):
    """Como heroine_rig._skinned_object, com os grupos de `names` (inclui os ossos da trança)."""
    me = bpy.data.meshes.new(name + "Mesh")
    mb.bm.normal_update()
    mb.bm.to_mesh(me)
    mb.bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for n in names:
        obj.vertex_groups.new(name=n)
    for mat in materials:
        me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = True
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj
