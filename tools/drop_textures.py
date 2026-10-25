"""Texturas da caixa de paraquedas do telhado (drop_crate.png) e da lona dela (chute.png), com os blocos de
make_level_textures.py. Geradas por ele (python tools/make_level_textures.py).
"""
from PIL import ImageDraw

from make_level_textures import N, base, rng, smooth_noise


def drop_crate():
    """Caixa de lançamento aéreo (caixa de paraquedas do telhado): compensado pintado de oliva escuro, moldura de
    sarrafos, duas cintas de carga amarelas e estêncil preto."""
    img = base((70, 74, 46), 0.05, cells=((32, 0.12), (8, 0.07)))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, N - 1, N - 1], outline=(50, 54, 32), width=16)
    d.rectangle([16, 16, N - 17, N - 17], outline=(40, 42, 24), width=2)
    d.line([(0, 16), (N - 1, 16)], fill=(92, 98, 64), width=1)
    # cintas de carga (nylon amarelado com fivela)
    for x in (58, 186):
        d.rectangle([x - 9, 0, x + 9, N - 1], fill=(150, 128, 58))
        d.line([(x - 9, 0), (x - 9, N - 1)], fill=(98, 82, 34), width=2)
        d.line([(x + 9, 0), (x + 9, N - 1)], fill=(98, 82, 34), width=2)
        for y in range(4, N, 7):
            d.line([(x - 7, y), (x + 7, y + 3)], fill=(136, 116, 50))
        d.rectangle([x - 12, 118, x + 12, 138], fill=(96, 100, 104))
        d.rectangle([x - 8, 122, x + 8, 134], fill=(54, 56, 58))
    # tinta lascada nas bordas
    wear = smooth_noise(8)
    px = img.load()
    for y in range(N):
        for x in range(N):
            edge = min(x, y, N - 1 - x, N - 1 - y)
            if edge < 10 and wear(x, y) > 0.6 and rng.random() < 0.5:
                px[x, y] = (104, 92, 70)
    for text, ty, size in (("AIRDROP", 74, 26), ("CAL .45 SD", 156, 15)):
        tw = d.textlength(text, font_size=size)
        d.text(((N - tw) / 2, ty), text, fill=(22, 22, 18), font_size=size)
    return img


def chute():
    """Lona do paraquedas caído: náilon verde-oliva com gomos mais claros, costuras e dobras (sombra suave)."""
    img = base((96, 102, 70), 0.03, cells=((64, 0.16), (16, 0.08)))
    px = img.load()
    folds = smooth_noise(32)
    for y in range(N):
        for x in range(N):
            gore = (x // 64) % 2  # gomos alternados
            k = (1.08 if gore else 0.94) * (0.86 + 0.28 * folds(x, y))
            px[x, y] = tuple(max(0, min(255, int(c * k))) for c in px[x, y])
    d = ImageDraw.Draw(img)
    for x in range(0, N, 64):
        d.line([(x, 0), (x, N - 1)], fill=(58, 62, 40), width=2)
        d.line([(x + 2, 0), (x + 2, N - 1)], fill=(124, 130, 92), width=1)
    for y in (0, 128):
        d.line([(0, y), (N - 1, y)], fill=(66, 70, 46), width=1)
    return img
