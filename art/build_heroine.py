"""Gera a heroína inteira (malha, UV, pesos, esqueleto, animações) e exporta para o Godot.

Uso:
  blender --background --factory-startup --python art/build_heroine.py
Saídas:
  art/heroine.blend
  game/assets/characters/heroine.glb
  game/assets/characters/m16.glb, shotgun.glb e m79.glb (as armas deitadas no baú, em relação à raiz dela ajoelhada)
  game/assets/characters/pistol_sd.glb (a pistola com silenciador sozinha: tela do item) e pistol_crate.glb (a mesma
    deitada na caixa de paraquedas, em relação à raiz dela ajoelhada: heroine_drop)
  game/assets/characters/heroine_moves.json (caminhos da raiz e medidas dos movimentos, lidos pelo Godot)
"""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

ART = Path(__file__).resolve().parent
ROOT = ART.parent
sys.path.insert(0, str(ART))

import heroine_anims  # noqa: E402
import heroine_drop  # noqa: E402
import heroine_m79  # noqa: E402
import heroine_mesh  # noqa: E402
import heroine_moves  # noqa: E402
import heroine_rifle  # noqa: E402
import heroine_sniper  # noqa: E402
import heroine_rig  # noqa: E402
import heroine_shotgun  # noqa: E402
import heroine_body  # noqa: E402
import heroine_spec  # noqa: E402

ATLAS = ROOT / "game/assets/characters/heroine_atlas.png"
GLB = ROOT / "game/assets/characters/heroine.glb"
CHEST_GLB = ROOT / "game/assets/characters/m16.glb"
CHEST_SHOTGUN_GLB = ROOT / "game/assets/characters/shotgun.glb"
CHEST_M79_GLB = ROOT / "game/assets/characters/m79.glb"
CHEST_SNIPER_GLB = ROOT / "game/assets/characters/sniper.glb"
PISTOL_SD_GLB = ROOT / "game/assets/characters/pistol_sd.glb"
PISTOL_CRATE_GLB = ROOT / "game/assets/characters/pistol_crate.glb"
MOVES_JSON = ROOT / "game/assets/characters/heroine_moves.json"
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
    for o in rig.children:
        if o.type == "MESH" and o is not mesh_obj:
            print(f"[heroine] {o.name}: triangulos={sum(len(p.vertices) - 2 for p in o.data.polygons)}")
    print(f"[heroine] triangulos={tris} vertices={len(me.vertices)} ossos={len(rig.data.bones)}")
    print(f"[heroine] vertices_sem_peso={len(unweighted)}")
    for a in actions:
        print(f"[heroine] acao {a.name}: frames {int(a.frame_range[0])}-{int(a.frame_range[1])}")
    if unweighted:
        raise SystemExit("vértices sem peso de osso")


def export(path, **extra):
    path.parent.mkdir(parents=True, exist_ok=True)
    opts = {"export_materials": "EXPORT", **extra}
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        **opts,
        export_format="GLB",
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
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


def export_chest_weapon(name, build, path):
    """A arma sozinha (sem esqueleto) deitada em RIFLE_CHEST: o Godot põe no baú, onde as mãos a pegam
    (fuzil e escopeta têm o cabo e a telha nos mesmos pontos)."""
    mb = heroine_mesh.MeshBuilder(heroine_spec.BONE_NAMES)
    build(mb, heroine_rifle.RIFLE_CHEST, {"Hand_R": 1})
    me = bpy.data.meshes.new(name + "Mesh")
    mb.bm.normal_update()
    mb.bm.to_mesh(me)
    mb.bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    me.materials.append(bpy.data.materials["HeroineBody"])
    for o in bpy.data.objects:
        o.select_set(o is obj)
    export(path, use_selection=True, export_materials="NONE")  # o Godot põe o material (atlas da heroína)
    bpy.data.objects.remove(obj)


def export_pistol_sd(path):
    """A pistola com silenciador sozinha, fora da mão: origem no meio dela, cano para +X e o ferrolho para cima (+Z;
    no Godot, cano +X e em cima +Y)."""
    w, t, _, u = heroine_mesh.pistol_frame()
    t = t.normalized()
    u = (u - t * u.dot(t)).normalized()
    basis = Matrix((t, t.cross(u).normalized() * -1.0, u)).transposed()  # colunas: X = cano, Y = lado, Z = em cima
    frame = Matrix.Translation(w + t * 0.16 + u * 0.03) @ basis.to_4x4()
    mb = heroine_mesh.build_weapon(heroine_spec.BONE_NAMES, "pistol")
    heroine_mesh.build_suppressor(mb)
    me = bpy.data.meshes.new("PistolSDItemMesh")
    mb.bm.normal_update()
    mb.bm.to_mesh(me)
    mb.bm.free()
    me.transform(frame.inverted())
    obj = bpy.data.objects.new("PistolSDItem", me)
    bpy.context.scene.collection.objects.link(obj)
    me.materials.append(bpy.data.materials["HeroineBody"])
    for poly in me.polygons:
        poly.use_smooth = False
    for o in bpy.data.objects:
        o.select_set(o is obj)
    export(path, use_selection=True, export_materials="NONE")  # o Godot põe o material (atlas da heroína)
    bpy.data.objects.remove(obj)


def write_moves(path):
    data = heroine_moves.data(heroine_moves.gaits(heroine_anims))
    data["rifle"] = {"grab_frame": heroine_rifle.GRAB_FRAME, "pickup_frames": heroine_rifle.PICKUP_FRAMES,
                     "kneel_dist": heroine_rifle.KNEEL_DIST}
    sg = heroine_shotgun
    data["pistol_pickup"] = {"grab_frame": heroine_drop.GRAB_FRAME, "frames": heroine_drop.FRAMES}
    data["shotgun"] = {"frames": sg.FRAMES, "pump": [[f, d] for f, d in sg.PUMP_KEYS], "stroke": sg.STROKE}
    path.write_text(json.dumps(data, indent=1), encoding="utf8")
    print(f"[heroine] medidas em {path}")


def main():
    scene = reset_scene()
    # corpo = o modelo base (art/heroine_body.py); o esqueleto nasce nas juntas dele
    body, joints = heroine_body.prepare()
    joints["extra_bones"] = heroine_body.braid_bones(joints["braid"])  # a trança balança (mola no Godot)
    scene.render.fps = heroine_anims.FPS  # a importação do FBX troca o fps da cena (24): as animações são a 30
    heroine_spec.use_joints(joints)
    heroine_moves.ANKLE_Z = heroine_spec.ANKLE_L.z  # tornozelo com o pé chato no chão
    # poses, borda/obstáculo e fuzil na medida do corpo dela (as medidas de projeto eram da heroína antiga)
    heroine_anims.LOC_SCALE = heroine_anims.leg_scale(heroine_spec.HIP_L.z, heroine_spec.ANKLE_L.z)
    heroine_moves.adapt(heroine_spec)
    heroine_rifle.adapt(heroine_spec)
    rig = heroine_rig.make_armature()
    heroine_body.bind(body, rig)
    heroine_rig.make_weapons(rig, ATLAS, extra=(("PistolSD", "pistol_sd"),))
    heroine_body.make_hair(rig, ATLAS)  # a nossa trança na cabeça dela
    heroine_body.make_boots(rig, ATLAS)  # e a bota no lugar do pé dela
    heroine_rig.make_muzzle(rig)
    heroine_rig.make_muzzle(rig, "RifleMuzzle", heroine_rifle.muzzle_position())
    heroine_rig.make_muzzle(rig, "ShotgunMuzzle", heroine_shotgun.muzzle_position())
    heroine_rig.make_muzzle(rig, "M79Muzzle", heroine_m79.muzzle_position())
    heroine_rig.make_muzzle(rig, "SniperMuzzle", heroine_sniper.muzzle_position())
    heroine_rig.make_muzzle(rig, "SDMuzzle", heroine_mesh.suppressed_muzzle_position())
    heroine_rig.make_pump(rig)
    acts = heroine_anims.build_actions(rig)
    stats(body, rig, acts)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    export(GLB)
    export_chest_weapon("M16Chest", heroine_rifle.build_rifle, CHEST_GLB)
    export_chest_weapon("ShotgunChest", heroine_shotgun.build_shotgun, CHEST_SHOTGUN_GLB)
    export_chest_weapon("M79Chest", heroine_m79.build_m79, CHEST_M79_GLB)
    export_chest_weapon("SniperChest", heroine_sniper.build_sniper, CHEST_SNIPER_GLB)
    export_pistol_sd(PISTOL_SD_GLB)
    export_chest_weapon("PistolCrate", lambda mb, *_: heroine_drop.build_crate_pistol(mb), PISTOL_CRATE_GLB)
    write_moves(MOVES_JSON)


if __name__ == "__main__":
    main()
