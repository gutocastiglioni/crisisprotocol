"""Layout do atlas do guerrilheiro: o da heroína (art/atlas.py: as armas usam os mesmos retângulos, copiados do atlas
dela) mais peças próprias nos cantos livres. Mesmas convenções: unidades de layout num quadro de 256, textura
TEX_SCALE vezes isso, u = volta da peça (0 = costas, 0.5 = frente), v = altura (Z_RANGES) ou comprimento.

Peças do guerrilheiro (art/guerrilla_body.py): torso = calça, cinto, moletom e colete; head = capuz com o rosto
(balaclava) na frente; sleeve_* = mangas do moletom; hand = mão (pele); thigh/shin = calça camuflada, barra embolada e
cano do coturno; foot = coturno; pouch = bolsas de carregador do colete; bpouch = bolsas do cinto; leather = coldre;
cargo = bolso da calça; cord = cordão do capuz; vest = colete (art/guerrilla_vest.py: frente na metade esquerda, costas
na direita, u pelo x e v pela altura).
"""
import atlas

SIZE = atlas.SIZE
TEX_SCALE = atlas.TEX_SCALE
RECTS = {
    **atlas.RECTS,
    "cargo": (224, 96, 32, 32),
    "cord": (192, 112, 32, 16),
    "bpouch": (208, 160, 48, 32),
    "vest": (0, 96, 128, 64),  # colete (no lugar do cabelo da heroína, que ele não tem): frente | costas, de frente
}
Z_RANGES = {
    "torso": (1.50, 0.76),
    "head": (1.80, 1.50),
    "thigh": (0.98, 0.51),
    "shin": (0.51, 0.09),
    "vest": (1.56, 0.97),
}


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
