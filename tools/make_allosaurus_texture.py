"""Pinta o atlas 512x512 do alossauro: mesmo layout e mesmas ferramentas do raptor (`make_raptor_texture`), outra pele:
dorso marrom-escuro quase preto, flancos terrosos, faixas largas e poucas, barriga creme e cristas cor de ferrugem.

Uso: python tools/make_allosaurus_texture.py [saida.png]
Saída padrão: game/assets/characters/allosaurus_atlas.png
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "art"))
sys.path.insert(0, str(ROOT / "tools"))
import make_raptor_texture as T  # noqa: E402
import paint_face  # noqa: E402

# olho do alossauro: a cabeça é bem mais comprida (v menor por metro), o olho fica a ~0,4 m da nuca
T.atlas.EYE_UV = (0.2, 0.3)

T.BACK = (40, 34, 30)
T.SIDE = (92, 76, 58)
T.SIDE_HI = (128, 108, 82)
T.BELLY = (190, 172, 132)
T.BELLY_LO = (150, 132, 98)
T.STRIPE = (30, 24, 20)
T.STRIPE_CORE = (18, 14, 12)
T.EYE = (196, 96, 24)
T.EYE_HI = (236, 160, 70)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "game/assets/characters/allosaurus_atlas.png"
    T.paint_skin("body", 5.0, reach=0.36, belly_width=0.17, width=0.26, scale=4, scutes=12)
    T.paint_skin("neck", 2.5, reach=0.34, belly_width=0.2, width=0.24, scutes=6, scale=4)
    T.paint_skin("tail", 7.0, reach=0.44, belly_width=0.12, width=0.3, scutes=16)
    T.paint_skin("thigh", 2.5, reach=0.4, belly_width=0.0, width=0.28, scale=5)
    T.paint_skin("shin", 3.0, reach=0.4, belly_width=0.0, scale=4)
    T.paint_skin("meta", 2.0, reach=0.5, belly_width=0.0, scale=3)
    T.paint_skin("arm", 2.0, reach=0.4, belly_width=0.0, scale=3)
    T.paint_skin("toe", 2.0, reach=0.5, belly_width=0.0, scale=3)
    for n in ("body", "neck", "tail", "thigh"):
        T.speckle(n, 0.008)
    T.paint_head()
    T.paint_jaw()
    T.shade_trunk("body", 0.17, ends=(0.15, 0.2), hang=0.1)
    T.shade_trunk("neck", 0.2, ends=(0.22, 0.2))
    T.throat_folds("neck", 6, 0.2)
    T.shade_trunk("tail", 0.12, sheen=0.22, flank=0.36, ends=(0.25, 0.0))
    T.shade_limb("thigh", top=1.18, bottom=0.62, bulge=0.15, ends=(0.3, 0.35))
    T.shade_limb("shin", top=1.02, bottom=0.72, bulge=0.12, ends=(0.35, 0.25))
    T.shade_limb("meta", top=0.95, bottom=0.8, ends=(0.2, 0.25))
    T.shade_limb("arm", top=1.08, bottom=0.8, bulge=0.08, ends=(0.3, 0.2))
    T.shade_limb("toe", top=0.95, bottom=0.8, ends=(0.2, 0.0))
    T.shade_head()
    T.multiply("jaw", lambda u, v: 1 - 0.25 * T.gauss(abs(u - 0.5) * 2 - 0.35, 0.12) - 0.12 * T.gauss(v, 0.1))
    T.paint_gradient("teeth", T.TOOTH, T.TOOTH_LO)
    T.paint_gradient("mouth", T.MOUTH, T.MOUTH_LO)
    T.paint_gradient("claw", (120, 70, 44), (40, 28, 22), streak=(150, 100, 70))  # garras e cristas cor de ferrugem
    final = paint_face.pad(T.img)
    out.parent.mkdir(parents=True, exist_ok=True)
    final.convert("RGB").save(out)
    print(f"[allosaurus] atlas salvo em {out}")


if __name__ == "__main__":
    main()
