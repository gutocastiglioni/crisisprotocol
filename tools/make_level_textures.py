"""Texturas 256x256 do galpão (visual de PS2 do começo): piso de concreto, parede de painéis metálicos,
caixa de madeira e faixa de perigo. Cada uma cobre ~2 m no mundo (world_uv_scale 0.5).

Uso: python tools/make_level_textures.py
Saída: game/assets/textures/*.png
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "game/assets/textures"
N = 256
rng = random.Random(3)


def smooth_noise(cell, size=N):
    """Ruído suave e emendável (a grade aleatória se repete na borda) com valores 0..1."""
    g = size // cell
    small = Image.new("L", (g, g))
    small.putdata([rng.randrange(256) for _ in range(g * g)])
    tiled = Image.new("L", (g * 3, g * 3))
    for i in range(3):
        for j in range(3):
            tiled.paste(small, (i * g, j * g))
    big = tiled.resize((size * 3, size * 3), Image.BICUBIC).crop((size, size, size * 2, size * 2))
    data = big.load()
    return lambda x, y: data[x % size, y % size] / 255.0


def base(color, amount, cells=((32, 0.18), (8, 0.10))):
    """Cor com manchas de várias escalas e grão fino."""
    layers = [(smooth_noise(c), k) for c, k in cells]
    img = Image.new("RGB", (N, N))
    px = img.load()
    for y in range(N):
        for x in range(N):
            k = 1.0 + sum((f(x, y) - 0.5) * w * 2 for f, w in layers) + rng.uniform(-amount, amount)
            px[x, y] = tuple(max(0, min(255, int(c * k))) for c in color)
    return img


def wrap_line(d, pts, fill, width=1):
    """Linha que dá a volta na borda (a textura repete)."""
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            d.line([(x + ox, y + oy) for x, y in pts], fill=fill, width=width)


def concrete():
    img = base((92, 90, 84), 0.05)
    d = ImageDraw.Draw(img)
    # junta de dilatação (sulco escuro com borda clara) a cada placa
    for a in (0,):
        d.line([(0, a), (N - 1, a)], fill=(50, 48, 44), width=3)
        d.line([(0, a + 2), (N - 1, a + 2)], fill=(116, 112, 104))
        d.line([(a, 0), (a, N - 1)], fill=(50, 48, 44), width=3)
        d.line([(a + 2, 0), (a + 2, N - 1)], fill=(116, 112, 104))
    # agregado (pedrinhas) e manchas de óleo
    for _ in range(900):
        x, y = rng.randrange(N), rng.randrange(N)
        c = rng.choice(((112, 108, 100), (70, 68, 62), (100, 98, 90)))
        d.point([(x, y)], fill=c)
    stains = Image.new("L", (N, N), 0)
    sd = ImageDraw.Draw(stains)
    for _ in range(3):
        x, y, r = rng.randrange(N), rng.randrange(N), rng.randint(14, 34)
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                sd.ellipse([x - r + ox, y - r * 0.7 + oy, x + r + ox, y + r * 0.7 + oy], fill=90)
    stains = stains.filter(ImageFilter.GaussianBlur(8))
    img = Image.composite(Image.new("RGB", (N, N), (46, 44, 40)), img, stains)
    d = ImageDraw.Draw(img)
    # rachaduras (caminho aleatório)
    for _ in range(4):
        x, y = rng.randrange(N), rng.randrange(N)
        ang = rng.uniform(0, 2 * math.pi)
        pts = [(x, y)]
        for _ in range(rng.randint(8, 16)):
            ang += rng.uniform(-0.7, 0.7)
            x, y = x + math.cos(ang) * 6, y + math.sin(ang) * 6
            pts.append((x, y))
        wrap_line(d, pts, (52, 50, 46), 1)
    return img


def wall():
    img = base((72, 80, 86), 0.03, ((32, 0.08), (4, 0.04)))
    d = ImageDraw.Draw(img)
    px = img.load()
    # sujeira subindo do chão (a textura de parede repete na vertical a cada 2 m)
    for y in range(N):
        for x in range(N):
            k = 1.0 - 0.25 * max(0.0, (y - N * 0.6) / (N * 0.4))
            px[x, y] = tuple(int(c * k) for c in px[x, y])
    # painéis: emendas verticais com sombra e brilho, nervura horizontal, chapa de rodapé
    for x in (0, N // 2):
        d.line([(x, 0), (x, N - 1)], fill=(36, 42, 46), width=3)
        d.line([(x + 3, 0), (x + 3, N - 1)], fill=(104, 112, 118))
    d.rectangle([0, 96, N - 1, 104], fill=(84, 92, 98))
    d.line([(0, 96), (N - 1, 96)], fill=(112, 120, 126))
    d.line([(0, 104), (N - 1, 104)], fill=(40, 46, 50), width=2)
    d.rectangle([0, 200, N - 1, N - 1], fill=(54, 60, 64))
    d.line([(0, 200), (N - 1, 200)], fill=(104, 112, 118), width=2)
    # rebites com escorrido de ferrugem
    rust = Image.new("L", (N, N), 0)
    rd = ImageDraw.Draw(rust)
    for x in (12, 116, 140, 244):
        for y in (12, 88, 112, 190, 212, 244):
            if rng.random() < 0.55:
                ln = rng.randint(10, 40)
                rd.line([(x, y), (x + rng.randint(-2, 2), y + ln)], fill=rng.randint(60, 140), width=rng.randint(2, 4))
    rust = rust.filter(ImageFilter.GaussianBlur(1.5))
    img = Image.composite(Image.new("RGB", (N, N), (104, 62, 36)), img, rust)
    d = ImageDraw.Draw(img)
    for x in (12, 116, 140, 244):
        for y in (12, 88, 112, 190, 212, 244):
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(48, 52, 56))
            d.ellipse([x - 2, y - 2, x + 1, y + 1], fill=(146, 152, 156))
    return img


def crate():
    img = Image.new("RGB", (N, N))
    px = img.load()
    grain = smooth_noise(16)
    for y in range(N):
        plank = y // 48
        tone = 1.0 + (plank % 3 - 1) * 0.06
        for x in range(N):
            # veio da madeira: ondas ao longo da tábua deformadas pelo ruído
            g = math.sin(y * 0.9 + grain(x, y) * 9 + plank * 2.1)
            k = tone * (0.9 + 0.08 * g) * (0.94 + rng.uniform(0, 0.08))
            px[x, y] = tuple(int(c * k) for c in (128, 92, 54))
    d = ImageDraw.Draw(img)
    for y in range(0, N, 48):
        d.line([(0, y), (N - 1, y)], fill=(62, 42, 22), width=3)
        d.line([(0, y + 3), (N - 1, y + 3)], fill=(150, 112, 70))
    # moldura, travessa em diagonal, cantoneiras de metal com parafusos
    d.rectangle([0, 0, N - 1, N - 1], outline=(70, 48, 26), width=14)
    d.rectangle([14, 14, N - 15, N - 15], outline=(54, 36, 20), width=2)
    d.line([(14, 14), (N - 15, N - 15)], fill=(146, 108, 66), width=14)
    d.line([(14, 21), (N - 22, N - 15)], fill=(92, 64, 36), width=2)
    for cx, cy in ((0, 0), (N - 30, 0), (0, N - 30), (N - 30, N - 30)):
        d.rectangle([cx, cy, cx + 29, cy + 29], fill=(70, 74, 78))
        d.rectangle([cx + 2, cy + 2, cx + 27, cy + 27], outline=(108, 112, 116))
        for bx, by in ((8, 8), (21, 21)):
            d.ellipse([cx + bx - 3, cy + by - 3, cx + bx + 3, cy + by + 3], fill=(140, 144, 148))
    # estêncil
    d.rectangle([84, 100, 172, 156], fill=(46, 38, 30))
    d.text((104, 104), "SC", fill=(186, 164, 120), font_size=34)
    d.text((92, 140), "BIOLAB-07", fill=(170, 150, 110), font_size=11)
    return img


def hazard():
    img = Image.new("RGB", (N, N), (200, 158, 32))
    d = ImageDraw.Draw(img)
    for k in range(-N, N * 2, 64):
        d.polygon([(k, 0), (k + 32, 0), (k + 32 + N, N), (k + N, N)], fill=(30, 28, 24))
    # tinta gasta: arranhões e lascas mostrando o concreto
    wear = smooth_noise(16)
    px = img.load()
    for y in range(N):
        for x in range(N):
            w = wear(x, y)
            if w > 0.72 and rng.random() < (w - 0.72) * 3:
                px[x, y] = (96, 94, 88)
            elif rng.random() < 0.02:
                px[x, y] = tuple(int(c * 0.8) for c in px[x, y])
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in (("concrete", concrete), ("wall", wall), ("crate", crate), ("hazard", hazard)):
        fn().save(OUT / f"{name}.png")
        print(OUT / f"{name}.png")


if __name__ == "__main__":
    main()
