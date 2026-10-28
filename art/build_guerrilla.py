"""Gera o guerrilheiro encapuzado (pele única: art/guerrilla_body.py, medidas em art/guerrilla_spec.py) no esqueleto e
com as animações da heroína, e exporta para o Godot.

Uso (depois de tools/make_guerrilla_texture.py):
  blender --background --factory-startup --python art/build_guerrilla.py [-- <pasta>]
Sem pasta: art/guerrilla.blend (fora do git, serve para art/preview.py) e game/assets/characters/guerrilla.glb.
Com pasta (prévia, antes de aprovar): lê <pasta>/guerrilla_atlas.png e grava <pasta>/guerrilla.blend e .glb; depois da
pasta, as partes a montar (ex.: "torso" = só o tronco com as pernas, para revisar por partes).
"""
import sys
from pathlib import Path

import bpy

ART = Path(__file__).resolve().parent
ROOT = ART.parent
sys.path.insert(0, str(ART))

import build_heroine  # noqa: E402  (reaproveita reset_scene/stats/export)
import guerrilla_body  # noqa: E402
import guerrilla_spec  # noqa: E402
import heroine_anims  # noqa: E402
import heroine_m79  # noqa: E402
import heroine_moves  # noqa: E402
import heroine_rifle  # noqa: E402
import heroine_rig  # noqa: E402
import heroine_shotgun  # noqa: E402
import heroine_sniper  # noqa: E402
import heroine_spec  # noqa: E402


def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def paths():
    args_ = args()
    if args_:
        out = Path(args_[0]).resolve()
        return out / "guerrilla_atlas.png", out / "guerrilla.glb", out / "guerrilla.blend"
    return ROOT / "game/assets/characters/guerrilla_atlas.png", ROOT / "game/assets/characters/guerrilla.glb", ART / "guerrilla.blend"


def main():
    atlas, glb, blend = paths()
    build_heroine.reset_scene()
    # esqueleto nas juntas dele; poses, borda/obstáculo e fuzil na medida do corpo (como no build da heroína)
    heroine_spec.use_joints(guerrilla_spec.joints())
    heroine_moves.ANKLE_Z = heroine_spec.ANKLE_L.z
    heroine_anims.LOC_SCALE = heroine_anims.leg_scale(heroine_spec.HIP_L.z, heroine_spec.ANKLE_L.z)
    heroine_moves.adapt(heroine_spec)
    heroine_rifle.adapt(heroine_spec)
    rig = heroine_rig.make_armature()
    parts = tuple(args()[1:]) or guerrilla_body.PARTS
    body = guerrilla_body.make_body(rig, atlas, parts)
    heroine_rig.make_weapons(rig, atlas)
    heroine_rig.make_muzzle(rig)
    heroine_rig.make_muzzle(rig, "RifleMuzzle", heroine_rifle.muzzle_position())
    heroine_rig.make_muzzle(rig, "ShotgunMuzzle", heroine_shotgun.muzzle_position())
    heroine_rig.make_muzzle(rig, "M79Muzzle", heroine_m79.muzzle_position())
    heroine_rig.make_muzzle(rig, "SniperMuzzle", heroine_sniper.muzzle_position())
    heroine_rig.make_pump(rig)
    acts = heroine_anims.build_actions(rig)
    build_heroine.stats(body, rig, acts)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    build_heroine.export(glb)


if __name__ == "__main__":
    main()
