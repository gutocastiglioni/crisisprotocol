"""Efeitos sonoros do jogo, sintetizados por código (nada gravado nem baixado).

Gera WAV mono 16 bits a 22050 Hz (a taxa típica dos efeitos de PS1/PS2) em game/assets/sounds/. Cada som é
montado com ruído filtrado, senos amortecidos (modos de metal, madeira, plástico), varreduras de frequência e,
nas vozes do raptor, fonte + formantes (dente de serra com aspereza sub-harmônica passando por filtros de
banda que imitam a garganta). Mesma semente = mesmo som (dá para regerar sem mudar nada).

Nomes `x_1.wav, x_2.wav...` são variações que o jogo sorteia (passos, impactos); a contagem fica em
game/scripts/sfx.gd (SOUNDS) e o teste confere que as duas listas batem.

Os blocos de síntese ficam em sound_dsp.py e as vozes do raptor, avisos e ambientes em sound_creatures.py.

    python tools/make_sounds.py
"""
import math
import wave
from pathlib import Path

import numpy as np

from sound_creatures import (
    alert, amb_warehouse, amb_yard, raptor_bite, raptor_chirp, raptor_death, raptor_hiss, raptor_hurt, raptor_roar,
    raptor_screech, raptor_shake, raptor_snarl, raptor_suspicious, suspicious, tail_whoosh,
)
from sound_dsp import (
    SR, bell, bp, cloth, contour, crackle, decay, echo, finish, hp, jitter, lp, modes, n_of, noise, rng_for, soft_clip,
    sweep, thud, tt,
)

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "sounds"


# ------------------------------------------------------------------ armas
def gunshot(name, dur, crack_tau, crack_hp, body_lp, body_tau, boom_f, boom_tau, tail_lp, tail_tau, tail_amp, taps, drive):
    r = rng_for(name)
    t = tt(dur)
    crack = hp(noise(r, dur), crack_hp) * decay(dur, crack_tau, 0.0002)
    body = lp(noise(r, dur), body_lp) * decay(dur, body_tau, 0.0008)
    f = boom_f[1] + (boom_f[0] - boom_f[1]) * np.exp(-t / 0.02)
    boom = sweep(dur, f) * decay(dur, boom_tau, 0.001)
    tail = lp(noise(r, dur), tail_lp) * decay(dur, tail_tau, 0.03, 0.005) * tail_amp
    x = crack * 0.9 + body * 0.8 + boom * 1.0 + tail
    return finish(soft_clip(echo(x, taps), drive), 0.97)


def pistol_shot():
    return gunshot("pistol_shot", 0.9, 0.004, 1300, 3000, 0.035, (170, 55), 0.07, 800, 0.28, 0.16,
                   [(0.11, 0.22, 1400), (0.24, 0.1, 900)], 1.8)


def m16_shot():
    return gunshot("m16_shot", 0.7, 0.003, 1900, 4200, 0.024, (210, 70), 0.05, 1000, 0.2, 0.13,
                   [(0.09, 0.2, 1800), (0.19, 0.08, 1100)], 2.0)



def sniper_shot():
    # Estalo hipersônico agudo + estrondo grave de alta energia + eco reverberante longo
    return gunshot("sniper_shot", 1.8, 0.002, 2200, 4800, 0.045, (160, 45), 0.12, 700, 0.55, 0.32,
                   [(0.12, 0.28, 1200), (0.28, 0.16, 850), (0.45, 0.1, 550)], 2.5)

def shotgun_shot():
    return gunshot("shotgun_shot", 1.4, 0.006, 900, 2000, 0.07, (130, 40), 0.15, 550, 0.45, 0.26,
                   [(0.14, 0.25, 1000), (0.3, 0.12, 700)], 2.4)


def metal_clack(r, dur, start, base, strength=1.0):
    ratios = [1.0, 1.73, 2.6, 3.47]
    freqs = [base * k * r.uniform(0.97, 1.03) for k in ratios]
    x = modes(dur, freqs, [0.03, 0.024, 0.018, 0.012], [1.0, 0.7, 0.5, 0.35], start, r)
    x += hp(noise(r, dur), 2000) * decay(dur, 0.004, 0.0002, start) * 1.2
    x += sweep(dur, np.full(n_of(dur), 300.0)) * decay(dur, 0.012, 0.0005, start) * 0.6
    return x * strength


def pump(name, travel, base, strength):
    r = rng_for(name)
    dur = 0.3
    scrape = bp(noise(r, dur), 2600, 2.0) * bell(dur, 0.0, travel * 0.5, travel) * 0.35
    return finish(scrape + metal_clack(r, dur, travel, base, strength), 0.85)


def shotgun_pump_back():
    # a telha vai do quadro 7 ao 10 (0,1 s a 30 qps): arrasta e bate no fim do curso
    return pump("shotgun_pump_back", 0.09, 1500, 1.0)


def shotgun_pump_fwd():
    return pump("shotgun_pump_fwd", 0.08, 1750, 1.2)


def casing_brass(i):
    r = rng_for(f"casing_brass_{i}")
    dur = 0.45
    out = np.zeros(n_of(dur))
    at, amp = 0.0, 1.0
    for _ in range(3):
        freqs = [f * r.uniform(0.92, 1.08) for f in (4200, 6100, 8300, 9700)]
        out += modes(dur, freqs, [0.05, 0.035, 0.02, 0.015], [1.0, 0.8, 0.5, 0.3], at, r) * amp
        out += hp(noise(r, dur), 3000) * decay(dur, 0.002, 0.0001, at) * amp * 0.5
        at += r.uniform(0.06, 0.11) * amp + 0.02
        amp *= r.uniform(0.35, 0.55)
    return finish(out, 0.8)


def casing_shell(i):
    r = rng_for(f"casing_shell_{i}")
    dur = 0.4
    out = np.zeros(n_of(dur))
    at, amp = 0.0, 1.0
    for _ in range(3):
        freqs = [f * r.uniform(0.93, 1.07) for f in (1150, 2300, 3900)]
        out += modes(dur, freqs, [0.02, 0.014, 0.01], [1.0, 0.5, 0.4], at, r) * amp
        out += lp(noise(r, dur), 1500) * decay(dur, 0.006, 0.0003, at) * amp
        at += r.uniform(0.08, 0.13) * amp + 0.02
        amp *= 0.4
    return finish(out, 0.8)


def weapon_switch():
    r = rng_for("weapon_switch")
    dur = 0.35
    x = metal_clack(r, dur, 0.0, 2800, 0.7) + metal_clack(r, dur, 0.13, 3300, 0.9)
    x += bp(noise(r, dur), 1800, 0.8) * bell(dur, 0.0, 0.08, 0.25) * 0.15  # roupa/coldre
    return finish(x, 0.8)


def weapon_pickup():
    r = rng_for("weapon_pickup")
    dur = 0.6
    x = bp(noise(r, dur), 1500, 0.7) * bell(dur, 0.0, 0.15, 0.5) * 0.25  # bandoleira
    for at in sorted(r.uniform(0.02, 0.4, 4)):
        x += metal_clack(r, dur, at, r.uniform(1800, 3200), r.uniform(0.4, 0.9))
    x += metal_clack(r, dur, 0.46, 2300, 1.0)  # ferrolho
    return finish(x, 0.85)


def dry_fire():
    # arma vazia: o cão cai no vazio (um clique seco e um segundo, mais fraco, do ferrolho)
    r = rng_for("dry_fire")
    dur = 0.2
    x = metal_clack(r, dur, 0.0, 3300, 0.8) + metal_clack(r, dur, 0.06, 2300, 0.35)
    return finish(x, 0.6)


# ------------------------------------------------------------------ impactos
def impact_concrete(i):
    r = rng_for(f"impact_concrete_{i}")
    dur = 0.3
    x = hp(noise(r, dur), 2000) * decay(dur, 0.003, 0.0001) * 1.2
    x += bp(noise(r, dur), r.uniform(3000, 4200), 2.0) * decay(dur, 0.012) * 0.8
    x += sweep(dur, np.full(n_of(dur), 180.0)) * decay(dur, 0.01) * 0.5
    x += bp(crackle(r, dur, 90, 0.02, 0.2), 3500, 0.8) * decay(dur, 0.08) * 1.5  # lascas caindo
    return finish(x, 0.85)


def impact_metal(i):
    r = rng_for(f"impact_metal_{i}")
    if i == 3:
        # ricochete: assobio que cai de tom e passa
        dur = 0.6
        t = tt(dur)
        f = 1400 + 1900 * np.exp(-t / 0.18)
        f *= 1 + 0.01 * np.sin(2 * math.pi * 23 * t)
        x = sweep(dur, f) * bell(dur, 0.01, 0.06, 0.55) * 0.6
        x += bp(noise(r, dur), f, 8.0) * bell(dur, 0.0, 0.05, 0.5) * 0.5
        x += metal_clack(r, dur, 0.0, 2100, 1.0)
        return finish(x, 0.85)
    dur = 0.45
    base = r.uniform(1750, 2100)
    x = modes(dur, [base, base * 1.58, base * 2.3, base * 3.05], [0.12, 0.09, 0.06, 0.04], [1.0, 0.7, 0.5, 0.3], 0.0, r)
    x += hp(noise(r, dur), 2500) * decay(dur, 0.003, 0.0001) * 1.5
    return finish(x, 0.85)


def impact_wood(i):
    r = rng_for(f"impact_wood_{i}")
    dur = 0.3
    x = bp(noise(r, dur), r.uniform(800, 1000), 1.5) * decay(dur, 0.02) * 1.2
    x += modes(dur, [210 * r.uniform(0.9, 1.1), 470, 820], [0.05, 0.03, 0.02], [1.0, 0.6, 0.4], 0.0, r)
    x += hp(crackle(r, dur, 120, 0.005, 0.07), 3000) * 1.2  # farpas
    return finish(x, 0.85)


def impact_flesh(i):
    r = rng_for(f"impact_flesh_{i}")
    dur = 0.25
    t = tt(dur)
    x = lp(noise(r, dur), 700) * decay(dur, 0.03, 0.001) * 1.5
    x += sweep(dur, 60 + 30 * np.exp(-t / 0.03)) * decay(dur, 0.045, 0.002)
    squish = bp(noise(r, dur), r.uniform(1200, 1700), 3.0) * decay(dur, 0.04, 0.005)
    x += squish * (0.6 + 0.4 * np.sin(2 * math.pi * 45 * t)) * 0.5
    return finish(soft_clip(x, 1.5), 0.85)


# ------------------------------------------------------------------ passos e corpo
def step_concrete(i):
    r = rng_for(f"step_concrete_{i}")
    dur = 0.2
    heel = lp(noise(r, dur), 900) * decay(dur, 0.012, 0.001) + sweep(dur, np.full(n_of(dur), 110.0)) * decay(dur, 0.012) * 0.4
    toe_at = r.uniform(0.035, 0.055)
    toe = bp(noise(r, dur), r.uniform(1700, 2400), 1.0) * decay(dur, 0.01, 0.0005, toe_at) * 0.6
    scuff = hp(noise(r, dur), 3000) * bell(dur, 0.0, 0.02, 0.09) * 0.15
    return finish(heel + toe + scuff, 0.8)


def step_grass(i):
    r = rng_for(f"step_grass_{i}")
    dur = 0.28
    rustle = hp(noise(r, dur) * (0.3 + np.abs(crackle(r, dur, 400))), 1500) * decay(dur, 0.06, 0.012)
    thud = lp(noise(r, dur), 300) * decay(dur, 0.015, 0.002) * 0.6
    return finish(rustle + thud, 0.8)


def raptor_step(i):
    r = rng_for(f"raptor_step_{i}")
    dur = 0.28
    x = lp(noise(r, dur), 250) * decay(dur, 0.03, 0.002) * 1.4
    x += sweep(dur, np.full(n_of(dur), 70.0)) * decay(dur, 0.04, 0.002) * 0.8
    for _ in range(r.integers(2, 4)):  # garras batendo no chão
        at = r.uniform(0.01, 0.07)
        x += modes(dur, [3200 * r.uniform(0.9, 1.1), 5100 * r.uniform(0.9, 1.1)], [0.006, 0.004], [0.5, 0.3], at, r)
    return finish(x, 0.85)


def roll():
    r = rng_for("roll")
    dur = 1.0
    t = tt(dur)
    swish = bp(noise(r, dur), 800 + 1700 * np.sin(np.clip(t / 0.45, 0, 1) * math.pi), 1.2) * bell(dur, 0.02, 0.2, 0.55) * 0.5
    x = swish + thud(r, dur, 0.22, 320, 0.035) + thud(r, dur, 0.45, 280, 0.03, 0.7)
    x += thud(r, dur, 0.83, 600, 0.015, 0.5) + cloth(r, dur, 0.8, 0.95, 2500, 0.15)
    return finish(x, 0.8)


def jump():
    r = rng_for("jump")
    dur = 0.3
    x = cloth(r, dur, 0.0, 0.25, 1400, 0.5) + hp(noise(r, dur), 2500) * bell(dur, 0.0, 0.02, 0.07) * 0.3
    return finish(x, 0.75)


def land():
    r = rng_for("land")
    dur = 0.35
    x = thud(r, dur, 0.0, 450, 0.04, 1.2) + thud(r, dur, 0.035, 700, 0.015, 0.6)
    x += hp(noise(r, dur), 2500) * bell(dur, 0.01, 0.04, 0.12) * 0.2 + cloth(r, dur, 0.0, 0.2, 1300, 0.3)
    return finish(x, 0.85)


def ledge_grab():
    r = rng_for("ledge_grab")
    dur = 0.25
    x = np.zeros(n_of(dur))
    for at in (0.0, 0.018):  # as duas mãos
        x += hp(noise(r, dur), 800) * decay(dur, 0.008, 0.0003, at) + bp(noise(r, dur), 1200, 1.5) * decay(dur, 0.02, 0.001, at) * 0.6
    x += cloth(r, dur, 0.0, 0.2, 1500, 0.25)
    return finish(x, 0.8)


def climb():
    r = rng_for("climb")
    dur = 1.2
    x = cloth(r, dur, 0.0, 0.6, 1300, 0.45) + cloth(r, dur, 0.4, 1.1, 1700, 0.35)
    x += hp(noise(r, dur), 2200) * bell(dur, 0.25, 0.4, 0.6) * 0.15  # joelho raspando na borda
    x += thud(r, dur, 0.55, 400, 0.02, 0.6) + thud(r, dur, 1.0, 600, 0.015, 0.5)
    return finish(x, 0.75)


def body_fall():
    r = rng_for("body_fall")
    dur = 0.7
    t = tt(dur)
    x = thud(r, dur, 0.0, 220, 0.06, 1.4) + sweep(dur, 55 + 25 * np.exp(-t / 0.04)) * decay(dur, 0.08, 0.002)
    x += thud(r, dur, 0.12, 400, 0.03, 0.6) + thud(r, dur, 0.26, 500, 0.02, 0.35)  # braços e pernas
    x += cloth(r, dur, 0.0, 0.3, 1100, 0.3)
    return finish(soft_clip(x, 1.4), 0.9)


def claw_hit():
    r = rng_for("claw_hit")
    dur = 0.4
    t = tt(dur)
    slash = bp(noise(r, dur), 3200 - 2000 * np.clip(t / 0.12, 0, 1), 2.0) * bell(dur, 0.0, 0.03, 0.14)
    punch = thud(r, dur, 0.04, 300, 0.05, 1.3) + sweep(dur, 50 + 40 * np.exp(-t / 0.03)) * decay(dur, 0.05, 0.002, 0.04)
    return finish(soft_clip(slash * 0.8 + punch, 1.6), 0.9)


# ------------------------------------------------------------------ baú
def chest_open():
    r = rng_for("chest_open")
    dur = 0.9
    t = tt(dur)
    x = metal_clack(r, dur, 0.0, 1900, 0.6)  # trinco
    # rangido: atrito em pulsos (gruda e solta) passando pelas ressonâncias da madeira
    rate = contour(dur, [(0, 40), (0.3, 75), (0.6, 55), (1, 50)]) * jitter(r, dur, 0.15, 20)
    phase = np.cumsum(rate) / SR
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float) * r.uniform(0.5, 1.0, len(t))
    pulses *= bell(dur, 0.05, 0.2, 0.5)
    creak = bp(pulses, 650, 6) + bp(pulses, 1350, 7) * 0.7 + bp(pulses, 2150, 8) * 0.4
    x += creak * 3.0
    x += thud(r, dur, 0.47, 300, 0.04, 0.8) + modes(dur, [140, 310], [0.06, 0.03], [0.5, 0.3], 0.47, r)  # tampa no batente
    return finish(x, 0.85)


# ------------------------------------------------------------------ M79, explosão, chave e cadeado
def m79_shot():
    # "thump": o lança-granadas não estala como fuzil; é um baque grave e oco, com o cano soando um pouco
    r = rng_for("m79_shot")
    dur = 1.1
    t = tt(dur)
    f = 45 + (130 - 45) * np.exp(-t / 0.03)
    boom = sweep(dur, f) * decay(dur, 0.12, 0.002)
    body = lp(noise(r, dur), 900) * decay(dur, 0.05, 0.001)
    crack = hp(noise(r, dur), 1500) * decay(dur, 0.003, 0.0002) * 0.35
    ring = modes(dur, [620, 1150, 1840], [0.15, 0.1, 0.06], [0.18, 0.1, 0.05], 0.0, r)
    x = boom * 1.2 + body * 0.7 + crack + ring
    return finish(soft_clip(echo(x, [(0.12, 0.2, 900), (0.27, 0.08, 600)]), 1.8), 0.95)


def explosion():
    # granada de 40 mm: estalo, estrondo grave que desce, ronco longo e terra/estilhaços caindo
    r = rng_for("explosion")
    dur = 2.8
    t = tt(dur)
    crack = hp(noise(r, dur), 800) * decay(dur, 0.012, 0.0003)
    f = 28 + (75 - 28) * np.exp(-t / 0.08)
    boom = sweep(dur, f) * decay(dur, 0.35, 0.002)
    rumble = lp(noise(r, dur), 280) * decay(dur, 0.8, 0.01)
    mid = lp(noise(r, dur), 1600) * decay(dur, 0.12, 0.002)
    debris = lp(crackle(r, dur, 60, 0.15, 1.6), 3500) * 0.35
    x = crack * 0.8 + boom * 1.4 + rumble * 1.2 + mid * 0.8 + debris
    return finish(soft_clip(echo(x, [(0.18, 0.35, 600), (0.42, 0.2, 400), (0.8, 0.1, 300)]), 2.6), 0.97)


def key_drop():
    # chavinha de latão batendo no concreto e quicando
    r = rng_for("key_drop")
    dur = 0.5
    out = np.zeros(n_of(dur))
    at, amp = 0.0, 1.0
    for _ in range(3):
        freqs = [f * r.uniform(0.94, 1.06) for f in (2600, 4100, 5900)]
        out += modes(dur, freqs, [0.06, 0.04, 0.025], [1.0, 0.6, 0.35], at, r) * amp
        out += hp(noise(r, dur), 2500) * decay(dur, 0.002, 0.0001, at) * amp * 0.4
        at += r.uniform(0.07, 0.12) * amp + 0.03
        amp *= 0.45
    return finish(out, 0.7)


def lock_rattle():
    # puxou o cadeado trancado: a haste bate na argola algumas vezes
    r = rng_for("lock_rattle")
    dur = 0.55
    x = bp(noise(r, dur), 2400, 1.5) * bell(dur, 0.0, 0.1, 0.35) * 0.12
    for at in (0.0, 0.07, 0.13, 0.21, 0.3):
        x += metal_clack(r, dur, at, r.uniform(1400, 2200), r.uniform(0.5, 1.0))
    return finish(x, 0.8)


def unlock():
    # a chave entra e gira (cliques), a haste do cadeado salta e ele cai no chão
    r = rng_for("unlock")
    dur = 1.4
    x = bp(noise(r, dur), 3000, 1.2) * bell(dur, 0.0, 0.08, 0.16) * 0.15  # chave entrando
    x += metal_clack(r, dur, 0.18, 3200, 0.5) + metal_clack(r, dur, 0.27, 2900, 0.6)
    x += metal_clack(r, dur, 0.36, 1800, 1.1)  # haste salta
    x += modes(dur, [880, 1640, 2500], [0.09, 0.06, 0.04], [0.8, 0.5, 0.3], 1.0, r)  # cadeado no chão
    x += thud(r, dur, 1.0, 400, 0.03, 0.6)
    x += modes(dur, [1000, 1900], [0.05, 0.03], [0.3, 0.2], 1.12, r)
    return finish(x, 0.85)


def item_get():
    # pegou um item: arpejo curto e limpo (aviso de interface)
    r = rng_for("item_get")
    dur = 1.1
    x = np.zeros(n_of(dur))
    for k, (at, f) in enumerate([(0.0, 523.25), (0.08, 659.25), (0.16, 783.99), (0.24, 1046.5)]):
        tau = 0.5 if k == 3 else 0.18
        x += modes(dur, [f, f * 2.0, f * 3.0], [tau, tau * 0.6, tau * 0.3], [1.0, 0.25, 0.08], at, r)
    return finish(x, 0.6)


# ------------------------------------------------------------------ saída
SOUNDS = {
    "pistol_shot": pistol_shot,
    "m16_shot": m16_shot,
    "shotgun_shot": shotgun_shot,
    "sniper_shot": sniper_shot,
    "shotgun_pump_back": shotgun_pump_back,
    "shotgun_pump_fwd": shotgun_pump_fwd,
    "weapon_switch": weapon_switch,
    "weapon_pickup": weapon_pickup,
    "dry_fire": dry_fire,
    "chest_open": chest_open,
    "m79_shot": m79_shot,
    "explosion": explosion,
    "key_drop": key_drop,
    "lock_rattle": lock_rattle,
    "unlock": unlock,
    "item_get": item_get,
    "roll": roll,
    "jump": jump,
    "land": land,
    "ledge_grab": ledge_grab,
    "climb": climb,
    "body_fall": body_fall,
    "claw_hit": claw_hit,
    "raptor_roar": raptor_roar,
    "raptor_screech": raptor_screech,
    "raptor_snarl": raptor_snarl,
    "raptor_hiss": raptor_hiss,
    "raptor_suspicious": raptor_suspicious,
    "raptor_bite": raptor_bite,
    "raptor_shake": raptor_shake,
    "raptor_death": raptor_death,
    "tail_whoosh": tail_whoosh,
    "alert": alert,
    "suspicious": suspicious,
    "amb_yard": amb_yard,
    "amb_warehouse": amb_warehouse,
}
VARIANTS = {
    "casing_brass": (casing_brass, 3),
    "casing_shell": (casing_shell, 2),
    "impact_concrete": (impact_concrete, 3),
    "impact_metal": (impact_metal, 3),
    "impact_wood": (impact_wood, 2),
    "impact_flesh": (impact_flesh, 3),
    "step_concrete": (step_concrete, 4),
    "step_grass": (step_grass, 4),
    "raptor_step": (raptor_step, 3),
    "raptor_chirp": (raptor_chirp, 2),
    "raptor_hurt": (raptor_hurt, 2),
}


def write(name: str, x: np.ndarray) -> None:
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [(name, fn) for name, fn in SOUNDS.items()]
    for base, (fn, count) in VARIANTS.items():
        jobs += [(f"{base}_{i}", (lambda f=fn, k=i: f(k))) for i in range(1, count + 1)]
    for name, fn in jobs:
        x = fn()
        write(name, x)
        print(f"{name:22s} {len(x) / SR:5.2f} s")
    print(f"{len(jobs)} sons em {OUT}")


if __name__ == "__main__":
    main()
