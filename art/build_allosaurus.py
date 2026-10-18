"""Gera o alossauro inteiro (malha, UV, pesos, esqueleto, animações) e exporta para o Godot.

Uso:
  blender --background --factory-startup --python art/build_allosaurus.py
Saídas:
  art/allosaurus.blend (fora do git)
  game/assets/characters/allosaurus.glb
"""
import sys
from pathlib import Path

import bpy

ART = Path(__file__).resolve().parent
ROOT = ART.parent
sys.path.insert(0, str(ART))

import allosaurus_anims  # noqa: E402
import allosaurus_mesh  # noqa: E402
import allosaurus_spec  # noqa: E402
import build_heroine  # noqa: E402
import raptor_rig  # noqa: E402

ATLAS = ROOT / "game/assets/characters/allosaurus_atlas.png"
GLB = ROOT / "game/assets/characters/allosaurus.glb"
BLEND = ART / "allosaurus.blend"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = allosaurus_anims.FPS
    rig = raptor_rig.make_armature("AllosaurusRig", allosaurus_spec)
    body = raptor_rig.make_mesh_object(rig, ATLAS, allosaurus_spec, allosaurus_mesh, "Allosaurus")
    raptor_rig.make_mouth(rig, allosaurus_spec)
    acts = allosaurus_anims.build_actions(rig)
    build_heroine.stats(body, rig, acts)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    build_heroine.export(GLB)


if __name__ == "__main__":
    main()
