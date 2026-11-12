"""Leitura do raptor de referência para o build (`build_raptor.py`): o modelo no nosso espaço, a malha deformada até o
repouso com os pesos nos ossos novos, a redução de triângulos e o esqueleto com os nossos nomes.

Fonte: "PBR Velociraptor (Animated)" de Ferocious Industries, CC BY 4.0, em `possible_models/velocirraptor/` (fora do git).
"""
import math
import re
from pathlib import Path
from types import SimpleNamespace

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
REF_DIR = ROOT / "possible_models/velocirraptor"
REF_GLB = REF_DIR / "pbr_velociraptor_animated.glb"
REF_ZIP = REF_DIR / "pbr_velociraptor_animated.zip"
HIP_H = 0.93  # altura do quadril (o raptor de antes): o resto escala junto
HIP_Y = 0.05

SIDED = {"Eye": "Eye", "Shoulder": "Shoulder", "UpperArm": "Arm", "LowerArm": "Forearm", "Hand": "Hand",
         "Breast": "Breast", "Pelvis": "Pelvis", "Hip": "Hip", "UpperLeg": "Thigh", "LowerLeg": "Shin", "Ankle": "Meta",
         "Foot": "Toe", "Thigh": "ThighFlesh"}
DIGITS = {"ForeFinger": "FingerA", "MiddleFinger": "FingerB", "PinkyFinger": "FingerC",
          "BigToe": "ToeA", "MiddleToe": "ToeB", "PinkyToe": "ToeC"}
CENTER = {"Spine_1": "Hips", "Spine_2": "Spine", "Spine_3": "Chest", "Neck_1": "Neck1", "Neck_2": "Neck2",
          "Neck_3": "Neck3", "Head": "Head", "Jaw_1": "Jaw", "Jaw_2": "Jaw2"}


def base_name(n):
    head, _, tail = n.rpartition("_")
    return head if tail.isdigit() and head else n


def our_name(base, swap):
    """Nome no nosso esqueleto (None = osso de controle, sai)."""
    if "IK" in base or base.endswith("_end") or base in ("Root", "_rootJoint"):
        return None
    if base in CENTER:
        return CENTER[base]
    m = re.fullmatch(r"(Tail|Tongue)_(\d+)", base)
    if m:
        return m.group(1) + m.group(2)
    m = re.fullmatch(r"([A-Za-z]+?)(\d?)\.(L|R)", base)
    if not m:
        return None
    word, num, side = m.groups()
    if swap:
        side = "R" if side == "L" else "L"
    if word in DIGITS:
        return f"{DIGITS[word]}{num}_{side}"
    if word in SIDED and not num:
        return f"{SIDED[word]}_{side}"
    return None


HOME = {}  # objetos da referência como vieram (algumas animações dela movem o objeto e isso ficava para as próximas)


def set_action(arm, name):
    for o, m in HOME.items():
        o.matrix_basis = m
    act = bpy.data.actions[name]
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    return act


def goto(scene, frame):
    i = math.floor(frame)
    scene.frame_set(i, subframe=frame - i)


def clean(m):
    loc, rot, _ = m.decompose()
    return Matrix.LocRotScale(loc, rot, None)


# ------------------------------------------------------------------ referência no nosso espaço
def load_reference():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(REF_GLB))
    for o in list(bpy.data.objects):
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.animation_data_create()
    meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    HOME.update({o: o.matrix_basis.copy() for o in bpy.data.objects if o.type != "MESH"})
    return arm, meshes


def to_ours(arm, meshes, scene):
    """Matriz que leva a referência (no quadro de descanso) ao nosso espaço: quadril na origem a HIP_H, frente -Y."""
    pb = {base_name(b.name): b for b in arm.pose.bones}
    hips = arm.matrix_world @ pb["Spine_1"].head
    chest = arm.matrix_world @ pb["Spine_3"].head
    dg = bpy.context.evaluated_depsgraph_get()
    ev = meshes["0"].evaluated_get(dg)
    ground = min((ev.matrix_world @ v.co).z for v in ev.to_mesh().vertices)
    ev.to_mesh_clear()
    f = (chest - hips).xy.normalized()
    yaw = math.atan2(-1.0, 0.0) - math.atan2(f.y, f.x)
    s = HIP_H / (hips.z - ground)
    return (Matrix.Translation((0, HIP_Y, 0)) @ Matrix.Scale(s, 4) @ Matrix.Rotation(yaw, 4, "Z")
            @ Matrix.Translation((-hips.x, -hips.y, -ground))), s


def bone_table(arm, C):
    """Ossos que ficam: nome nosso -> (osso dele, pai nosso, matriz no descanso). Decide se L/R troca de lado."""
    pose = {b.name: b for b in arm.pose.bones}
    up_l = next(b for b in arm.pose.bones if base_name(b.name) == "UpperLeg.L")
    swap = (C @ arm.matrix_world @ up_l.head).x < 0
    keep, owner = {}, {}
    order = sorted(arm.data.bones, key=lambda b: len(b.parent_recursive))
    for b in order:
        new = our_name(base_name(b.name), swap)
        parent = next((owner[p.name] for p in b.parent_recursive if owner.get(p.name)), None)
        if new:
            keep[new] = SimpleNamespace(src=pose[b.name], parent=parent, M=C @ arm.matrix_world @ pose[b.name].matrix)
            owner[b.name] = new
        else:
            owner[b.name] = parent  # peso de osso que sai vai para o pai que fica
    return keep, owner


# ------------------------------------------------------------------ malha
def rest_mesh(src, C, owner, scene):
    """Cópia da malha deformada no quadro de descanso, no nosso espaço, com os pesos nos ossos novos."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = src.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    me.transform(C @ ev.matrix_world)
    me.update()
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    me.materials.clear()
    names = [g.name for g in src.vertex_groups]
    obj = bpy.data.objects.new("Raptor" + src.name, me)
    bpy.context.scene.collection.objects.link(obj)
    weights = []
    for v in me.vertices:
        acc = {}
        for g in v.groups:
            if g.weight <= 0:
                continue
            new = owner.get(names[g.group]) or "Hips"
            acc[new] = acc.get(new, 0.0) + g.weight
        weights.append(acc)
    # o mesh copiado traz os pesos nos grupos antigos (por índice): troca pelos novos
    me_groups = sorted({n for acc in weights for n in acc})
    for n in me_groups:
        obj.vertex_groups.new(name=n)
    bm = bmesh.new()
    bm.from_mesh(me)
    dl = bm.verts.layers.deform.verify()
    idx = {n: obj.vertex_groups[n].index for n in me_groups}
    for v, acc in zip(bm.verts, weights):
        v[dl].clear()
        total = sum(acc.values()) or 1.0
        for n, w in acc.items():
            v[dl][idx[n]] = w / total
    bm.to_mesh(me)
    bm.free()
    return obj, weights


def decimate(obj, target):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= target:
        return
    mod = obj.modifiers.new("Reduce", "DECIMATE")
    mod.ratio = target / tris
    mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    obj.modifiers.remove(mod)
    old = obj.data
    obj.data = me
    bpy.data.meshes.remove(old)


# ------------------------------------------------------------------ esqueleto
def chain_next(name):
    m = re.fullmatch(r"([A-Za-z]+?)(\d+)(_[LR])?", name)
    side = name[-2:] if name[-2:] in ("_L", "_R") else ""
    fixed = {"Hips": "Spine", "Spine": "Chest", "Chest": "Neck1", "Neck1": "Neck2", "Neck2": "Neck3", "Neck3": "Head",
             "Jaw": "Jaw2"}
    if name in fixed:
        return fixed[name]
    sided = {"Shoulder": "Arm", "Arm": "Forearm", "Forearm": "Hand", "Hand": "FingerB1", "Pelvis": "Hip", "Hip": "Thigh",
             "Thigh": "Shin", "Shin": "Meta", "Meta": "Toe"}
    stem = name[:-2] if side else name
    if stem in sided:
        return sided[stem] + side
    if m:
        word, num, _ = m.groups()
        return f"{word}{int(num) + 1}{side}"
    return None


def weighted_points(objs_weights, name, wmin=0.4):
    pts = []
    for obj, weights in objs_weights:
        for v, acc in zip(obj.data.vertices, weights):
            if acc.get(name, 0.0) >= wmin * (sum(acc.values()) or 1):
                pts.append(Vector(v.co))
    return pts


def build_rig(keep, objs_weights):
    data = bpy.data.armatures.new("RaptorRig")
    rig = bpy.data.objects.new("RaptorRig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    tails = {}
    for name, info in keep.items():
        head = info.M.translation
        rot = info.M.to_3x3().normalized()
        ydir, zdir = rot @ Vector((0, 1, 0)), rot @ Vector((0, 0, 1))
        nxt = chain_next(name)
        tail = None
        if name == "Head":
            pts = weighted_points(objs_weights, "Head")
            tail = min(pts, key=lambda p: p.y)  # ponta do focinho
        elif name.startswith("Toe_"):
            pts = weighted_points(objs_weights, "ToeB2" + name[-2:], 0.3)
            tail = max(pts, key=lambda p: (p - head).length)  # ponta da garra do dedo do meio
        elif nxt in keep and (keep[nxt].M.translation - head).length > 0.005:
            tail = keep[nxt].M.translation
        if tail is None:
            pts = weighted_points(objs_weights, name, 0.3)
            reach = max([(p - head).dot(ydir) for p in pts] + [0.0])
            tail = head + ydir * max(reach, 0.02)
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        eb.align_roll(zdir)
        tails[name] = tail
    for name, info in keep.items():
        if info.parent:
            data.edit_bones[name].parent = data.edit_bones[info.parent]
            data.edit_bones[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return rig
