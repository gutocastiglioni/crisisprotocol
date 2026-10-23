import bpy
import math

bpy.ops.wm.read_factory_settings(use_empty=True)
glb_path = r"D:\Projetos\crisisprotocol\game\assets\characters\guerrilla.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderEngine') else 'CYCLES'
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.film_transparent = True

# Add 3-point lighting
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

armature = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
if armature:
    if armature.animation_data:
        armature.animation_data.action = None
    for pb in armature.pose.bones:
        pb.matrix_basis.identity()

# Hide firearms except sniper to match reference
for obj in bpy.data.objects:
    nl = obj.name.lower()
    if any(w in nl for w in ["pistol", "m16", "m79", "shotgun"]):
        obj.hide_render = True
    elif "sniper" in nl:
        obj.hide_render = False

# Ortho camera matching reference
cam_data = bpy.data.cameras.new(name="OrthoCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 2.064
cam_obj = bpy.data.objects.new(name="OrthoCam", object_data=cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.location = (0.0, -3.0, 0.8426)
cam_obj.rotation_euler = (math.radians(90), 0, 0)

out_path = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\cur_render_rest.png"
scene.render.filepath = out_path
bpy.ops.render.render(write_still=True)
print("Rendered:", out_path)
