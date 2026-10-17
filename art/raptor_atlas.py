"""Layout do atlas de textura do raptor, compartilhado entre o pintor (tools/) e o Blender (art/).

Retângulos em unidades de layout (x, y, w, h) num quadro de 256, origem no canto superior esquerdo como no PIL;
a textura tem TEX_SCALE vezes isso (512x512).
Peças "loft" mapeiam u = volta da peça (0 = dorso/costas, 0.25 = lado esquerdo, 0.5 = barriga,
0.75 = lado direito) e v = comprimento (0 = primeiro anel: traseira do corpo, base do pescoço,
nuca, raiz da cauda, alto da perna).
"""

SIZE = 256  # unidades de layout (retângulos abaixo)
TEX_SCALE = 2  # textura final = 512x512, pintada direto nessa resolução

RECTS = {
    "body": (0, 0, 128, 64),
    "head": (128, 0, 128, 64),
    "tail": (0, 64, 128, 48),
    "neck": (128, 64, 64, 48),
    "jaw": (192, 64, 64, 48),
    "thigh": (0, 112, 64, 48),
    "shin": (64, 112, 48, 48),
    "meta": (112, 112, 32, 48),
    "arm": (144, 112, 48, 32),
    "toe": (192, 112, 32, 32),
    "claw": (224, 112, 32, 32),
    "teeth": (192, 144, 32, 16),
    "mouth": (224, 144, 32, 16),
}

# olho pintado na cabeça: (u, v) do centro no retângulo "head" (lado esquerdo; o direito é 1 - u)
EYE_UV = (0.19, 0.21)


def uv(rect_name, u, v):
    """Converte (u, v) locais do retângulo, com v=0 no topo, para UV do Blender (origem embaixo)."""
    x, y, w, h = RECTS[rect_name]
    px = min(max(x + u * w, x + 0.5), x + w - 0.5)
    py = min(max(y + v * h, y + 0.5), y + h - 0.5)
    return (px / SIZE, 1.0 - py / SIZE)


def z_to_v(rect_name, z):
    raise NotImplementedError("o raptor não usa faixas de altura")
