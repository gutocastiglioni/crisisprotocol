"""Malha procedural legada do guerrilheiro, usada exclusivamente para amostragem
de raios e transferência de coordenadas UV do atlas (guerrilla_atlas.png) para a malha Mesh.fbx.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

import guerrilla_atlas
import heroine_head
import heroine_mesh as M
import heroine_spec as S

X, Y, Z = M.X, M.Y, M.Z
R = M.R

TORSO = [
    (0.80, 0.000, 0.112, 0.088), (0.84, 0.000, 0.148, 0.100), (0.88, 0.004, 0.158, 0.106),
    (0.905, 0.004, 0.150, 0.100), (0.907, 0.002, 0.180, 0.125), (0.95, 0.000, 0.178, 0.123),
    (0.97, 0.000, 0.174, 0.119), (1.03, 0.000, 0.172, 0.117), (1.10, -0.004, 0.174, 0.116),
    (1.18, -0.006, 0.182, 0.119), (1.26, -0.006, 0.192, 0.123), (1.32, -0.004, 0.198, 0.121),
    (1.37, 0.000, 0.184, 0.113), (1.41, 0.000, 0.168, 0.104), (1.435, 0.000, 0.138, 0.094),
    (1.455, 0.000, 0.108, 0.085), (1.47, 0.000, 0.086, 0.079),
]

def _torso_bones(z):
    for lim, w in ((0.97, {"Hips": 1}), (1.05, {"Hips": 0.5, "Spine": 0.5}), (1.13, {"Spine": 1}),
                   (1.17, {"Spine": 0.7, "Chest": 0.3}), (1.23, {"Spine": 0.3, "Chest": 0.7}), (1.46, {"Chest": 1})):
        if z <= lim:
            return w
    return {"Chest": 0.5, "Neck": 0.5}

def _volume(th, z):
    v = M._lobe(th, z, math.pi, 1.00, 0.010, 0.55, 0.045)
    for k in (1, -1):
        v += M._lobe(th, z, math.pi - k * 0.5, 1.28, 0.008, 0.4, 0.06) + M._lobe(th, z, k * 0.6, 1.32, 0.008, 0.4, 0.06)
    return v

def build_torso(mb):
    rings = []
    for z, y, rx, ry in TORSO:
        w = _torso_bones(z)
        push = {j: _volume(2 * math.pi * j / M.TORSO_SIDES, z) for j in range(M.TORSO_SIDES)}
        rings.append(R((0, y, z), rx, ry * (1.1 if 0.95 < z < 1.44 else 1.0), w, push, frame=(X, Y), wfn=M._torso_weights(w, z)))
    mb.loft(rings, "torso", M.TORSO_SIDES, v_by_z=True)

def build_head(mb):
    head = {"Head": 1}
    rings = [R((0, y, z), rx * 1.07, ry * 1.04, head, push or None, frame=(X, Y))
             for z, y, rx, ry, push in heroine_head.HEAD]
    mb.loft(rings, "head", heroine_head.SIDES, v_by_z=True)
    neck = {"Neck": 1}
    mb.loft([
        R((0, -0.003, 1.43), 0.078, 0.072, {"Chest": 0.5, "Neck": 0.5}),
        R((0, -0.005, 1.47), 0.064, 0.060, neck),
        R((0, -0.008, 1.50), 0.060, 0.058, neck),
        R((0, -0.012, 1.535), 0.058, 0.060, {"Neck": 0.5, "Head": 0.5}),
    ], "neck", 8)

def build_arm(mb, s):
    ua, la, hand, chest = f"UpperArm_{s}", f"LowerArm_{s}", f"Hand_{s}", "Chest"
    p = lambda d: S.arm_point(s, d)
    UA, w0 = S.UPPER_ARM_LEN, S.UPPER_ARM_LEN + S.FOREARM_LEN
    pu, pl = (lambda f: p(UA * f)), (lambda f: p(UA + S.FOREARM_LEN * f))
    mb.loft([
        R(p(-0.038), 0.020, 0.024, {chest: 0.6, ua: 0.4}), R(p(-0.026), 0.040, 0.046, {chest: 0.5, ua: 0.5}),
        R(p(-0.008), 0.054, 0.060, {chest: 0.3, ua: 0.7}), R(pu(0.08), 0.064, 0.066, {chest: 0.12, ua: 0.88}),
        R(pu(0.30), 0.062, 0.064, {ua: 1}), R(pu(0.60), 0.058, 0.060, {ua: 1}),
        R(pu(0.85), 0.055, 0.056, {ua: 1}), R(p(UA + 0.005), 0.052, 0.054, {ua: 0.5, la: 0.5}),
    ], "sleeve_upper", 8)
    mb.loft([
        R(p(UA - 0.005), 0.053, 0.055, {ua: 0.5, la: 0.5}), R(pl(0.30), 0.052, 0.054, {la: 1}),
        R(pl(0.60), 0.049, 0.051, {la: 1}), R(pl(0.80), 0.047, 0.048, {la: 1}),
        R(p(w0 - 0.035), 0.040, 0.042, {la: 1}), R(p(w0 - 0.012), 0.036, 0.038, {la: 0.8, hand: 0.2}),
        R(p(w0 + 0.004), 0.031, 0.033, {la: 0.5, hand: 0.5}),
    ], "sleeve_lower", 8)
    mb.loft([
        R(p(w0), 0.028, 0.036, {hand: 0.6, la: 0.4}), R(p(w0 + 0.03), 0.033, 0.052, {hand: 1}),
        R(p(w0 + 0.062), 0.035, 0.056, {hand: 1}), R(p(w0 + 0.088), 0.031, 0.050, {hand: 1}),
        R(p(w0 + 0.104), 0.019, 0.036, {hand: 1}),
    ], "hand", 6)
    a, _ = M.ring_frame(S.side(S.ARM_DIR_L, s))
    mb.box(p(w0 + 0.045) + Vector((0, -0.057, 0)), a, Y, (0.016, 0.013, 0.03), "hand", {hand: 1})

def build_leg(mb, s):
    k = 1 if s == "L" else -1
    ul, ll, foot, hips = f"UpperLeg_{s}", f"LowerLeg_{s}", f"Foot_{s}", "Hips"
    mb.loft([
        R((k * 0.085, 0, 0.93), 0.098, 0.104, {hips: 0.5, ul: 0.5}), R((k * 0.09, 0, 0.86), 0.096, 0.100, {hips: 0.2, ul: 0.8}),
        R((k * 0.092, -0.003, 0.78), 0.089, 0.093, {ul: 1}), R((k * 0.092, -0.006, 0.69), 0.082, 0.085, {ul: 1}),
        R((k * 0.091, -0.008, 0.60), 0.075, 0.078, {ul: 1}), R((k * 0.09, -0.01, 0.53), 0.069, 0.072, {ul: 1}),
        R((k * 0.09, -0.01, 0.48), 0.067, 0.070, {ul: 0.5, ll: 0.5}),
    ], "thigh", 8, v_by_z=True)
    mb.loft([
        R((k * 0.09, -0.01, 0.51), 0.067, 0.070, {ul: 0.5, ll: 0.5}), R((k * 0.09, -0.005, 0.45), 0.067, 0.069, {ll: 1}),
        R((k * 0.09, 0.0, 0.38), 0.065, 0.067, {ll: 1}), R((k * 0.09, 0.005, 0.30), 0.063, 0.065, {ll: 1}),
        R((k * 0.09, 0.008, 0.24), 0.066, 0.068, {ll: 1}), R((k * 0.09, 0.010, 0.215), 0.069, 0.071, {ll: 1}),
        R((k * 0.09, 0.012, 0.205), 0.054, 0.058, {ll: 1}), R((k * 0.09, 0.015, 0.15), 0.050, 0.056, {ll: 0.8, foot: 0.2}),
        R((k * 0.09, 0.02, 0.10), 0.051, 0.058, {ll: 0.6, foot: 0.4}), R((k * 0.09, 0.02, 0.08), 0.053, 0.060, {ll: 0.5, foot: 0.5}),
    ], "shin", 8, v_by_z=True)
    fr = (X, Z)
    mb.loft([
        R((k * 0.09, 0.075, 0.06), 0.050, 0.060, {ll: 0.3, foot: 0.7}, frame=fr),
        R((k * 0.09, 0.0, 0.06), 0.055, 0.062, {foot: 1}, frame=fr),
        R((k * 0.09, -0.09, 0.05), 0.057, 0.050, {foot: 1}, frame=fr),
        R((k * 0.09, -0.165, 0.038), 0.050, 0.036, {foot: 1}, frame=fr),
        R((k * 0.09, -0.195, 0.030), 0.034, 0.024, {foot: 1}, frame=fr),
    ], "foot", 6)

def build_legacy_bvh(atlas_path):
    import numpy as np
    from mathutils.bvhtree import BVHTree
    mb = M.MeshBuilder(S.BONE_NAMES, atlas_module=guerrilla_atlas, remap=M._proportion)
    build_torso(mb)
    build_head(mb)
    for s in ("L", "R"):
        build_arm(mb, s)
        build_leg(mb, s)
    bm = mb.bm
    bm.faces.ensure_lookup_table()
    img = bpy.data.images.load(str(atlas_path))
    w, h = img.size
    atlas = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bones = {n: (hd.copy(), tl.copy()) for n, hd, tl, _ in S.bones()}
    return BVHTree.FromBMesh(bm), bm, mb.uv, atlas, bones
