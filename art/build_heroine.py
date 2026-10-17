"""Gera a heroína inteira (malha, UV, pesos, esqueleto, animações) e exporta para o Godot.

Uso:
  blender --background --factory-startup --python art/build_heroine.py
Saídas:
  art/heroine.blend
  game/assets/characters/heroine.glb
"""
import sys
from pathlib import Path

import bpy

ART = Path(__file__).resolve().parent
ROOT = ART.parent
sys.path.insert(0, str(ART))

import heroine_anims  # noqa: E402
import heroine_rig  # noqa: E402

ATLAS = ROOT / "game/assets/characters/heroine_atlas.png"
GLB = ROOT / "game/assets/characters/heroine.glb"
BLEND = ART / "heroine.blend"


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = heroine_anims.FPS
    return scene


def stats(mesh_obj, rig, actions):
    me = mesh_obj.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    unweighted = [v.index for v in me.vertices if not v.groups]
    print(f"[heroine] triangulos={tris} vertices={len(me.vertices)} ossos={len(rig.data.bones)}")
    print(f"[heroine] vertices_sem_peso={len(unweighted)}")
    for a in actions:
        print(f"[heroine] acao {a.name}: frames {int(a.frame_range[0])}-{int(a.frame_range[1])}")
    if unweighted:
        raise SystemExit("vértices sem peso de osso")


def export(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_skins=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_step=1,
        export_def_bones=False,
        export_anim_single_armature=True,
    )
    print(f"[heroine] exportado {path}")


def main():
    reset_scene()
    rig = heroine_rig.make_armature()
    body = heroine_rig.make_mesh_object(rig, ATLAS)
    heroine_rig.make_muzzle(rig)
    acts = heroine_anims.build_actions(rig)
    stats(body, rig, acts)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    export(GLB)


if __name__ == "__main__":
    main()
