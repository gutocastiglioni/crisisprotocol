"""Roupa da heroína sobre o corpo do modelo base (art/heroine_body.py): a textura da heroína original
transferida para a pele e o colete dela, as alças do colete deitadas no ombro e a bota no lugar do pé dela.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

import heroine_spec as S

from heroine_hair import SURF

ART = Path(__file__).resolve().parent


STRAP_GAP = 0.010  # alças do colete deitadas no ombro, com a espessura do colete (volume)


def _flat_straps(mesh, joints):
    """As alças do maiô dela, feitas para o T, ficam em pé no ombro com o braço caído: no alto do ombro, cada vértice
    do colete vai para o ponto mais perto da pele, STRAP_GAP acima dela (a alça fica, deitada no ombro)."""
    from mathutils.bvhtree import BVHTree

    names = {i: sl.material.name.removeprefix("Body_") for i, sl in enumerate(mesh.material_slots)}
    skin = bmesh.new()
    skin.from_mesh(mesh.data)
    bmesh.ops.delete(skin, geom=[f for f in skin.faces if names[f.material_index] != "skin"], context="FACES")
    tree = BVHTree.FromBMesh(skin)
    skin.free()
    top = joints["shoulder"].z - 0.10
    vest = {i for i, n in names.items() if n == "costume"}
    me = mesh.data
    moved = set()
    for poly in me.polygons:
        if poly.material_index not in vest:
            continue
        for vi in poly.vertices:
            v = me.vertices[vi]
            if vi in moved or v.co.z < top or abs(v.co.x) < 0.05:
                continue
            loc, nrm, _, dist = tree.find_nearest(v.co)
            if loc is not None and dist > STRAP_GAP:
                v.co = loc + nrm * STRAP_GAP
            moved.add(vi)


# ------------------------------------------------------------------ pés -> bota
BOOT_TOP = 0.45  # borda do cano (altura real), abaixo do joelho
BOOT_THICK = 0.007  # couro por cima da perna dela
BOOT_DESIGN = (0.085, 0.435)  # faixa de altura de projeto em que a bota original está pintada (retângulo "shin")
SHAFT_Z = [0.45, 0.41, 0.36, 0.31, 0.26, 0.21, 0.17, 0.14]  # anéis do cano; depois vem o do tornozelo
FOOT = [  # (y em relação ao tornozelo, z, meia-largura, meia-altura): calcanhar, peito do pé, planta, bico, ponta
    (-0.008, 0.042, 0.040, 0.054),
    (-0.068, 0.040, 0.046, 0.040),
    (-0.125, 0.033, 0.048, 0.033),
    (-0.172, 0.026, 0.042, 0.026),
    (-0.200, 0.020, 0.028, 0.019),
]
HEEL = 0.024  # quanto o calcanhar passa para trás da curva do tornozelo


def _drop_feet(mesh):
    """Tira os pés dela (descalços, modelados na ponta): a bota entra no lugar."""
    feet = {g.index for g in mesh.vertex_groups if g.name.startswith("Foot")}
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    dl = bm.verts.layers.deform.active

    def foot_w(v):
        return sum(w for g, w in v[dl].items() if g in feet)

    bmesh.ops.delete(bm, geom=[f for f in bm.faces if sum(foot_w(v) for v in f.verts) / len(f.verts) > 0.5],
                     context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()


def _frame(t):
    t = t.normalized()
    a = t.cross(Vector((0.0, 1.0, 0.0)))
    if a.length < 1e-6:
        a = Vector((1.0, 0.0, 0.0))
    a.normalize()
    return a, a.cross(t).normalized()


def make_boots(rig, atlas_path):
    """Bota da heroína original sobre a perna dela: o cano segue a panturrilha e o tornozelo dela (raio dela + couro),
    o pé é desenhado (calcanhar, peito do pé, bico, sola reta no chão). Textura da bota original (cadarço) do atlas."""
    import heroine_mesh as HM
    import heroine_rig

    mb = HM.MeshBuilder(S.BONE_NAMES)
    sides = 8
    angles = [2 * math.pi * j / sides for j in range(sides)]
    X = Vector((1.0, 0.0, 0.0))
    for s in ("L", "R"):
        knee, ankle = S.side(S.KNEE_L, s), S.side(S.ANKLE_L, s)
        a, b = _frame(ankle - knee)
        lo, hi = BOOT_DESIGN
        rings = []
        for z in SHAFT_Z + [ankle.z]:
            f = (knee.z - z) / (knee.z - ankle.z)
            c = knee.lerp(ankle, f)
            pts = []
            for th in angles:
                d = (a * math.sin(th) + b * math.cos(th)).normalized()
                hit = SURF["body"].ray_cast(c, d, 0.15)[0]
                r = max(0.032, (hit - c).length if hit is not None else 0.05) + BOOT_THICK
                pts.append(c + d * r)
            if z > BOOT_TOP - 0.02:  # borda do cano um pouco mais larga
                pts = [c + (q - c) * 1.06 for q in pts]
            design = lo + (z - ankle.z) * (hi - lo) / (BOOT_TOP - ankle.z)
            w = {f"LowerLeg_{s}": 1} if z > 0.16 else {f"LowerLeg_{s}": 0.6, f"Foot_{s}": 0.4}
            rings.append(HM.R((c.x, c.y, design), 0, 0, w, pts=pts, frame=(a, b)))
        g = mb.loft(rings, "shin", sides, caps=(False, False), v_by_z=True)
        # pé: do tornozelo para a frente; o referencial vira (atrás no tornozelo = embaixo no pé)
        centers = [ankle] + [Vector((ankle.x, ankle.y + dy, z)) for dy, z, _, _ in FOOT]
        foot = [HM.R(ankle, 0, 0, {f"Foot_{s}": 1}, verts=g[-1], frame=(a, b))]
        for i, (dy, z, hw, hh) in enumerate(FOOT, start=1):
            t = centers[min(i + 1, len(centers) - 1)] - centers[i - 1]
            fa, fb = X.copy(), X.cross(t.normalized()).normalized()
            c = centers[i]
            pts = []
            for th in angles:
                q = c + fa * (hw * math.sin(th)) + fb * (hh * math.cos(th))
                if i == 1 and math.cos(th) > 0:
                    q = q + Vector((0.0, 1.0, 0.0)) * (HEEL * math.cos(th) ** 2)
                pts.append(Vector((q.x, q.y, max(0.0, q.z))))
            foot.append(HM.R(c, 0, 0, {f"Foot_{s}": 1}, pts=pts, frame=(fa, fb)))
        mb.loft(foot, "foot", sides, caps=(False, True))
    image = bpy.data.images.load(str(atlas_path))
    image.pack()
    mat = heroine_rig.make_material("HeroineBoots", image, double_sided=False)
    obj = heroine_rig._skinned_object(rig, "HeroineBoots", mb, [mat])
    print(f"[corpo] botas: {sum(len(p.vertices) - 2 for p in obj.data.polygons)} triângulos")
    return obj


# ------------------------------------------------------------------ textura da heroína original
ROMPER_LEG = 0.35  # perna do romper: fração da coxa abaixo da junta do quadril
ROMPER_HEM = 0.012  # barra (m)
BAND_BELOW = 0.08  # faixa da coxa logo abaixo da barra (m): o marrom ali vira preto claro
BAND_GRAY = 0.16  # cor da faixa (preto mais claro que o romper)
VEST_DARK = 0.45  # brilho do colete em relação à jaqueta (mais preto)
VEST_SAT = 0.35  # saturação que sobra no colete (quase preto, sem puxar para o verde da jaqueta)
COLLAR = 0.03  # gola da jaqueta acima da base do pescoço (acima disso fica a pele dela)


def _old_body():
    """A heroína original (gerada por código nas medidas antigas: heroine_spec ainda sem use_joints), só o corpo,
    para ler a cor da roupa dela; e o atlas pintado dela."""
    import numpy as np
    from mathutils.bvhtree import BVHTree

    import heroine_mesh as HM

    mb = HM.build_all(S.BONE_NAMES)
    bm = mb.bm
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != HM.MAT_BODY], context="FACES")
    bm.faces.ensure_lookup_table()
    img = bpy.data.images.load(str(ART.parent / "game/assets/characters/heroine_atlas.png"))
    w, h = img.size
    atlas = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bones = {n: (hd.copy(), tl.copy()) for n, hd, tl, _ in S.bones()}
    return BVHTree.FromBMesh(bm), bm, mb.uv, atlas, bones


def _her_bones(j):
    """Os ossos dela (os dois lados) nas juntas lidas do modelo, como os nossos serão criados."""
    out = dict(j["torso"])
    for s, k in (("L", 1), ("R", -1)):
        down = Vector((k * math.sin(S.ARM_SPREAD), 0.0, -math.cos(S.ARM_SPREAD)))

        def m(v, k=k):
            return Vector((k * abs(v.x), v.y, v.z))

        sh = m(j["shoulder"])
        el = sh + down * j["upper_arm"]
        wr = el + down * j["forearm"]
        out[f"UpperArm_{s}"] = (sh, el)
        out[f"LowerArm_{s}"] = (el, wr)
        out[f"Hand_{s}"] = (wr, wr + down * j["hand"])
        out[f"UpperLeg_{s}"] = (m(j["hip"]), m(j["knee"]))
        out[f"LowerLeg_{s}"] = (m(j["knee"]), m(j["ankle"]))
    return out


def _original_texture(mesh, joints):
    """A roupa da heroína original (jaqueta, colete com tiras, zíper, cinto, calça, luva) nas texturas dela: cada
    pixel da pele e do maiô vira um ponto no corpo dela, que vai para o ponto equivalente no corpo original (mesmo
    osso, mesma fração do comprimento e mesma direção em volta; o tronco pela altura entre o quadril e o pescoço),
    e ganha a cor do atlas original ali. O sombreado da textura dela fica, leve, por cima."""
    import numpy as np
    from mathutils.interpolate import poly_3d_calc

    bvh, obm, ouv, atlas, old = _old_body()
    ah, aw = atlas.shape[:2]
    her = _her_bones(joints)
    names = {g.index: g.name for g in mesh.vertex_groups}
    hip_h, neck_h = joints["hip"].z, joints["torso"]["Neck"][0].z
    hip_o, neck_o = S.HIP_L.z, old["Neck"][0].z
    # romper: o colete desce em shorts até ROMPER_LEG da coxa (do quadril ao joelho)
    romper_bottom = joints["hip"].z - ROMPER_LEG * (joints["hip"].z - joints["knee"].z)

    def torso_z(z):
        return hip_o + (z - hip_h) * (neck_o - hip_o) / (neck_h - hip_h)

    def color(p, bone):
        if bone in ("Hips", "Spine", "Chest", "Neck"):
            if bone == "Neck" and p.z > neck_h + COLLAR:
                return None
            th = math.atan2(p.x, p.y)
            c = Vector((0.0, 0.0, torso_z(p.z)))
            d = Vector((math.sin(th), math.cos(th), 0.0))
        elif bone in her and bone in old:
            h0, h1 = her[bone]
            o0, o1 = old[bone]
            dv = h1 - h0
            f = min(1.1, max(-0.1, (p - h0).dot(dv) / dv.length_squared))
            a, b = _frame(dv)
            q = p - (h0 + dv * f)
            th = math.atan2(q.dot(a), q.dot(b))
            oa, ob = _frame(o1 - o0)
            c = o0 + (o1 - o0) * f
            d = oa * math.sin(th) + ob * math.cos(th)
        else:
            return None
        hit, _, fi, _ = bvh.ray_cast(c, d.normalized(), 0.3)
        if hit is None:
            return None
        face = obm.faces[fi]
        wts = poly_3d_calc([v.co for v in face.verts], hit)
        u = sum(wt * lp[ouv].uv.x for wt, lp in zip(wts, face.loops))
        v = sum(wt * lp[ouv].uv.y for wt, lp in zip(wts, face.loops))
        return atlas[min(ah - 1, max(0, int(v * ah))), min(aw - 1, max(0, int(u * aw)))]

    me = mesh.data
    uvl = me.uv_layers.active.data
    me.calc_loop_triangles()
    for key in ("skin", "costume"):
        slot = next(i for i, sl in enumerate(mesh.material_slots) if sl.material.name == f"Body_{key}")
        node = next(n for n in mesh.material_slots[slot].material.node_tree.nodes if n.type == "TEX_IMAGE")
        img = node.image
        w, h = img.size
        src = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
        out = src.copy()
        done = np.zeros((h, w), dtype=bool)
        romper = np.zeros((h, w), dtype=bool)  # pele do quadril e da coxa coberta pela perna do romper
        hem = np.zeros((h, w), dtype=bool)  # barra do romper na coxa
        band = np.zeros((h, w), dtype=bool)  # logo abaixo da barra: a faixa marrom da coxa vira preto mais claro
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
            if bone.startswith(("Head", "Foot")):
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
                    if bone == "Hips" or bone.startswith("UpperLeg"):
                        if romper_bottom < q.z < joints["hip"].z:
                            romper[py, px] = True
                            hem[py, px] = q.z < romper_bottom + ROMPER_HEM
                        elif romper_bottom - BAND_BELOW < q.z <= romper_bottom:
                            band[py, px] = True
        # sombreado dela, leve; 2 pixels para fora (o filtro não puxa a pele na costura)
        lum = src[..., :3] @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        if done.any():
            mean = float(lum[done].mean())
            shade = np.clip(0.85 + 0.35 * (lum - mean) / max(mean, 1e-3), 0.65, 1.2)[..., None]
            out[..., :3] = np.where(done[..., None], np.clip(out[..., :3] * shade, 0, 1), out[..., :3])
        for _ in range(2):
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sh = np.roll(done, (dy, dx), axis=(0, 1))
                grow = sh & ~done
                out[grow] = np.roll(out, (dy, dx), axis=(0, 1))[grow]
                done = done | grow
        if key == "skin" and romper.any():  # pernas do romper: o mesmo preto do colete, com a barra mais clara
            rgb = out[..., :3]
            gray = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
            dark = np.clip((gray[..., None] * (1 - VEST_SAT) + rgb * VEST_SAT) * VEST_DARK, 0, 1)
            rgb[:] = np.where(romper[..., None], dark, rgb)
            rgb[:] = np.where(hem[..., None], np.clip(dark * 1.9 + 0.03, 0, 1), rgb)
            # faixa marrom da coxa (logo abaixo da barra): só os pixels marrons (r > g > b e saturados) viram preto claro
            mx, mn = rgb.max(axis=2), rgb.min(axis=2)
            brown = band & (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2]) & ((mx - mn) / np.maximum(mx, 1e-6) > 0.2)
            light = np.clip(rgb.mean(axis=2, keepdims=True) * 0 + BAND_GRAY, 0, 1)
            shade = np.clip(0.75 + 0.5 * (gray / max(float(gray[brown].mean()) if brown.any() else 1.0, 1e-3)), 0.7, 1.2)
            rgb[:] = np.where(brown[..., None], light * shade[..., None], rgb)
            print(f"[corpo] romper: {int(romper.sum())} pixels de perna, faixa da coxa: {int(brown.sum())} pixels")
        if key == "costume":  # colete mais preto que o resto da roupa (as costuras e tiras continuam aparecendo)
            rgb = out[..., :3]
            gray = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
            rgb[:] = np.clip((gray[..., None] * (1 - VEST_SAT) + rgb * VEST_SAT) * VEST_DARK, 0, 1)
        new = bpy.data.images.new(f"{key}_heroine", w, h, alpha=True)
        new.pixels = out.ravel().tolist()
        new.pack()
        node.image = new
        print(f"[corpo] textura original em {key}: {int(done.sum())} pixels")
    obm.free()
