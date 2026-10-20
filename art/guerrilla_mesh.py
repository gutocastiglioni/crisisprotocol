import heroine_mesh as M
"""Guerrilheiro encapuzado (milícia) construído sobre o modelo base em art/base_body/ (art/heroine_body.py):
mesmo esqueleto adaptado às juntas reais (heroine_spec.use_joints) e mesmas animações da heroína, mas com o corpo
remodelado para anatomia masculina e roupa tática folgada:
  - braços longos (+6.8 cm) alinhados às laterais do tronco (sem sobrepor as costas);
  - tronco em V com peitoral masculino e moletom reto;
  - nádegas masculinas anatômicas sob a calça cargo e cavalo baixo com braguilha reta;
  - balaclava preta tática cobrindo boca e queixo com abertura horizontal limpa para os olhos 3D;
  - capuz tático arredondado sem furos, com arco suave na testa e gola contínua sobre os ombros.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

import guerrilla_atlas
import guerrilla_legacy
import heroine_body as HB
import heroine_outfit as HO
import heroine_rig
import heroine_spec as S
from heroine_hair import SURF, _surfaces

ART = Path(__file__).resolve().parent
ATLAS_PATH = ART.parent / "game/assets/characters/guerrilla_atlas.png"
TARGET_TRIS = 2750
DROP_MATS = ("hair", "hair_2", "eyelash", "holster", "pouch")
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
HEAD_RX, HEAD_RY = 1.08, 1.05


def _pose_male(arm):
    """Pose masculina: ombros naturais alinhados à lateral do tronco (sem sobrepor costas) e braços longos (+6.8 cm)."""
    old_drop = HB.CLAVICLE_DROP
    HB.CLAVICLE_DROP = math.radians(1.5)
    try:
        HB._pose(arm)
    finally:
        HB.CLAVICLE_DROP = old_drop
    for side, k in (("left", 1), ("right", -1)):
        down = Vector((k * math.sin(S.ARM_SPREAD), 0.0, -math.cos(S.ARM_SPREAD)))
        clav = arm.pose.bones[f"arm {side} shoulder 1"]
        # desloca o ombro levemente para frente em Y para não sobrepor o dorso nas costas
        clav.matrix = Matrix.Translation(Vector((k * 0.012, -0.032, 0.0))) @ clav.matrix
        bpy.context.view_layer.update()
        fore = arm.pose.bones[f"arm {side} elbow"]
        fore.matrix = Matrix.Translation(down * 0.033) @ fore.matrix
        bpy.context.view_layer.update()
        hand = arm.pose.bones[f"arm {side} wrist"]
        hand.matrix = Matrix.Translation(down * 0.035) @ hand.matrix
        bpy.context.view_layer.update()


def _drop_extras(mesh, joints):
    """Remove cabelos, cílios, coldre/tiras, bolsas e a parte inferior do macaquinho feminino (eliminando a fralda)."""
    hip_z = joints["hip"].z
    drop = {i for i, sl in enumerate(mesh.material_slots) if sl.material.name.removeprefix("Body_") in DROP_MATS}
    costume_idx = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_costume")
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in drop], context="FACES")
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
    # Remove as faces inferiores do macaquinho (abaixo de hip_z - 0.055)
    # eliminando o recorte em V de fralda/calcinha e deixando a calça contínua
    low_costume = [f for f in bm.faces if f.material_index == costume_idx and all(v.co.z < hip_z - 0.055 for v in f.verts)]
    bmesh.ops.delete(bm, geom=low_costume, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()
    for sl in mesh.material_slots:
        if sl.material and sl.material.name == "Body_eye":
            node = next(n for n in sl.material.node_tree.nodes if n.type == "TEX_IMAGE")
            img = bpy.data.images.load(str(HB.SRC / "eye.png"))
            img.pack()
            node.image = img
    order = ("skin", "costume", "face", "eye")
    mats = {sl.material.name.removeprefix("Body_"): sl.material for sl in mesh.material_slots if sl.material}
    old_names = {i: sl.material.name.removeprefix("Body_") for i, sl in enumerate(mesh.material_slots)}
    new_idx = {k: i for i, k in enumerate(order)}
    poly_mats = [new_idx.get(old_names.get(p.material_index, "skin"), 0) for p in mesh.data.polygons]
    mesh.data.materials.clear()
    for k in order:
        mesh.data.materials.append(mats[k])
    for p, mi in zip(mesh.data.polygons, poly_mats):
        p.material_index = mi


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
    """Remodela para homem: ombros naturais, nádegas masculinas, calça cargo larga e cabeça protegida."""
    her = HO._her_bones(joints)
    names = {g.index: g.name for g in mesh.vertex_groups}
    hip_z, knee_z = joints["hip"].z, joints["knee"].z
    sh_z = joints["shoulder"].z
    neck_z, head_z = joints["torso"]["Neck"][0].z, joints["torso"]["Head"][0].z
    w_len = joints["upper_arm"] + joints["forearm"]
    me = mesh.data
    eye_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_eye")
    eye_zs = [me.vertices[vi].co.z for p in me.polygons if p.material_index == eye_slot for vi in p.vertices]
    eye_z = sum(eye_zs) / max(len(eye_zs), 1)

    for v in me.vertices:
        w = {names[g.group]: g.weight for g in v.groups if g.weight > 0 and g.group in names}
        p = v.co.copy()

        # 1. tronco masculino em V suave
        wt = w.get("Hips", 0.0) + w.get("Spine", 0.0) + w.get("Chest", 0.0)
        wa_tot = sum(w.get(f"{b}_{s}", 0.0) for b in ("UpperArm", "LowerArm", "Hand") for s in ("L", "R"))
        wl_tot = sum(w.get(f"{b}_{s}", 0.0) for b in ("UpperLeg", "LowerLeg", "Foot") for s in ("L", "R"))
        if wt > 0.02 and p.z >= hip_z - 0.14 and p.z <= neck_z + 0.04:
            yc, rx, ry_f, ry_b = _male_torso_section(p.z, hip_z, neck_z)
            dx, dy = p.x, p.y - yc
            th = math.atan2(dx, dy)
            sx, cy = math.sin(th), math.cos(th)
            ry = ry_f if cy < 0 else ry_b
            denom = (abs(sx) / max(rx, 1e-4)) ** 2.15 + (abs(cy) / max(ry, 1e-4)) ** 2.15
            r_env = denom ** (-1.0 / 2.15) if denom > 1e-8 else rx
            tx, ty = r_env * sx, yc + r_env * cy
            crotch_fade = min(1.0, max(0.0, (p.z - (hip_z - 0.13)) / 0.05))
            top_fade = 1.0 / (1.0 + math.exp((p.z - (neck_z - 0.01)) / 0.018))
            arm_fade = min(1.0, max(0.0, 1.0 - wa_tot * 1.15))
            alpha = min(1.0, wt * 1.1) * crotch_fade * top_fade * arm_fade * (1.0 - 0.5 * wl_tot)
            p.x = p.x + (tx - p.x) * alpha
            p.y = p.y + (ty - p.y) * alpha

        # 2. quadril masculino: largura atlética e robusta da referência tr_guerilla.glb
        if hip_z - 0.18 < p.z < hip_z + 0.06:
            # Mantém a largura plena do quadril masculino (sem estreitar os trocanteres)
            pass

        # 3. cabeça/pescoço: retração da nuca/crânio para folga total do capuz
        wh, wn = w.get("Head", 0.0), w.get("Neck", 0.0)
        if wh > 0.01 or wn > 0.01:
            yc = -0.010 if p.z > head_z else -0.005
            if p.y < yc - 0.015:
                jaw = wh * max(0.0, min(1.0, (eye_z - p.z) / 0.065)) * max(0.0, 1.0 - abs(p.z - (eye_z - 0.04)) / 0.06)
                p.x *= 1.0 + wh * (HEAD_RX - 1.0 + 0.18 * jaw) + wn * 0.14
                p.y = yc + (p.y - yc) * (1.0 + wh * (HEAD_RY - 1.0 + 0.10 * jaw) + wn * 0.12)
                if wh > 0.5 and p.y < yc - 0.04:
                    brow = math.exp(-((p.z - (eye_z + 0.016)) / 0.014) ** 2) * math.exp(-((p.x) / 0.055) ** 2)
                    p.y -= 0.007 * brow
                    p.z -= 0.003 * brow
            else:
                p.x *= 0.90
                p.y = yc + (p.y - yc) * 0.90

        # 4. braços masculinos: mangas de moletom posicionadas na lateral do corpo
        for s, k in (("L", 1), ("R", -1)):
            wa = w.get(f"UpperArm_{s}", 0.0) + w.get(f"LowerArm_{s}", 0.0) + w.get(f"Hand_{s}", 0.0)
            w_delt = wa + (w.get("Chest", 0.0) if k * p.x > 0.11 and p.z > sh_z - 0.10 else 0.0)
            if w_delt > 0.02:
                sh, ht = her[f"UpperArm_{s}"][0], her[f"Hand_{s}"][1]
                u_dir = (ht - sh).normalized()
                d_along = (p - sh).dot(u_dir)
                if -0.045 <= d_along <= w_len:
                    axis = sh + u_dir * max(0.0, d_along)
                    rad = p - axis
                    r_cur = rad.length
                    if r_cur > 1e-5:
                        t = min(1.0, max(0.0, d_along / max(w_len, 1e-4)))
                        cuff = math.exp(-((t - 0.96) / 0.05) ** 2)
                        r_want = 0.064 * (1.0 - 0.16 * t) + 0.006 * math.sin(math.pi * t) - 0.014 * cuff
                        blend = min(1.0, wa * 1.15) if d_along >= 0.0 else min(1.0, wa * 1.1) * max(0.0, 1.0 + d_along / 0.045)
                        r_new = r_cur + (max(r_cur * 1.10, r_want) - r_cur) * blend
                        p_new = axis + rad * (r_new / r_cur)
                        # não permite que a manga avance sobre as costas além de y = 0.075
                        if p_new.y > 0.075 and d_along < 0.18:
                            p_new.y = 0.075 + (p_new.y - 0.075) * 0.35
                        p = p_new
                elif d_along > w_len and wa > 0.01:
                    axis = sh + u_dir * d_along
                    rad = p - axis
                    p = axis + u_dir * ((d_along - w_len) * 0.14 * wa) + rad * (1.0 + 0.28 * wa)

        # 5. pernas: calça cargo larga (baggy) com virilha e entrepernas calibrados por tr_guerilla.glb
        for s, k in (("L", 1), ("R", -1)):
            wl = w.get(f"UpperLeg_{s}", 0.0) + w.get(f"LowerLeg_{s}", 0.0)
            if (wl > 0.01 or (wt > 0.01 and p.z < hip_z - 0.02 and k * p.x >= -0.002)) and p.z < hip_z - 0.01 and k * p.x >= -0.008:
                h0, k0 = her[f"UpperLeg_{s}"]
                _, a0 = her[f"LowerLeg_{s}"]
                leg_x = k * (abs(h0.x) * 0.94)
                if p.z >= knee_z:
                    f = min(1.0, max(0.0, (h0.z - p.z) / max(h0.z - k0.z, 1e-4)))
                    cy = h0.lerp(k0, f).y * 0.35
                    rx_w, ry_w = 0.118 - 0.008 * f, 0.124 - 0.008 * f
                else:
                    f = min(1.0, max(0.0, (k0.z - p.z) / max(k0.z - a0.z, 1e-4)))
                    cy = k0.lerp(a0, f).y * 0.45
                    blouse = math.exp(-((p.z - 0.225) / 0.032) ** 2)
                    tuck = 1.0 / (1.0 + math.exp(-(p.z - 0.198) / 0.006))
                    rx_w = (0.108 - 0.006 * f + 0.016 * blouse) * tuck + 0.058 * (1.0 - tuck)
                    ry_w = (0.114 - 0.006 * f + 0.016 * blouse) * tuck + 0.062 * (1.0 - tuck)
                dx, dy = p.x - leg_x, p.y - cy
                th = math.atan2(dx, dy)
                r_cur = math.hypot(dx, dy)
                r_env = 1.0 / max(math.hypot(math.sin(th) / rx_w, math.cos(th) / ry_w), 1e-4)
                blend = min(1.0, (wl + (0.5 * wt if p.z < hip_z else 0.0)) * 1.35)
                r_new = r_cur + (max(r_cur * 1.12, r_env) - r_cur) * blend
                if r_cur > 1e-5:
                    tx = leg_x + math.sin(th) * r_new
                    # Margem interna da entreperna calibrada pelo modelo tr_guerilla.glb
                    in_seam = 0.006 + 0.018 * max(0.0, min(1.0, (hip_z - 0.10 - p.z) / 0.26))
                    # Preenche o tecido interno da coxa em direção ao gancho para fechar o vão
                    if k * (p.x - leg_x) < 0.0 and p.z >= knee_z:
                        inner_t = max(0.0, min(1.0, (abs(leg_x) - k * p.x) / max(abs(leg_x), 1e-4)))
                        tx_target = k * in_seam
                        tx = tx + (tx_target - tx) * inner_t * 0.70 * min(1.0, wl * 1.2)
                    if k * tx < in_seam:
                        tx = k * in_seam
                    p.x = p.x + (tx - p.x) * blend
                    p.y = p.y + (cy + math.cos(th) * r_new - p.y) * blend

        # 6. pelve: virilha e bunda anatômicas masculinas da referência tr_guerilla.glb
        if hip_z - 0.24 < p.z < hip_z + 0.05:
            # Virilha / braguilha masculina com projeção de tr_guerilla.glb (Y ~ -0.160 descendo até -0.135)
            if p.y < -0.01 and abs(p.x) < 0.080:
                u_z = min(1.0, max(0.0, (hip_z - 0.06 - p.z) / 0.18))
                target_fy = -0.162 + 0.027 * u_z
                fly_fade = max(0.0, 1.0 - (abs(p.x) / 0.080) ** 1.8)
                z_fade = math.exp(-(((p.z - (hip_z - 0.09)) / 0.09) ** 2))
                alpha_groin = fly_fade * z_fade
                p.y = min(p.y, target_fy * alpha_groin + p.y * (1.0 - alpha_groin))
                min_y = -0.155 + 0.020 * u_z
                if abs(p.x) < 0.040 and p.z > hip_z - 0.22:
                    p.y = min(p.y, min_y)

            # Bunda masculina anatômica: dois glúteos redondos volumosos (ápice x=±0.095, Y=+0.131) e vinco central
            elif p.y > 0.015 and abs(p.x) < 0.195:
                dz = p.z - (hip_z - 0.065)
                dx = abs(p.x) - 0.095
                glute_mound = math.exp(-((dx / 0.052) ** 2 + (dz / 0.075) ** 2))
                seam_dip = 0.022 * math.exp(-((p.x / 0.038) ** 2))
                t_z = min(1.0, max(0.0, (p.z - (hip_z - 0.22)) / 0.22))
                base_y = 0.085 + 0.025 * t_z
                target_by = base_y + 0.045 * glute_mound - seam_dip
                z_blend = min(1.0, max(0.0, (p.z - (hip_z - 0.22)) / 0.08))
                p.y = max(p.y, target_by * z_blend)
        v.co = p


def _guerrilla_texture(mesh, joints):
    """Mapeia o atlas do guerrilheiro sobre a malha reconstruída."""
    import numpy as np
    from mathutils.interpolate import poly_3d_calc

    bvh, obm, ouv, atlas, old = guerrilla_legacy.build_legacy_bvh(ATLAS_PATH)
    ah, aw = atlas.shape[:2]
    her = HO._her_bones(joints)
    hip_h, neck_h = joints["hip"].z - 0.085, joints["torso"]["Neck"][0].z
    hip_o, neck_o = 0.905, old["Neck"][0].z

    def color(p, bone):
        if bone in ("Hips", "Spine", "Chest", "Neck", "Head"):
            th = math.atan2(abs(p.x), p.y)
            tz = hip_o + (p.z - hip_h) * (neck_o - hip_o) / (neck_h - hip_h)
            c, d = Vector((0.0, 0.0, min(1.52, max(0.81, tz)))), Vector((math.sin(th), math.cos(th), 0.0))
        elif bone in her and bone in old:
            h0, h1 = her[bone]
            o0, o1 = old[bone]
            dv = h1 - h0
            f = min(1.08, max(-0.08, (p - h0).dot(dv) / dv.length_squared))
            a, b = HO._frame(dv)
            q = p - (h0 + dv * f)
            th = math.atan2(q.dot(a), q.dot(b))
            oa, ob = HO._frame(o1 - o0)
            c, d = o0 + (o1 - o0) * f, oa * math.sin(th) + ob * math.cos(th)
        else:
            return None
        hit, _, fi, _ = bvh.ray_cast(c, d.normalized(), 0.35)
        if hit is None:
            return None
        face = obm.faces[fi]
        wts = poly_3d_calc([v.co for v in face.verts], hit)
        us = [lp[ouv].uv.x for lp in face.loops]
        if max(us) - min(us) > 0.4:
            us_unwrapped = [u + 1.0 if u < 0.5 else u for u in us]
            u = sum(wt * u for wt, u in zip(wts, us_unwrapped)) % 1.0
        else:
            u = sum(wt * u for wt, u in zip(wts, us))
        v = sum(wt * lp[ouv].uv.y for wt, lp in zip(wts, face.loops))
        px, py = int(round(u * (aw - 1))) % aw, int(round((1.0 - v) * (ah - 1))) % ah
        if bone in ("Hips", "Spine", "Chest") and px >= 254:
            px = 250
        return atlas[py, px]

    names = {g.index: g.name for g in mesh.vertex_groups}
    me = mesh.data
    uvl = me.uv_layers.active.data
    me.calc_loop_triangles()
    for key in ('skin', 'costume'):
        slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == f'Body_{key}')
        node = next(n for n in mesh.material_slots[slot].material.node_tree.nodes if n.type == 'TEX_IMAGE')
        img = node.image
        w, h = img.size
        src = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
        out = src.copy()
        done = np.zeros((h, w), dtype=bool)
        bone_of = {}
        for tri in me.loop_triangles:
            if tri.material_index != slot:
                continue
            pi = tri.polygon_index
            if pi not in bone_of:
                acc = {}
                for vi in me.polygons[pi].vertices:
                    for g in me.vertices[vi].groups:
                        acc[names[g.group]] = acc.get(names[g.group], 0.0) + g.weight
                bone_of[pi] = max(acc, key=acc.get)
            bone = bone_of[pi]
            if bone.startswith(('Head', 'Foot')):
                continue
            raw = np.array([[uvl[li].uv.x, uvl[li].uv.y] for li in tri.loops])
            raw -= np.floor(raw.mean(axis=0))
            pts = raw * np.array([w, h])
            P = [me.vertices[vi].co.copy() for vi in tri.vertices]
            x0, y0 = np.floor(pts.min(axis=0)).astype(int)
            x1, y1 = np.ceil(pts.max(axis=0)).astype(int)
            (ax, ay), (bx, by), (cx, cy) = pts
            dd = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(dd) < 1e-9:
                continue
            for py in range(max(y0, 0), min(y1, h - 1) + 1):
                for px in range(max(x0, 0), min(x1, w - 1) + 1):
                    if done[py, px]:
                        continue
                    xs, ys = px + 0.5, py + 0.5
                    l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / dd
                    l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / dd
                    l3 = 1 - l1 - l2
                    if l1 < -0.02 or l2 < -0.02 or l3 < -0.02:
                        continue
                    q = P[0] * l1 + P[1] * l2 + P[2] * l3
                    col = color(q, bone)
                    if col is None:
                        continue
                    out[py, px, :3] = col[:3]
                    done[py, px] = True
        if key == 'costume' and done.any():
            lum = src[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
            mean = float(lum[done].mean())
            shade = np.clip(0.85 + 0.35 * (lum - mean) / max(mean, 1e-3), 0.65, 1.2)[..., None]
            out[..., :3] = np.where(done[..., None], np.clip(out[..., :3] * shade, 0, 1), out[..., :3])
        elif key == 'skin' and done.any():
            # Na calça (skin), preserva a cor e o tecido militar contínuo sem as sombras do macaquinho da heroína
            out[..., :3] = np.where(done[..., None], out[..., :3], out[..., :3])
        for _ in range(2):
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sh = np.roll(done, (dy, dx), axis=(0, 1))
                grow = sh & ~done
                out[grow] = np.roll(out, (dy, dx), axis=(0, 1))[grow]
                done = done | grow
        new = bpy.data.images.new(f'tex_{key}_guerrilla', w, h, alpha=True)
        new.pixels = out.ravel().tolist()
        new.pack()
        node.image = new
    _paint_balaclava_face(mesh)


def _paint_balaclava_face(mesh):
    """Balaclava preta tática: cobre boca e queixo, deixando uma fresta limpa para os olhos 3D reais."""
    import numpy as np

    me = mesh.data
    uvl = me.uv_layers.active.data
    eye_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_eye")
    face_slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == "Body_face")
    eye_verts = [me.vertices[vi].co for p in me.polygons if p.material_index == eye_slot for vi in p.vertices]
    el, er = [v for v in eye_verts if v.x > 0], [v for v in eye_verts if v.x < 0]
    eye_l, eye_r = sum(el, Vector()) / max(len(el), 1), sum(er, Vector()) / max(len(er), 1)

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
                # Abertura tática horizontal contínua sobre os olhos (sem furo bizarro de boca)
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
    """Importa Mesh.fbx, aplica pose masculina com braços alinhados e exporta o corpo."""
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
    _surfaces(mesh)
    HO._drop_feet(mesh)
    _guerrilla_texture(mesh, joints)
    old_target = HB.TARGET_TRIS
    HB.TARGET_TRIS = TARGET_TRIS
    try:
        HB._decimate(mesh)
    finally:
        HB.TARGET_TRIS = old_target
    for p in mesh.data.polygons:
        p.use_smooth = True
    return mesh, joints
