import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

ref_path = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\.user_uploaded\media_1792589449209_208716b3.png"
cur_path = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\cur_render_rest.png"
out_overlay_path = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\silhueta_overlay.png"
out_triptych_path = r"C:\Users\Augusto\.gemini\antigravity\brain\3ca1af0d-d8cf-49aa-98b1-3369dc3a18fc\silhueta_comparativa.png"

ref = Image.open(ref_path).convert("RGBA")
cur = Image.open(cur_path).convert("RGBA")

# Extract alpha mask of current render
cur_arr = np.array(cur)
alpha = cur_arr[:, :, 3]

# Create edge silhouette of current model
mask_img = Image.fromarray(alpha)
# Find edges: dilate minus erode
dilated = mask_img.filter(ImageFilter.MaxFilter(5))
eroded = mask_img.filter(ImageFilter.MinFilter(5))
edges = np.array(dilated).astype(int) - np.array(eroded).astype(int)
edges = np.clip(edges, 0, 255).astype(np.uint8)

# Color edge: Neon Magenta/Cyan (e.g. Cyan RGB: 0, 255, 255, alpha: edges)
# We can do Cyan outline + 25% magenta fill
edge_img = np.zeros((1024, 1024, 4), dtype=np.uint8)
# Fill interior with subtle transparent orange/red
edge_img[:, :, 0] = 255
edge_img[:, :, 1] = 60
edge_img[:, :, 2] = 20
edge_img[:, :, 3] = (alpha > 30).astype(np.uint8) * 55

# Outline with bright neon cyan
edge_mask = edges > 40
edge_img[edge_mask, 0] = 0
edge_img[edge_mask, 1] = 255
edge_img[edge_mask, 2] = 255
edge_img[edge_mask, 3] = 255

overlay_layer = Image.fromarray(edge_img, mode="RGBA")
composite = Image.alpha_composite(ref, overlay_layer)
composite.save(out_overlay_path)
print("Saved overlay:", out_overlay_path)

# Make side-by-side triptych (3 panels):
# 1. Referencia Solicitada (media_1792589449209_208716b3.png)
# 2. Modelo Atual (cur_render_rest.png sobre fundo neutro)
# 3. Silhueta do Atual Sobreposto na Referencia Solicitada
triptych = Image.new("RGBA", (1024 * 3, 1024 + 80), (30, 32, 38, 255))
draw = ImageDraw.Draw(triptych)

# Panel 1
triptych.paste(ref, (0, 80))

# Panel 2: Cur render over ref-like background
bg_panel2 = Image.new("RGBA", (1024, 1024), (74, 76, 84, 255))
bg_panel2.paste(cur, (0, 0), cur)
triptych.paste(bg_panel2, (1024, 80))

# Panel 3: Composite
triptych.paste(composite, (2048, 80))

# Headers
titles = [
    ("1. MODELO SOLICITADO (REFERENCIA ORIGINAL)", 512),
    ("2. MODELO ATUAL (ESTADO ATUAL)", 1024 + 512),
    ("3. SILHUETA ATUAL (CIANO/LARANJA) SOBRE REFERENCIA", 2048 + 512),
]
for title, cx in titles:
    draw.text((cx, 40), title, fill=(255, 255, 255, 255), anchor="mm")

triptych.save(out_triptych_path)
print("Saved comparative triptych:", out_triptych_path)
