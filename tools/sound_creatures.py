"""Vozes do raptor (fonte + formantes), avisos de furtividade e ambientes em loop (ver make_sounds.py)."""
import math

import numpy as np

from sound_dsp import (
    SR, bell, bp, contour, crackle, decay, finish, hp, jitter, loop_seamless, lp, modes, n_of, noise, rng_for, saw,
    soft_clip, sweep, thud, tt,
)


# ------------------------------------------------------------------ raptor (fonte + formantes)
def voice(r, dur, f0, formants, rough=0.5, rough_rate=None, breath=0.15, second=0.0, env=None):
    """Voz animal: dente de serra com pitch `f0` (uma curva) e aspereza (modulação em f0/2 ou `rough_rate` Hz), mais
    uma segunda voz (siringe: duas notas ao mesmo tempo) e sopro, passando por formantes [(f(t) ou f, Q, ganho)]."""
    t = tt(dur)
    f0 = f0 * jitter(r, dur, 0.03, 25) * (1 + 0.02 * np.sin(2 * math.pi * 6.5 * t))
    src = saw(f0)
    if second > 0:
        src += saw(f0 * 1.47 * jitter(r, dur, 0.02, 10)) * second
    rr = (np.cumsum(f0 * 0.5) / SR) if rough_rate is None else (np.cumsum(np.broadcast_to(rough_rate, t.shape)) / SR)
    am = 1.0 + rough * np.sin(2 * math.pi * rr) * jitter(r, dur, 0.4, 12)
    src = src * am + noise(r, dur) * breath
    out = np.zeros_like(t)
    for f, q, g in formants:
        out += bp(src, f, q) * g
    out += hp(src, 3500) * 0.15  # chiado agudo da garganta
    if env is not None:
        out *= env
    return out


def raptor_roar():
    r = rng_for("raptor_roar")
    dur = 1.8
    inhale = bp(noise(r, dur), 3200, 1.5) * bell(dur, 0.0, 0.15, 0.3) * 0.3
    f0 = contour(dur, [(0, 280), (0.18, 300), (0.35, 520), (0.6, 470), (0.85, 300), (1, 220)])
    form = [(contour(dur, [(0, 650), (0.4, 950), (1, 600)]), 5, 1.0), (1700, 6, 0.8), (2900, 7, 0.5)]
    env = bell(dur, 0.15, 0.32, 1.75) ** 0.6
    shriek = voice(r, dur, f0, form, rough=0.7, breath=0.25, second=0.45, env=env)
    growl = voice(r, dur, f0 * 0.25, [(400, 3, 1.0), (900, 4, 0.5)], rough=0.9, rough_rate=38, breath=0.2, env=env) * 0.6
    return finish(soft_clip(inhale + shriek + growl, 1.6), 0.95)


def raptor_screech():
    r = rng_for("raptor_screech")
    dur = 0.6
    f0 = contour(dur, [(0, 450), (0.4, 720), (1, 520)])
    x = voice(r, dur, f0, [(1000, 5, 1.0), (2000, 6, 0.8), (3300, 7, 0.5)], rough=0.6, breath=0.3, second=0.5,
              env=bell(dur, 0.0, 0.08, 0.58))
    return finish(soft_clip(x, 1.6), 0.95)


def raptor_snarl():
    r = rng_for("raptor_snarl")
    dur = 0.75
    f0 = contour(dur, [(0, 120), (0.3, 150), (1, 105)])
    x = voice(r, dur, f0, [(500, 4, 1.0), (1100, 5, 0.6), (2400, 6, 0.3)], rough=1.0, rough_rate=45, breath=0.5,
              env=bell(dur, 0.0, 0.1, 0.72))
    return finish(soft_clip(x, 2.0), 0.9)


def raptor_hiss():
    r = rng_for("raptor_hiss")
    dur = 1.3
    t = tt(dur)
    hiss = bp(noise(r, dur), 4200, 1.0) * (0.6 + 0.4 * np.sin(2 * math.pi * 3 * t)) * bell(dur, 0.0, 0.2, 1.25)
    purr = voice(r, dur, np.full(n_of(dur), 55.0), [(300, 3, 1.0), (700, 4, 0.5)], rough=1.0, rough_rate=22, breath=0.1,
                 env=bell(dur, 0.1, 0.5, 1.2)) * 0.8
    return finish(hiss * 0.7 + purr, 0.85)


def raptor_chirp(i):
    r = rng_for(f"raptor_chirp_{i}")
    dur = 0.45
    x = np.zeros(n_of(dur))
    count = 2 if i == 1 else 3
    for k in range(count):
        at = k * r.uniform(0.11, 0.14)
        f0 = contour(dur, [(0, 520), (1, 520)]) * (r.uniform(0.95, 1.15) - 0.05 * k)
        env = bell(dur, at, at + 0.02, at + 0.09)
        x += voice(r, dur, f0, [(900, 5, 1.0), (1800, 6, 0.7), (3000, 7, 0.3)], rough=0.4, breath=0.1, second=0.3, env=env)
    return finish(x, 0.85)


def raptor_suspicious():
    r = rng_for("raptor_suspicious")
    dur = 0.55
    t = tt(dur)
    f0 = contour(dur, [(0, 360), (0.7, 560), (1, 590)])
    env = bell(dur, 0.0, 0.15, 0.53) * (0.7 + 0.3 * np.sin(2 * math.pi * 18 * t))  # trinado de quem pergunta
    x = voice(r, dur, f0, [(800, 5, 1.0), (1700, 6, 0.6), (2800, 7, 0.3)], rough=0.3, breath=0.15, second=0.25, env=env)
    return finish(x, 0.85)


def raptor_bite():
    r = rng_for("raptor_bite")
    dur = 0.55
    teeth = modes(dur, [2500, 3700, 5200], [0.01, 0.008, 0.006], [1.0, 0.7, 0.4], 0.0, r) + hp(noise(r, dur), 2500) * decay(dur, 0.003)
    jaw = thud(r, dur, 0.0, 300, 0.03, 1.0)
    growl = voice(r, dur, np.full(n_of(dur), 110.0), [(500, 4, 1.0), (1200, 5, 0.5)], rough=1.0, rough_rate=40, breath=0.4,
                  env=bell(dur, 0.05, 0.15, 0.5)) * 0.6
    return finish(soft_clip(teeth * 1.3 + jaw + growl, 1.5), 0.92)


def raptor_shake():
    r = rng_for("raptor_shake")
    dur = 1.6
    t = tt(dur)
    f0 = 100 + 20 * np.sin(2 * math.pi * t / 0.4)  # acompanha o sacudir da cabeça (0,4 s)
    growl = voice(r, dur, f0, [(450, 4, 1.0), (1000, 5, 0.6), (2200, 6, 0.3)], rough=1.0, rough_rate=42, breath=0.5,
                  env=bell(dur, 0.0, 0.1, 1.55))
    tear = bp(crackle(r, dur, 60), 1800, 1.0) * 1.5  # pano e carne
    return finish(soft_clip(growl + tear, 1.8), 0.9)


def raptor_hurt(i):
    r = rng_for(f"raptor_hurt_{i}")
    dur = 0.45
    top = 650 if i == 1 else 760
    f0 = contour(dur, [(0, top * 0.8), (0.15, top), (1, top * 0.55)])
    x = voice(r, dur, f0, [(1000, 5, 1.0), (2100, 6, 0.7), (3200, 7, 0.4)], rough=0.8, breath=0.3, second=0.4,
              env=bell(dur, 0.0, 0.04, 0.43))
    return finish(soft_clip(x, 1.7), 0.92)


def raptor_death():
    r = rng_for("raptor_death")
    dur = 1.9
    t = tt(dur)
    f0 = contour(dur, [(0, 520), (0.15, 560), (0.7, 260), (1, 140)])
    gurgle = 2 * math.pi * np.cumsum(contour(dur, [(0, 9), (1, 4)])) / SR
    env = bell(dur, 0.0, 0.08, 1.6) * (0.75 + 0.25 * np.sin(gurgle))
    x = voice(r, dur, f0, [(contour(dur, [(0, 900), (1, 500)]), 5, 1.0), (1700, 6, 0.6), (2700, 7, 0.3)],
              rough=0.9, breath=0.3, second=0.35, env=env)
    x += lp(noise(r, dur), 1200) * bell(dur, 1.4, 1.6, 1.88) * 0.25  # último sopro
    return finish(soft_clip(x, 1.6), 0.92)


def tail_whoosh():
    r = rng_for("tail_whoosh")
    dur = 0.45
    t = tt(dur)
    center = 400 + 1300 * np.sin(np.clip(t / 0.4, 0, 1) * math.pi)
    x = bp(noise(r, dur), center, 1.8) * bell(dur, 0.0, 0.2, 0.42)
    return finish(x, 0.85)


# ------------------------------------------------------------------ avisos (furtividade)
def alert():
    """Visto! Acorde dissonante de metal (filtro abrindo e fechando), com uma pancada no começo."""
    r = rng_for("alert")
    dur = 0.8
    t = tt(dur)
    chord = np.zeros(n_of(dur))
    for f in (523.25, 554.37, 783.99, 1046.5):  # dó, ré bemol, sol, dó
        chord += saw(np.full(n_of(dur), f) * (1 + 0.004 * r.standard_normal()))
    bright = 600 + 5000 * np.exp(-t / 0.12)
    x = lp(chord, bright, 1.2) * decay(dur, 0.3, 0.004)
    x += lp(noise(r, dur), 3000) * decay(dur, 0.02, 0.001) * 0.6 + sweep(dur, 80 + 60 * np.exp(-t / 0.03)) * decay(dur, 0.1) * 0.7
    return finish(soft_clip(x, 1.3), 0.9)


def suspicious():
    """"Hum?": dois toques curtos subindo."""
    dur = 0.32
    t = tt(dur)
    x = np.sin(2 * math.pi * 600 * t) * bell(dur, 0.0, 0.01, 0.09) + np.sin(2 * math.pi * 800 * t) * bell(dur, 0.12, 0.13, 0.3)
    x += 0.3 * np.sin(2 * math.pi * 1600 * t) * bell(dur, 0.12, 0.13, 0.25)
    return finish(x, 0.7)


# ------------------------------------------------------------------ ambiente (loops)
def amb_yard():
    """Mata: vento nas folhas (corte e volume andando devagar), dois grilos e um pássaro longe."""
    r = rng_for("amb_yard")
    dur, over = 11.0, 1.0
    t = tt(dur)
    lfo = 0.5 + 0.3 * np.sin(2 * math.pi * 0.11 * t) + 0.2 * np.sin(2 * math.pi * 0.27 * t + 1.0)
    wind = lp(noise(r, dur), 300 + 700 * lfo) * (0.4 + 0.6 * lfo)
    leaves = hp(noise(r, dur) * np.abs(crackle(r, dur, 200)), 2500) * lfo * 0.5
    crickets = np.zeros_like(t)
    for f, period, gain in ((4600, 0.7, 0.25), (5200, 0.93, 0.15)):
        gate = np.zeros_like(t)
        start = r.uniform(0, period)
        while start < dur:
            for k in range(3):  # três pulsos por cricrilar
                a = start + k * 0.035
                gate += bell(dur, a, a + 0.008, a + 0.025)
            start += period * r.uniform(0.9, 1.1)
        crickets += np.sin(2 * math.pi * f * t) * gate * gain
    bird_at = 4.0
    bird_f = contour(dur, [(0, 2500), (bird_at / dur, 2500), ((bird_at + 0.25) / dur, 3300), ((bird_at + 0.5) / dur, 2700), (1, 2700)])
    bird = sweep(dur, bird_f) * (bell(dur, bird_at, bird_at + 0.1, bird_at + 0.25) + bell(dur, bird_at + 0.3, bird_at + 0.4, bird_at + 0.55)) * 0.12
    x = wind * 0.8 + leaves + crickets + bird
    return finish(loop_seamless(x, over), 0.6, fade=0.0)


def amb_warehouse():
    """Galpão: zumbido da rede elétrica, ar parado e estalos de metal longe."""
    r = rng_for("amb_warehouse")
    dur, over = 11.0, 1.0
    t = tt(dur)
    hum = sum(a * np.sin(2 * math.pi * f * t) for f, a in ((60, 0.5), (120, 0.35), (180, 0.12), (240, 0.08)))
    hum *= 1 + 0.1 * np.sin(2 * math.pi * 0.3 * t)
    air = lp(noise(r, dur), 220) * 1.5
    ticks = np.zeros_like(t)
    for at in (2.5, 6.8, 9.1):
        ticks += modes(dur, [900 * r.uniform(0.9, 1.1), 1500, 2300], [0.05, 0.04, 0.02], [0.5, 0.3, 0.2], at, r)
    x = hum * 0.6 + air + lp(ticks, 2500) * 0.6
    return finish(loop_seamless(x, over), 0.5, fade=0.0)
