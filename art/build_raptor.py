"""Gera o velociraptor inteiro (malha, UV, pesos, esqueleto, animações) e exporta para o Godot.

Uso:
  blender --background --factory-startup --python art/build_raptor.py
Saídas:
  art/raptor.blend
  game/assets/characters/raptor.glb
"""
import sys
from pathlib import Path

import bpy

ART = Path(__file__).resolve().parent
ROOT = ART.parent
sys.path.insert(0, str(ART))

import build_heroine  # noqa: E402
import raptor_anims  # noqa: E402
import raptor_rig  # noqa: E402

ATLAS = ROOT / "game/assets/characters/raptor_atlas.png"
GLB = ROOT / "game/assets/characters/raptor.glb"
BLEND = ART / "raptor.blend"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = raptor_anims.FPS
    rig = raptor_rig.make_armature()
    body = raptor_rig.make_mesh_object(rig, ATLAS)
    raptor_rig.make_mouth(rig)
    acts = raptor_anims.build_actions(rig)
    build_heroine.stats(body, rig, acts)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    build_heroine.export(GLB)


if __name__ == "__main__":
    main()
