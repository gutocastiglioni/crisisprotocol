"""Renderiza prévias de um personagem (heroína ou raptor) para conferência visual (Workbench, textura sem filtro).

Uso:
  blender --background art/heroine.blend --python art/preview.py -- <pasta_saida> [turntable|anims|ACAO:frame,frame]
  blender --background art/raptor.blend --python art/preview.py -- <pasta_saida> [...]
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def setup(res=(360, 480)):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_backface_culling = True
    sh.show_shadows = False
    sh.show_specular_highlight = False
    sh.show_cavity = False
    scene.display.render_aa = "OFF"
    world = bpy.data.worlds.new("w") if not scene.world else scene.world
    scene.world = world
    world.color = (0.08, 0.08, 0.09)
    sh.background_type = "WORLD"
    if "PreviewFloor" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=3)
        bpy.context.active_object.name = "PreviewFloor"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


TARGET = Vector((0, 0, 0.88))


def frame_subject(cam, rig):
    """Enquadra o personagem pela caixa da malha em repouso (heroína ~2 m, raptor ~3,6 m)."""
    global TARGET
    pts = [o.matrix_world @ Vector(c) for o in bpy.data.objects if o.type == "MESH" and o.parent == rig for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    TARGET = (lo + hi) * 0.5
    size = hi - lo
    if max(size.x, size.y) > size.z:  # comprido (raptor): quadro em paisagem
        scene = bpy.context.scene
        scene.render.resolution_x, scene.render.resolution_y = 560, 360
    cam.data.ortho_scale = max(size) * 1.15


def aim_camera(cam, yaw_deg, target=None, dist=4.0, pitch_deg=8):
    target = TARGET if target is None else target
    """yaw 0 = de frente (câmera em -Y olhando para +Y)."""
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    pos = target + Vector((math.sin(yaw) * math.cos(pitch) * dist, -math.cos(yaw) * math.cos(pitch) * dist, math.sin(pitch) * dist))
    cam.location = pos
    cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()


def render(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def show_weapon(name):
    """Mostra só a arma da ação (o Godot faz o mesmo): escopeta nas Shotgun*, fuzil nas Rifle*/Pickup, pistola
    nas outras."""
    shown = "Shotgun" if name.startswith("Shotgun") else ("M16" if name.startswith(("Rifle", "Pickup")) else "Pistol")
    for o in bpy.data.objects:
        if o.name in ("Pistol", "M16", "Shotgun", "ShotgunPump"):
            o.hide_render = not o.name.startswith(shown)


def set_action(rig, name):
    show_weapon(name)
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    if hasattr(rig.animation_data, "action_slot") and len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
    return act


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    mode = argv[1] if len(argv) > 1 else "turntable"
    scene, cam = setup()
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rig.animation_data_create()
    frame_subject(cam, rig)
    if mode == "turntable":
        rig.animation_data.action = None
        show_weapon("")
        for yaw in (0, 35, 90, 180, 270):
            aim_camera(cam, yaw)
            render(scene, out / f"turn_{yaw:03d}.png")
        # close do rosto
        head = rig.data.bones["Head"]
        cam.data.ortho_scale = max(0.45, head.length * 2.25)
        aim_camera(cam, 15, target=rig.matrix_world @ ((head.head_local + head.tail_local) * 0.5), pitch_deg=4)
        render(scene, out / "face.png")
        return
    if mode == "anims":
        jobs = []
        for act in bpy.data.actions:
            a, b = int(act.frame_range[0]), int(act.frame_range[1])
            frames = sorted({a, a + (b - a) // 4, a + (b - a) // 2, a + 3 * (b - a) // 4})
            jobs.append((act.name, frames))
    else:
        name, frames = mode.split(":")
        jobs = [(name, [int(f) for f in frames.split(",")])]
    for name, frames in jobs:
        set_action(rig, name)
        for yaw in (35, 90):
            aim_camera(cam, yaw)
            for f in frames:
                scene.frame_set(f)
                render(scene, out / f"{name}_{yaw:03d}_{f:02d}.png")


main()
