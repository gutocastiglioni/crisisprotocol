"""Guerrilheiro encapuzado (milícia) construído sobre o modelo base (art/heroine_body.py)
com a parte inferior autêntica (calça cargo militar, bolsos, coldre e coturnos) de tr_guerilla.glb:
  - braços longos (+6.8 cm) alinhados às laterais do tronco;
  - tronco em V com peitoral masculino e moletom reto;
  - calça cargo camuflada autêntica com bolsos traseiros, bolsos laterais e virilha fechada;
  - balaclava preta tática com abertura horizontal limpa para os olhos 3D;
  - capuz tático arredondado sem furos e gola contínua sobre os ombros.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

import guerrilla_atlas
import heroine_body as HB
import heroine_outfit as HO
import heroine_rig
import heroine_spec as S
from heroine_hair import SURF, _surfaces

ART = Path(__file__).resolve().parent
ROOT = ART.parent
TR_PATH = ROOT / "possible_models/tr_guerilla.glb"
TARGET_UPPER_TRIS = 1350
DROP_MATS = ("hair", "hair_2", "eyelash", "holster", "pouch")
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
HEAD_RX, HEAD_RY = 1.08, 1.05


def _pose_male(arm):
    """Pose masculina: ombros naturais alinhados à lateral do tronco e braços longos (+6.8 cm)."""
    old_drop = HB.CLAVICLE_DROP
    HB.CLAVICLE_DROP = math.radians(1.5)
    try:
        HB._pose(arm)
    finally:
        HB.CLAVICLE_DROP = old_drop
    for side, k in (("left", 1), ("right", -1)):
        down = Vector((k * math.sin(S.ARM_SPREAD), 0.0, -math.cos(S.ARM_SPREAD)))
        clav = arm.pose.bones[f"arm {side} shoulder 1"]
        clav.matrix = Matrix.Translation(Vector((k * 0.012, -0.032, 0.0))) @ clav.matrix
        bpy.context.view_layer.update()
        fore = arm.pose.bones[f"arm {side} elbow"]
        fore.matrix = Matrix.Translation(down * 0.033) @ fore.matrix
        bpy.context.view_layer.update()
        hand = arm.pose.bones[f"arm {side} wrist"]
        hand.matrix = Matrix.Translation(down * 0.035) @ hand.matrix
        bpy.context.view_layer.update()


def _drop_extras(mesh, joints):
    """Remove cabelos, cílios, bolsas femininas e toda a metade inferior da malha feminina."""
    hip_z = joints["hip"].z
    drop = {i for i, sl in enumerate(mesh.material_slots) if sl.material.name.removeprefix("Body_") in DROP_MATS}
    costume_idx = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_costume")
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in drop], context="FACES")
    
    # Remove as partes desconectadas de costume mantendo o tronco
    c_faces = [f for f in bm.faces if f.material_index == costume_idx]
    seen, comps = set(), []
    for f in c_faces:
        if f in seen:
            continue
        q, comp = [f], []
        seen.add(f)
        while q:
            cur = q.pop()
            comp.append(cur)
            for v in cur.verts:
                for lf in v.link_faces:
                    if lf.material_index == costume_idx and lf not in seen:
                        seen.add(lf)
                        q.append(lf)
        comps.append(comp)
    if len(comps) > 1:
        main_comp = set(max(comps, key=len))
        bmesh.ops.delete(bm, geom=[f for f in c_faces if f not in main_comp], context="FACES")
        
    # Remove toda a parte inferior feminina abaixo da bainha do moletom
    lower_faces = [f for f in bm.faces if all(v.co.z < hip_z - 0.045 for v in f.verts)]
    bmesh.ops.delete(bm, geom=lower_faces, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()

    for sl in mesh.material_slots:
        if sl.material and sl.material.name == "Body_eye":
            node = next(n for n in sl.material.node_tree.nodes if n.type == "TEX_IMAGE")
            img = bpy.data.images.load(str(HB.SRC / "eye.png"))
            img.pack()
            node.image = img


def _male_torso_section(z, hip_z, neck_z):
    """Seção transversal masculina: cintura reta, dorsal em V e trapézio suave."""
    u = (z - hip_z) / max(neck_z - hip_z, 1e-4)
    hem = 1.0 / (1.0 + math.exp(-(z - (hip_z - 0.085)) / 0.006))
    v_taper = min(1.0, max(0.0, (u + 0.05) / 0.68))
    trap_slope = 1.0 / (1.0 + math.exp((u - 0.78) / 0.075))
    rx = (0.162 + 0.014 * hem + 0.022 * v_taper) * trap_slope + 0.078 * (1.0 - trap_slope)
    pec = math.exp(-((u - 0.62) / 0.24) ** 2)
    ry_f = (0.104 + 0.012 * hem + 0.020 * pec) * trap_slope + 0.074 * (1.0 - trap_slope)
    upper_back = math.exp(-((u - 0.66) / 0.28) ** 2)
    ry_b = (0.098 + 0.008 * hem + 0.018 * upper_back) * trap_slope + 0.074 * (1.0 - trap_slope)
    yc = -0.005 * hem
    return yc, rx, ry_f, ry_b


def _reshape_male(mesh, joints):
    """Remodela tronco superior para homem: ombros naturais, peitoral em V, braços longos e nuca protegida."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    hip_z = joints["hip"].z
    neck_z, head_z = joints["torso"]["Neck"][0].z, joints["torso"]["Head"][0].z
    me = mesh.data

    for v in me.vertices:
        w = {names[g.group]: g.weight for g in v.groups if g.weight > 0 and g.group in names}
        p = v.co.copy()

        # 1. tronco masculino em V suave
        wt = w.get("Hips", 0.0) + w.get("Spine", 0.0) + w.get("Chest", 0.0)
        if wt > 0.02 and p.z >= hip_z - 0.08 and p.z <= neck_z + 0.04:
            yc, rx, ry_f, ry_b = _male_torso_section(p.z, hip_z, neck_z)
            dx, dy = p.x, p.y - yc
            th = math.atan2(dx, dy)
            sx, cy = math.sin(th), math.cos(th)
            ry = ry_f if cy < 0 else ry_b
            denom = (abs(sx) / max(rx, 1e-4)) ** 2.15 + (abs(cy) / max(ry, 1e-4)) ** 2.15
            rad = (1.0 / max(denom, 1e-6)) ** (1.0 / 2.15)
            alpha = min(1.0, wt * 1.05)
            p.x = p.x + (sx * rad - p.x) * alpha
            p.y = p.y + ((yc + cy * rad) - p.y) * alpha

        # 2. cabeça/pescoço: retração da nuca/crânio para folga total do capuz
        wh, wn = w.get("Head", 0.0), w.get("Neck", 0.0)
        if wh + wn > 0.05 and p.z > neck_z:
            alpha = min(1.0, (wh + wn) * 1.1)
            p.x *= (1.0 - 0.03 * alpha)
            if p.y > 0.0:
                p.y *= (1.0 - 0.16 * alpha)
            else:
                p.y *= (1.0 - 0.02 * alpha)

        # 3. braços masculinos: alinhamento lateral
        wa_l = sum(w.get(f"{b}_L", 0.0) for b in ("UpperArm", "LowerArm", "Hand"))
        wa_r = sum(w.get(f"{b}_R", 0.0) for b in ("UpperArm", "LowerArm", "Hand"))
        if wa_l > 0.02:
            p.y += -0.018 * wa_l
            p.x += 0.008 * wa_l
        elif wa_r > 0.02:
            p.y += -0.018 * wa_r
            p.x += -0.008 * wa_r

        v.co = p


def _guerrilla_texture(mesh, joints):
    """Textura escura tática do moletom e mangas."""
    import numpy as np

    dark_hoodie = np.array([32 / 255.0, 32 / 255.0, 34 / 255.0], dtype=np.float32)
    sleeve_col = np.array([36 / 255.0, 36 / 255.0, 38 / 255.0], dtype=np.float32)

    for key, base_col in (("costume", dark_hoodie), ("skin", sleeve_col)):
        slot_idx = next((i for i, sl in enumerate(mesh.material_slots) if sl.material and sl.material.name == f"Body_{key}"), None)
        if slot_idx is None:
            continue
        node = next((n for n in mesh.material_slots[slot_idx].material.node_tree.nodes if n.type == "TEX_IMAGE"), None)
        if not node or not node.image:
            continue
        img = node.image
        w, h = img.size
        src = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
        lum = src[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        mean = max(float(lum.mean()), 1e-3)
        shade = np.clip(0.85 + 0.35 * (lum - mean) / mean, 0.70, 1.25)[..., None]
        out = src.copy()
        out[..., :3] = np.clip(base_col * shade, 0.0, 1.0)
        new = bpy.data.images.new(f"tex_{key}_guerrilla", w, h, alpha=True)
        new.pixels = out.ravel().tolist()
        new.pack()
        node.image = new


def _paint_balaclava_face(mesh):
    """Balaclava preta tática cobrindo boca e queixo, com fresta limpa para os olhos 3D reais."""
    import numpy as np

    me = mesh.data
    uvl = me.uv_layers.active.data
    eye_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_eye")
    face_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_face")
    eye_verts = [me.vertices[vi].co for p in me.polygons if p.material_index == eye_slot for vi in p.vertices]
    el, er = [v for v in eye_verts if v.x > 0], [v for v in eye_verts if v.x < 0]
    eye_l = sum(el, Vector()) / max(len(el), 1)

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

    rim_col = np.array([48 / 255.0, 48 / 255.0, 54 / 255.0], dtype=np.float32)
    male_skin = np.array([156 / 255.0, 114 / 255.0, 88 / 255.0], dtype=np.float32)
    male_brow = np.array([32 / 255.0, 24 / 255.0, 20 / 255.0], dtype=np.float32)

    for tri in me.loop_triangles:
        if tri.material_index != face_slot:
            continue
        P = [me.vertices[vi].co.copy() for vi in tri.vertices]
        if min(p.y for p in P) > eye_l.y + 0.025:
            continue
        raw = np.array([[uvl[li].uv.x, uvl[li].uv.y] for li in tri.loops])
        pts = (raw - np.floor(raw.mean(axis=0))) * np.array([w, h])
        x0, y0 = np.floor(pts.min(axis=0)).astype(int)
        x1, y1 = np.ceil(pts.max(axis=0)).astype(int)
        (ax, ay), (bx, by), (cx, cy) = pts
        dd = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(dd) < 1e-9:
            continue
        for py in range(max(y0, 0), min(y1, h - 1) + 1):
            for px in range(max(x0, 0), min(x1, w - 1) + 1):
                xs, ys = px + 0.5, py + 0.5
                l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / dd
                l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / dd
                l3 = 1 - l1 - l2
                if l1 < -0.02 or l2 < -0.02 or l3 < -0.02:
                    continue
                q = P[0] * l1 + P[1] * l2 + P[2] * l3
                if q.y > eye_l.y + 0.018:
                    continue
                slit_x = abs(q.x) / 0.046
                slit_z = (q.z - eye_l.z) / (0.015 if q.z >= eye_l.z else 0.011)
                de = math.hypot(slit_x, slit_z)
                if de < 1.0:
                    sh_f = float(np.clip(0.75 + 0.40 * lum[py, px], 0.55, 1.10))
                    is_brow = q.z > eye_l.z + 0.005 and abs(q.x) > 0.010
                    out[py, px, :3] = male_brow if is_brow else np.clip(male_skin * sh_f, 0.0, 1.0)
                elif de < 1.25:
                    out[py, px, :3] = np.clip(rim_col * shade[py, px], 0.0, 1.0)

    new = bpy.data.images.new("face_guerrilla", w, h, alpha=True)
    new.pixels = out.ravel().tolist()
    new.pack()
    node.image = new


def _import_tr_lower(joints):
    """Importa calça cargo camuflada, bolsos, cinto, coldre e coturnos de tr_guerilla.glb."""
    bpy.ops.import_scene.gltf(filepath=str(TR_PATH))
    tr_obj = next(o for o in bpy.context.selected_objects if o.type == "MESH")
    mw = tr_obj.matrix_world.copy()

    bm = bmesh.new()
    bm.from_mesh(tr_obj.data)
    for v in bm.verts:
        v.co = mw @ v.co

    islands, vis = [], set()
    for f in bm.faces:
        if f in vis:
            continue
        isl = []
        q = [f]
        vis.add(f)
        while q:
            cur = q.pop()
            isl.append(cur)
            for e in cur.edges:
                for lf in e.link_faces:
                    if lf not in vis:
                        vis.add(lf)
                        q.append(lf)
        islands.append(isl)

    # Ilhas de interesse: coturnos, calça, cinto, fivela, bolsos traseiros, bolsos cargo, braguilha e coldre
    target_islands = {4, 5, 6, 7, 8, 9, 10, 11, 12, 17, 19, 21, 22, 40, 41, 42, 46, 57}
    keep_faces = set()
    for idx in target_islands:
        keep_faces.update(islands[idx])

    delete_faces = [f for f in bm.faces if f not in keep_faces]
    bmesh.ops.delete(bm, geom=delete_faces, context="FACES")

    # Remove qualquer fragmento residual de manga/ombro
    stray = [f for f in bm.faces if any(v.co.z > 46.5 or (v.co.z > 43.5 and abs(v.co.x) > 9.8) for v in f.verts)]
    bmesh.ops.delete(bm, geom=stray, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

    hip_z = joints["hip"].z
    knee_z = joints["knee"].z
    ankle_z = joints["ankle"].z

    zs = [v.co.z for v in bm.verts]
    min_z, belt_z = min(zs), 45.70
    target_top = hip_z - 0.045
    scale = target_top / (belt_z - min_z)

    for v in bm.verts:
        v.co.z = (v.co.z - min_z) * scale
        v.co.x = v.co.x * scale
        v.co.y = (v.co.y + 0.6) * scale

    me_lower = bpy.data.meshes.new("LowerPartMesh")
    bm.to_mesh(me_lower)
    bm.free()

    if me_lower.uv_layers:
        me_lower.uv_layers[0].name = "UV1"

    obj_lower = bpy.data.objects.new("LowerPart", me_lower)
    bpy.context.scene.collection.objects.link(obj_lower)

    pants_mat = tr_obj.material_slots[0].material
    pants_mat.name = "Body_pants"
    me_lower.materials.append(pants_mat)

    bpy.data.objects.remove(tr_obj)
    for o in list(bpy.context.scene.objects):
        if o.name.startswith("Sketchfab") or o.name.startswith("asdasd"):
            bpy.data.objects.remove(o)

    # Criação dos vertex groups para a armação
    for gname in ("Hips", "Spine", "UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R"):
        obj_lower.vertex_groups.new(name=gname)
    vg = {g.name: g for g in obj_lower.vertex_groups}

    for v in me_lower.vertices:
        p = v.co
        side = "_L" if p.x >= 0 else "_R"
        opp_side = "_R" if p.x >= 0 else "_L"
        x_blend = min(1.0, max(0.0, abs(p.x) / 0.03))

        if p.z < ankle_z + 0.05:
            vg[f"Foot{side}"].add([v.index], 1.0, "REPLACE")
        elif p.z < ankle_z + 0.12:
            t = (p.z - (ankle_z + 0.05)) / 0.07
            vg[f"Foot{side}"].add([v.index], 1.0 - t, "REPLACE")
            vg[f"LowerLeg{side}"].add([v.index], t, "REPLACE")
        elif p.z < knee_z - 0.06:
            vg[f"LowerLeg{side}"].add([v.index], 1.0, "REPLACE")
        elif p.z < knee_z + 0.06:
            t = (p.z - (knee_z - 0.06)) / 0.12
            vg[f"LowerLeg{side}"].add([v.index], 1.0 - t, "REPLACE")
            vg[f"UpperLeg{side}"].add([v.index], t, "REPLACE")
        elif p.z < hip_z - 0.18:
            w_main = 0.5 + 0.5 * x_blend
            w_opp = 0.5 - 0.5 * x_blend
            vg[f"UpperLeg{side}"].add([v.index], w_main, "REPLACE")
            if w_opp > 0.01:
                vg[f"UpperLeg{opp_side}"].add([v.index], w_opp, "REPLACE")
        elif p.z < hip_z - 0.08:
            t = (p.z - (hip_z - 0.18)) / 0.10
            w_hip = t
            w_leg = 1.0 - t
            vg["Hips"].add([v.index], w_hip, "REPLACE")
            w_main = w_leg * (0.5 + 0.5 * x_blend)
            w_opp = w_leg * (0.5 - 0.5 * x_blend)
            vg[f"UpperLeg{side}"].add([v.index], w_main, "REPLACE")
            if w_opp > 0.01:
                vg[f"UpperLeg{opp_side}"].add([v.index], w_opp, "REPLACE")
        else:
            if p.z > hip_z - 0.03:
                t_sp = min(0.30, (p.z - (hip_z - 0.03)) / 0.02 * 0.30)
                vg["Hips"].add([v.index], 1.0 - t_sp, "REPLACE")
                vg["Spine"].add([v.index], t_sp, "REPLACE")
            else:
                vg["Hips"].add([v.index], 1.0, "REPLACE")

    return obj_lower


from guerrilla_props import make_boots, make_gear, make_hood  # noqa: F401


def adapt_anims(anims):
    """Adaptação das poses de animação para a postura de combate masculina."""
    anims.RUN_LEAN = 7
    anims.RUN_BODY = dict(anims.RUN_BODY, **{
        "Spine": (8, 0, 0), "Chest": (4, 0, 0), "Neck": (-4, 0, 0), "Head": (-8, 0, 0),
    })
    anims.RUN_HALF = [
        (f, ((loc[0] * 0.40, loc[1], loc[2]), (hips[0] * 0.70, hips[1] * 0.45), spine, chest, head, leg_l, leg_r,
             (arm_l[0], arm_l[1] + 2, arm_l[2]), (arm_r[0], arm_r[1] + 2, arm_r[2])))
        for f, (loc, hips, spine, chest, head, leg_l, leg_r, arm_l, arm_r) in anims.RUN_HALF
    ]
    anims.HIT = dict(anims.HIT, **{
        "Spine": (-10, -4, 0), "Chest": (-16, 8, -3), "Head": (-24, 6, 0),
        "UpperArm_L": (-16, 0, 18), "LowerArm_L": (14, 0, 0), "UpperArm_R": (-20, 0, 10),
    })


def prepare():
    """Importa tronco masculino de Mesh.fbx e calça/coturnos de tr_guerilla.glb, unindo em malha única."""
    bpy.ops.import_scene.fbx(filepath=str(HB.SRC / "Mesh.fbx"))
    arm = next(o for o in bpy.context.selected_objects if o.type == "ARMATURE")
    mesh = next(o for o in bpy.context.selected_objects if o.type == "MESH")
    mesh.name = "Guerrilla"
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
    _pose_male(arm)
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
    ground = min(v.co.z for v in mesh.data.vertices)
    shift = Vector((0.0, -joints["hip"].y, -ground))
    mesh.data.transform(Matrix.Translation(shift))
    for k in ("shoulder", "hip", "knee", "ankle", "toe"):
        joints[k] = joints[k] + shift
    joints["torso"] = {k: (h + shift, t + shift) for k, (h, t) in joints["torso"].items()}

    HB._merge_groups(mesh)
    HO._flat_straps(mesh, joints)
    _drop_extras(mesh, joints)
    _reshape_male(mesh, joints)
    _paint_balaclava_face(mesh)
    _guerrilla_texture(mesh, joints)

    # Redução poligonal do tronco superior para manter orçamento PS2
    old_target = HB.TARGET_TRIS
    HB.TARGET_TRIS = TARGET_UPPER_TRIS
    try:
        HB._decimate(mesh)
    finally:
        HB.TARGET_TRIS = old_target

    # Importação e fusão da parte inferior de tr_guerilla.glb
    obj_lower = _import_tr_lower(joints)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    obj_lower.select_set(True)
    bpy.ops.object.join()

    _surfaces(mesh)
    for p in mesh.data.polygons:
        p.use_smooth = True
    return mesh, joints
