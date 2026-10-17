"""Esqueleto, objeto da malha, materiais e marcador da boca do raptor."""
import bpy
from mathutils import Matrix, Vector

import raptor_mesh
import raptor_spec as S
from heroine_rig import make_material

ROLL = {"up": Vector((0, 0, 1)), "fwd": Vector((0, -1, 0))}


def make_armature(name="RaptorRig"):
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent, roll in S.bones():
        eb = arm.edit_bones.new(bname)
        eb.head, eb.tail = head, tail
        eb.align_roll(ROLL[roll])
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in obj.pose.bones:
        pb.rotation_mode = "ZYX"
    return obj


def make_mesh_object(rig, image_path):
    mb = raptor_mesh.build_all(S.BONE_NAMES)
    me = bpy.data.meshes.new("RaptorMesh")
    mb.bm.normal_update()
    mb.bm.to_mesh(me)
    mb.bm.free()
    obj = bpy.data.objects.new("Raptor", me)
    bpy.context.scene.collection.objects.link(obj)
    for n in S.BONE_NAMES:
        obj.vertex_groups.new(name=n)
    image = bpy.data.images.load(str(image_path))
    image.pack()
    me.materials.append(make_material("RaptorSkin", image, double_sided=False))
    me.materials.append(make_material("RaptorTeeth", image, double_sided=True))
    for poly in me.polygons:
        poly.use_smooth = True
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def make_mouth(rig):
    """Empty filho do osso Head: no Godot vira BoneAttachment3D com o nó "Mouth" (onde a presa fica presa)."""
    empty = bpy.data.objects.new("Mouth", None)
    empty.empty_display_size = 0.05
    bpy.context.scene.collection.objects.link(empty)
    empty.parent = rig
    empty.parent_type = "BONE"
    empty.parent_bone = "Head"
    bone = rig.data.bones["Head"]
    bone_tail_mat = rig.matrix_world @ bone.matrix_local @ Matrix.Translation((0, bone.length, 0))
    empty.matrix_parent_inverse = Matrix.Identity(4)
    empty.matrix_basis = bone_tail_mat.inverted() @ Matrix.Translation(S.MOUTH)
    return empty
