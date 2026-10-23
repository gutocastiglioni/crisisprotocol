import numpy as np
from PIL import Image, ImageDraw, ImageFont

base = Image.open(r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\silhueta_comparativa.png").convert("RGBA")
draw = ImageDraw.Draw(base)

# Annotations on Panel 3 (X offset: 2048, Y offset: 80)
ox = 2048
oy = 80

# 1. Torso width comparison
# Reference chest width: Y=360 -> X = 390..619 (width 229px = 46cm)
# Current chest width: Y=360 -> X = 430..594 (width 164px = 33cm)
draw.line([(ox + 390, oy + 360), (ox + 619, oy + 360)], fill=(0, 255, 0, 255), width=3)
draw.line([(ox + 390, oy + 350), (ox + 390, oy + 370)], fill=(0, 255, 0, 255), width=2)
draw.line([(ox + 619, oy + 350), (ox + 619, oy + 370)], fill=(0, 255, 0, 255), width=2)
draw.text((ox + 504, oy + 340), "Ref Peito: 46 cm", fill=(0, 255, 0, 255), anchor="mm")

draw.line([(ox + 430, oy + 380), (ox + 594, oy + 380)], fill=(255, 80, 80, 255), width=3)
draw.text((ox + 512, oy + 395), "Atual Peito: 33 cm (-13 cm)", fill=(255, 100, 100, 255), anchor="mm")

# 2. Arm angle comparison on left arm (viewer right)
# Ref arm axis: (ox + 600, oy + 280) to (ox + 803, oy + 485) -> 45 deg
draw.line([(ox + 600, oy + 280), (ox + 803, oy + 485)], fill=(0, 255, 0, 255), width=4)
draw.text((ox + 740, oy + 330), "Ref: A-pose 45°", fill=(0, 255, 0, 255))
draw.text((ox + 740, oy + 350), "Braço Robusto (14cm)", fill=(0, 255, 0, 255))

# Current arm axis: (ox + 550, oy + 280) to (ox + 600, oy + 500) -> ~12 deg
draw.line([(ox + 550, oy + 280), (ox + 600, oy + 500)], fill=(255, 50, 50, 255), width=3)
draw.text((ox + 615, oy + 460), "Atual: 12° (Colado)", fill=(255, 80, 80, 255))
draw.text((ox + 615, oy + 480), "Fino (7.5cm)", fill=(255, 80, 80, 255))

# 3. Waist / Belt comparison
# Reference belt width: Y=440 -> X = 413..610 (width 197px = 40cm)
draw.line([(ox + 413, oy + 440), (ox + 610, oy + 440)], fill=(0, 255, 0, 255), width=2)
draw.text((ox + 512, oy + 430), "Ref Cintura: 40 cm", fill=(0, 255, 0, 255), anchor="mm")

out_annotated = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\silhueta_analise.png"
base.save(out_annotated)
print("Saved annotated silhouette:", out_annotated)
