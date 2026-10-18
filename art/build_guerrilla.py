"""Gera o guerrilheiro encapuzado (esqueleto e animações da heroína, corpo e capuz próprios) e exporta para o Godot.

Uso (depois de tools/make_guerrilla_texture.py):
  blender --background --factory-startup --python art/build_guerrilla.py
Saídas:
  art/guerrilla.blend (fora do git, como heroine.blend; serve para art/preview.py)
  game/assets/characters/guerrilla.glb
"""
import sys
from pathlib import Path

import bpy

ART = Path(__file__).resolve().parent
ROOT = ART.parent
sys.path.insert(0, str(ART))

import build_heroine  # noqa: E402  (reaproveita reset_scene/stats/export)
import guerrilla_mesh  # noqa: E402
import heroine_anims  # noqa: E402
import heroine_mesh  # noqa: E402
import heroine_rifle  # noqa: E402
import heroine_rig  # noqa: E402
import heroine_shotgun  # noqa: E402

ATLAS = ROOT / "game/assets/characters/guerrilla_atlas.png"
GLB = ROOT / "game/assets/characters/guerrilla.glb"
BLEND = ART / "guerrilla.blend"


def main():
    build_heroine.reset_scene()
    # a heroína monta o corpo com heroine_mesh.build_all; aqui entra o do guerrilheiro (as armas são as mesmas)
    heroine_mesh.build_all = guerrilla_mesh.build_all
    rig = heroine_rig.make_armature()
    body = heroine_rig.make_mesh_object(rig, ATLAS)
    heroine_rig.make_muzzle(rig)
    heroine_rig.make_muzzle(rig, "RifleMuzzle", heroine_rifle.muzzle_position())
    heroine_rig.make_muzzle(rig, "ShotgunMuzzle", heroine_shotgun.muzzle_position())
    heroine_rig.make_pump(rig)
    acts = heroine_anims.build_actions(rig)
    build_heroine.stats(body, rig, acts)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    build_heroine.export(GLB)


if __name__ == "__main__":
    main()
