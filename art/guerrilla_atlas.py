"""Layout do atlas do guerrilheiro: o da heroína (art/atlas.py: as armas usam os mesmos retângulos, copiados do atlas
dela) mais peças próprias nos cantos livres. Mesmas convenções: unidades de layout num quadro de 256, textura
TEX_SCALE vezes isso, u = volta da peça (0.5 = frente), v = altura (Z_RANGES) ou comprimento.

Peças do guerrilheiro: torso = moletom (e o começo da calça), hair = capuz (u ao longo da abertura, v do pescoço ao
topo), head = balaclava, neck = gola da balaclava, sleeve_* = mangas do moletom, hand = luva, thigh/shin = calça
cargo e cano do coturno, foot = coturno, pouch = bolsas do colete, cargo = bolso da calça, cord = cordão do capuz.
"""
import atlas

SIZE = atlas.SIZE
TEX_SCALE = atlas.TEX_SCALE
RECTS = {
    **atlas.RECTS,
    "cargo": (224, 96, 32, 32),
    "cord": (192, 112, 32, 16),
}
Z_RANGES = atlas.Z_RANGES


def uv(rect_name, u, v):
    x, y, w, h = RECTS[rect_name]
    px = min(max(x + u * w, x + 0.5), x + w - 0.5)
    py = min(max(y + v * h, y + 0.5), y + h - 0.5)
    return (px / SIZE, 1.0 - py / SIZE)


def z_to_v(rect_name, z):
    top, bottom = Z_RANGES[rect_name]
    return (top - z) / (top - bottom)


def z_to_py(rect_name, z):
    x, y, w, h = RECTS[rect_name]
    return y + z_to_v(rect_name, z) * h
