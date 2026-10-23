import bpy
import math
import os

bpy.ops.wm.read_factory_settings(use_empty=True)

glb_path = r"D:\Projetos\crisisprotocol\game\assets\characters\guerrilla.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderEngine') else 'CYCLES'
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024

world = bpy.data.worlds.new("StudioWorld")
scene.world = world
world.use_nodes = True
bg_node = world.node_tree.nodes.get("Background")
if bg_node:
    bg_node.inputs[0].default_value = (0.12, 0.12, 0.15, 1.0)
    bg_node.inputs[1].default_value = 1.0

def add_sun(name, energy, rot):
    light_data = bpy.data.lights.new(name=name, type='SUN')
    light_data.energy = energy
    light_obj = bpy.data.objects.new(name=name, object_data=light_data)
    scene.collection.objects.link(light_obj)
    light_obj.rotation_euler = rot
    return light_obj

add_sun("Key", 4.5, (math.radians(45), math.radians(25), math.radians(35)))
add_sun("Fill", 2.5, (math.radians(35), math.radians(-25), math.radians(-135)))
add_sun("Rim", 3.0, (math.radians(-30), math.radians(0), math.radians(180)))

# Set Idle animation
armature = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
actions = {a.name: a for a in bpy.data.actions}
if "Idle" in actions and armature:
    armature.animation_data_create()
    armature.animation_data.action = actions["Idle"]
    scene.frame_set(1)

# Hide weapons
for obj in bpy.data.objects:
    nl = obj.name.lower()
    if any(w in nl for w in ["pistol", "m16", "m79", "shotgun", "sniper"]):
        obj.hide_render = True

cam_data = bpy.data.cameras.new(name="Cam")
cam_obj = bpy.data.objects.new(name="Cam", object_data=cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

out_dir = r"D:\Projetos\crisisprotocol\art"

# Pelvis / Crotch / Glute Close-up camera shots: (name, dist, target_z, pitch_deg, yaw_deg)
shots = [
    ("guerrilla_crotch_close_front", 1.25, 0.82, 86, 0),         # Frente virilha
    ("guerrilla_crotch_close_back", 1.25, 0.82, 86, 180),        # Trás bunda/glúteos
    ("guerrilla_crotch_side_right", 1.25, 0.82, 86, 90),         # Perfil lateral da pelve
    ("guerrilla_crotch_angle_back", 1.25, 0.82, 84, 150),        # 3/4 traseiro glúteo
    ("guerrilla_crotch_angle_front", 1.25, 0.82, 84, 30),        # 3/4 frontal virilha
]

for name, dist, tz, pitch, yaw in shots:
    rad = math.radians(yaw)
    cx = -dist * math.sin(rad)
    cy = -dist * math.cos(rad)
    cz = tz + 0.05
    cam_obj.location = (cx, cy, cz)
    cam_obj.rotation_euler = (math.radians(pitch), 0, -rad)
    scene.render.filepath = os.path.join(out_dir, f"{name}.png")
    bpy.ops.render.render(write_still=True)

print("CLOSEUPS_DONE")
