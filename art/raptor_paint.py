"""Pinta a pele do raptor com as cores do jogo em cima do mapa de UV da referência (roda dentro do Blender, numpy).

Cada pixel da textura é levado ao ponto 3D da malha em repouso (rasterizando os triângulos no espaço de UV) e pintado
como as peças do gerador antigo (`tools/make_raptor_texture.py`, mesma paleta): pela posição ao longo da cadeia de
ossos mais perto (coluna da ponta da cauda ao focinho, pernas, braços) e pelo lado em volta dela (dorso escuro ->
flanco -> barriga bege), com as listras transversais de borda irregular, as placas da barriga e o volume "assado"
(brilho no dorso, sombra no flanco baixo, membros claros em cima). Da textura da referência entram só o relevo (a
luminância dividida pela média em volta: dobras, escamas, rugas) e a oclusão; as cores dela não. A boca (vermelho da
referência) vira a boca do jogo; olhos, dentes e garras ficam na outra textura (a da referência, sem mudar).
"""
import math

import numpy as np

# paleta do jogo (tools/make_raptor_texture.py)
BACK = (56, 64, 36)
SIDE = (104, 110, 64)
SIDE_HI = (138, 138, 88)
BELLY = (186, 172, 124)
BELLY_LO = (150, 136, 96)
STRIPE = (42, 38, 24)
STRIPE_CORE = (26, 24, 16)
MOUTH = (124, 38, 38)
MOUTH_LO = (80, 22, 24)

# por tipo de peça: (barriga, alcance das listras, largura das listras, listras por metro, placas por metro)
KINDS = {
    "body": (0.18, 0.42, 0.32, 6.5, 18.0),
    "head": (0.13, 0.30, 0.22, 5.0, 0.0),
    "limb": (0.0, 0.5, 0.36, 9.0, 0.0),
}
DETAIL = (0.78, 1.22)  # limites do relevo tirado da referência (multiplica a cor)
AO = 0.45  # quanto a oclusão da referência escurece


def _c(rgb):
    return np.array(rgb, np.float32)


def _lerp(a, b, t):
    t = np.clip(t, 0.0, 1.0)[..., None]
    return a + (b - a) * t


def _gauss(x, w):
    return np.exp(-(x / w) ** 2)


def _blur(img, r):
    """Desfoque de caixa repetido 3x (quase gaussiano), separável, com borda presa."""
    out = img.astype(np.float32)
    for _ in range(3):
        for axis in (0, 1):
            pad = [(0, 0)] * out.ndim
            pad[axis] = (r + 1, r)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
            out = (hi - lo) / (2 * r + 1)
    return out


def _noise(size, cell, rng):
    small = rng.random((size // cell + 3, size // cell + 3)).astype(np.float32)
    big = np.kron(small, np.ones((cell, cell), np.float32))[:size, :size]
    return _blur(big, max(1, cell // 2))


def raster(tri_uv, tri_pos, tri_nrm, tri_kind, size):
    """Posição, normal e tipo de peça por pixel. tri_* = arrays (n, 3, k); tri_kind = (n,) inteiros."""
    pos = np.zeros((size, size, 3), np.float32)
    nrm = np.zeros((size, size, 3), np.float32)
    kind = np.full((size, size), -1, np.int32)
    q = tri_uv * size - 0.5
    for i in range(len(q)):
        a, b, c = q[i]
        x0, y0 = np.floor(np.minimum(np.minimum(a, b), c)).astype(int)
        x1, y1 = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-3) & (w1 >= -1e-3) & (w2 >= -1e-3)
        if not inside.any():
            continue
        w = np.stack([w0[inside], w1[inside], w2[inside]], axis=1)
        yy, xx = ys[inside], xs[inside]
        pos[yy, xx] = w @ tri_pos[i]
        nrm[yy, xx] = w @ tri_nrm[i]
        kind[yy, xx] = tri_kind[i]
    n = np.linalg.norm(nrm, axis=2, keepdims=True)
    nrm = nrm / np.maximum(n, 1e-6)
    return pos, nrm, kind


def chain_coords(pos, chains, kind, chain_of_kind):
    """Para cada pixel: comprimento ao longo da cadeia (m) e lado (0 = dorso/em cima, 1 = barriga/embaixo), pela
    cadeia do tipo da peça. chains = {nome: array (k, 3) de pontos}; chain_of_kind = {tipo: [nomes]}."""
    h, w = kind.shape
    s = np.zeros((h, w), np.float32)
    side = np.zeros((h, w), np.float32)
    up = np.array((0.0, 0.0, 1.0), np.float32)
    fwd = np.array((0.0, -1.0, 0.0), np.float32)
    for k, names in chain_of_kind.items():
        sel = kind == k
        if not sel.any():
            continue
        p = pos[sel]
        best = np.full(len(p), np.inf, np.float32)
        out_s = np.zeros(len(p), np.float32)
        out_side = np.zeros(len(p), np.float32)
        for name in names:
            pts = chains[name]
            acc = 0.0
            for a, b in zip(pts[:-1], pts[1:]):
                d = b - a
                ln = float(np.linalg.norm(d))
                if ln < 1e-6:
                    continue
                d = d / ln
                t = np.clip((p - a) @ d, 0.0, ln)
                foot = a + t[:, None] * d
                r = p - foot
                dist = np.linalg.norm(r, axis=1)
                better = dist < best
                ref = up - d * float(up @ d)
                if np.linalg.norm(ref) < 0.3:
                    ref = fwd - d * float(fwd @ d)
                ref = ref / np.linalg.norm(ref)
                rn = r / np.maximum(dist, 1e-6)[:, None]
                ang = np.arccos(np.clip(rn @ ref, -1.0, 1.0)) / math.pi
                best = np.where(better, dist, best)
                out_s = np.where(better, acc + t, out_s)
                out_side = np.where(better, ang, out_side)
                acc += ln
        s[sel] = out_s
        side[sel] = out_side
    return s, side


def _skin(dorsal, belly_w):
    """Cor base pela volta (dorsal: 1 no dorso, 0 na barriga), como `skin` do pintor antigo."""
    bw2 = belly_w * 2
    belly = _lerp(_c(BELLY), _c(BELLY_LO), dorsal / max(bw2, 1e-6) * 0.6)
    t = (dorsal - bw2) / max(1 - bw2, 0.01)
    low = _lerp(_c(SIDE_HI), _c(SIDE), t * 2)
    high = _lerp(_c(SIDE), _c(BACK), (t - 0.5) * 2)
    out = np.where((t < 0.5)[..., None], low, high)
    return np.where((dorsal < bw2)[..., None], belly, out)


def paint(pos, nrm, kind, s, side, ref_rgb, ref_ao, eyes, kind_names, seed=11):
    """RGB float (0..255) da pele. ref_rgb/ref_ao: textura e oclusão da referência já na resolução de `pos`."""
    rng = np.random.default_rng(seed)
    size = kind.shape[0]
    edge = _noise(size, 12, rng)
    blot = _noise(size, 6, rng)
    phase = rng.random()
    dorsal = 1.0 - side
    out = np.zeros((size, size, 3), np.float32)
    shade = np.ones((size, size), np.float32)
    for k, name in kind_names.items():
        sel = kind == k
        if not sel.any():
            continue
        belly_w, reach, width, freq, scutes = KINDS[name]
        dv, sv = dorsal[sel], s[sel]
        c = _skin(dv, belly_w)
        wave = np.sin((sv * freq + phase) * 2 * math.pi + 2.2 * (edge[sel] - 0.5) + 1.2 * np.sin(side[sel] * 4.5))
        limit = 1 - width * 2 + 0.25 * (1 - dv) + 0.3 * (blot[sel] - 0.5)
        band = (dv > 1 - reach * 2) & (wave > limit)
        core = band & (wave > limit + 0.32)
        soft = ~band & (dv > 1 - reach * 2 - 0.05) & (wave > limit - 0.12)
        c = np.where(core[:, None], _c(STRIPE_CORE), c)
        c = np.where((band & ~core)[:, None], _lerp(_c(STRIPE), c, np.full(len(c), 0.15)), c)
        c = np.where(soft[:, None], _lerp(c, _c(STRIPE), np.full(len(c), 0.45)), c)
        k_ = np.ones(len(c), np.float32)
        if scutes:
            grooves = (dv < belly_w * 2) & (((sv * scutes) % 1.0) < 0.12)
            k_ = np.where(grooves, 0.8, k_)
        if name == "limb":
            k_ *= 0.84 + 0.28 * np.clip(nrm[sel][:, 2] * 0.5 + 0.5, 0, 1)
        else:
            k_ *= 1 + 0.25 * _gauss(1 - dv, 0.2)
            k_ *= 1 - 0.32 * _gauss(dv - (belly_w * 2 + 0.16), 0.14)
        out[sel] = c
        shade[sel] = k_
    # órbita escura em volta do olho e arco ósseo por cima (o globo é peça à parte)
    for e in eyes:
        d = np.linalg.norm(pos - np.asarray(e, np.float32), axis=2)
        above = np.clip((pos[..., 2] - e[2]) / 0.02, 0, 1)
        shade *= 1 - 0.45 * _gauss(d - 0.012, 0.012) * (kind >= 0)
        shade *= 1 - 0.25 * _gauss(d - 0.03, 0.015) * above
    # boca: onde a referência é vermelha, a boca do jogo com o relevo dela
    r, g, b = ref_rgb[..., 0], ref_rgb[..., 1], ref_rgb[..., 2]
    mouth = (r > g * 1.35) & (r > b * 1.15) & (r > 40)
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    out = np.where(mouth[..., None], _lerp(_c(MOUTH_LO), _c(MOUTH), lum / max(float(lum[mouth].max()) if mouth.any() else 1.0, 1.0)), out)
    detail = lum / np.maximum(_blur(lum, max(2, size // 128)), 1.0)
    shade *= np.clip(detail, *DETAIL)
    shade *= 1 - AO * (1 - ref_ao)
    out *= shade[..., None]
    return np.clip(out, 0, 255)


def pad(rgb, covered, steps=24):
    """Preenche o fundo com a cor da borda mais perto (para o filtro e os mipmaps)."""
    out = rgb.copy()
    done = covered.copy()
    for _ in range(steps):
        acc = np.zeros_like(out)
        cnt = np.zeros(done.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = np.roll(done, (dy, dx), axis=(0, 1))
            acc += np.roll(out, (dy, dx), axis=(0, 1)) * m[..., None]
            cnt += m
        grow = ~done & (cnt > 0)
        out[grow] = acc[grow] / cnt[grow][:, None]
        done = done | grow
    out[~done] = out[done].mean(axis=0)
    return out
