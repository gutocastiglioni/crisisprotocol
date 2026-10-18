"""Texturas 256x256 do galpão (visual de PS2 do começo): piso de concreto, parede de painéis metálicos,
caixa de madeira, faixa de perigo e os baús de armas (metal verde-oliva, estêncil do M16 e da escopeta). Cada uma cobre
~2 m no mundo (world_uv_scale 0.5). Mais os decalques de buraco de bala (bullet_holes.png) e os quadros dos efeitos
do tiro (shot_fx.png: clarões e baforada), com alfa.

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


def chest(caliber="U.S. 5.56MM", label="RIFLE M16"):
    """Baú militar de metal: verde-oliva com nervuras, cantos gastos e estêncil."""
    img = base((78, 84, 52), 0.04, cells=((32, 0.12), (8, 0.06)))
    d = ImageDraw.Draw(img)
    # nervuras horizontais (sombra embaixo, brilho em cima)
    for y in (40, 128, 216):
        d.rectangle([0, y - 6, N - 1, y + 6], fill=(70, 76, 46))
        d.line([(0, y - 6), (N - 1, y - 6)], fill=(104, 110, 72), width=2)
        d.line([(0, y + 6), (N - 1, y + 6)], fill=(44, 48, 28), width=2)
    d.rectangle([0, 0, N - 1, N - 1], outline=(46, 50, 30), width=6)
    # tinta lascada nos cantos e nas bordas
    wear = smooth_noise(8)
    px = img.load()
    for y in range(N):
        for x in range(N):
            edge = min(x, y, N - 1 - x, N - 1 - y)
            if edge < 12 and wear(x, y) > 0.62 and rng.random() < 0.5:
                px[x, y] = (96, 94, 88)
    for text, ty in ((caliber, 66), (label, 150)):
        tw = d.textlength(text, font_size=18)
        d.text(((N - tw) / 2, ty), text, fill=(206, 196, 150), font_size=18)
    return img


def chest_shotgun():
    return chest("U.S. 12 GAUGE", "SHOTGUN M870")


def bullet_holes():
    """Decalques de tiro 128x128 com alfa, 2x2 quadros de 64: [0] buraco (concreto/madeira), [1] mossa no metal,
    [2] chumbo pequeno, [3] chumbo no metal. O fundo transparente leva a cor média da borda (filtro sem halo)."""
    S = 64
    img = Image.new("RGBA", (S * 2, S * 2), (70, 66, 60, 0))
    r = random.Random(7)
    for i, (metal, core) in enumerate(((False, 11), (True, 9), (False, 7), (True, 6))):
        tile = Image.new("RGBA", (S, S), (70, 66, 60, 0))
        td = ImageDraw.Draw(tile)
        c = S / 2
        ring = core * 2.3
        # borda lascada (concreto) ou amassada e brilhante (metal), recortada de forma irregular
        pts = []
        for k in range(18):
            a = k / 18 * math.tau
            rr = ring * r.uniform(0.75, 1.2)
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
        td.polygon(pts, fill=(150, 150, 156, 255) if metal else (104, 100, 92, 255))
        if not metal:
            # rachaduras saindo do buraco
            for k in range(5):
                a = r.uniform(0, math.tau)
                ln = min(ring * r.uniform(1.05, 1.4), S / 2 - 2)
                td.line([(c, c), (c + math.cos(a) * ln, c + math.sin(a) * ln)], fill=(40, 38, 34, 255), width=2)
        td.ellipse([c - core * 1.5, c - core * 1.5, c + core * 1.5, c + core * 1.5],
                   fill=(96, 98, 104, 255) if metal else (62, 58, 52, 255))
        td.ellipse([c - core, c - core, c + core, c + core], fill=(8, 8, 8, 255))
        img.paste(tile, ((i % 2) * S, (i // 2) * S))
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


def grass():
    """Capim de chão: verde manchado com fios claros e escuros e uns tufos de terra."""
    img = base((54, 88, 40), 0.06, ((32, 0.16), (8, 0.10)))
    d = ImageDraw.Draw(img)
    for _ in range(1400):
        x, y = rng.randrange(N), rng.randrange(N)
        ln = rng.randint(3, 8)
        c = rng.choice(((82, 124, 52), (34, 62, 26), (96, 132, 58), (44, 76, 32)))
        wrap_line(d, [(x, y), (x + rng.randint(-2, 2), y - ln)], c, 1)
    for _ in range(6):
        x, y, r = rng.randrange(N), rng.randrange(N), rng.randint(4, 9)
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d.ellipse([x - r + ox, y - r * 0.6 + oy, x + r + ox, y + r * 0.6 + oy], fill=(78, 62, 40))
    return img


def dirt():
    """Terra batida da estrada: marrom com poças secas, pedrinhas e raízes finas."""
    img = base((122, 94, 62), 0.07, ((32, 0.16), (8, 0.09)))
    d = ImageDraw.Draw(img)
    for _ in range(40):
        x, y, r = rng.randrange(N), rng.randrange(N), rng.randint(5, 14)
        c = rng.choice(((98, 74, 48), (140, 110, 76)))
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d.ellipse([x - r + ox, y - r * 0.6 + oy, x + r + ox, y + r * 0.6 + oy], fill=c)
    for _ in range(700):
        x, y = rng.randrange(N), rng.randrange(N)
        r = rng.choice((1, 1, 2))
        c = rng.choice(((160, 150, 132), (84, 70, 54), (132, 122, 104), (64, 52, 40)))
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    for _ in range(5):
        x, y = rng.randrange(N), rng.randrange(N)
        ang = rng.uniform(0, 2 * math.pi)
        pts = [(x, y)]
        for _ in range(rng.randint(6, 12)):
            ang += rng.uniform(-0.6, 0.6)
            x, y = x + math.cos(ang) * 5, y + math.sin(ang) * 5
            pts.append((x, y))
        wrap_line(d, pts, (70, 54, 38), 2)
    return img


def bark():
    """Casca de árvore: sulcos verticais escuros, cristas claras e uns nós. Emenda nos lados."""
    streak = smooth_noise(16)
    fine = smooth_noise(4)
    img = Image.new("RGB", (N, N))
    px = img.load()
    for y in range(N):
        for x in range(N):
            k = 0.55 + 0.75 * streak(x * 2, y // 8) + (fine(x, y // 3) - 0.5) * 0.3 + rng.uniform(-0.04, 0.04)
            px[x, y] = tuple(max(0, min(255, int(c * k))) for c in (92, 70, 50))
    d = ImageDraw.Draw(img)
    for _ in range(4):
        x, y = rng.randrange(N), rng.randrange(N)
        for ox in (-N, 0, N):
            d.ellipse([x - 9 + ox, y - 13, x + 9 + ox, y + 13], fill=(40, 30, 22), outline=(116, 92, 66))
    return img


def leaves():
    """Folhagem de copa e de arbusto: manchas de folhas em vários verdes (sem alfa; o recorte é pela malha)."""
    img = base((40, 74, 34), 0.05, ((32, 0.20), (8, 0.12)))
    d = ImageDraw.Draw(img)
    for _ in range(1100):
        x, y = rng.randrange(N), rng.randrange(N)
        w, h = rng.randint(3, 7), rng.randint(5, 11)
        c = rng.choice(((24, 52, 24), (58, 104, 40), (78, 124, 48), (34, 64, 30), (92, 132, 54), (48, 86, 36)))
        a = rng.uniform(0, math.pi)
        dx, dy = math.cos(a) * h, math.sin(a) * h
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d.polygon([(x + ox, y + oy), (x + dx / 2 - dy * w / h / 2 + ox, y + dy / 2 + dx * w / h / 2 + oy),
                           (x + dx + ox, y + dy + oy), (x + dx / 2 + dy * w / h / 2 + ox, y + dy / 2 - dx * w / h / 2 + oy)], fill=c)
    return img


def rock():
    """Pedra cinza com rachaduras e musgo."""
    img = base((112, 110, 102), 0.07, ((32, 0.18), (8, 0.12)))
    d = ImageDraw.Draw(img)
    for _ in range(6):
        x, y = rng.randrange(N), rng.randrange(N)
        ang = rng.uniform(0, 2 * math.pi)
        pts = [(x, y)]
        for _ in range(rng.randint(8, 16)):
            ang += rng.uniform(-0.8, 0.8)
            x, y = x + math.cos(ang) * 7, y + math.sin(ang) * 7
            pts.append((x, y))
        wrap_line(d, pts, (54, 52, 48), 2)
    moss = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(moss)
    for _ in range(14):
        x, y, r = rng.randrange(N), rng.randrange(N), rng.randint(10, 28)
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                md.ellipse([x - r + ox, y - r + oy, x + r + ox, y + r + oy], fill=rng.randint(60, 140))
    moss = moss.filter(ImageFilter.GaussianBlur(7))
    return Image.composite(Image.new("RGB", (N, N), (62, 92, 40)), img, moss)


def _card():
    """Cartão com alfa: o RGB do fundo transparente é verde (o filtro/mipmap não puxa preto para a borda)."""
    return Image.new("RGBA", (N, N), (40, 72, 30, 0))


def grass_card():
    """Tufo de capim alto para cartões cruzados: lâminas afinando para a ponta sobre fundo transparente."""
    img = _card()
    d = ImageDraw.Draw(img)
    for _ in range(46):
        x = rng.randint(8, N - 8)
        top = rng.randint(30, 150)
        lean = rng.randint(-34, 34)
        w = rng.randint(4, 8)
        g = rng.randint(0, 40)
        base_c = (30 + g // 2, 58 + g, 24, 255)
        tip_c = (96 + g, 140 + g // 2, 54, 255)
        steps = 12
        for k in range(steps):
            t0, t1 = k / steps, (k + 1) / steps
            y0, y1 = N - 1 - (N - 1 - top) * t0, N - 1 - (N - 1 - top) * t1
            x0, x1 = x + lean * t0 * t0, x + lean * t1 * t1
            w0, w1 = w * (1 - t0), w * (1 - t1)
            c = tuple(int(base_c[i] + (tip_c[i] - base_c[i]) * t0) for i in range(4))
            d.polygon([(x0 - w0, y0), (x0 + w0, y0), (x1 + w1, y1), (x1 - w1, y1)], fill=c)
    return img


def fern_card():
    """Samambaia: várias folhas arqueadas com folíolos, sobre fundo transparente."""
    img = _card()
    d = ImageDraw.Draw(img)
    cx = N // 2
    for k in range(9):
        ang = math.radians(-80 + k * 20 + rng.uniform(-6, 6))
        length = rng.randint(100, 170)
        px_, py_ = cx, N - 4
        for s in range(30):
            t = s / 30
            a = ang + t * 0.3 * (1 if ang >= 0 else -1)
            nx = px_ + math.sin(a) * length / 30
            ny = py_ - math.cos(a) * length / 30
            d.line([(px_, py_), (nx, ny)], fill=(40, 78, 30, 255), width=2)
            leaf = int(18 * (1 - t) + 4)
            c = (50 + int(40 * t), 98 + int(30 * t), 36, 255)
            for sgn in (-1, 1):
                d.line([(nx, ny), (nx + math.cos(a) * leaf * sgn, ny + math.sin(a) * leaf * sgn - leaf * 0.25)], fill=c, width=3)
            px_, py_ = nx, ny
    return img


def shot_fx():
    """Efeitos do tiro 192x64 com alfa, 3 quadros de 64: [0] clarão redondo de 4 pontas (pistola, escopeta),
    [1] estrela de 3 jatos do quebra-chamas (M16), [2] baforada macia (fumaça, poeira, sangue: tingida no jogo)."""
    S = 64
    img = Image.new("RGBA", (S * 3, S), (255, 255, 255, 0))
    c = S / 2 - 0.5
    px = img.load()
    for y in range(S):
        for x in range(S):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy) / (S / 2)
            a = math.atan2(dy, dx)
            # 0: miolo branco-amarelo + 4 pontas (rodadas 45°) + 4 menores
            spikes = 0.55 + 0.4 * abs(math.cos(2 * a)) ** 6 + 0.18 * abs(math.sin(2 * a)) ** 8
            k = max(0.0, 1.0 - r / spikes)
            if k > 0:
                px[x, y] = (255, int(200 + 55 * k), int(90 + 165 * k * k), int(255 * min(1.0, k * 2.2)))
            # 1: três jatos finos (laterais do quebra-chamas) e miolo pequeno
            jets = 0.3 + 0.68 * max(0.0, math.cos(3 * (a + math.pi / 2))) ** 18
            k = max(0.0, 1.0 - r / jets)
            if k > 0:
                px[x + S, y] = (255, int(190 + 65 * k), int(80 + 170 * k * k), int(255 * min(1.0, k * 2.5)))
            # 2: baforada: borda irregular e macia
            wob = 0.86 + 0.06 * math.sin(a * 5 + 1.3) + 0.03 * math.sin(a * 9)
            k = max(0.0, 1.0 - r / wob)
            if k > 0:
                px[x + 2 * S, y] = (255, 255, 255, int(255 * min(1.0, k * 1.6) ** 1.4))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in (("concrete", concrete), ("wall", wall), ("crate", crate), ("hazard", hazard), ("chest", chest),
                     ("chest_shotgun", chest_shotgun), ("bullet_holes", bullet_holes),
                     ("grass", grass), ("dirt", dirt), ("bark", bark), ("leaves", leaves), ("rock", rock),
                     ("grass_card", grass_card), ("fern_card", fern_card), ("shot_fx", shot_fx)):
        fn().save(OUT / f"{name}.png")
        print(OUT / f"{name}.png")


if __name__ == "__main__":
    main()
