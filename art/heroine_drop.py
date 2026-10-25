"""Pegar a pistola com silenciador na caixa de paraquedas do telhado (animação PickupPistol, estilo do Pickup do fuzil).

Ela ajoelha na frente da caixa (a mesma pose do Pickup, raiz a heroine_rifle.KNEEL_DIST da frente dela), a mão direita
entra na caixa e fecha no cabo da pistola deitada de lado (palma para baixo, cano para a frente, ferrolho para a
esquerda dela) no quadro GRAB_FRAME, e ela levanta voltando para a pose parada com a pistola na mão. A esquerda fica
apoiada no joelho. A pistola na caixa fica em crate_frame() (referencial da pistola na mão = o pulso, ver
heroine_mesh.pistol_frame): o build exporta pistol_crate.glb já nessa posição e o Godot a põe na caixa (SupplyDrop).
"""
from mathutils import Vector

import heroine_ik as IK
import heroine_mesh as HM
import heroine_moves as M
import heroine_rifle as RF

GRAB_FRAME = 24
FRAMES = 50
CRATE_TOP = 0.44  # altura do pulso com a pistola deitada na espuma (topo do corpo da caixa 0,42 + meia espessura)
CRATE_IN = 0.08  # do lado de dentro da frente da caixa até o pulso
CRATE_X = -0.1  # para a direita dela


def pistol_rest():
    """Referencial da pistola na mão direita em repouso: origem no pulso, frente = cano, cima = ferrolho."""
    w, t, _, u = HM.pistol_frame()
    return RF.frame_matrix(w, t, u)


def crate_frame():
    """Pistola deitada de lado na caixa (em relação à raiz dela ajoelhada): cano para a frente, ferrolho para a esquerda."""
    return RF.frame_matrix((CRATE_X, -(RF.KNEEL_DIST + CRATE_IN), CRATE_TOP), (0, -1, 0), (1, 0, 0))


def _pistol_now(sk, m):
    return m["Hand_R"] @ sk.rest["Hand_R"].inverted() @ pistol_rest()


def _grab(sk, pose, target):
    """Mão direita (posição + giro) fechada no cabo da pistola em `target`."""
    def res(m):
        cur = _pistol_now(sk, m)
        e = list(cur.col[3].to_3d() - target.col[3].to_3d())
        e += list((cur.col[1].to_3d() - target.col[1].to_3d()) * 0.3)
        e += list((cur.col[2].to_3d() - target.col[2].to_3d()) * 0.3)
        return e

    return IK.solve(sk, pose, IK.arm_unknowns("R"), res, IK.arm_bounds("R"))


def pickup_keys(A, sk):
    """Ajoelha (perna direita no chão), a direita pega a pistola na caixa e ela levanta com a pistola na mão."""
    kneel_body = {"loc": (0, -0.47, 0), "Hips": (8, 0, 0), "Spine": (8, -6, 0), "Chest": (4, -4, 0), "Neck": (6, 0, 0),
                  "Head": (18, 0, 0)}
    kneel = A.merge(kneel_body, M.legs(80, -95, 10, 0, -95, -40), M.arms(30, -10, 40))
    kneel = RF._kneel_legs(sk, kneel)
    # inclinada para a caixa: o chute da IK (braço direito para a frente e para baixo)
    lean = A.merge(kneel, {"Hips": (10, 0, 0), "Spine": (16, -8, 0), "Chest": (8, -6, 0), "Head": (14, 0, 0)},
                   M.arms(30, -10, 40, 60, -10, 20))
    reach, e = _grab(sk, lean, crate_frame())
    print(f"[drop] PickupPistol: erro da mão direita {e * 1000:.1f} mm")
    # um pouco acima da pistola antes de fechar a mão (a mão entra na caixa de cima)
    above = crate_frame().copy()
    above.translation += Vector((0, 0.04, 0.09))
    hover, _ = _grab(sk, reach, above)
    lift = A.merge(kneel, {"Spine": (12, -8, 0), "Chest": (8, -8, 0), "Head": (6, 6, 0)},
                   {k: reach[k] for k in ("UpperArm_R", "LowerArm_R", "Hand_R")})
    lift["LowerArm_R"] = (70, 0, 0)
    return [
        (0, A.IDLE),
        (12, kneel),
        (19, hover),
        (GRAB_FRAME, reach),
        (27, reach),
        (36, lift),
        (45, A.IDLE),
        (FRAMES, A.IDLE),
    ]


def build_crate_pistol(mb):
    """Pistola + silenciador na posição da caixa (crate_frame), para o pistol_crate.glb."""
    HM.build_pistol(mb)
    HM.build_suppressor(mb)
    m = crate_frame() @ pistol_rest().inverted()
    for v in mb.bm.verts:
        v.co = m @ v.co
