"""Junta capturas 320x240 do jogo numa folha 2x (uso: python tools/game_sheet.py <pasta> <saida> nome1 nome2 ...)."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

folder, out, names = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]
ims = [Image.open(folder / f"{n}.png").convert("RGB") for n in names]
w, h = ims[0].size
s, cols = 2, 4
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (w * s * cols, (h * s + 12) * rows))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(zip(names, ims)):
    x, y = (i % cols) * w * s, (i // cols) * (h * s + 12)
    sheet.paste(im.resize((im.width * s, im.height * s), Image.NEAREST), (x, y + 12))
    d.text((x + 2, y), n, fill=(255, 255, 0))
sheet.save(out)
print(out)
