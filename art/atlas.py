"""Layout do atlas de textura da heroína, compartilhado entre o pintor (tools/) e o Blender (art/).

Retângulos em unidades de layout (x, y, w, h) num quadro de 256, origem no canto superior esquerdo como no PIL.
A textura tem TEX_SCALE vezes isso (512x512): o corpo é pintado em 256 e ampliado, rosto e cabelo são
pintados direto em 512.
Peças "loft" mapeiam u = volta do corpo (0 = costas, 0.25 = lado esquerdo, 0.5 = frente,
0.75 = lado direito) e v = altura (topo do retângulo = topo da peça).
"""

SIZE = 256  # unidades de layout
TEX_SCALE = 2  # textura final = 512x512

RECTS = {
    "torso": (0, 0, 128, 96),
    "head": (128, 0, 128, 64),
    "hair": (0, 96, 128, 64),
    "sleeve_upper": (128, 64, 48, 32),
    "sleeve_lower": (128, 96, 48, 32),
    "hand": (176, 64, 32, 32),
    "pistol": (208, 64, 48, 32),
    "thigh": (0, 160, 64, 48),
    "shin": (64, 160, 48, 64),
    "foot": (112, 160, 32, 32),
    "pouch": (144, 160, 32, 32),
    "leather": (176, 160, 32, 32),
    "neck": (192, 96, 32, 16),
}

# Faixas de altura (z em metros) que cada peça vertical ocupa no seu retângulo.
Z_RANGES = {
    "torso": (1.47, 0.80),
    "head": (1.728, 1.505),
    "thigh": (0.93, 0.48),
    "shin": (0.51, 0.08),
}


def uv(rect_name, u, v):
    """Converte (u, v) locais do retângulo, com v=0 no topo, para UV do Blender (origem embaixo)."""
    x, y, w, h = RECTS[rect_name]
    # meio pixel para dentro: com filtro "nearest" a borda exata pegaria o retângulo vizinho
    px = min(max(x + u * w, x + 0.5), x + w - 0.5)
    py = min(max(y + v * h, y + 0.5), y + h - 0.5)
    return (px / SIZE, 1.0 - py / SIZE)


def z_to_v(rect_name, z):
    """Altura em metros -> v local (0 no topo) para peças com faixa em Z_RANGES."""
    top, bottom = Z_RANGES[rect_name]
    return (top - z) / (top - bottom)


def z_to_py(rect_name, z):
    """Altura em metros -> linha de pixel no atlas (para o pintor)."""
    x, y, w, h = RECTS[rect_name]
    return y + z_to_v(rect_name, z) * h
