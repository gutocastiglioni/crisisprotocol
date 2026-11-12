"""Gera o velociraptor do jogo a partir do modelo de referência e exporta para o Godot.

Fonte: "PBR Velociraptor (Animated)" de Ferocious Industries, CC BY 4.0
(https://sketchfab.com/3d-models/pbr-velociraptor-animated-8f1744af7b0847a2aabe3df90be802f0), em
`possible_models/velocirraptor/` (fora do git; crédito no jogo e em game/CREDITOS.txt). Exceção à regra de
`possible_models/` decidida pelo usuário: a malha, o mapa de UV, os pesos e as animações dele entram no jogo; a pele é
repintada com as cores do jogo (`raptor_paint.py`); olhos, dentes e garras ficam com a textura dele.

O que o build faz:
- pose de descanso = o primeiro quadro do Idle_01 dele (em pé, boca fechada): a malha é deformada até ela e o
  esqueleto novo nasce nela (o ragdoll e os limites das juntas partem dela);
- leva ao nosso espaço (frente -Y, esquerda +X, Z para cima), quadril a HIP_H do chão, como o raptor de antes;
- esqueleto com os nossos nomes nos ossos que o jogo usa (Hips, Spine, Chest, Neck1, Neck2, Head, Jaw, Tail1..4,
  Thigh/Shin/Meta/Toe, Arm/Forearm/Hand) e os ossos a mais dele com nomes nossos (Neck3, Tail5..10, dedos, língua...);
  os de controle (IK, pontas) saem e os pesos deles vão para o pai;
- malha reduzida a `TRIS` (orçamento do raptor: 8000);
- animações dele passadas para o esqueleto novo (mesma deformação, quadro a quadro, 30 fps) com os nomes do jogo, e
  as que faltam montadas em cima das dele (Stalk, Study, Shake, TailWhip/TailWhipR).

Uso:
  blender --background --factory-startup --python art/build_raptor.py [-- <pasta>]
  (com <pasta>: prévia, grava raptor.glb/raptor_atlas.png/raptor_parts.png/raptor.blend lá, sem tocar no jogo)
Saídas:
  art/raptor.blend, game/assets/characters/raptor.glb, raptor_atlas.png (pele) e raptor_parts.png (olhos, dentes, garras)
"""
import json
import re
import sys
import tempfile
import zipfile
from pathlib import Path
from types import SimpleNamespace

import bpy
import numpy as np

ART = Path(__file__).resolve().parent
ROOT = ART.parent
sys.path.insert(0, str(ART))

import build_heroine  # noqa: E402
import raptor_import as RI  # noqa: E402
import raptor_motion as RM  # noqa: E402
import raptor_paint as P  # noqa: E402
import raptor_rig  # noqa: E402
from heroine_rig import make_material  # noqa: E402

OUT = ROOT / "game/assets/characters"
ATLAS, PARTS, GLB, BLEND = OUT / "raptor_atlas.png", OUT / "raptor_parts.png", OUT / "raptor.glb", ART / "raptor.blend"
if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1:
    _out = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    _out.mkdir(parents=True, exist_ok=True)
    ATLAS, PARTS, GLB, BLEND = _out / "raptor_atlas.png", _out / "raptor_parts.png", _out / "raptor.glb", _out / "raptor.blend"

TRIS = {"0": 5500, "1": 2400}  # pele / peças (dentes, olhos, garras): ~7900 no total
TEX = 512  # pele e peças (pintada em 2x e reduzida)


# ------------------------------------------------------------------ texturas
def ref_textures():
    tmp = Path(tempfile.mkdtemp(prefix="raptor_ref_"))
    with zipfile.ZipFile(RI.REF_ZIP) as z:
        for n in ("textures/Body_Mat_diffuse.png", "textures/Body_Mat_occlusion.png", "textures/Other_Mat_diffuse.png"):
            z.extract(n, tmp)
    return {n: bpy.data.images.load(str(tmp / "textures" / f"{n}.png")) for n in
            ("Body_Mat_diffuse", "Body_Mat_occlusion", "Other_Mat_diffuse")}


def pixels(img, size):
    """RGBA float (0..1) da imagem em size x size, linha 0 embaixo (como o UV)."""
    im = img.copy()
    im.scale(size, size)
    arr = np.empty(size * size * 4, np.float32)
    im.pixels.foreach_get(arr)
    bpy.data.images.remove(im)
    return arr.reshape(size, size, 4)


def save_png(arr, path, name):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.concatenate([arr, np.ones((h, w, 1), np.float32)], axis=2) if arr.shape[2] == 3 else arr
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    return img


def paint_skin(body, rig, refs, eyes):
    size = TEX * 2
    me = body.data
    me.calc_loop_triangles()
    uvl = me.uv_layers[0].data
    groups = {g.index: g.name for g in body.vertex_groups}
    kinds = {"body": 0, "head": 1, "limb": 2}

    def kind_of(v):
        acc = {"body": 0.0, "head": 0.0, "limbL": 0.0, "limbR": 0.0, "armL": 0.0, "armR": 0.0}
        for g in v.groups:
            n = groups[g.group]
            if re.fullmatch(r"(Thigh|Shin|Meta|Toe[ABC]?\d?|Hip|Pelvis|ThighFlesh)_[LR]", n):
                acc["limb" + n[-1]] += g.weight
            elif re.fullmatch(r"(Arm|Forearm|Hand|Finger[ABC]\d|Shoulder)_[LR]", n):
                acc["arm" + n[-1]] += g.weight
            elif re.fullmatch(r"(Head|Jaw\d?|Tongue\d|Eye_[LR])", n):
                acc["head"] += g.weight
            else:
                acc["body"] += g.weight
        return max(acc, key=acc.get)

    vkind = [kind_of(v) for v in me.vertices]
    code = {"body": 0, "head": 1, "limbL": 2, "limbR": 3, "armL": 4, "armR": 5}
    n = len(me.loop_triangles)
    tri_uv = np.zeros((n, 3, 2), np.float32)
    tri_pos = np.zeros((n, 3, 3), np.float32)
    tri_nrm = np.zeros((n, 3, 3), np.float32)
    tri_kind = np.zeros(n, np.int32)
    for i, t in enumerate(me.loop_triangles):
        votes = {}
        for k, (li, vi) in enumerate(zip(t.loops, t.vertices)):
            tri_uv[i, k] = uvl[li].uv
            tri_pos[i, k] = me.vertices[vi].co
            tri_nrm[i, k] = me.vertices[vi].normal
            votes[vkind[vi]] = votes.get(vkind[vi], 0) + 1
        tri_kind[i] = code[max(votes, key=votes.get)]
    pos, nrm, kind = P.raster(tri_uv, tri_pos, tri_nrm, tri_kind, size)
    B = {b.name: b for b in rig.data.bones}
    head = lambda b: np.array(B[b].head_local, np.float32)
    tail = lambda b: np.array(B[b].tail_local, np.float32)
    spine = [tail("Tail10")] + [head(f"Tail{i}") for i in range(10, 0, -1)] + [head(b) for b in
             ("Spine", "Chest", "Neck1", "Neck2", "Neck3", "Head")] + [tail("Head")]
    chains = {"spine": np.array(spine)}
    for s in ("L", "R"):
        chains["leg" + s] = np.array([head(f"Thigh_{s}"), head(f"Shin_{s}"), head(f"Meta_{s}"), head(f"Toe_{s}"), tail(f"Toe_{s}")])
        chains["arm" + s] = np.array([head(f"Arm_{s}"), head(f"Forearm_{s}"), head(f"Hand_{s}"), tail(f"Hand_{s}")])
    s_, side = P.chain_coords(pos, chains, kind, {0: ["spine"], 1: ["spine"], 2: ["legL"], 3: ["legR"], 4: ["armL"], 5: ["armR"]})
    kind3 = np.where(kind >= 2, 2, kind)  # 0 corpo, 1 cabeça, 2 membro
    diff = pixels(refs["Body_Mat_diffuse"], size)[..., :3] * 255
    ao = pixels(refs["Body_Mat_occlusion"], size)[..., 0]
    rgb = P.paint(pos, nrm, kind3, s_, side, diff, ao, eyes, {0: "body", 1: "head", 2: "limb"})
    rgb = P.pad(rgb, kind >= 0)
    small = rgb.reshape(TEX, 2, TEX, 2, 3).mean(axis=(1, 3)) / 255.0
    return save_png(small, ATLAS, "raptor_atlas")


# ------------------------------------------------------------------ montagem
def main():
    arm, meshes = RI.load_reference()
    scene = bpy.context.scene
    RI.set_action(arm, RM.REST[0])
    RI.goto(scene, RM.REST[1])
    C, scale = RI.to_ours(arm, meshes, scene)
    keep, owner = RI.bone_table(arm, C)
    parts = {}
    for key in ("0", "1"):
        parts[key] = RI.rest_mesh(meshes[key], C, owner, scene)
    rig = RI.build_rig(keep, list(parts.values()))
    F = RM.Frames(keep, rig, C)
    actions = {name: F.sample(arm, scene, src, speed=sp) for name, (src, sp) in RM.DIRECT.items()}
    for name in RM.STRIP:
        RM.strip_travel(F, actions[name])
    actions.update(RM.composed(F, arm, scene))
    eyes = [tuple(rig.data.bones[f"Eye_{s}"].head_local) for s in ("L", "R")]
    refs = ref_textures()
    for key, target in TRIS.items():
        RI.decimate(parts[key][0], target)
    body = parts["0"][0]
    atlas = paint_skin(body, rig, refs, eyes)
    parts_img = refs["Other_Mat_diffuse"].copy()
    parts_img.scale(TEX, TEX)
    parts_img.filepath_raw = str(PARTS)
    parts_img.file_format = "PNG"
    parts_img.save()
    atlas.pack()
    parts_img.pack()
    body.data.materials.append(make_material("RaptorSkin", atlas, double_sided=False))
    other = parts["1"][0]
    other.data.materials.append(make_material("RaptorParts", parts_img, double_sided=True))
    # tira a referência (só os nossos objetos e animações vão para o arquivo)
    for o in list(bpy.data.objects):
        if o not in (body, other, rig):
            bpy.data.objects.remove(o)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for name, frames in actions.items():
        if name != "Embryo":
            RM.hands_down(F, frames)
    made, moving = RM.write_actions(rig, F, actions)
    with bpy.context.temp_override(active_object=body, object=body, selected_editable_objects=[body, other],
                                   selected_objects=[body, other]):
        bpy.ops.object.join()
    body.name = "Raptor"
    body.data.name = "RaptorMesh"
    for poly in body.data.polygons:
        poly.use_smooth = True
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    # boca: entre os dentes, a 60% do caminho da junta da mandíbula até a ponta do focinho
    jaw, tip = rig.data.bones["Jaw"].head_local, rig.data.bones["Head"].tail_local
    mouth = jaw.lerp(tip, 0.6)
    raptor_rig.make_mouth(rig, SimpleNamespace(MOUTH=mouth))
    info = RM.measure(F, actions)
    info.update({"scale": round(scale, 4), "claw_len": round((rig.data.bones["Toe_L"].tail_local - rig.data.bones["Toe_L"].head_local).length, 3),
                 "toe_rest_h": round(rig.data.bones["Toe_L"].head_local.z, 3), "moving": sorted(moving),
                 "bones": [b.name for b in rig.data.bones],
                 "len": {b.name: round(b.length, 3) for b in rig.data.bones}})
    (BLEND.parent / "raptor_build.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    print("[raptor] medidas:", json.dumps({k: v for k, v in info.items() if k not in ("bones", "len", "moving")}))
    build_heroine.stats(body, rig, made)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    build_heroine.export(GLB)


if __name__ == "__main__":
    main()
