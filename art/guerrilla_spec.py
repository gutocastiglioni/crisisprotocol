"""Medidas e cores do guerrilheiro encapuzado, tiradas da imagem de referência (o primeiro boneco do painel que o
usuário mandou: vista de frente, braços em A, 1,80 m). Uma fonte só para a malha (art/guerrilla_body.py), o esqueleto
(heroine_spec.use_joints) e a pintura do atlas (tools/make_guerrilla_texture.py). Ficha com as cotas: a que foi
aprovada a partir de guerrilla_ficha.png.

Larguras de frente medidas na referência (largura total): capuz 18 cm, gola 19, alto do colete 41 (com os ombros do
moletom), peito 44, colete 40 em z 1,10, barra do colete 36, cinto 35. Braço: eixo a 44° na pose da referência,
passando no ombro em x = 19 cm; ombro ao punho 48 cm (25 + 23, o cotovelo não aparece na manga); grossura 10,9 / 9,4 /
7,9 / 5,5 cm (meio do braço, cotovelo, antebraço, punho). A referência só tem a vista de frente: as profundidades são
de um homem comum. Calça, cinto, coldre e coturnos não são gerados aqui: são os de antes (art/guerrilla_lower.py).
Metros, Blender: Z para cima, frente -Y, esquerda +X.
"""
import math

HEIGHT = 1.80

# ------------------------------------------------------------------ esqueleto (lado esquerdo, +X)
ARM_SPREAD = math.radians(12)  # o mesmo repouso da heroína (as poses dela partem dele)
SHOULDER = (0.170, 0.0, 1.47)  # junta do ombro: 2 cm acima do eixo medido (x 0,189 em z 1,43) para o alto do ombro bater
# com a linha da referência (1,485 em x 20 cm, 1,463 em 24 cm); mais baixo o ombro ficava caído
# alto do ombro cai na linha da referência (0,193 m em z 1,485 e 0,266 m em z 1,44, com o braço em A)
UPPER_ARM, FOREARM, HAND = 0.269, 0.239, 0.10  # 48 cm de z 1,43 ao punho, mais os 2,8 cm até a junta
HIP = (0.10, 0.0, 0.93)
KNEE = (0.12, -0.01, 0.51)
ANKLE = (0.13, 0.02, 0.095)
TOE = (0.13, -0.15, 0.03)
TORSO_BONES = {
    "Hips": ((0.0, 0.0, 0.93), (0.0, 0.0, 1.05)),
    "Spine": ((0.0, 0.0, 1.05), (0.0, 0.0, 1.22)),
    "Chest": ((0.0, 0.0, 1.22), (0.0, 0.0, 1.48)),
    "Neck": ((0.0, 0.0, 1.48), (0.0, 0.0, 1.56)),
    "Head": ((0.0, 0.0, 1.56), (0.0, 0.0, 1.78)),
}


def joints():
    """Juntas no formato de heroine_spec.use_joints (só no Blender: o pintor do atlas lê o resto sem mathutils)."""
    from mathutils import Vector

    return {
        "shoulder": Vector(SHOULDER), "upper_arm": UPPER_ARM, "forearm": FOREARM, "hand": HAND,
        "hip": Vector(HIP), "knee": Vector(KNEE), "ankle": Vector(ANKLE), "toe": Vector(TOE),
        "torso": {k: (Vector(h), Vector(t)) for k, (h, t) in TORSO_BONES.items()},
    }


# ------------------------------------------------------------------ tronco: moletom por baixo, colete por cima
TORSO_SIDES = 24
# corpo de moletom: (z, centro y, meia-largura, meia-profundidade na frente, atrás)
BODY = [
    (0.945, 0.000, 0.150, 0.100, 0.100),  # dentro da calça (por baixo do cinto, alto em 0,969)
    (0.972, 0.000, 0.158, 0.110, 0.110),  # faixa de moletom entre o cinto e o colete
    (0.984, 0.000, 0.156, 0.110, 0.110),
    (0.990, 0.000, 0.152, 0.110, 0.110),
    (1.012, -0.001, 0.152, 0.108, 0.108),
    (1.050, -0.004, 0.152, 0.106, 0.106),
    (1.120, -0.006, 0.155, 0.106, 0.108),
    (1.200, -0.008, 0.158, 0.110, 0.110),
    (1.270, -0.008, 0.158, 0.112, 0.112),
    (1.305, -0.007, 0.130, 0.112, 0.112),
    (1.340, -0.006, 0.178, 0.110, 0.110),  # axila: a emenda com o braço começa aqui (5 cm, como na referência)
    (1.385, -0.003, 0.188, 0.106, 0.108),
    (1.430, 0.000, 0.188, 0.100, 0.104),  # ombro: vai até a cúpula do deltoide (a união solda só aqui)
    (1.470, 0.000, 0.192, 0.096, 0.100),
    (1.485, 0.000, 0.188, 0.094, 0.098),  # alto do ombro: 0,182 m de frente com o braço em A (referência)
]
# colete (placa da frente e de trás largas, lateral recolhida onde o braço caído passa):
# (z, largura de frente, meia-largura na lateral, frente, costas[, expoente: menor = cantos mais redondos]).
VEST = {
    0.990: (0.163, 0.145, 0.140, 0.134, 2.3),  # pé do colete (degrau sobre o moletom): cantos arredondados de frente
    1.012: (0.178, 0.150, 0.145, 0.137, 2.8),
    1.050: (0.185, 0.152, 0.144, 0.136, 3.0),
    1.120: (0.200, 0.155, 0.146, 0.138),
    1.200: (0.208, 0.150, 0.150, 0.140),
    1.270: (0.220, 0.135, 0.152, 0.142),  # peito: 44 cm de frente; a lateral recolhe onde o braço caído passa
    1.305: (0.215, 0.130, 0.152, 0.142),  # axila
    1.340: (0.208, 0.178, 0.150, 0.140),
    1.385: (0.200, 0.188, 0.146, 0.138),
    1.430: (0.195, 0.162, 0.140, 0.134),
    1.470: (0.190, 0.158, 0.132, 0.130),
    1.485: (0.185, 0.150, 0.126, 0.126),  # alto do colete (alças por cima do ombro)
}
VEST_T = 0.028  # espessura do colete sobre o moletom (para o pintor e a vista de lado)
VEST_ARMHOLE = ((1.305, 0.215), (1.485, 0.148))  # cava: até onde vai o colete, da axila ao canto do ombro
PLATE = 0.008  # a placa da frente salta um pouco mais (borda do painel)
NECK_RING = (1.502, 0.005, 0.145, 0.100)  # emenda com o capuz: a gola cai larga sobre o alto do colete (0,154 m em z 1,50)


def _interp(table, z):
    rows = sorted(table)
    if z <= rows[0][0]:
        return rows[0][1:]
    for a, b in zip(rows, rows[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(p + (q - p) * t for p, q in zip(a[1:], b[1:]))
    return rows[-1][1:]


def armhole(z):
    """Meia-largura até onde vai o colete na altura z (abaixo da axila ele cobre tudo)."""
    (z0, x0), (z1, x1) = VEST_ARMHOLE
    if z <= z0:
        return 9.0
    return x0 + (x1 - x0) * min(1.0, (z - z0) / (z1 - z0))


def body_point(z, th):
    """Ponto do moletom no anel z, ângulo th (0 = costas, pi/2 = esquerda, pi = frente): (x, y)."""
    yc, rx, ryf, ryb = _interp(BODY, z)
    c = math.cos(th)
    return rx * math.sin(th), yc + (ryb if c > 0 else ryf) * c


def _vest_outline(w, side, df, db, n=3.2, samples=720):
    """Contorno do colete: superelipse (cantos quase retos) com a lateral recolhida até exatamente `side` em y = 0 (onde
    o braço caído passa); a largura da superelipse é buscada para a largura de frente (o máximo de x) dar `w`."""
    def outline(wr):
        pts = []
        for i in range(samples):
            a = 2 * math.pi * i / samples
            s, c = math.sin(a), math.cos(a)
            d = db if c > 0 else df
            x = wr * math.copysign(abs(s) ** (2 / n), s)
            y = d * math.copysign(abs(c) ** (2 / n), c)
            x -= math.copysign((wr - side) * math.exp(-(y / (0.8 * d)) ** 2), x) if abs(x) > 1e-9 else 0.0
            pts.append((x, y))
        return pts
    lo, hi = w, w * 2.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if max(abs(x) for x, _ in outline(mid)) < w:
            lo = mid
        else:
            hi = mid
    return outline((lo + hi) / 2)


_OUTLINES = {}


def vest_point(z, th):
    """Ponto do colete no anel z (só nos anéis de VEST), na direção th a partir do centro: (x, y), ou None."""
    if z not in VEST:
        return None
    if z not in _OUTLINES:
        _OUTLINES[z] = _vest_outline(*VEST[z])
    yc = _interp(BODY, z)[0]
    s, c = math.sin(th), math.cos(th)
    best = max(_OUTLINES[z], key=lambda p: (p[0] * s + p[1] * c) / max(math.hypot(*p), 1e-9))
    return best[0], yc + best[1]


def vest_covers(z, x):
    """O colete cobre o ponto de meia-largura x na altura z (cava acima da axila)?"""
    return VEST_Z[0] <= z <= VEST_Z[1] and abs(x) <= armhole(z) + 1e-4


VEST_Z = (min(VEST), max(VEST))


def torso_bones(z):
    for lim, w in ((0.97, {"Hips": 1}), (1.05, {"Hips": 0.5, "Spine": 0.5}), (1.15, {"Spine": 1}),
                   (1.22, {"Spine": 0.5, "Chest": 0.5}), (9.0, {"Chest": 1})):
        if z <= lim:
            return w
    return {"Chest": 1}


def shoulder_share(th, z):
    """Quanto do alto do ombro do tronco segue o braço (só em volta da cúpula do ombro, acima da axila): sem isso a
    emenda abre ao erguer o braço; abaixo da axila nada segue o braço (era o que fazia a 'asa')."""
    zs = [(1.40, 0.0), (1.45, 0.25), (1.49, 0.3), (1.505, 0.15), (1.52, 0.0)]
    k = 0.0
    for (z0, k0), (z1, k1) in zip(zs, zs[1:]):
        if z0 <= z <= z1:
            k = k0 + (k1 - k0) * (z - z0) / (z1 - z0)
    side = abs(math.atan2(math.sin(th - math.pi / 2), math.cos(th - math.pi / 2)))
    return k * max(0.0, 1 - side / 0.7) ** 1.5


# ------------------------------------------------------------------ corpo sem colete (o personagem de moletom)
# (z, centro y, meia-largura, meia-profundidade na frente, atrás): homem de 1,80 m de moletom, sem nada por cima; o
# colete é outra peça, vestida depois. Ombro = trapézio descendo do pescoço + cúpula do deltoide (dos braços).
BARE = [
    (0.945, 0.004, 0.150, 0.104, 0.104),  # dentro da calça (por baixo do cinto)
    (0.972, 0.004, 0.156, 0.114, 0.112),  # barra do moletom sobre o cinto
    (1.050, 0.000, 0.158, 0.116, 0.112),  # cintura
    (1.120, -0.004, 0.164, 0.120, 0.114),
    (1.200, -0.006, 0.174, 0.126, 0.118),
    (1.270, -0.008, 0.184, 0.130, 0.122),  # peito (26 cm de frente a costas com o moletom)
    (1.330, -0.006, 0.186, 0.128, 0.122),  # axila
    (1.380, -0.003, 0.186, 0.120, 0.120),
    (1.420, 0.000, 0.186, 0.112, 0.114),
    (1.455, 0.002, 0.182, 0.100, 0.106),
    (1.485, 0.004, 0.178, 0.088, 0.096),  # alto do ombro, alto como na referência (0,182 m em z 1,485)
    (1.505, 0.006, 0.152, 0.076, 0.084),  # o ombro quase na altura da base do pescoço (0,154 m em z 1,50)
    (1.520, 0.008, 0.088, 0.066, 0.072),  # base do pescoço
    (1.545, 0.010, 0.066, 0.060, 0.055),  # pescoço (a cabeça entra aqui; atrás na linha da nuca às costas, sem calombo)
]


def _lobe(th, z, th_c, z_c, amp, s_th, s_z):
    d = math.atan2(math.sin(th - th_c), math.cos(th - th_c))
    return amp * math.exp(-(d / s_th) ** 2 - ((z - z_c) / s_z) ** 2)


def bare_volume(th, z):
    """Volume além da elipse (th: 0 = costas, pi = frente): peitoral, escápulas e o sulco da coluna."""
    v = 0.0
    for k in (1, -1):
        v += _lobe(th, z, math.pi - k * 0.50, 1.285, 0.013, 0.38, 0.06)  # peitoral
        v += _lobe(th, z, k * 0.55, 1.34, 0.010, 0.35, 0.06)  # escápula
    v -= _lobe(th, z, 0.0, 1.20, 0.006, 0.15, 0.15)  # sulco da coluna
    for side in (math.pi / 2, -math.pi / 2):  # a lateral recolhe onde o braço caído encosta (axila livre, sem "asa")
        v -= _lobe(th, z, side, 1.29, 0.036, 0.38, 0.08)
    return v


def bare_ring(z):
    """(centro y, meia-largura, frente, costas) do corpo de moletom na altura z (a elipse, sem os volumes)."""
    return _interp(BARE, z)


def bare_y(x, z, back=False):
    """y da superfície do moletom (elipse) em x na altura z, na frente ou atrás; None fora da largura."""
    yc, rx, ryf, ryb = bare_ring(z)
    if abs(x) >= rx:
        return None
    k = math.sqrt(1 - (x / rx) ** 2)
    return yc + ryb * k if back else yc - ryf * k


# ------------------------------------------------------------------ colete por cima do moletom (o do painel do usuário)
# Placa da frente e de trás, alças com almofada por cima do ombro e faixa em volta da cintura (as tiras de lado), sem
# gola. Medido na referência de frente (1,80 m): pé em z 0,99 reto de -13 a +14 cm com os cantos subindo até 1,04 nos
# lados (+-18,5 cm); lados retos até 1,20; a cava sobe até a alça (+-14,8 cm); alça de 8 a 15 cm de x até o alto do
# ombro; costura de cima em V em 1,40 e costura do meio até embaixo. Medidas em metros.
CARRIER_T = 0.024  # quanto a placa fica para fora do moletom
CARRIER_IN = 0.020  # quanto a peça entra no corpo (a união solda e some com o que fica dentro)
CARRIER_BOTTOM, CARRIER_CORNER = 0.99, 0.05  # pé do colete e raio dos cantos de baixo (vistos de frente)
CARRIER_SIDE = 0.185  # meia-largura dos lados retos
CARRIER_ARMHOLE = [(1.20, 0.185), (1.24, 0.176), (1.30, 0.160), (1.36, 0.152), (1.42, 0.150), (1.47, 0.148)]
CARRIER_NECK = (1.452, 1.478)  # alto da placa no meio (decote) na frente e atrás
CARRIER_SHOULDER_Z = 1.47  # alto da placa debaixo das alças
CARRIER_STRAP = (0.078, 0.148, 0.012, 1.44)  # alça: x de dentro e de fora, espessura, onde ela entra nas placas
CARRIER_PAD = (0.0, 0.0, 0.010)  # almofada no alto da alça: quanto ela engrossa em cima do ombro
CARRIER_BAND = (1.045, 1.195, 0.016)  # faixa em volta da cintura: z de baixo e de cima, quanto fica para fora
CARRIER_TABS = [(k * 0.150, 1.188) for k in (1, -1)]  # tiras de lado com fivela (x, z), por cima da faixa
CARRIER_TAB_HALF = (0.024, 0.004, 0.011)
VEST_UV_SPAN = 0.84  # x que cabe em cada metade do retângulo "vest" do atlas (+-0,21 m)
# costuras da frente (x >= 0, espelhadas): o painel de cima em V e a do meio até o pé
CARRIER_SEAMS = [[(0.080, 1.470), (0.098, 1.410), (0.0, 1.392)], [(0.098, 1.410), (0.150, 1.385)],
                 [(0.0, 1.392), (0.0, CARRIER_BOTTOM)]]


def carrier_half_width(z):
    """Meia-largura da placa na altura z (vista de frente): lados retos, depois a cava."""
    return CARRIER_SIDE if z <= CARRIER_ARMHOLE[0][0] else _interp(CARRIER_ARMHOLE, z)[0]


def carrier_bottom(x):
    """z do pé do colete em x: reto no meio, cantos redondos subindo até os lados."""
    d = abs(x) - (CARRIER_SIDE - CARRIER_CORNER)
    if d <= 0:
        return CARRIER_BOTTOM
    return CARRIER_BOTTOM + CARRIER_CORNER - math.sqrt(max(CARRIER_CORNER ** 2 - min(d, CARRIER_CORNER) ** 2, 0.0))


def carrier_top(x, back=False):
    """z do alto da placa em x: decote no meio, reto debaixo da alça, depois desce pela cava."""
    ax = abs(x)
    if ax <= CARRIER_STRAP[0]:
        neck = CARRIER_NECK[1 if back else 0]
        return neck + (CARRIER_SHOULDER_Z - neck) * (ax / CARRIER_STRAP[0]) ** 2
    if ax <= CARRIER_ARMHOLE[-1][1]:
        return CARRIER_SHOULDER_Z
    for (z0, x0), (z1, x1) in zip(CARRIER_ARMHOLE[::-1], CARRIER_ARMHOLE[-2::-1]):  # cava, de cima para baixo
        if x0 <= ax <= x1:
            return z0 + (z1 - z0) * (ax - x0) / (x1 - x0)
    return CARRIER_ARMHOLE[0][0]


# ------------------------------------------------------------------ capuz e rosto (balaclava)
HEAD_SIDES = 24
# (z, centro y, rx, ry na frente, ry atrás, abertura 0..1): abertura = quanto a frente do anel afunda até o rosto
HOOD = [  # (z, centro y, rx, ry na frente, ry atrás, abertura, largura do rosto 0..1)
    (1.512, 0.008, 0.092, 0.098, 0.106, 0.0, 0.0),  # gola do capuz em volta do pescoço
    (1.530, 0.009, 0.093, 0.099, 0.108, 0.45, 0.45),  # queixo: o rosto afina em V até aqui (referência)
    (1.555, 0.010, 0.093, 0.100, 0.111, 0.85, 0.70),
    (1.585, 0.011, 0.093, 0.100, 0.113, 1.0, 0.86),
    (1.620, 0.012, 0.093, 0.099, 0.115, 1.0, 0.96),  # meia-largura 9,3 cm (0,050 H na referência)
    (1.655, 0.012, 0.092, 0.099, 0.115, 1.0, 1.0),  # olhos (1,657)
    (1.688, 0.013, 0.090, 0.097, 0.113, 0.9, 0.95),
    (1.708, 0.014, 0.087, 0.094, 0.110, 0.5, 0.70),  # testa: a borda desce até a sobrancelha (1,72 na referência)
    (1.735, 0.016, 0.080, 0.086, 0.102, 0.0, 0.0),
    (1.760, 0.018, 0.070, 0.073, 0.090, 0.0, 0.0),  # alto em cúpula redonda
    (1.781, 0.020, 0.052, 0.054, 0.068, 0.0, 0.0),
    (1.795, 0.022, 0.028, 0.029, 0.036, 0.0, 0.0),
]
RIM_X = 0.058  # meia-largura da borda da abertura: laterais do capuz grossas (~4 cm), como na referência
# rosto (balaclava) dentro da abertura: j a partir da frente (0 = meio) -> (meia-largura, recuo atrás da borda); quase
# no plano da borda, como na referência (a balaclava aparece inteira de frente e de três quartos)
FACE = {0: (0.0, -0.004), 1: (0.026, 0.002), 2: (0.048, 0.010)}
FACE_RIM = 3  # j = 3 a partir da frente é a borda do capuz


# ------------------------------------------------------------------ braços (medidos na referência)
ARM_SIDES = 8
# (distância ao longo do braço a partir do ombro, rx, ry): cúpula do ombro, manga do moletom, punho canelado
SLEEVE_UPPER = [(-0.060, 0.020, 0.022), (-0.045, 0.040, 0.042), (-0.020, 0.052, 0.054), (0.020, 0.056, 0.058),
                (0.120, 0.054, 0.056), (0.200, 0.050, 0.052)]
ELBOW_R = (0.047, 0.049)  # 9,4 cm
SLEEVE_LOWER = [(0.300, 0.044, 0.046), (0.367, 0.039, 0.041), (0.430, 0.033, 0.035), (0.468, 0.029, 0.031)]
WRIST_R = (0.026, 0.028)
FIST = [(0.510, 0.028, 0.042), (0.540, 0.030, 0.047), (0.565, 0.027, 0.044), (0.582, 0.016, 0.031)]
THUMB = 0.014  # volume do polegar na frente do punho


# ------------------------------------------------------------------ equipamento (unido à pele)
MAG_POUCHES = [(x, 1.295) for x in (-0.072, 0.0, 0.072)]
MAG_HALF = (0.029, 0.018, 0.050)  # 5,8 x 10 cm, vão de ~1,4 cm, como na referência
MAG_FLAP = (0.031, 0.007, 0.014)  # aba por cima (mais larga, na frente)
CORDS = [0.036, -0.036]  # x dos cordões do capuz

# ------------------------------------------------------------------ cores (albedo; calibradas na prévia pela calça, igual à da referência)
COLORS = {
    "hood": (54, 58, 51), "hood_in": (40, 43, 38), "knit": (29, 29, 29), "skin": (150, 124, 110), "eye_skin": (112, 86, 74),
    "hoodie": (45, 46, 49), "vest": (47, 47, 49), "vest_low": (43, 43, 46), "vest_dark": (30, 30, 32), "mag": (52, 54, 47),
    "carrier": (31, 31, 34), "carrier_mag": (42, 42, 45),  # o colete de agora: preto, bem mais escuro que o moletom
    "cord": (176, 176, 170),
}
