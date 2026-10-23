import bpy
import math
import os
import numpy as np

# 1. Reset scene completely
bpy.ops.wm.read_factory_settings(use_empty=True)

# 2. Import current guerrilla.glb
glb_path = r"D:\Projetos\crisisprotocol\game\assets\characters\guerrilla.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderEngine') else 'CYCLES'
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024

# Set world background to transparent or pure black
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg_node = world.node_tree.nodes.get("Background")
if bg_node:
    bg_node.inputs[0].default_value = (0.0, 0.0, 0.0, 1.0)
    bg_node.inputs[1].default_value = 1.0

# Add lighting
light_data = bpy.data.lights.new(name="Sun", type='SUN')
light_data.energy = 5.0
light_obj = bpy.data.objects.new(name="Sun", object_data=light_data)
scene.collection.objects.link(light_obj)
light_obj.rotation_euler = (math.radians(50), 0, math.radians(20))

# Armature and pose
armature = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
if armature:
    # Set to rest pose (or clear actions)
    if armature.animation_data:
        armature.animation_data.action = None
    for pb in armature.pose.bones:
        pb.matrix_basis.identity()

# Hide firearms except sniper if sniper is in reference, or hide all firearms
for obj in bpy.data.objects:
    nl = obj.name.lower()
    if any(w in nl for w in ["pistol", "m16", "m79", "shotgun"]):
        obj.hide_render = True
    elif "sniper" in nl:
        obj.hide_render = False

# Ortho camera matching reference scale
# Reference 1024x1024:
# Character height in ref is ~902 px = 1.80m -> 501.1 px/m -> ortho_scale = 1024 / 501.1 = 2.0435
# Character center Z = ~0.958m
cam_data = bpy.data.cameras.new(name="OrthoCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 2.0435
cam_obj = bpy.data.objects.new(name="OrthoCam", object_data=cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj
cam_obj.location = (0.0, -3.0, 0.958)
cam_obj.rotation_euler = (math.radians(90), 0, 0)

out_render = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\current_front_ortho.png"
scene.render.filepath = out_render
bpy.ops.render.render(write_still=True)
print("Rendered current front ortho to:", out_render)
