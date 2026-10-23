import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import guerrilla_atlas
import heroine_rig
import heroine_spec as S

# =================================================================================================
# GERADOR DE CAPUZ TÁTICO PROFISSIONAL:
# - Silhueta anatômica ajustada: acompanha o crânio sem abas pontudas, sem pirâmide e sem cone largo.
# - Abertura oval realista para o rosto:
#   * Fechado na gola (z = 1.42 a 1.46)
#   * Abertura oval suave do queixo (z = 1.47) à testa (z = 1.63)
#   * Borda superior da testa arredondada (arco suave, sem bico em V)
#   * Cúpula craniana arredondada com topo suave (z = 1.715)
# =================================================================================================

def build_tactical_hood(rig, atlas_path):
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    
    # Parâmetros dos níveis de altura (Z)
    # Formato: (z, y_center, rx, ry_front, ry_back)
    LEVELS = [
        # Gola sobre o colarinho do moletom
        (1.425, -0.005, 0.098, 0.092, 0.095),
        # Base do pescoço
        (1.455, -0.003, 0.090, 0.088, 0.095),
        # Queixo (início da abertura)
        (1.485,  0.000, 0.085, 0.084, 0.100),
        # Mandíbula / boca
        (1.525,  0.003, 0.086, 0.084, 0.105),
        # Bochechas / nariz
        (1.570,  0.005, 0.088, 0.084, 0.108),
        # Olhos / têmporas
        (1.610,  0.006, 0.086, 0.084, 0.108),
        # Testa / arco da sobrancelha (fim da abertura)
        (1.645,  0.007, 0.082, 0.082, 0.102),
        # Testa alta (fechado sobre a fronte)
        (1.675,  0.008, 0.076, 0.076, 0.092),
        # Calota superior
        (1.700,  0.010, 0.060, 0.060, 0.072),
        # Topo arredondado da cúpula
        (1.715,  0.012, 0.035, 0.035, 0.042),
    ]
    
    # Meia-abertura em X da face em cada nível (0.0 = fechado)
    # Curva oval natural: abre no queixo, alarga nos olhos, fecha na testa
    OPEN_HX = [
        0.000,  # 1.425: fechado
        0.000,  # 1.455: fechado
        0.032,  # 1.485: queixo
        0.046,  # 1.525: mandíbula
        0.054,  # 1.570: bochechas
        0.052,  # 1.610: olhos
        0.000,  # 1.645: testa (borda superior fecha aqui!)
        0.000,  # 1.675: fechado
        0.000,  # 1.700: fechado
        0.000,  # 1.715: fechado
    ]
    
    # Ponto culminante da cúpula
    TOP_Z = 1.722
    TOP_Y = 0.013
    
    # Discretização angular:
    # Usaremos 16 colunas em volta da cabeça para curvas bem suaves
    # Coluna 0: borda esquerda da abertura (ou centro frontal quando fechado)
    # Coluna 8: nuca (meio das costas, +Y)
    # Coluna 16: borda direita da abertura (ou centro frontal quando fechado)
    N_COLS = 16
    
    grid_verts = []
    
    for lvl_idx, (z, yc, rx, ry_f, ry_b) in enumerate(LEVELS):
        hx = OPEN_HX[lvl_idx]
        is_open = (hx > 0.001)
        row = []
        
        if not is_open:
            # Anel 360 fechado
            # phi vai de -pi (frente) a 0 (nuca) a +pi (frente)
            for col in range(N_COLS + 1):
                t = col / N_COLS  # 0 a 1
                phi = -math.pi + 2.0 * math.pi * t
                cp = math.cos(phi)
                sp = math.sin(phi)
                # cp < 0 é frente (-Y), cp > 0 é costas (+Y)
                ry = ry_b if cp >= 0 else ry_f
                x = rx * sp
                y = yc + cp * ry
                # Quando t=0 ou t=1, x deve ser exatamente 0.0
                if col in (0, N_COLS):
                    x = 0.0
                    y = yc - ry_f
                v = bm.verts.new(Vector((x, y, z)))
                row.append(v)
        else:
            # Anel aberto na frente para o rosto
            # phi_open é o ângulo da abertura
            sin_open = min(0.95, max(0.10, hx / max(rx, 1e-4)))
            phi_open = math.asin(sin_open)
            # Arco coberto vai de (-pi + phi_open) até (+pi - phi_open)
            # t=0 -> -pi + phi_open (borda esquerda)
            # t=0.5 -> 0 (nuca)
            # t=1 -> +pi - phi_open (borda direita)
            phi_start = -math.pi + phi_open
            phi_end = math.pi - phi_open
            
            for col in range(N_COLS + 1):
                t = col / N_COLS
                phi = phi_start + t * (phi_end - phi_start)
                cp = math.cos(phi)
                sp = math.sin(phi)
                ry = ry_b if cp >= 0 else ry_f
                x = rx * sp
                y = yc + cp * ry
                if col == 0:
                    x = -hx
                    y = yc - ry_f * math.cos(phi_open)
                elif col == N_COLS:
                    x = hx
                    y = yc - ry_f * math.cos(phi_open)
                v = bm.verts.new(Vector((x, y, z)))
                row.append(v)
                
        grid_verts.append((row, is_open))
        
    v_top = bm.verts.new(Vector((0.0, TOP_Y, TOP_Z)))
    bm.verts.ensure_lookup_table()
    
    # Cria faces conectando as camadas
    n_lvls = len(LEVELS)
    for i in range(n_lvls - 1):
        row0, open0 = grid_verts[i]
        row1, open1 = grid_verts[i + 1]
        v_coord0 = i / (n_lvls - 1)
        v_coord1 = (i + 1) / (n_lvls - 1)
        
        # Conecta as colunas
        for col in range(N_COLS):
            v0_a = row0[col]
            v0_b = row0[col + 1]
            v1_a = row1[col]
            v1_b = row1[col + 1]
            
            # Se for transição entre fechado e aberto no queixo (open0=False, open1=True):
            # No centro da frente (col=0 e col=N_COLS-1), v0_a e v0_b são o mesmo vértice ou muito próximos
            # Criamos o quad normal
            f = bm.faces.new([v0_a, v1_a, v1_b, v0_b])
            u0 = col / N_COLS
            u1 = (col + 1) / N_COLS
            f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0, v_coord0)
            f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", u0, v_coord1)
            f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1, v_coord1)
            f.loops[3][uv_layer].uv = guerrilla_atlas.uv("hair", u1, v_coord0)
            
    # Cúpula do topo (conecta o último anel com v_top)
    last_row, _ = grid_verts[-1]
    last_v = (n_lvls - 1) / (n_lvls - 1)
    for col in range(N_COLS):
        v_a = last_row[col]
        v_b = last_row[col + 1]
        f = bm.faces.new([v_a, v_top, v_b])
        u0 = col / N_COLS
        u1 = (col + 1) / N_COLS
        f.loops[0][uv_layer].uv = guerrilla_atlas.uv("hair", u0, 0.94)
        f.loops[1][uv_layer].uv = guerrilla_atlas.uv("hair", (u0 + u1) * 0.5, 1.0)
        f.loops[2][uv_layer].uv = guerrilla_atlas.uv("hair", u1, 0.94)
        
    # Borda dobrada para dentro na abertura do rosto (dá espessura de tecido)
    # Adiciona uma fita dobrada de 6mm para dentro ao longo das bordas da abertura
    open_indices = [idx for idx, (_, is_open) in enumerate(grid_verts) if is_open]
    for side_col in (0, N_COLS):
        rim_line = []
        sign = -1 if side_col == 0 else 1
        for idx in open_indices:
            v_edge = grid_verts[idx][0][side_col]
            v_inner = bm.verts.new(v_edge.co + Vector((-sign * 0.006, 0.005, 0.0)))
            rim_line.append((v_edge, v_inner, idx))
            
        for k in range(len(rim_line) - 1):
            vo0, vi0, idx0 = rim_line[k]
            vo1, vi1, idx1 = rim_line[k + 1]
            if side_col == 0:
                f = bm.faces.new([vo0, vo1, vi1, vi0])
            else:
                f = bm.faces.new([vo0, vi0, vi1, vo1])
            u_val = 0.02 if side_col == 0 else 0.98
            v_a = idx0 / (n_lvls - 1)
            v_b = idx1 / (n_lvls - 1)
            for loop in f.loops:
                loop[uv_layer].uv = guerrilla_atlas.uv("hair", u_val, v_a if loop.vert in (vo0, vi0) else v_b)

    # Weld vertices duplicados no centro fechado se houver (para garantir malha contínua)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    
    # Cria objeto
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
            
    img = bpy.data.images.load(str(atlas_path))
    img.pack()
    mat = heroine_rig.make_material("GuerrillaHood", img, double_sided=True)
    me.materials.append(mat)
    
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    
    print(f"[guerrilla] capuz tático gerado: {len(me.vertices)} verts, {len(me.polygons)} polígonos")
    return obj
