"""Gera o guerrilheiro encapuzado sobre o modelo base (art/base_body/ + art/guerrilla_mesh.py) e exporta para o Godot.

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
import heroine_body  # noqa: E402
import heroine_m79  # noqa: E402
import heroine_moves  # noqa: E402
import heroine_rifle  # noqa: E402
import heroine_sniper  # noqa: E402
import heroine_rig  # noqa: E402
import heroine_shotgun  # noqa: E402
import heroine_spec  # noqa: E402

ATLAS = ROOT / "game/assets/characters/guerrilla_atlas.png"
GLB = ROOT / "game/assets/characters/guerrilla.glb"
BLEND = ART / "guerrilla.blend"


def main():
    scene = build_heroine.reset_scene()
    body, joints = guerrilla_mesh.prepare()
    scene.render.fps = heroine_anims.FPS  # a importação do FBX troca o fps da cena (24): as animações são a 30
    heroine_spec.use_joints(joints)
    heroine_moves.ANKLE_Z = heroine_spec.ANKLE_L.z
    heroine_anims.LOC_SCALE = heroine_anims.leg_scale(heroine_spec.HIP_L.z, heroine_spec.ANKLE_L.z)
    heroine_moves.adapt(heroine_spec)
    heroine_rifle.adapt(heroine_spec)
    guerrilla_mesh.adapt_anims(heroine_anims)
    rig = heroine_rig.make_armature()
    heroine_body.bind(body, rig)
    heroine_rig.make_weapons(rig, ATLAS)
    guerrilla_mesh.make_hood(rig, ATLAS)
    guerrilla_mesh.make_gear(rig, ATLAS)
    heroine_rig.make_muzzle(rig)
    heroine_rig.make_muzzle(rig, "RifleMuzzle", heroine_rifle.muzzle_position())
    heroine_rig.make_muzzle(rig, "ShotgunMuzzle", heroine_shotgun.muzzle_position())
    heroine_rig.make_muzzle(rig, "M79Muzzle", heroine_m79.muzzle_position())
    heroine_rig.make_muzzle(rig, "SniperMuzzle", heroine_sniper.muzzle_position())
    heroine_rig.make_pump(rig)
    acts = heroine_anims.build_actions(rig)
    build_heroine.stats(body, rig, acts)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    build_heroine.export(GLB)


if __name__ == "__main__":
    main()
