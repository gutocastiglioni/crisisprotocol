import bpy
import math
import os

# Reset
bpy.ops.wm.read_factory_settings(use_empty=True)

# Import guerrilla.glb
glb_path = r"D:\Projetos\crisisprotocol\game\assets\characters\guerrilla.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderEngine') else 'CYCLES'
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024

# Set background
world = bpy.data.worlds.new("StudioWorld")
scene.world = world
world.use_nodes = True
bg_node = world.node_tree.nodes.get("Background")
if bg_node:
    bg_node.inputs[0].default_value = (0.10, 0.10, 0.12, 1.0)
    bg_node.inputs[1].default_value = 1.0

# 3-point Lighting
def add_sun(name, energy, rot):
    light_data = bpy.data.lights.new(name=name, type='SUN')
    light_data.energy = energy
    light_obj = bpy.data.objects.new(name=name, object_data=light_data)
    scene.collection.objects.link(light_obj)
    light_obj.rotation_euler = rot
    return light_obj

add_sun("Key", 4.0, (math.radians(50), math.radians(20), math.radians(30)))
add_sun("Fill", 2.0, (math.radians(40), math.radians(-20), math.radians(-120)))
add_sun("Rim", 2.5, (math.radians(-30), math.radians(0), math.radians(180)))

# Find armature
armature = None
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        armature = obj
        break

# Set Idle animation (repouso)
actions = {a.name: a for a in bpy.data.actions}
if "Idle" in actions and armature:
    armature.animation_data_create()
    armature.animation_data.action = actions["Idle"]
    scene.frame_set(1)

# In repouso, hide firearms so we see the character cleanly
for obj in bpy.data.objects:
    nl = obj.name.lower()
    if any(w in nl for w in ["pistol", "m16", "m79", "shotgun"]):
        obj.hide_render = True

# Add Camera
cam_data = bpy.data.cameras.new(name="Cam")
cam_obj = bpy.data.objects.new(name="Cam", object_data=cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

out_dir = r"D:\Projetos\crisisprotocol\art"

# Angles definition: (name, distance, z, target_z, angle_deg)
# Full body turnaround
angles = [
    ("front", 0),
    ("front_right", 45),
    ("right", 90),
    ("back_right", 135),
    ("back", 180),
    ("back_left", 225),
    ("left", 270),
    ("front_left", 315),
]

for name, deg in angles:
    rad = math.radians(deg)
    dist = 2.8
    # camera circles around center (0, 0, 0.9)
    cx = -dist * math.sin(rad)
    cy = -dist * math.cos(rad)
    cz = 1.05
    cam_obj.location = (cx, cy, cz)
    # look at (0, 0, 0.9)
    cam_obj.rotation_euler = (math.radians(87), 0, -rad)
    scene.render.filepath = os.path.join(out_dir, f"guerrilla_idle_{name}.png")
    bpy.ops.render.render(write_still=True)

# Face Close-ups (Head turnaround)
face_angles = [
    ("face_front", 0),
    ("face_three_quarter", 35),
    ("face_profile", 80),
    ("face_three_quarter_left", 325),
]

for name, deg in face_angles:
    rad = math.radians(deg)
    dist = 0.95
    cx = -dist * math.sin(rad)
    cy = -dist * math.cos(rad)
    cz = 1.56
    cam_obj.location = (cx, cy, cz)
    cam_obj.rotation_euler = (math.radians(90), 0, -rad)
    scene.render.filepath = os.path.join(out_dir, f"guerrilla_{name}.png")
    bpy.ops.render.render(write_still=True)

print("ALL_ANGLES_DONE")
