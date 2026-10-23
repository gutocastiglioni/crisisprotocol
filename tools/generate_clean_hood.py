import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

import guerrilla_atlas
import heroine_mesh as M
import heroine_rig
import heroine_spec as S

# -------------------------------------------------------------------------------------------------
# MODELO DO CAPUZ:
# - Anéis circulares/elípticos em torno do crânio e pescoço.
# - Abaixo de z = 1.46: fechado 360° (gola do moletom sobre o peito e ombros).
# - Entre z = 1.47 e z = 1.64: abertura oval frontal para o rosto de balaclava.
# - Acima de z = 1.64: fechado 360° sobre a testa e calota craniana até o topo (z ~ 1.725).
# -------------------------------------------------------------------------------------------------

# (z, y_center, rx, ry_front, ry_back, opening_half_width_x, w)
# Se opening_half_width_x <= 0: anel totalmente fechado na frente.
# Se opening_half_width_x > 0: anel aberto na frente com largura 2 * opening_half_width_x.
HOOD_LAYERS = [
    # 0. Base da gola sobre o peito e ombros (fechado 360°)
    (1.415, -0.005, 0.145, 0.105, 0.105, 0.000, {"Chest": 0.9, "Neck": 0.1}),
    # 1. Gola subindo no pescoço (fechado 360°)
    (1.445, -0.005, 0.125, 0.095, 0.100, 0.000, {"Chest": 0.5, "Neck": 0.5}),
    # 2. Embaixo do queixo (início da abertura oval do rosto)
    (1.475, -0.003, 0.114, 0.088, 0.108, 0.038, {"Neck": 0.6, "Head": 0.4}),
    # 3. Boca / maxilar
    (1.515,  0.002, 0.110, 0.088, 0.115, 0.052, {"Head": 1.0}),
    # 4. Nariz / maçãs do rosto
    (1.560,  0.005, 0.108, 0.088, 0.120, 0.058, {"Head": 1.0}),
    # 5. Olhos / têmporas (abertura máxima)
    (1.605,  0.006, 0.106, 0.088, 0.122, 0.056, {"Head": 1.0}),
    # 6. Sobrancelhas / testa baixa (fechando a abertura)
    (1.645,  0.008, 0.100, 0.085, 0.118, 0.040, {"Head": 1.0}),
    # 7. Testa alta (fechado 360° contínuo)
    (1.675,  0.010, 0.092, 0.082, 0.110, 0.000, {"Head": 1.0}),
    # 8. Curva da calota
    (1.705,  0.012, 0.076, 0.070, 0.092, 0.000, {"Head": 1.0}),
    # 9. Topo arredondado da cúpula
    (1.724,  0.014, 0.045, 0.042, 0.055, 0.000, {"Head": 1.0}),
]
CROWN_POINT = (1.732, 0.015, {"Head": 1.0})

def generate_hood(rig, atlas_path):
    bm = bmesh.new()
    sides = 14  # 14 lados na volta para uma silhueta suave e redonda
    
    # Gera anéis
    layer_data = []
    for layer_idx, (z, yc, rx, ry_f, ry_b, open_hx, w) in enumerate(HOOD_LAYERS):
        is_open = (open_hx > 0.001)
        verts = []
        u_coords = []
        
        if not is_open:
            # Anel fechado 360 graus:
            # j=0 é a frente central (-Y, x=0)
            # j=sides/2 é a nuca (+Y, x=0)
            # j=sides volta à frente central
            for j in range(sides):
                # angulo de 0 (frente -Y) a 2*pi
                phi = 2.0 * math.pi * (j / sides)
                # x = rx * sin(phi)
                # y = yc - cos(phi) * (ry_f se cos(phi) > 0 else ry_b)
                cp = math.cos(phi)
                sp = math.sin(phi)
                ry = ry_f if cp >= 0 else ry_b
                x = rx * sp
                y = yc - cp * ry
                v = bm.verts.new(Vector((x, y, z)))
                verts.append(v)
                # u no atlas: 0 na frente, 0.5 na nuca, 1.0 na frente
                u = (j / sides)
                u_coords.append(u)
        else:
            # Anel aberto na frente:
            # O arco vai da borda direita da abertura (+X negativo), passando pela nuca, até a borda esquerda (+X positivo).
            # No plano X-Y, a abertura tem x entre -open_hx e +open_hx.
            # phi_open é o meio-ângulo da abertura na frente
            sin_open = min(0.98, max(0.05, open_hx / max(rx, 1e-4)))
            phi_open = math.asin(sin_open)
            # Arco coberto de tecido: de phi_open até (2*pi - phi_open)
            phi_start = phi_open
            phi_end = 2.0 * math.pi - phi_open
            
            for j in range(sides + 1):
                t = j / sides
                phi = phi_start + t * (phi_end - phi_start)
                cp = math.cos(phi)
                sp = math.sin(phi)
                ry = ry_f if cp >= 0 else ry_b
                x = rx * sp
                y = yc - cp * ry
                v = bm.verts.new(Vector((x, y, z)))
                verts.append(v)
                # u no atlas: mapeia o arco de forma simétrica com 0.5 na nuca
                # t=0 -> u = phi_start / (2*pi)
                # t=1 -> u = phi_end / (2*pi)
                u = (phi / (2.0 * math.pi))
                u_coords.append(u)
                
        layer_data.append((verts, is_open, u_coords, w))
    
    # Vértice do topo da calota (centro da cúpula)
    v_crown = bm.verts.new(Vector((0.0, CROWN_POINT[1], CROWN_POINT[0])))
    bm.verts.ensure_lookup_table()
    
    # Camada UV
    uv_layer = bm.loops.layers.uv.new("UVMap")
    n_layers = len(HOOD_LAYERS)
    
    # Conecta camadas com faces
    for i in range(n_layers - 1):
        v0, open0, u0, _ = layer_data[i]
        v1, open1, u1, _ = layer_data[i + 1]
        v_h0 = i / (n_layers - 1)
        v_h1 = (i + 1) / (n_layers - 1)
        
        if (not open0) and (not open1):
            # Fechado para fechado
            for j in range(sides):
                j_next = (j + 1) % sides
                f = bm.faces.new([v0[j], v1[j], v1[j_next], v0[j_next]])
                # UVs
                f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0[j], v_h0)
                f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", u1[j], v_h1)
                f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1[j_next] if j_next > 0 else 1.0, v_h1)
                f.loops[3][uv_layer].uv = guerrilla_atlas.uv("hair", u0[j_next] if j_next > 0 else 1.0, v_h0)
                
        elif open0 and open1:
            # Aberto para aberto (sides quads)
            for j in range(sides):
                f = bm.faces.new([v0[j], v1[j], v1[j + 1], v0[j + 1]])
                f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0[j], v_h0)
                f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", u1[j], v_h1)
                f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1[j + 1], v_h1)
                f.loops[3][uv_layer].uv = guerrilla_atlas.uv("hair", u0[j + 1], v_h0)
                
        elif (not open0) and open1:
            # Transição embaixo: de fechado (i) para aberto (i+1)
            # v0 tem sides verts (fechado), v1 tem sides+1 verts (aberto)
            # Conecta o corpo
            for j in range(sides):
                v1_a = v1[j]
                v1_b = v1[j + 1]
                v0_a = v0[j]
                v0_b = v0[(j + 1) % sides]
                f = bm.faces.new([v0_a, v1_a, v1_b, v0_b])
                f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0[j], v_h0)
                f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", u1[j], v_h1)
                f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1[j + 1], v_h1)
                f.loops[3][uv_layer].uv = guerrilla_atlas.uv("hair", u0[(j + 1) % sides] if (j + 1) % sides > 0 else 1.0, v_h0)
                
        elif open0 and (not open1):
            # Transição em cima: de aberto (i) para fechado (i+1)
            # v0 tem sides+1 verts, v1 tem sides verts
            for j in range(sides):
                v0_a = v0[j]
                v0_b = v0[j + 1]
                v1_a = v1[j]
                v1_b = v1[(j + 1) % sides]
                f = bm.faces.new([v0_a, v1_a, v1_b, v0_b])
                f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0[j], v_h0)
                f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", u1[j], v_h1)
                f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1[(j + 1) % sides] if (j + 1) % sides > 0 else 1.0, v_h1)
                f.loops[3][uv_layer].uv = guerrilla_atlas.uv("hair", u0[j + 1], v_h0)

    # Topo da cúpula (fan com v_crown)
    top_verts = layer_data[-1][0]
    top_u = layer_data[-1][2]
    for j in range(sides):
        j_next = (j + 1) % sides
        f = bm.faces.new([top_verts[j], v_crown, top_verts[j_next]])
        u_mid = (top_u[j] + (top_u[j_next] if j_next > 0 else 1.0)) * 0.5
        f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", top_u[j], 0.95)
        f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", u_mid, 1.0)
        f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", top_u[j_next] if j_next > 0 else 1.0, 0.95)

    # Borda dobrada para dentro na abertura frontal (espessura realista de tecido, sem pontas soltas)
    # Pega os vértices da borda esquerda (j=0) e direita (j=sides) dos anéis abertos
    open_layer_indices = [idx for idx, (_, is_open, _, _) in enumerate(layer_data) if is_open]
    for side_col in (0, sides):
        rim_line = []
        for idx in open_layer_indices:
            v_edge = layer_data[idx][0][side_col]
            # dobra 8mm para dentro (-X se side_col==sides, +X se side_col==0) e 4mm para trás (+Y)
            sign = 1 if side_col == sides else -1
            v_inner = bm.verts.new(v_edge.co + Vector((-sign * 0.008, 0.006, 0.0)))
            rim_line.append((v_edge, v_inner, idx))
            
        for k in range(len(rim_line) - 1):
            vo0, vi0, idx0 = rim_line[k]
            vo1, vi1, idx1 = rim_line[k + 1]
            if side_col == 0:
                f = bm.faces.new([vo0, vo1, vi1, vi0])
            else:
                f = bm.faces.new([vo0, vi0, vi1, vo1])
            u_val = 0.02 if side_col == 0 else 0.98
            v_a, v_b = idx0 / (n_layers - 1), idx1 / (n_layers - 1)
            for loop in f.loops:
                v_coord = v_a if loop.vert in (vo0, vi0) else v_b
                loop[uv_layer].uv = guerrilla_atlas.uv("hair", u_val, v_coord)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    
    # Objeto
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
            obj.vertex_groups["Chest"].add([v.index], 1.0 - 0.4 * f, "REPLACE")
            obj.vertex_groups["Neck"].add([v.index], 0.4 * f, "REPLACE")

    # Material
    img = bpy.data.images.load(str(atlas_path))
    img.pack()
    mat = heroine_rig.make_material("GuerrillaHood", img, double_sided=True)
    me.materials.append(mat)
    
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    
    print(f"[guerrilla] capuz novo gerado: {len(me.vertices)} verts, {len(me.polygons)} polígonos")
    return obj
