"""Camadas de gravações reais (CC0) para as vozes do raptor (ver sound_creatures.py).

As amostras ficam em art/ref_sounds/ (fora do git; LEIAME.txt tem fonte e licença): `t-rex_calls.wav` = chamadas de T-rex feitas de
jacaré, leão e alce (CaveboyTup, CC0, opengameart.org). Cada voz corta o trecho mais forte de uma faixa da gravação, sobe o tom por
reamostragem (o raptor é menor que o T-rex: duração e tom mudam juntos, como no cinema), tira o grave que não toca em caixa de som e
o chiado, e entrega no formato do jogo. Sem a pasta, `render` devolve None e vale a voz sintética de sempre.
"""
import wave
from pathlib import Path

import numpy as np

from sound_dsp import SR, hp, lp, n_of

REF = Path(__file__).resolve().parent.parent / "art" / "ref_sounds"
TREX = "t-rex_calls.wav"

# nome -> faixa (segundos da gravação) onde procurar o trecho mais forte, duração final, tom (k>1 = mais agudo e mais curto),
# filtro de agudos, esvanecimentos e volume (RMS em dBFS: os sintéticos de antes estavam em -11 a -17; os que se repetem, como
# o piado, ficam mais baixos). `rng` e `k` podem ser listas: uma por variante (1, 2, ...).
SPECS = {
    "raptor_roar": {"rng": (26.5, 31.0), "dur": 1.8, "k": 1.5, "hi": 5500, "fade": (0.06, 0.25), "rms": -13.0},
    "raptor_screech": {"rng": (36.6, 41.0), "dur": 0.6, "k": 1.6, "hi": 6000, "fade": (0.02, 0.12), "rms": -13.0},
    "raptor_snarl": {"rng": (15.8, 18.5), "dur": 0.75, "k": 1.4, "hi": 4500, "fade": (0.03, 0.18), "rms": -17.0},
    "raptor_chirp": {"rng": [(0.3, 1.5), (2.4, 3.3)], "dur": 0.45, "k": [1.5, 1.7], "hi": 4500, "fade": (0.03, 0.15), "rms": -20.0},
    "raptor_suspicious": {"rng": (31.5, 35.0), "dur": 0.55, "k": 1.5, "hi": 4500, "fade": (0.05, 0.2), "rms": -17.0},
    "raptor_hurt": {"rng": [(23.1, 25.4), (19.6, 21.9)], "dur": 0.45, "k": [1.7, 1.9], "hi": 5000, "fade": (0.015, 0.12), "rms": -14.0},
    "raptor_shake": {"rng": (10.5, 15.3), "dur": 1.6, "k": 1.2, "hi": 4000, "fade": (0.05, 0.25), "rms": -17.0},
    "raptor_death": {"rng": (4.3, 9.0), "dur": 1.9, "k": 1.6, "hi": 4500, "fade": (0.05, 0.5), "rms": -16.0},
}

_cache: dict[str, tuple[np.ndarray, int] | None] = {}


def source(name: str):
    """(amostras mono em float, taxa) da gravação, ou None se o arquivo não está na máquina."""
    if name not in _cache:
        p = REF / name
        if not p.exists():
            _cache[name] = None
        else:
            with wave.open(str(p), "rb") as w:
                n = w.getnchannels()
                x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0
                if n > 1:
                    x = x.reshape(-1, n).mean(axis=1)
                _cache[name] = (x, w.getframerate())
    return _cache[name]


def _pick(x: np.ndarray, sr: int, rng, length: float) -> float:
    """Começo (s) da janela de `length` s com mais energia dentro da faixa `rng`."""
    a, b = rng
    hop = int(sr * 0.05)
    win = int(sr * length)
    best, at = -1.0, a
    t = a
    while t + length <= b + 1e-9:
        i = int(t * sr)
        e = float(np.mean(x[i:i + win] ** 2))
        if e > best:
            best, at = e, t
        t += hop / sr
    return at


def render(name: str, variant: int | None = None):
    """A voz `name` (variante 1, 2, ... das que têm), em SR Hz mono e pico ~0,9; None sem a gravação."""
    spec = SPECS[name]
    src = source(TREX)
    if src is None:
        return None
    x, sr = src
    pick = (lambda v: v[(variant or 1) - 1] if isinstance(v, list) else v)
    rng, k = pick(spec["rng"]), pick(spec["k"])
    dur = spec["dur"]
    length = min(dur * k, rng[1] - rng[0])
    k = length / dur  # faixa curta demais: o tom sobe menos em vez de a voz acabar antes
    t0 = _pick(x, sr, rng, length)
    pos = t0 * sr + np.arange(n_of(dur)) * (sr * k / SR)
    y = np.interp(pos, np.arange(len(x)), x)
    y = lp(hp(y, 70), spec["hi"])
    fi, fo = spec["fade"]
    t = np.arange(len(y)) / SR
    env = np.clip(t / max(fi, 1e-4), 0, 1) * np.clip((dur - t) / max(fo, 1e-4), 0, 1)
    y = y * np.sin(env * np.pi / 2)
    # volume percebido (RMS) em vez de pico: a gravação é densa e normalizada pelo pico ficaria bem mais alta que a sintética
    y = y * 10 ** (spec["rms"] / 20) / max(float(np.sqrt(np.mean(y ** 2))), 1e-9)
    return 0.95 * np.tanh(y / 0.95)  # limitador suave: picos raros não estouram
