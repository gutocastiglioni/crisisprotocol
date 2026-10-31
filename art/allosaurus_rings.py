"""Anéis finais da cabeça (pescoço medido + crânio) e da mandíbula do alossauro, no espaço da referência (sem a subida
HEAD_LIFT): saem das tabelas medidas (`allosaurus_ref`) com os acertos do gerador. O gerador (`allosaurus_head`) e a
pintura (`tools/make_allosaurus_texture.py`) usam os mesmos anéis, para o desenho cair no lugar certo da malha.
Python puro (a pintura roda sem o Blender).
"""
import allosaurus_ref as REF

JAW_RISE = 0.06  # no fim da arcada o alto da mandíbula sobe por cima do fim da maxila (o osso aparece por cima)
JAW_OUT = 1.03  # e fica por fora dela
JAW_TIP = (0.05, 0.6, 0.03)  # fim da mandíbula: comprimento além do último anel medido, escala do anel da ponta,
# quanto abaixo do alto ela fica (a ponta sai por cima, para trás, deitada sobre a garganta; por baixo a mandíbula sobe
# em rampa até ela, em 3 anéis: sem parede reta atrás)
HULL_IN = 0.985  # o casco atrás da boca encolhe isto onde a mandíbula está dentro dele (ela aparece por cima)
JAW_END = -2.43  # fim da mandíbula medido: daí para trás o casco é o pescoço


def smooth_rings(table, passes=2, keep=()):
    """Alisa os anéis ao longo do comprimento (média 1-2-1 de cada ponto com o mesmo ponto dos anéis vizinhos): o encaixe
    na referência pega pontos diferentes da crista em anéis vizinhos e deixava vincos em pé. A boca (lábio e céu da boca
    na frente do canto) fica como medida."""
    rows = [list(half) for _, half in table]
    for _ in range(passes):
        new = [r[:] for r in rows]
        for i in range(1, len(rows) - 1):
            mouth = table[i][0] < -2.60
            if i in keep:
                continue
            for j in range(len(rows[i])):
                if mouth and j >= 11:
                    continue
                new[i][j] = tuple((rows[i - 1][j][k] + 2 * rows[i][j][k] + rows[i + 1][j][k]) / 4 for k in range(2))
        rows = new
    return [(y, tuple(r)) for (y, _), r in zip(table, rows)]


def _hull(y, half):
    """Anel do casco atrás da boca; onde a mandíbula está dentro dele, encolhido para ela aparecer por cima."""
    if y > JAW_END:
        return tuple(half)
    zs = [z for _, z in half]
    zc = (max(zs) + min(zs)) / 2
    return tuple((x * HULL_IN, zc + (z - zc) * HULL_IN) for x, z in half)


def head_rings():
    """Pescoço medido + crânio, da base do pescoço para a ponta do focinho: (y, meia volta do alto para baixo). Atrás da
    boca (REF.HULL: do canto da boca até -2,29) o anel é o casco de fora medido com a mandíbula: o bloco bochecha-mandíbula
    vai até y -2,35 e cai de uma vez no pescoço (a borda de trás dele), sem alisar."""
    y0, y1 = REF.HULL[-1][0], REF.HULL[0][0]
    head = [r for r in REF.HEAD_DENSE if not y0 - 0.005 <= r[0] <= y1 + 0.005]
    k = next(i for i, r in enumerate(head) if r[0] < y0)
    table = REF.NECK_DENSE + head[:k] + [(y, _hull(y, half)) for y, half in REF.HULL] + head[k:]
    keep = {i for i, (y, _) in enumerate(table) if y0 - 0.005 <= y <= y1 + 0.005}
    return smooth_rings(table, keep=keep)


def jaw_top(y, half):
    """No fim da arcada (do último dente para trás) o alto da mandíbula sobe e sai para fora: o osso fica por cima do
    fim da maxila, como na referência."""
    f = min(1.0, max(0.0, (y + 2.80) / 0.12), max(0.0, (-2.56 - y) / 0.08))  # sobe até o canto, some no casco
    fall = {0: 0.0, 1: 0.5, 2: 1.0, 3: 1.0, 4: 0.8, 5: 0.5, 6: 0.2}
    return [(x * (1 + (JAW_OUT - 1) * f * fall.get(j, 0.0)), z + JAW_RISE * f * fall.get(j, 0.0))
            for j, (x, z) in enumerate(half)]


def jaw_rings():
    """Mandíbula da ponta de trás (JAW_TIP: por cima, para trás) até o queixo."""
    y0, back = REF.JAW_DENSE[0]
    back = jaw_top(y0, list(back))
    zc = max(z for _, z in back) - JAW_TIP[2]
    taper = []
    for t in (1.0, 0.66, 0.33):  # da ponta para o último anel medido
        sc = 1 - (1 - JAW_TIP[1]) * t ** 0.8
        taper.append((y0 + JAW_TIP[0] * t, tuple((x * sc, zc + (z - zc) * sc) for x, z in back)))
    return taper + [(y, tuple(jaw_top(y, list(half)))) for y, half in REF.JAW_DENSE]


def body_rings():
    """Tronco e cauda medidos (REF.BODY, 16 raios: meia volta de 9 pontos), da base do pescoço à ponta da cauda, alisados
    ao longo do comprimento e em volta (a referência tem quinas soltas onde entram as pernas)."""
    rows = [list(half) for _, half in smooth_rings(REF.BODY, passes=1)]
    for r in rows:
        r[:] = [r[0]] + [tuple((r[j - 1][k] + 2 * r[j][k] + r[j + 1][k]) / 4 for k in range(2))
                         for j in range(1, len(r) - 1)] + [r[-1]]
    return [(y, tuple(r)) for (y, _), r in zip(REF.BODY, rows)]
