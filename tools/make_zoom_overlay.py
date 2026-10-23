import numpy as np
from PIL import Image, ImageDraw, ImageFont

# Load the single overlay image (1024x1024)
overlay = Image.open(r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\silhueta_overlay.png").convert("RGBA")

# Crop upper body: X 100..924, Y 50..750 (824 x 700)
cropped = overlay.crop((80, 60, 944, 760))
W, H = cropped.size

draw = ImageDraw.Draw(cropped)
# Use thick lines and bold markers
# Shift coordinates by (-80, -60)
def tr(x, y):
    return (x - 80, y - 60)

# 1. Arm trajectory lines
p_sh = tr(600, 280)
p_wt = tr(803, 485)
draw.line([p_sh, p_wt], fill=(0, 255, 128, 255), width=5)

p_sh_cur = tr(550, 280)
p_wt_cur = tr(610, 500)
draw.line([p_sh_cur, p_wt_cur], fill=(255, 50, 50, 255), width=5)

# 2. Chest width
c_ref_l, c_ref_r = tr(390, 360), tr(619, 360)
draw.line([c_ref_l, c_ref_r], fill=(0, 255, 128, 255), width=4)

c_cur_l, c_cur_r = tr(430, 380), tr(594, 380)
draw.line([c_cur_l, c_cur_r], fill=(255, 60, 60, 255), width=4)

# Try loading a large default font if available, or draw styled label boxes
def draw_label(text, pos, bg_col, text_col=(255, 255, 255, 255)):
    # Draw simple background box
    x, y = pos
    padding = 6
    # approximate text length: len * 8
    tw = len(text) * 8
    th = 16
    draw.rectangle([x - padding, y - padding, x + tw + padding, y + th + padding], fill=bg_col)
    draw.text((x, y), text, fill=text_col)

draw_label("SOLICITADO: A-POSE 45 DEG (ROBUSTO 14cm)", (p_wt[0] - 140, p_wt[1] - 80), (0, 100, 40, 230))
draw_label("ATUAL: 12 DEG COLADO (FINO 7.5cm)", (p_wt_cur[0] + 15, p_wt_cur[1] - 30), (140, 20, 20, 230))
draw_label("SOLICITADO PEITO: 46 cm", (c_ref_l[0] + 40, c_ref_l[1] - 30), (0, 100, 40, 230))
draw_label("ATUAL PEITO: 33 cm (-13 cm)", (c_cur_l[0] + 40, c_cur_r[1] + 12), (140, 20, 20, 230))

out_path = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\silhueta_zoom_analise.png"
cropped.save(out_path)
print("Saved zoom analysis:", out_path)
