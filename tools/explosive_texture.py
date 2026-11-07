"""Textura do caixote de metal com explosivos (explosive.png, ExplosiveCrate do posto da porta do pátio), com os blocos
de make_level_textures.py (chamada por ele, depois das outras: o sorteio das outras texturas não muda).
"""
import math

from PIL import Image, ImageDraw

from make_level_textures import N, base, rng, smooth_noise


def explosive():
    """Caixote de metal com explosivos (o canto da porta do pátio): chapa vermelho-escura com nervuras nas bordas,
    faixa de perigo amarela e preta no meio, losango laranja "1.1" e estêncil. Uma face inteira por textura
    (o ExplosiveCrate põe UV 0..1 em cada face)."""
    img = base((118, 34, 26), 0.04, cells=((32, 0.12), (8, 0.06)))
    d = ImageDraw.Draw(img)
    # moldura de cantoneira (sombra por dentro, brilho por fora) e nervuras em cima e embaixo
    d.rectangle([0, 0, N - 1, N - 1], outline=(70, 22, 18), width=10)
    d.rectangle([10, 10, N - 11, N - 11], outline=(150, 52, 40), width=2)
    for y in (34, N - 35):
        d.rectangle([10, y - 5, N - 11, y + 5], fill=(104, 30, 24))
        d.line([(10, y - 5), (N - 11, y - 5)], fill=(146, 50, 38), width=2)
        d.line([(10, y + 5), (N - 11, y + 5)], fill=(64, 18, 14), width=2)
    # faixa de perigo no meio
    band = Image.new("RGB", (N - 20, 34), (214, 170, 34))
    bd = ImageDraw.Draw(band)
    for k in range(-40, N, 28):
        bd.polygon([(k, 0), (k + 14, 0), (k + 14 + 34, 34), (k + 34, 34)], fill=(28, 26, 22))
    img.paste(band, (10, 150))
    # losango laranja da classe 1 (explosivo) com o número
    cx, cy, r = N // 2, 92, 40
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=(226, 120, 30), outline=(40, 30, 20))
    d.polygon([(cx, cy - r + 6), (cx + r - 6, cy), (cx, cy + r - 6), (cx - r + 6, cy)], outline=(40, 30, 20))
    tw = d.textlength("1.1", font_size=22)
    d.text((cx - tw / 2, cy + 6), "1.1", fill=(30, 24, 18), font_size=22)
    # estrela da explosão (oito pontas) acima do número
    pts = []
    for i in range(16):
        a = i * math.pi / 8
        rr = 14 if i % 2 == 0 else 6
        pts.append((cx + math.cos(a) * rr, cy - 10 + math.sin(a) * rr))
    d.polygon(pts, fill=(30, 24, 18))
    for text, ty in (("HIGH EXPLOSIVE", 196), ("HANDLE WITH CARE", 218)):
        tw = d.textlength(text, font_size=15)
        d.text(((N - tw) / 2, ty), text, fill=(224, 214, 180), font_size=15)
    # tinta lascada nas bordas e nas quinas (aparece o aço)
    wear = smooth_noise(8)
    px = img.load()
    for y in range(N):
        for x in range(N):
            edge = min(x, y, N - 1 - x, N - 1 - y)
            if edge < 14 and wear(x, y) > 0.6 and rng.random() < 0.55:
                px[x, y] = (110, 108, 102)
    return img
