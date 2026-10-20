"""Esqueleto, objeto da malha, materiais e marcador do cano da pistola."""
import bpy
from mathutils import Matrix, Vector

import heroine_mesh
import heroine_spec as S

FORWARD = Vector((0, -1, 0))
UP = Vector((0, 0, 1))


def make_armature(name="HeroineRig"):
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent in S.bones():
        eb = arm.edit_bones.new(bname)
        eb.head, eb.tail = head, tail
        # Z local para a frente em todos os ossos (pé: Z para cima). Assim +X local = dobrar "para a frente".
        eb.align_roll(UP if bname.startswith("Foot") else FORWARD)
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in obj.pose.bones:
        pb.rotation_mode = "ZYX"
    return obj


def make_material(name, image, double_sided):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = not double_sided
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def _skinned_object(rig, name, mb, materials):
    me = bpy.data.meshes.new(name + "Mesh")
    mb.bm.normal_update()
    mb.bm.to_mesh(me)
    mb.bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for n in S.BONE_NAMES:
        obj.vertex_groups.new(name=n)
    for mat in materials:
        me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = True
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def make_weapons(rig, image_path):
    """Só as armas em malhas à parte ("Pistol", "M16", "Shotgun", "M79"), com o atlas (o corpo vem de outro lugar:
    art/heroine_body.py)."""
    image = bpy.data.images.load(str(image_path))
    image.pack()
    body = make_material("HeroineBody", image, double_sided=False)
    for name, kind in (("Pistol", "pistol"), ("M16", "rifle"), ("Shotgun", "shotgun"), ("M79", "m79")):
        part = _skinned_object(rig, name, heroine_mesh.build_weapon(S.BONE_NAMES, kind), [body])
        for poly in part.data.polygons:
            poly.use_smooth = False  # arma: arestas duras


def make_mesh_object(rig, image_path):
    """Corpo ("Heroine") + armas em malhas à parte ("Pistol", "M16", "Shotgun", "M79"), todas com o mesmo atlas."""
    image = bpy.data.images.load(str(image_path))
    image.pack()
    body = make_material("HeroineBody", image, double_sided=False)
    hair = make_material("HeroineHair", image, double_sided=True)
    obj = _skinned_object(rig, "Heroine", heroine_mesh.build_all(S.BONE_NAMES), [body, hair])
    for name, kind in (("Pistol", "pistol"), ("M16", "rifle"), ("Shotgun", "shotgun"), ("M79", "m79")):
        part = _skinned_object(rig, name, heroine_mesh.build_weapon(S.BONE_NAMES, kind), [body])
        for poly in part.data.polygons:
            poly.use_smooth = False  # arma: arestas duras
    return obj


def make_muzzle(rig, name="Muzzle", position=None):
    """Empty filho do osso Hand_R: o Godot importa como BoneAttachment3D com o nó `name` (cano da arma)."""
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_size = 0.03
    bpy.context.scene.collection.objects.link(empty)
    empty.parent = rig
    empty.parent_type = "BONE"
    empty.parent_bone = "Hand_R"
    bone = rig.data.bones["Hand_R"]
    # parent_type BONE usa a cauda do osso como origem
    bone_tail_mat = rig.matrix_world @ bone.matrix_local @ Matrix.Translation((0, bone.length, 0))
    empty.matrix_parent_inverse = Matrix.Identity(4)
    pos = heroine_mesh.muzzle_position() if position is None else position
    empty.matrix_basis = bone_tail_mat.inverted() @ Matrix.Translation(pos)
    return empty


def _bone_tail(rig, bone_name):
    bone = rig.data.bones[bone_name]
    # parent_type BONE usa a cauda do osso como origem
    return rig.matrix_world @ bone.matrix_local @ Matrix.Translation((0, bone.length, 0))


def make_pump(rig):
    """Telha da escopeta: malha rígida filha do osso Hand_R (não deformada), para o Godot deslizá-la no
    bombeamento. Origem no centro da telha, eixos da arma (o Godot a move ao longo do cano = -Z local)."""
    import heroine_shotgun

    mb = heroine_mesh.MeshBuilder(S.BONE_NAMES)
    heroine_shotgun.build_pump(mb, Matrix.Identity(4), {"Hand_R": 1})
    me = bpy.data.meshes.new("ShotgunPumpMesh")
    mb.bm.normal_update()
    mb.bm.to_mesh(me)
    mb.bm.free()
    me.materials.append(bpy.data.materials["HeroineBody"])
    for poly in me.polygons:
        poly.use_smooth = False
    obj = bpy.data.objects.new("ShotgunPump", me)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = "Hand_R"
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = _bone_tail(rig, "Hand_R").inverted() @ heroine_shotgun.pump_rest()
    return obj
