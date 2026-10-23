import bpy
import math
from mathutils import Matrix, Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'game/assets/characters/guerrilla.glb')
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderEngine') else 'CYCLES'
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.film_transparent = True

# 3-point lighting
def add_sun(name, energy, rot):
    light_data = bpy.data.lights.new(name=name, type='SUN')
    light_data.energy = energy
    light_obj = bpy.data.objects.new(name=name, object_data=light_data)
    scene.collection.objects.link(light_obj)
    light_obj.rotation_euler = rot
    return light_obj

add_sun("Key", 3.5, (math.radians(50), math.radians(20), math.radians(30)))
add_sun("Fill", 1.8, (math.radians(40), math.radians(-20), math.radians(-120)))
add_sun("Rim", 2.2, (math.radians(-30), math.radians(0), math.radians(180)))

arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
if arm.animation_data:
    arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.matrix_basis.identity()

bpy.context.view_layer.update()

# Reference Arm angles in coronal plane matching media_1792589449209_208716b3.png:
# UpperArm: 43.0 deg from vertical down
# LowerArm: 46.8 deg from vertical down
# Hand:     34.1 deg from vertical down

for side, k in [("L", 1), ("R", -1)]:
    pb_u = arm.pose.bones[f'UpperArm_{side}']
    pb_l = arm.pose.bones[f'LowerArm_{side}']
    pb_h = arm.pose.bones[f'Hand_{side}']

    want_u = Vector((k * math.sin(math.radians(43.0)), 0, -math.cos(math.radians(43.0))))
    want_l = Vector((k * math.sin(math.radians(46.8)), 0, -math.cos(math.radians(46.8))))
    want_h = Vector((k * math.sin(math.radians(34.1)), 0, -math.cos(math.radians(34.1))))

    for pb, want in [(pb_u, want_u), (pb_l, want_l), (pb_h, want_h)]:
        cur = (pb.tail - pb.head).normalized()
        q = cur.rotation_difference(want)
        m_head = Matrix.Translation(pb.head)
        pb.matrix = m_head @ q.to_matrix().to_4x4() @ m_head.inverted() @ pb.matrix
        bpy.context.view_layer.update()

# Hide all firearms so the silhouette compares purely the character's body
for obj in bpy.data.objects:
    nl = obj.name.lower()
    if any(w in nl for w in ["pistol", "m16", "m79", "shotgun", "sniper"]):
        obj.hide_render = True

# Ortho camera matching reference (H: 1.80m, ground at Y=987, head crown at Y=94)
cam_data = bpy.data.cameras.new(name="OrthoCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 2.06405
cam_obj = bpy.data.objects.new(name="OrthoCam", object_data=cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.location = (-0.004, -3.0, 0.95745)
cam_obj.rotation_euler = (math.radians(90), 0, 0)

out_path = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\cur_render_apose.png"
scene.render.filepath = out_path
bpy.ops.render.render(write_still=True)
print("Rendered mathematically aligned A-pose:", out_path)
