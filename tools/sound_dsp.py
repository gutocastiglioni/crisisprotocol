"""Blocos de síntese dos efeitos sonoros (ruído filtrado, senos amortecidos, varreduras, envelopes), usados por
make_sounds.py e sound_creatures.py. Tudo mono a SR = 22050 Hz, em arrays numpy de -1 a 1."""
import math
import zlib

import numpy as np

SR = 22050


# ------------------------------------------------------------------ blocos
def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode()))


def n_of(dur: float) -> int:
    return int(round(dur * SR))


def tt(dur: float) -> np.ndarray:
    return np.arange(n_of(dur)) / SR


def noise(r: np.random.Generator, dur: float) -> np.ndarray:
    return r.uniform(-1.0, 1.0, n_of(dur))


def decay(dur: float, tau: float, attack: float = 0.0005, start: float = 0.0) -> np.ndarray:
    """Envelope: sobe em `attack` s a partir de `start` e cai exponencial com constante `tau`."""
    t = tt(dur) - start
    e = np.where(t < 0, 0.0, np.exp(-np.maximum(t - attack, 0.0) / tau))
    if attack > 0:
        e *= np.clip(t / attack, 0.0, 1.0)
    return e


def bell(dur: float, start: float, peak: float, end: float) -> np.ndarray:
    """Envelope que sobe de `start` até `peak` e desce até `end` (curvas em seno)."""
    t = tt(dur)
    up = np.clip((t - start) / max(peak - start, 1e-4), 0.0, 1.0)
    down = np.clip((end - t) / max(end - peak, 1e-4), 0.0, 1.0)
    return np.sin(up * math.pi / 2) ** 2 * np.sin(down * math.pi / 2) ** 2


def _coefs(kind: str, f: float, q: float):
    w = 2 * math.pi * min(max(f, 10.0), SR * 0.45) / SR
    cw, sw = math.cos(w), math.sin(w)
    al = sw / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:  # "bp": ganho 1 no centro
        b0, b1, b2 = al, 0.0, -al
    a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    return b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0


def biquad(x: np.ndarray, kind: str, f, q: float = 0.707) -> np.ndarray:
    """Filtro de 2 polos (RBJ). `f` = número ou um valor por amostra (filtro que anda; recalcula a cada 32)."""
    fa = np.broadcast_to(np.asarray(f, dtype=float), x.shape)
    xs = x.tolist()
    out = [0.0] * len(xs)
    x1 = x2 = y1 = y2 = 0.0
    b0 = b1 = b2 = a1 = a2 = 0.0
    for i, xi in enumerate(xs):
        if i % 32 == 0:
            b0, b1, b2, a1, a2 = _coefs(kind, float(fa[i]), q)
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        out[i] = yi
    return np.array(out)


def lp(x, f, q=0.707):
    return biquad(x, "lp", f, q)


def hp(x, f, q=0.707):
    return biquad(x, "hp", f, q)


def bp(x, f, q=1.0):
    return biquad(x, "bp", f, q)


def modes(dur: float, freqs, taus, amps=None, start: float = 0.0, r: np.random.Generator | None = None) -> np.ndarray:
    """Senos amortecidos (o "tom" de uma peça de metal, madeira ou plástico batida)."""
    t = tt(dur) - start
    out = np.zeros_like(t)
    amps = amps or [1.0] * len(freqs)
    for f, tau, a in zip(freqs, taus, amps):
        ph = r.uniform(0, 2 * math.pi) if r is not None else 0.0
        out += a * np.sin(2 * math.pi * f * t + ph) * np.exp(-np.maximum(t, 0) / tau)
    return np.where(t < 0, 0.0, out)


def sweep(dur: float, freq: np.ndarray) -> np.ndarray:
    """Seno com frequência variando no tempo (`freq` = um valor por amostra)."""
    return np.sin(2 * math.pi * np.cumsum(freq) / SR)


def saw(f0: np.ndarray) -> np.ndarray:
    """Dente de serra limitado em banda (soma de harmônicos que não passam de 0,45 x SR): sem serrilhado."""
    phase = np.cumsum(f0) / SR
    out = np.zeros_like(f0)
    k = 1
    while k * f0.min() < SR * 0.45:
        g = np.clip((SR * 0.45 - k * f0) / (SR * 0.05), 0.0, 1.0)  # some suave perto do limite
        out += g * np.sin(2 * math.pi * k * phase) / k
        k += 1
    return out * 0.6


def shift(x: np.ndarray, sec: float, total: int | None = None) -> np.ndarray:
    """Atrasa `x` em `sec` segundos (preenche com silêncio) e corta/estende para `total` amostras."""
    total = total or len(x)
    out = np.zeros(total)
    d = n_of(sec)
    if d < total:
        m = min(len(x), total - d)
        out[d:d + m] = x[:m]
    return out


def echo(x: np.ndarray, taps) -> np.ndarray:
    """Ecos de sala: lista de (atraso s, ganho, corte do passa-baixa)."""
    out = x.copy()
    for d, g, f in taps:
        out += g * shift(lp(x, f), d)
    return out


def contour(dur: float, points) -> np.ndarray:
    """Curva por pontos (tempo relativo 0..1, valor), suavizada (pitch e formantes)."""
    t = np.linspace(0.0, 1.0, n_of(dur))
    xs, ys = zip(*points)
    return np.interp(t, xs, ys)


def jitter(r: np.random.Generator, dur: float, amount: float, rate: float = 30.0) -> np.ndarray:
    """Variação aleatória lenta (1 + ±amount), para a voz não soar de máquina."""
    k = max(int(dur * rate), 2)
    pts = r.uniform(-amount, amount, k + 1)
    return 1.0 + np.interp(np.linspace(0, k, n_of(dur)), np.arange(k + 1), pts)


def crackle(r: np.random.Generator, dur: float, density: float, start: float = 0.0, end: float | None = None) -> np.ndarray:
    """Estalinhos esparsos (`density` por segundo), cada um um pulso de ruído de ~1 ms."""
    out = np.zeros(n_of(dur))
    end = dur if end is None else end
    count = r.poisson(density * (end - start))
    for _ in range(count):
        at = n_of(r.uniform(start, end))
        m = min(22, len(out) - at)
        if m > 0:
            out[at:at + m] += r.uniform(-1, 1, m) * np.exp(-np.arange(m) / 5.0) * r.uniform(0.3, 1.0)
    return out


def soft_clip(x: np.ndarray, drive: float) -> np.ndarray:
    return np.tanh(drive * x) / math.tanh(drive)


def finish(x: np.ndarray, peak: float = 0.89, fade: float = 0.01) -> np.ndarray:
    """Tira o DC, normaliza o pico e esvanece o fim (sem estalo no corte)."""
    x = x - np.mean(x)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    f = min(n_of(fade), len(x))
    x[len(x) - f:] *= np.linspace(1.0, 0.0, f)
    return x


def loop_seamless(x: np.ndarray, overlap: float) -> np.ndarray:
    """Para ambiente em loop: o fim é misturado no começo (sem emenda audível na volta)."""
    o = n_of(overlap)
    body = x[:-o].copy()
    fade = np.linspace(0.0, 1.0, o)
    body[:o] = body[:o] * fade + x[-o:] * (1.0 - fade)
    return body


def cloth(r, dur, start, end, center=1600.0, amount=0.4):
    return bp(noise(r, dur), center, 0.8) * bell(dur, start, (start + end) / 2, end) * amount


def thud(r, dur, at, f=350.0, tau=0.03, amount=1.0):
    return lp(noise(r, dur), f) * decay(dur, tau, 0.002, at) * amount
