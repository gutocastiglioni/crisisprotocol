"""Braços do guerrilheiro tirados do corpo base (art/base_body/Mesh.fbx, o mesmo da heroína: "modelo padrão"), com a
mão e os dedos fechados dele. Cada braço é recortado do corpo base, levado ao osso do nosso esqueleto (comprimentos da
referência: art/guerrilla_spec.py) e engrossado até a manga do moletom medida na referência; o corte perto do ombro é
plano, e a borda volta para art/guerrilla_body.py, que fecha o toco do ombro do tronco exatamente nesses vértices (pele
única, soldada). A textura de pele dele vira a manga do moletom, com a mão como estava.
"""
import math

import bmesh
import bpy
from mathutils import Vector

import build_heroine
import guerrilla_spec as G
import heroine_body as HB
import heroine_spec as S
from heroine_mesh import ring_frame

ARM_TRIS = 2600  # o corpo base inteiro é reduzido para isto antes de tirar os braços (cada braço fica com ~350)
CUT = 0.16  # o braço começa a CUT metros da junta (abaixo da axila dele; acima disso é o toco do ombro do tronco)
HAND_SCALE = 1.10  # mão de homem: um pouco maior que a dela
# raio da manga ao longo do braço, a partir da junta (m): o que a referência mede (10,9 / 9,4 / 7,9 / 5,5 cm)
SLEEVE = [(0.0, 0.056), (0.15, 0.0545), (0.27, 0.047), (0.39, 0.0395), (0.49, 0.0285), (0.508, 0.026)]
HAND_RECT = (0.742, 0.988, 0.270, 0.536)  # u0, u1, v0, v1 da mão na textura de pele dela (fica como está)


def _sleeve_r(t):
    for (t0, r0), (t1, r1) in zip(SLEEVE, SLEEVE[1:]):
        if t0 <= t <= t1:
            return r0 + (r1 - r0) * (t - t0) / (t1 - t0)
    return SLEEVE[-1][1] if t > SLEEVE[-1][0] else SLEEVE[0][1]


def _base_body():
    """O corpo base na pose de repouso (braços em ARM_SPREAD, dedos fechados), reduzido, pesos nos nossos ossos."""
    bpy.ops.import_scene.fbx(filepath=str(HB.SRC / "Mesh.fbx"))
    arm = next(o for o in bpy.context.selected_objects if o.type == "ARMATURE")
    mesh = next(o for o in bpy.context.selected_objects if o.type == "MESH")
    mesh.name = "BaseArms"
    HB._materials(mesh)
    zs = [(mesh.matrix_world @ v.co).z for v in mesh.data.vertices]
    arm.scale = (arm.scale.x * HB.HEIGHT / (max(zs) - min(zs)),) * 3
    bpy.context.view_layer.update()
    for o in bpy.data.objects:
        o.select_set(o in (arm, mesh))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for b in arm.data.bones:
        b.inherit_scale = "NONE"
    HB._pose(arm)
    HB._bake(mesh)
    joints = HB._joints(arm)
    world = mesh.matrix_world.copy()
    mesh.parent = None
    mesh.matrix_world = world
    bpy.data.objects.remove(arm)
    for o in bpy.data.objects:
        o.select_set(o is mesh)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    HB._merge_groups(mesh)
    old = HB.TARGET_TRIS
    HB.TARGET_TRIS = ARM_TRIS
    try:
        HB._decimate(mesh)
    finally:
        HB.TARGET_TRIS = old
    return mesh, joints


def _sleeve_texture(mesh):
    """A pele dela vira a manga do moletom (cor do moletom, com as dobras da textura dela); a mão fica como está."""
    import numpy as np

    slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_skin")
    mat = mesh.material_slots[slot].material
    node = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    img = node.image
    w, h = img.size
    src = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    lum = src[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    mean = max(float(lum.mean()), 1e-3)
    shade = np.clip(0.9 + 0.3 * (lum - mean) / mean, 0.75, 1.15)[..., None]
    out = src.copy()
    out[..., :3] = np.clip(np.array(G.COLORS["hoodie"], np.float32) / 255.0 * shade, 0, 1)
    u0, u1, v0, v1 = HAND_RECT
    yy, xx = np.mgrid[0:h, 0:w]
    hand = (xx >= u0 * w) & (xx <= u1 * w) & (yy >= v0 * h) & (yy <= v1 * h)
    out[hand, :3] = src[hand, :3]
    new = bpy.data.images.new("guerrilla_sleeve_skin", w, h, alpha=True)
    new.pixels = out.ravel().tolist()
    new.pack()
    node.image = new
    return mat


def _close(bm, keep):
    """O braço dela é feito de peças que só encostam (mão, punho, dedos): solda os vértices de borda coincidentes (3 mm),
    fecha os furos que sobram e junta as frestas. O anel do corte (`keep`) fica aberto para a solda com o ombro."""
    def open_edges():
        return [e for e in bm.edges if len(e.link_faces) == 1 and not all(v in keep for v in e.verts)]
    bmesh.ops.remove_doubles(bm, verts=list({v for e in open_edges() for v in e.verts if v not in keep}), dist=0.003)
    bmesh.ops.holes_fill(bm, edges=open_edges(), sides=0)
    rest = list({v for e in open_edges() for v in e.verts if v not in keep})
    if rest:
        bmesh.ops.remove_doubles(bm, verts=rest, dist=0.012)
        bmesh.ops.holes_fill(bm, edges=open_edges(), sides=0)
    left = len(open_edges())
    if left:
        print(f"[guerrilla] braço: {left} arestas de borda fora do corte ficaram abertas")


def base_arms(bone_names):
    """Os dois braços prontos: [(bmesh, borda)], borda = vértices do corte em volta do eixo (ordem do anel j do toco,
    th = 0 nas costas), e o material de pele (manga + mão). O objeto do corpo base sai da cena."""
    mesh, J = _base_body()
    mat = _sleeve_texture(mesh)
    skin_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material is mat)
    names = {g.index: g.name for g in mesh.vertex_groups}
    Ub, Fb, Hb = J["upper_arm"], J["forearm"], J["hand"]
    out = []
    for s, k in (("L", 1), ("R", -1)):
        sb = Vector((k * J["shoulder"].x, J["shoulder"].y, J["shoulder"].z))
        axis = S.side(S.ARM_DIR_L, s).normalized()
        joint = S.side(S.SHOULDER_L, s)
        U, F = S.UPPER_ARM_LEN, S.FOREARM_LEN
        bm = bmesh.new()
        bm.from_mesh(mesh.data)
        dl = bm.verts.layers.deform.active
        mine = {bone_names.index(f"{b}_{s}") for b in ("UpperArm", "LowerArm", "Hand")}
        idx = {gi: bone_names.index(nm) for gi, nm in names.items()}
        arm_w = lambda v: sum(x for g, x in v[dl].items() if idx.get(g) in mine)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(arm_w(v) > 0.5 and v.co.x * k > 0 for v in f.verts)],
                         context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        # raio dela por faixa ao longo do braço (para engrossar até a manga medida)
        bins = {}
        for v in bm.verts:
            t = (v.co - sb).dot(axis)
            r = ((v.co - sb) - axis * t).length
            bins.setdefault(round(t / 0.02), []).append(r)
        base_r = {b: sorted(rs)[len(rs) // 2] for b, rs in bins.items()}
        for v in bm.verts:
            rel = v.co - sb
            t = rel.dot(axis)
            radial = rel - axis * t
            if t < Ub:
                tn = t * U / Ub
            elif t < Ub + Fb:
                tn = U + (t - Ub) * F / Fb
            else:
                tn = U + F + (t - Ub - Fb) * HAND_SCALE
            if tn < U + F:
                br = max(base_r.get(round(t / 0.02), 0.035), 0.02)
                f = _sleeve_r(tn) / br
            else:
                f = HAND_SCALE
            v.co = joint + axis * tn + radial * f
        # pesos em índices nossos (os grupos do corpo base já têm os nossos nomes)
        for v in bm.verts:
            old = dict(v[dl])
            for g in list(v[dl].keys()):
                del v[dl][g]
            for g, x in old.items():
                v[dl][idx[g]] = x
        # corte plano a CUT da junta: tudo acima (para o ombro) sai
        res = bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                                     plane_co=joint + axis * CUT, plane_no=axis, clear_inner=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMVert)]
        a, b = ring_frame(axis)
        center = joint + axis * CUT
        ring = sorted(cut, key=lambda v: math.atan2((v.co - center).dot(a), (v.co - center).dot(b)) % (2 * math.pi))
        _close(bm, set(ring))
        for f in bm.faces:
            f.material_index = 2
        out.append((s, bm, ring))
    data = mesh.data
    bpy.data.objects.remove(mesh)
    bpy.data.meshes.remove(data)
    return out, mat
