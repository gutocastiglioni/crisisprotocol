"""Calça cargo camuflada, cinto com bolsas, coldre e coturnos do guerrilheiro: a parte de baixo de
possible_models/tr_guerilla.glb, mantida como está por decisão do usuário (exceção à regra de possible_models no
CLAUDE.md). Entra na cintura da parte de cima (art/guerrilla_body.py) por baixo do cinto, como no modelo original.
Só muda o que liga ao nosso esqueleto: cada perna é levada à linha dos ossos (`_align_legs`) e os pesos seguem as
juntas de art/guerrilla_spec.py; a forma (escala, cintura) é a de antes.
"""
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parent.parent
TR_PATH = ROOT / "possible_models/tr_guerilla.glb"
BELT_TOP = 0.969  # alto do cinto (a calça é escalada até aqui; a referência mede 0,968)
WAIST_FIT_Z = 1.014  # altura de onde a cintura da calça começa a ser ajustada (a de antes; não mexer = mesma forma)


def _bone_x(z, joints):
    """x da linha do osso da perna esquerda (quadril -> joelho -> tornozelo) na altura z; abaixo do tornozelo, a dele."""
    hip, knee, ankle = joints["hip"], joints["knee"], joints["ankle"]
    if z >= knee.z:
        return knee.x + (hip.x - knee.x) * min(1.0, (z - knee.z) / (hip.z - knee.z))
    return ankle.x + (knee.x - ankle.x) * max(0.0, (z - ankle.z) / (knee.z - ankle.z))


def _align_legs(bm, joints, step=0.02):
    """Põe cada perna da calça (e o coturno) na linha dos ossos dela: a calça veio com as pernas juntas e o coturno
    ficava ~4 cm para dentro do tornozelo (o pé girava fora dele). O centro de cada perna é medido por faixa de
    altura (meio entre as bordas, sem as pontas dos bolsos) e levado ao osso; perto do gancho o ajuste some."""
    top = WAIST_FIT_Z - 0.10  # gancho: acima daqui a calça fica como está
    full = joints["knee"].z + 0.05  # daqui para baixo o ajuste é inteiro
    centers = {}
    for k in (1, -1):
        rows = []
        for i in range(int(top / step) + 1):
            xs = sorted(v.co.x * k for v in bm.verts if i * step <= v.co.z < (i + 1) * step and v.co.x * k > 0.01)
            if len(xs) >= 4:
                rows.append(((i + 0.5) * step, (xs[len(xs) // 20] + xs[-1 - len(xs) // 20]) * 0.5))
        # média de 5 faixas: a borda de um bolso não puxa o centro
        centers[k] = [(z, sum(c for _, c in rows[max(0, j - 2):j + 3]) / len(rows[max(0, j - 2):j + 3]))
                      for j, (z, _) in enumerate(rows)]

    def center(k, z):
        rows = centers[k]
        if z <= rows[0][0]:
            return rows[0][1]
        for (z0, c0), (z1, c1) in zip(rows, rows[1:]):
            if z <= z1:
                return c0 + (c1 - c0) * (z - z0) / (z1 - z0)
        return rows[-1][1]

    moved = 0.0
    for v in bm.verts:
        z = v.co.z
        if z >= top:
            continue
        t = min(1.0, (top - z) / (top - full))
        fade = t * t * (3 - 2 * t)
        k = 1 if v.co.x >= 0 else -1
        dx = (_bone_x(z, joints) - center(k, z)) * fade
        v.co.x += k * dx
        moved = max(moved, abs(dx))
    print(f"[guerrilla] pernas da calça na linha dos ossos: até {moved * 100:.1f} cm")


def import_lower(joints):
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
    target_top = BELT_TOP
    scale_z = target_top / (belt_z - min_z)
    scale_xy = 0.0225

    for v in bm.verts:
        p_z = (v.co.z - min_z) * scale_z
        # Alinhamento da cintura/cinto para proporção harmônica com o colete
        if p_z > WAIST_FIT_Z - 0.20:
            u_w = min(1.0, max(0.0, (p_z - (WAIST_FIT_Z - 0.20)) / 0.15))
            w_fit = (1.0 - u_w) + u_w * (scale_z / scale_xy)
        else:
            w_fit = 1.0
        v.co.z = p_z
        v.co.x = v.co.x * scale_xy * w_fit
        v.co.y = (v.co.y + 0.6) * scale_xy * w_fit
    _align_legs(bm, joints)

    me_lower = bpy.data.meshes.new("LowerPartMesh")
    bm.to_mesh(me_lower)
    bm.free()

    if me_lower.uv_layers:
        me_lower.uv_layers[0].name = "UVMap"  # o mesmo nome da camada da parte de cima (a junção casa por nome)

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
