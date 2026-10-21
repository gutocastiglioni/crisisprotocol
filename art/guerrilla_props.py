"""Acessórios e equipamentos do guerrilheiro: capuz tático 3D, coturnos de combate e equipamento."""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

import guerrilla_atlas
import heroine_mesh as M
import heroine_outfit as HO
import heroine_rig
import heroine_spec as S
from heroine_hair import SURF

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

HOOD_LEVELS = [
    # z, yc, rx, ry_front, ry_back, open_width_x
    (1.425, -0.005, 0.098, 0.092, 0.095, 0.000),  # gola moletom (fechado)
    (1.455, -0.003, 0.090, 0.088, 0.095, 0.000),  # base pescoço (fechado)
    (1.485,  0.000, 0.085, 0.084, 0.100, 0.034),  # queixo
    (1.525,  0.003, 0.086, 0.084, 0.104, 0.048),  # mandíbula
    (1.570,  0.005, 0.088, 0.084, 0.106, 0.054),  # maçãs do rosto
    (1.610,  0.006, 0.086, 0.084, 0.106, 0.052),  # olhos
    (1.640,  0.007, 0.082, 0.082, 0.102, 0.038),  # testa suave
    (1.665,  0.008, 0.078, 0.078, 0.096, 0.000),  # testa alta (fechado)
    (1.692,  0.010, 0.065, 0.066, 0.082, 0.000),  # calota superior
    (1.708,  0.011, 0.042, 0.042, 0.054, 0.000),  # cúpula arredondada
]
CROWN_TOP = (1.714, 0.012)


def make_hood(rig, atlas_path):
    """Capuz tático 3D suave, anatômico, sem furos e perfeitamente ajustado sobre a balaclava."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    n_cols = 16
    grid = []

    for z, yc, rx, ry_f, ry_b, hx in HOOD_LEVELS:
        is_open = (hx > 0.001)
        row = []
        if not is_open:
            for col in range(n_cols + 1):
                t = col / n_cols
                phi = -math.pi + 2.0 * math.pi * t
                cp, sp = math.cos(phi), math.sin(phi)
                ry = ry_b if cp >= 0 else ry_f
                x = 0.0 if col in (0, n_cols) else rx * sp
                y = yc - ry_f if col in (0, n_cols) else yc + cp * ry
                row.append(bm.verts.new(Vector((x, y, z))))
        else:
            sin_open = min(0.95, max(0.10, hx / max(rx, 1e-4)))
            phi_open = math.asin(sin_open)
            phi_start = -math.pi + phi_open
            phi_end = math.pi - phi_open
            for col in range(n_cols + 1):
                t = col / n_cols
                phi = phi_start + t * (phi_end - phi_start)
                cp, sp = math.cos(phi), math.sin(phi)
                ry = ry_b if cp >= 0 else ry_f
                if col == 0:
                    x, y = -hx, yc - ry_f * math.cos(phi_open)
                elif col == n_cols:
                    x, y = hx, yc - ry_f * math.cos(phi_open)
                else:
                    x, y = rx * sp, yc + cp * ry
                row.append(bm.verts.new(Vector((x, y, z))))
        grid.append((row, is_open))

    v_crown = bm.verts.new(Vector((0.0, CROWN_TOP[1], CROWN_TOP[0])))
    bm.verts.ensure_lookup_table()

    n_lvls = len(HOOD_LEVELS)
    for i in range(n_lvls - 1):
        row0, _ = grid[i]
        row1, _ = grid[i + 1]
        v0, v1 = i / (n_lvls - 1), (i + 1) / (n_lvls - 1)
        for col in range(n_cols):
            f = bm.faces.new([row0[col], row1[col], row1[col + 1], row0[col + 1]])
            u0, u1 = col / n_cols, (col + 1) / n_cols
            f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0, v0)
            f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", u0, v1)
            f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1, v1)
            f.loops[3][uv_layer].uv = guerrilla_atlas.uv("hair", u1, v0)

    top_row, _ = grid[-1]
    for col in range(n_cols):
        f = bm.faces.new([top_row[col], v_crown, top_row[col + 1]])
        u0, u1 = col / n_cols, (col + 1) / n_cols
        f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0, 0.94)
        f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", (u0 + u1) * 0.5, 1.0)
        f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1, 0.94)

    open_indices = [idx for idx, (_, is_open) in enumerate(grid) if is_open]
    for side_col in (0, n_cols):
        rim = []
        sign = -1 if side_col == 0 else 1
        for idx in open_indices:
            v_edge = grid[idx][0][side_col]
            v_inner = bm.verts.new(v_edge.co + Vector((-sign * 0.007, 0.005, 0.0)))
            rim.append((v_edge, v_inner, idx))
        for k in range(len(rim) - 1):
            vo0, vi0, idx0 = rim[k]
            vo1, vi1, idx1 = rim[k + 1]
            f = bm.faces.new([vo0, vo1, vi1, vi0]) if side_col == 0 else bm.faces.new([vo0, vi0, vi1, vo1])
            u_val = 0.02 if side_col == 0 else 0.98
            v_a, v_b = idx0 / (n_lvls - 1), idx1 / (n_lvls - 1)
            for loop in f.loops:
                loop[uv_layer].uv = guerrilla_atlas.uv("hair", u_val, v_a if loop.vert in (vo0, vi0) else v_b)

    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    me = bpy.data.meshes.new("GuerrillaHood")
    bm.to_mesh(me)
    bm.free()

    obj = bpy.data.objects.new("GuerrillaHood", me)
    bpy.context.collection.objects.link(obj)

    for bone_name in S.BONE_NAMES:
        obj.vertex_groups.new(name=bone_name)
    for v in me.vertices:
        z = v.co.z
        if z >= 1.54:
            obj.vertex_groups["Head"].add([v.index], 1.0, "REPLACE")
        elif z >= 1.45:
            f = (z - 1.45) / (1.54 - 1.45)
            obj.vertex_groups["Neck"].add([v.index], 1.0 - f, "REPLACE")
            obj.vertex_groups["Head"].add([v.index], f, "REPLACE")
        else:
            f = max(0.0, min(1.0, (z - 1.41) / (1.45 - 1.41)))
            obj.vertex_groups["Chest"].add([v.index], 1.0 - 0.3 * f, "REPLACE")
            obj.vertex_groups["Neck"].add([v.index], 0.3 * f, "REPLACE")

    image = bpy.data.images.load(str(atlas_path))
    image.pack()
    mat = heroine_rig.make_material("GuerrillaHood", image, double_sided=True)
    obj.data.materials.append(mat)
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    print(f"[guerrilla] capuz tático gerado: {len(me.vertices)} verts, {len(me.polygons)} polígonos")
    return obj


def make_boots(rig, atlas_path):
    """Coturnos de combate com cano blusado sob a calça cargo."""
    mb = M.MeshBuilder(S.BONE_NAMES, atlas_module=guerrilla_atlas)
    sides = 8
    angles = [2 * math.pi * j / sides for j in range(sides)]
    for s in ("L", "R"):
        knee, ankle = S.side(S.KNEE_L, s), S.side(S.ANKLE_L, s)
        a, b = HO._frame(ankle - knee)
        lo, hi = (0.08, 0.30)
        shaft_z = [0.30, 0.26, 0.23, 0.215, 0.198, 0.17, 0.14, ankle.z]
        rings = []
        for z in shaft_z:
            f = (knee.z - z) / (knee.z - ankle.z)
            c = knee.lerp(ankle, f)
            blouse = 0.012 if 0.205 <= z <= 0.24 else (0.006 if z > 0.24 else 0.004)
            pts = []
            for th in angles:
                d = (a * math.sin(th) + b * math.cos(th)).normalized()
                hit = SURF["body"].ray_cast(c, d, 0.18)[0]
                r = max(0.048, (hit - c).length if hit is not None else 0.064) + blouse
                pts.append(c + d * r)
            design = lo + (z - ankle.z) * (hi - lo) / (shaft_z[0] - ankle.z)
            w = {f"LowerLeg_{s}": 1} if z > 0.16 else {f"LowerLeg_{s}": 0.6, f"Foot_{s}": 0.4}
            rings.append(M.R((c.x, c.y, design), 0, 0, w, pts=pts, frame=(a, b)))
        g = mb.loft(rings, "shin", sides, caps=(False, False), v_by_z=True)
        centers = [ankle] + [Vector((ankle.x, ankle.y + dy * 1.10, z)) for dy, z, _, _ in HO.FOOT]
        foot = [M.R(ankle, 0, 0, {f"Foot_{s}": 1}, verts=g[-1], frame=(a, b))]
        for i, (dy, z, hw, hh) in enumerate(HO.FOOT, start=1):
            t = centers[min(i + 1, len(centers) - 1)] - centers[i - 1]
            fa, fb = X.copy(), X.cross(t.normalized()).normalized()
            c = centers[i]
            pts = []
            for th in angles:
                q = c + fa * (hw * 1.28 * math.sin(th)) + fb * (hh * 1.18 * math.cos(th))
                if i == 1 and math.cos(th) > 0:
                    q = q + Vector((0.0, 1.0, 0.0)) * (HO.HEEL * 1.22 * math.cos(th) ** 2)
                pts.append(Vector((q.x, q.y, max(0.0, q.z))))
            foot.append(M.R(c, 0, 0, {f"Foot_{s}": 1}, pts=pts, frame=(fa, fb)))
        mb.loft(foot, "foot", sides, caps=(False, True))
    image = bpy.data.images.load(str(atlas_path))
    image.pack()
    mat = heroine_rig.make_material("GuerrillaBoots", image, double_sided=False)
    obj = heroine_rig._skinned_object(rig, "GuerrillaBoots", mb, [mat])
    return obj


def make_gear(rig, atlas_path):
    """Equipamento tático: bolsas de peito e cordões do moletom."""
    mb = M.MeshBuilder(S.BONE_NAMES, atlas_module=guerrilla_atlas)
    z_pouch = S.SHOULDER_L.z - 0.16
    for x in (-0.068, 0.0, 0.068):
        hit = SURF["body"].ray_cast(Vector((x, -0.35, z_pouch)), Vector((0.0, 1.0, 0.0)), 0.4)[0]
        y = (hit.y if hit is not None else -0.13) - 0.016
        mb.box(Vector((x, y, z_pouch)), X, Y, (0.030, 0.018, 0.044), "pouch", {"Chest": 1})
    z_cord = S.SHOULDER_L.z - 0.01
    for k in (1, -1):
        x = k * 0.044
        hit = SURF["body"].ray_cast(Vector((x, -0.35, z_cord)), Vector((0.0, 1.0, 0.0)), 0.4)[0]
        y = (hit.y if hit is not None else -0.125) - 0.005
        mb.box(Vector((x, y, z_cord)), X, Y, (0.0045, 0.004, 0.062), "cord", {"Chest": 1})
    image = bpy.data.images.load(str(atlas_path))
    image.pack()
    mat = heroine_rig.make_material("GuerrillaGear", image, double_sided=False)
    obj = heroine_rig._skinned_object(rig, "GuerrillaGear", mb, [mat])
    return obj
