"""Corpo da heroína = o modelo base em art/base_body/ ("DinoCrisisCustom - Regina", Otherspectre, CC-BY 4.0;
créditos em art/base_body/CREDITS.txt), preparado para o jogo: corpo, rosto, olhos e coldre dele, com as texturas dele.

Passos (prepare):
1. importa art/base_body/Mesh.fbx e põe a altura da heroína (HEIGHT, com o cabelo);
2. pose de repouso das nossas animações: braços caídos em heroine_spec.ARM_SPREAD com o cotovelo reto (no modelo
   eles estão em T) e os dedos fechados (a mão segura a arma); a pose vira a forma da malha, com suavização corretiva
   (o ombro dela, feito para o T, amassaria ao descer o braço);
3. lê as juntas dela nessa pose (ombro, cotovelo, punho, quadril, joelho, tornozelo, ponta do pé, tronco) e centra o
   corpo (quadril em x = y = 0);
4. os 68 ossos dela viram os nossos 17 (pesos somados: dedos -> mão, clavícula e seios -> peito, cabelo e mandíbula ->
   cabeça, ...);
5. reduz para caber no orçamento (corpo + armas < 5000 triângulos no teste).
Depois o build cria o NOSSO esqueleto nessas juntas (heroine_spec.use_joints) e liga a malha a ele (bind).
Os materiais saem com o nome "Body_<textura>": o Godot (HeroineModel) usa a textura de cada um, não o atlas.
Roupa e bota: heroine_outfit.py; calota, franja e trança: heroine_hair.py.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

import heroine_spec as S
from heroine_outfit import _drop_feet, _flat_straps, _original_texture, make_boots  # noqa: F401
from heroine_hair import _braid_path, _surfaces, braid_bones, make_hair  # noqa: F401

ART = Path(__file__).resolve().parent
SRC = ART / "base_body"
HEIGHT = 1.745  # altura da heroína com o cabelo
TARGET_TRIS = 3350  # o corpo; cabelo (~530), botas (~430) e armas (~560) somam no mesmo .glb (teste: < 5000)
# texturas do modelo (nome do arquivo dentro do FBX -> o nosso, em art/base_body/; tools/prepare_base_body.py)
FBX_TEXTURES = {"regina_d": "costume", "regina_u1_v1_u1_v1": "skin", "face_d": "face", "eye": "eye", "eyelash": "eyelash",
                "hair_d": "hair", "hair_2_d": "hair_2", "holster_d": "holster", "4": "pouch"}
HAIR = ("hair", "hair_2")  # o cabelo dela sai: entra a nossa trança (make_hair)
ALPHA = ("eyelash", "hair", "hair_2", "holster", "pouch")  # recortadas pelo alfa, dos dois lados
CLAVICLE_DROP = math.radians(6)  # a clavícula do modelo em T fica alta com o braço caído: desce (ombro solto)
FINGER_CURL = math.radians(62)  # cada falange dos dedos 2..5
FOOT_PITCH = math.radians(28)  # tornozelo -> planta do pé com o pé apoiado (o modelo vem a 44°, na ponta)
THUMB_REACH = 0.85  # quanto o polegar gira em direção aos dedos fechados (1 = aponta direto para eles)

# osso dela -> nosso (o lado vem do nome: left = +X = _L)
BONE_MAP = [
    ("root ground", "Hips"), ("root hips", "Hips"), ("belt holser", "Hips"),
    ("spine lower", "Spine"), ("spine middle", "Chest"), ("spine upper", "Chest"), ("boob", "Chest"),
    ("head neck lower", "Neck"), ("head neck upper", "Head"), ("head jaw", "Head"), ("head hair", "Head"),
    ("shoulder 1", "Chest"), ("shoulder 2", "UpperArm"), ("elbow", "LowerArm"), ("wrist", "Hand"), ("finger", "Hand"),
    ("thigh", "UpperLeg"), ("knee", "LowerLeg"), ("ankle", "Foot"), ("toes", "Foot"),
]


def _ours(name):
    side = "_L" if "left" in name else ("_R" if "right" in name else "")
    for key, bone in BONE_MAP:
        if key in name:
            return bone + side if bone in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot") else bone
    return "Chest"


def _materials(obj):
    """Material de cada parte com a textura dela (PNG de art/base_body), no estilo dos nossos: sem brilho, filtro
    "nearest"; as que têm alfa recortado ficam com as duas faces."""
    for slot in obj.material_slots:
        old = slot.material
        key = None
        for n in old.node_tree.nodes if old.use_nodes else []:
            if n.type == "BSDF_PRINCIPLED" and n.inputs["Base Color"].links:
                key = FBX_TEXTURES[Path(n.inputs["Base Color"].links[0].from_node.image.name).stem.split(".")[0]]
        img = bpy.data.images.load(str(SRC / f"{key}.png"))
        if key == "eye":
            _tint_iris(img)
        img.pack()
        mat = bpy.data.materials.new(f"Body_{key}")
        mat.use_nodes = True
        alpha = key in ALPHA
        mat.use_backface_culling = not alpha
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Metallic"].default_value = 0.0
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            mat.blend_method = "CLIP"
        slot.material = mat


IRIS_HUE = 0.30  # verde (matiz 0..1): a íris dela é castanha
IRIS_SAT = 0.35  # só os pixels saturados (a íris): o branco e a pupila preta ficam


def _tint_iris(img):
    """Olhos verdes: a íris (pixels saturados da textura do olho) troca de matiz, com o mesmo brilho e os mesmos
    riscos do desenho; o branco do olho e a pupila não mudam."""
    import numpy as np

    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    iris = (sat > IRIS_SAT) & (mx > 0.06)
    # mesmo brilho (máximo) e saturação, matiz verde: h = IRIS_HUE (setor entre amarelo e verde)
    v, sv = mx, sat
    hh = IRIS_HUE * 6.0
    f = hh - np.floor(hh)
    p_ = v * (1 - sv)
    q_ = v * (1 - sv * f)
    t_ = v * (1 - sv * (1 - f))
    sector = int(np.floor(hh)) % 6
    out = {0: (v, t_, p_), 1: (q_, v, p_), 2: (p_, v, t_), 3: (p_, q_, v), 4: (t_, p_, v), 5: (v, p_, q_)}[sector]
    for ch in range(3):
        rgb[..., ch] = np.where(iris, out[ch], rgb[..., ch])
    px[..., :3] = rgb
    img.pixels = px.ravel().tolist()
    print(f"[corpo] olhos verdes: {int(iris.sum())} pixels da íris")


def _rotate_bone(arm, pb, rot):
    """Gira o osso (e os filhos) em volta da cabeça dele, no espaço do esqueleto."""
    h = pb.head.copy()
    pb.matrix = Matrix.Translation(h) @ rot.to_4x4() @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


def _pose(arm):
    for side, k in (("left", 1), ("right", -1)):
        down = Vector((k * math.sin(S.ARM_SPREAD), 0.0, -math.cos(S.ARM_SPREAD)))
        clav = arm.pose.bones[f"arm {side} shoulder 1"]  # clavícula desce um pouco: o ombro e as alças acompanham
        # giro em Y: +ângulo leva o lado esquerdo (+X) para baixo; o direito (-X) desce com o ângulo negativo
        _rotate_bone(arm, clav, Matrix.Rotation(k * CLAVICLE_DROP, 3, "Y"))
        upper = arm.pose.bones[f"arm {side} shoulder 2"]
        _rotate_bone(arm, upper, (upper.tail - upper.head).normalized().rotation_difference(down).to_matrix())
        fore = arm.pose.bones[f"arm {side} elbow"]
        _rotate_bone(arm, fore, (fore.tail - fore.head).normalized().rotation_difference(down).to_matrix())
        hand = arm.pose.bones[f"arm {side} wrist"]
        _rotate_bone(arm, hand, (hand.tail - hand.head).normalized().rotation_difference(down).to_matrix())
        for f in range(1, 6):
            for seg in "abc":
                pb = arm.pose.bones[f"arm {side} finger {f}{seg}"]
                pb.rotation_mode = "XYZ"
                if f != 1:
                    pb.rotation_euler = (-FINGER_CURL, 0.0, 0.0)  # sinal: fecha para a palma
        bpy.context.view_layer.update()
        # polegar: aponta para o meio dos dedos já fechados (indicador e médio), por cima deles, como num punho
        thumb = arm.pose.bones[f"arm {side} finger 1a"]
        tip = (arm.pose.bones[f"arm {side} finger 2b"].head + arm.pose.bones[f"arm {side} finger 3b"].head) / 2
        cur = (thumb.tail - thumb.head).normalized()
        want = cur.lerp((tip - thumb.head).normalized(), THUMB_REACH).normalized()
        _rotate_bone(arm, thumb, cur.rotation_difference(want).to_matrix())
        # pé: o modelo vem na ponta (como de salto): o peito do pé desce em FOOT_PITCH e os dedos deitam
        ankle = arm.pose.bones[f"leg {side} ankle"]
        d = (ankle.tail - ankle.head).normalized()
        flat = Vector((0.0, -math.cos(FOOT_PITCH), -math.sin(FOOT_PITCH)))
        _rotate_bone(arm, ankle, d.rotation_difference(flat).to_matrix())
        toes = arm.pose.bones[f"leg {side} toes"]
        d = (toes.tail - toes.head).normalized()
        _rotate_bone(arm, toes, d.rotation_difference(Vector((0.0, -1.0, -0.05)).normalized()).to_matrix())
    bpy.context.view_layer.update()


def _bake(mesh):
    """A pose vira a forma da malha (armadura + suavização corretiva), mantendo pesos, UV e materiais."""
    cs = mesh.modifiers.new("Fix", "CORRECTIVE_SMOOTH")
    cs.rest_source = "ORCO"
    cs.factor = 0.5
    cs.iterations = 8
    cs.smooth_type = "LENGTH_WEIGHTED"
    dg = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(mesh.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = mesh.data
    mesh.data = baked
    mesh.modifiers.clear()
    bpy.data.meshes.remove(old)


def _joints(arm):
    P = lambda n: (arm.matrix_world @ arm.pose.bones[n].head, arm.matrix_world @ arm.pose.bones[n].tail)
    sh, el = P("arm left shoulder 2")
    wr, wt = P("arm left wrist")
    th, kn = P("leg left thigh")
    an = P("leg left ankle")[0]
    ball = P("leg left toes")[0]
    hips_h, hips_t = P("root hips")
    sl_h = P("spine lower")[0]
    sm_h = P("spine middle")[0]
    nl_h = P("head neck lower")[0]
    nu_h, nu_t = P("head neck upper")
    mid = lambda v: Vector((0.0, v.y, v.z))
    # ossos do tronco verticais (como os nossos de antes: as poses foram desenhadas assim), com o pivô na junta dela
    up = lambda h, t: (mid(h), mid(h) + Vector((0.0, 0.0, t.z - h.z)))
    return {
        "shoulder": sh, "upper_arm": (el - sh).length, "forearm": (wr - el).length, "hand": (wt - wr).length,
        "hip": th, "knee": kn, "ankle": an, "toe": ball,
        "torso": {
            "Hips": up(hips_h, sl_h), "Spine": up(sl_h, sm_h), "Chest": up(sm_h, nl_h),
            "Neck": up(nl_h, nu_h), "Head": up(nu_h, nu_t),
        },
    }


def _merge_groups(mesh):
    """Pesos dos 68 ossos dela somados nos nossos 17 (cada vértice normalizado)."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    acc = []
    for v in mesh.data.vertices:
        w = {}
        for g in v.groups:
            if g.weight > 0:
                b = _ours(names[g.group])
                w[b] = w.get(b, 0.0) + g.weight
        acc.append(w)
    mesh.vertex_groups.clear()
    groups = {n: mesh.vertex_groups.new(name=n) for n in S.BONE_NAMES}
    for i, w in enumerate(acc):
        total = sum(w.values()) or 1.0
        if not w:
            w = {"Hips": 1.0}
        for b, x in w.items():
            groups[b].add([i], x / total, "REPLACE")


def _drop_hair(mesh):
    keep = [i for i, sl in enumerate(mesh.material_slots) if sl.material.name.removeprefix("Body_") in HAIR]
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(mesh.data)
    bm.free()


def _decimate(mesh):
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    if tris <= TARGET_TRIS:
        return
    mod = mesh.modifiers.new("Budget", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = TARGET_TRIS / tris
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.modifier_apply(modifier=mod.name)


def prepare():
    """Importa, põe na pose de repouso e devolve (malha, juntas). A malha fica solta (sem esqueleto)."""
    bpy.ops.import_scene.fbx(filepath=str(SRC / "Mesh.fbx"))
    arm = next(o for o in bpy.context.selected_objects if o.type == "ARMATURE")
    mesh = next(o for o in bpy.context.selected_objects if o.type == "MESH")
    mesh.name = "Heroine"
    _materials(mesh)
    # altura da heroína
    zs = [(mesh.matrix_world @ v.co).z for v in mesh.data.vertices]
    arm.scale = (arm.scale.x * HEIGHT / (max(zs) - min(zs)),) * 3
    bpy.context.view_layer.update()
    for o in bpy.data.objects:
        o.select_set(o in (arm, mesh))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for b in arm.data.bones:
        b.inherit_scale = "NONE"
    _pose(arm)
    _bake(mesh)
    joints = _joints(arm)
    # solta do esqueleto dela e centra: quadril em x = y = 0, pés no chão
    world = mesh.matrix_world.copy()
    mesh.parent = None
    mesh.matrix_world = world
    bpy.data.objects.remove(arm)
    for o in bpy.data.objects:
        o.select_set(o is mesh)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ground = min(v.co.z for v in mesh.data.vertices)
    shift = Vector((0.0, -joints["hip"].y, -ground))
    mesh.data.transform(Matrix.Translation(shift))
    for k in ("shoulder", "hip", "knee", "ankle", "toe"):
        joints[k] = joints[k] + shift
    joints["torso"] = {k: (h + shift, t + shift) for k, (h, t) in joints["torso"].items()}
    _merge_groups(mesh)
    _flat_straps(mesh, joints)
    _drop_hair(mesh)
    _surfaces(mesh)
    joints["braid"] = _braid_path()
    _drop_feet(mesh)  # a bota (make_boots) entra no lugar
    _original_texture(mesh, joints)
    _decimate(mesh)
    for p in mesh.data.polygons:
        p.use_smooth = True
    return mesh, joints


def bind(mesh, rig):
    """Liga a malha ao nosso esqueleto (já criado nas juntas dela)."""
    mesh.parent = rig
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return mesh
