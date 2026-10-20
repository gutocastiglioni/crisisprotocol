"""Copia o modelo "DinoCrisisCustom - Regina" (Otherspectre, CC-BY 4.0) da referência local (possible_models/, fora do
git) para art/base_body/: a malha (Mesh.fbx) e só as texturas de cor, reduzidas a no máximo 512 px em PNG (visual de
PS2; os mapas normal/especular não são usados). Rodar uma vez; o build da heroína lê art/base_body/.

Uso: python tools/prepare_base_body.py
"""
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "possible_models/regina/dinocrisiscustom-regina/Test/Test"
OUT = ROOT / "art/base_body"
# arquivo no modelo -> nosso nome (o mesmo de heroine_body.FBX_TEXTURES)
TEXTURES = {"regina_d": "costume", "regina_u1_v1_u1_v1": "skin", "face_d": "face", "eye": "eye", "eyelash": "eyelash",
            "hair_d": "hair", "hair_2_d": "hair_2", "holster_d": "holster", "4": "pouch"}
MAX = 512


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SRC / "Mesh.fbx", OUT / "Mesh.fbx")
    for src_name, name in TEXTURES.items():
        im = Image.open(SRC / f"{src_name}.tga")
        im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
        if max(im.size) > MAX:
            k = MAX / max(im.size)
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        im.save(OUT / f"{name}.png")
        print(f"[corpo] {name}.png {im.size} {im.mode}")
    (OUT / "CREDITS.txt").write_text(
        '"DinoCrisisCustom - Regina" by Otherspectre (https://sketchfab.com/Otherspectre)\n'
        "https://sketchfab.com/3d-models/dinocrisiscustom-regina-4237f76d28de41afbdc2ac0e948b5991\n"
        "Licensed under Creative Commons Attribution 4.0 (http://creativecommons.org/licenses/by/4.0/).\n"
        "Changes: textures reduced to 512 px; in the build the mesh is posed (arms lowered, fingers closed), re-rigged to\n"
        "the game skeleton and reduced in triangles (art/heroine_body.py).\n", encoding="utf8")


if __name__ == "__main__":
    main()
