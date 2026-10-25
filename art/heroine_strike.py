"""Golpes furtivos a curta distância (faca): Assassinate pelas costas e CritStrike no inimigo caído.
Mesmo jeito de heroine_moves (poses por quadros-chave, pés presos por IK, caminho da raiz `*_PATH` gravado no
heroine_moves.json para o Godot seguir).
"""
import heroine_moves as M

ASSASSINATE_FRAMES = 20
ASSASSINATE_HIT = 8
ASSASSINATE_PATH = [(0, 0.0, 0.0), (4, 0.15, 0.0), (8, 0.42, 0.0), (14, 0.45, 0.0), (20, 0.45, 0.0)]
CRIT_FRAMES = 22
CRIT_HIT = 9
CRIT_PATH = [(0, 0.0, 0.0), (5, 0.22, 0.0), (9, 0.35, 0.0), (16, 0.35, 0.0), (22, 0.35, 0.0)]


def assassinate_keys(A, sk):
    """Golpe furtivo silencioso pelas costas: avança agachando (0-4), golpeia no pescoço/tronco (8) e recolhe (20)."""
    keys = [
        (0, A.IDLE),
        (4, A.merge(M.legs(28, -52, 20, 22, -42, 16, spread=5),
                    {"loc": (0, -0.10, 0), "Spine": (12, -15, 0), "Chest": (8, -20, 0), "Head": (-12, 20, 0),
                     "UpperArm_R": (-22, -18, 32), "LowerArm_R": (95, 0, 0), "Hand_R": (-10, 0, 0),
                     "UpperArm_L": (65, 10, -15), "LowerArm_L": (40, 0, 0)})),
        (ASSASSINATE_HIT, A.merge(M.legs(20, -38, 12, 42, -74, 24, spread=6),
                                  {"loc": (0, -0.18, 0), "Spine": (18, 18, 0), "Chest": (10, 24, 0),
                                   "Head": (-18, -24, 0), "UpperArm_R": (88, 24, -18), "LowerArm_R": (25, 0, 0),
                                   "Hand_R": (-12, 0, 0), "UpperArm_L": (48, -14, 18), "LowerArm_L": (72, 0, 0)})),
        (14, A.merge(M.legs(26, -48, 18, 30, -54, 20, spread=5),
                     {"loc": (0, -0.10, 0), "Spine": (10, 6, 0), "Chest": (6, 8, 0), "Head": (-10, -8, 0),
                      "UpperArm_R": (42, -8, 18), "LowerArm_R": (62, 0, 0),
                      "UpperArm_L": (24, 0, 8), "LowerArm_L": (42, 0, 0)})),
        (ASSASSINATE_FRAMES, A.IDLE),
    ]
    plants = [M.Plant("foot", "L", 0, 3), M.Plant("foot", "R", 0, 2),
              M.Plant("foot", "R", ASSASSINATE_HIT, ASSASSINATE_FRAMES), M.Plant("foot", "L", 14, ASSASSINATE_FRAMES)]
    return M.bake(sk, "Assassinate", keys, plants, ASSASSINATE_PATH)


def crit_strike_keys(A, sk):
    """Golpe crítico de cima para baixo no inimigo caído: ergue o golpe (0-5), crava no chão (9) e levanta (22)."""
    keys = [
        (0, A.IDLE),
        (5, A.merge(M.legs(20, -38, 14, 30, -56, 20, spread=5),
                    {"loc": (0, -0.06, 0), "Spine": (-8, -10, 0), "Chest": (-10, -14, 0), "Head": (16, 10, 0),
                     "UpperArm_R": (132, -10, 14), "LowerArm_R": (54, 0, 0),
                     "UpperArm_L": (72, 10, -12), "LowerArm_L": (48, 0, 0)})),
        (CRIT_HIT, A.merge(M.legs(62, -104, 34, 68, -110, 36, spread=7),
                           {"loc": (0, -0.34, 0), "Hips": (10, 0, 0), "Spine": (26, 12, 0), "Chest": (16, 16, 0),
                            "Head": (8, -12, 0), "UpperArm_R": (66, 12, -8), "LowerArm_R": (14, 0, 0),
                            "Hand_R": (-15, 0, 0), "UpperArm_L": (34, -10, 16), "LowerArm_L": (64, 0, 0)})),
        (16, A.merge(M.legs(44, -78, 26, 48, -84, 28, spread=6),
                     {"loc": (0, -0.22, 0), "Hips": (4, 0, 0), "Spine": (14, 4, 0), "Chest": (8, 6, 0),
                      "Head": (2, -4, 0), "UpperArm_R": (38, 0, 10), "LowerArm_R": (52, 0, 0),
                      "UpperArm_L": (24, 0, 8), "LowerArm_L": (42, 0, 0)})),
        (CRIT_FRAMES, A.IDLE),
    ]
    plants = [M.Plant("foot", "L", 0, 3), M.Plant("foot", "R", 0, 2),
              M.Plant("foot", "R", CRIT_HIT, CRIT_FRAMES), M.Plant("foot", "L", CRIT_HIT, CRIT_FRAMES)]
    return M.bake(sk, "CritStrike", keys, plants, CRIT_PATH)
