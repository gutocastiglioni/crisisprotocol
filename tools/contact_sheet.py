"""Junta PNGs de prévia numa folha só (para revisão rápida).

Uso: python tools/contact_sheet.py <pasta> <saida.png> [prefixo] [colunas]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

folder, out = Path(sys.argv[1]), Path(sys.argv[2])
prefix = sys.argv[3] if len(sys.argv) > 3 else ""
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
files = sorted(p for p in folder.glob(f"{prefix}*.png"))
if not files:
    raise SystemExit("nenhuma imagem")
w, h = Image.open(files[0]).size
scale = 0.5 if len(files) > 12 else 1.0
tw, th = int(w * scale), int(h * scale)
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (tw * cols, (th + 14) * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    im = Image.open(f).convert("RGB").resize((tw, th), Image.NEAREST)
    x, y = (i % cols) * tw, (i // cols) * (th + 14)
    sheet.paste(im, (x, y + 14))
    d.text((x + 3, y + 1), f.stem, fill=(230, 230, 230))
sheet.save(out)
print(out)
