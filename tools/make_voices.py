"""Falas dos guerrilheiros (game/assets/voices/<voz>_<fala>_<n>.wav), geradas por TTS local (Piper, sem rede na hora de
gerar) e tratadas para o jogo: corta o silêncio das pontas, abafa como voz atrás da balaclava, dá corpo às que são
gritadas e acerta o volume por RMS. WAV mono 16 bits a 22050 Hz, como os efeitos de make_sounds.py.

Vozes (art/voice_models/, fora do git; baixar com
`python -m piper.download_voices --data-dir art/voice_models pt_BR-cadu-medium pt_BR-faber-medium pt_BR-jeff-medium`):
pt_BR cadu / faber / jeff do repositório rhasspy/piper-voices, todas com dataset CC0 (MODEL_CARD de cada uma). A edresson
ficou de fora (CC BY 4.0 e qualidade baixa). Requer `pip install piper-tts`.

A tabela LINES tem que bater com `Voice.LINES` (game/scripts/voice.gd): mesmas falas, mesma quantidade de variações, normais + furiosas (o teste
`voice_tests.gd` confere que os arquivos existem).
"""
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sound_dsp import SR, bp, hp, lp, soft_clip  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "art" / "voice_models"
OUT = ROOT / "game" / "assets" / "voices"

# voz -> modelo e ritmo (length_scale < 1 = mais rápido; cada guerrilheiro com o seu jeito)
VOICES = {
    "cadu": {"model": "pt_BR-cadu-medium", "speed": 0.95},
    "faber": {"model": "pt_BR-faber-medium", "speed": 1.05},
    "jeff": {"model": "pt_BR-jeff-medium", "speed": 0.95},
}

# fala -> (frases, gritada, furiosas). Gritada = mais rápida, saturada e mais alta; as outras são murmúrio (baixo, sem
# pressa). As furiosas vêm numeradas depois das normais (o jogo sorteia entre todas: às vezes ele perde a cabeça): mais
# rápidas, um pouco mais agudas, com a garganta forçada e o grito estourado (`treat(..., fury=True)`).
LINES = {
    "huh": (["Ahn?", "Hum?", "O que foi isso?", "Ouviu isso?"], False, []),  # desconfiou (nível 1 "?")
    "check": (["Vou dar uma olhada.", "Tem alguém aí?", "Quem está aí?"], False, []),  # vai ver (busca amarela)
    "nothing": (["Não era nada.", "Deve ter sido um bicho.", "Hum... nada."], False, []),  # a busca amarela acabou
    "spot": (["Ali!", "Intrusa!", "Achei ela!", "Lá está ela!"], True,
             ["Ali, desgraçada!", "Fogo nela!", "Peguei você!"]),  # viu ela (o "!")
    "lost": (["Cadê ela?", "Perdi ela de vista!", "Onde ela se meteu?"], True,
             ["Aparece, covarde!", "Não adianta se esconder!"]),  # sumiu no meio da luta
    "search": (["Vasculhem a área!", "Ela não foi longe!", "Procurem ela!"], True,
               ["Achem essa maldita!", "Ela não sai viva daqui!"]),  # chegou ao lugar da busca ativa
    "corpse": (["Homem no chão!", "Temos um morto aqui!", "Mataram ele!"], True,
               ["Desgraçada! Ela matou ele!", "Ela vai pagar por isso!"]),  # grito de quem acha um corpo
    "hit": (["Fui atingido!", "Atirador!", "Estão atirando!"], True,
            ["Filha da mãe!", "Maldita! Me acertou!"]),  # ferido sem tê-la visto
    "giveup": (["Ela sumiu. Voltem aos postos.", "Perdemos ela.", "Fiquem atentos."], False,
               ["Droga! Ela escapou!"]),  # a busca ativa acabou
    "ack": (["Entendido!", "Indo pra lá!", "Na escuta!"], True,
            ["Deixa ela comigo!", "Vou pegar ela!"]),  # saiu para atender o alarme de outro
    "taunt": ([], True, ["Morre!", "Sai daí!", "Você não tem pra onde correr!", "Acabou pra você!",
                         "Vem, desgraçada!"]),  # provocação no tiroteio (às vezes, no começo de uma rajada)
    "down": (["Alvo caiu!", "Alvo abatido!", "Invasor abatido!", "Invasora abatida!"], True, []),  # o tiro dele a matou
}

SHOUT_RMS = -15.0  # dBFS
MURMUR_RMS = -19.0
FURY_RMS = -12.0
FURY_SPEED = 0.78  # x o ritmo da voz (a gritada normal é 0,92)
FURY_PITCH = 1.10  # ~1,7 semitom acima: garganta apertada de quem berra
FURY_DRIVE = 5.0  # saturação do grito (a gritada normal é 1,8)


def _trim(x: np.ndarray, pad: float = 0.04) -> np.ndarray:
    """Tira o silêncio das pontas (o Piper deixa até meio segundo), com uma folga de `pad` s."""
    env = np.abs(x)
    on = np.nonzero(env > max(env.max() * 0.04, 1e-4))[0]
    if on.size == 0:
        return x
    a = max(on[0] - int(pad * SR), 0)
    b = min(on[-1] + int(pad * SR * 2), x.size)
    return x[a:b]


def _rms_to(x: np.ndarray, db: float) -> np.ndarray:
    rms = float(np.sqrt(np.mean(x ** 2))) or 1e-6
    return x * (10 ** (db / 20) / rms)


def _pitch(x: np.ndarray, k: float) -> np.ndarray:
    """Sobe o tom `k` vezes reamostrando (encurta junto; com voz já filtrada a interpolação linear basta)."""
    t = np.arange(int(len(x) / k)) * k
    return np.interp(t, np.arange(len(x)), x)


def _squash(x: np.ndarray, win: float = 0.03, floor: float = 0.25) -> np.ndarray:
    """Achata o volume dentro da frase (envelope de `win` s): cada sílaba sai no talo, como quem berra sem respirar."""
    n = max(int(win * SR), 1)
    env = np.convolve(np.abs(x), np.ones(n) / n, mode="same")
    top = float(env.max()) or 1.0
    return x / np.maximum(env, top * floor) * top


def treat(x: np.ndarray, shout: bool, fury: bool = False) -> np.ndarray:
    """Voz atrás da balaclava, jeito PS2: sem o grave de microfone nem o agudo fino, presença no meio; gritada satura um
    pouco; furiosa sobe o tom, força a garganta (meio-agudo rasgado) e estoura mais o grito."""
    x = _trim(x)
    if fury:
        x = _pitch(x, FURY_PITCH)
    x = hp(x, 180.0 if fury else 140.0)
    x = lp(x, 4600.0 if fury else 4200.0)
    x = x + 0.35 * bp(x, 1800.0, 1.2)  # presença: a voz atravessa o tiroteio
    if fury:
        x = x + 0.6 * bp(x, 2700.0, 1.6)  # garganta forçada
        x = x + 0.3 * bp(x, 900.0, 1.4)  # peito do berro
        x = _squash(x)
        x = soft_clip(x / (np.abs(x).max() or 1.0), FURY_DRIVE)
        x = lp(x, 5200.0)  # o estouro sem chiado fino
    elif shout:
        x = soft_clip(x / (np.abs(x).max() or 1.0), 1.8)
    x = _rms_to(x - np.mean(x), FURY_RMS if fury else SHOUT_RMS if shout else MURMUR_RMS)
    peak = float(np.abs(x).max())
    if peak > 0.89:  # só baixa o pico que passou (finish() normalizaria e desfaria o volume por RMS)
        x = soft_clip(x / peak, 1.2) * 0.89
    f = int(0.012 * SR)
    x[-f:] *= np.linspace(1.0, 0.0, f)
    x[:f // 3] *= np.linspace(0.0, 1.0, f // 3)
    return x


def synth(voice, text: str, speed: float, fury: bool = False):
    from piper import SynthesisConfig

    # furiosa: mais variação de entonação e de duração (o padrão do Piper é 0,667 / 0,8)
    cfg = SynthesisConfig(length_scale=speed, normalize_audio=True,
                          noise_scale=0.95 if fury else None, noise_w_scale=1.1 if fury else None)
    a = np.concatenate([c.audio_float_array for c in voice.synthesize(text, syn_config=cfg)]).astype(np.float64)
    sr = voice.config.sample_rate
    if sr != SR:  # reamostra (linear basta para voz já filtrada)
        t = np.arange(int(len(a) * SR / sr)) * (sr / SR)
        a = np.interp(t, np.arange(len(a)), a)
    return a


def write(path: Path, x: np.ndarray) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes())


def main() -> None:
    """`--new` = só as falas que ainda não têm arquivo (as outras saem um pouco diferentes a cada geração); `--fury` = só
    as furiosas (refaz todas elas)."""
    try:
        from piper import PiperVoice
    except ImportError:
        sys.exit("falta o Piper: pip install piper-tts")
    only_new = "--new" in sys.argv[1:]
    only_fury = "--fury" in sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for vname, v in VOICES.items():
        model = MODELS / f"{v['model']}.onnx"
        if not model.exists():
            sys.exit(f"falta o modelo {model} (ver o cabeçalho deste arquivo)")
        pv = PiperVoice.load(str(model))
        for cat, (texts, shout, furious) in LINES.items():
            for i, (text, fury) in enumerate([(t, False) for t in texts] + [(t, True) for t in furious], 1):
                path = OUT / f"{vname}_{cat}_{i}.wav"
                if (only_new and path.exists()) or (only_fury and not fury):
                    continue
                speed = v["speed"] * (FURY_SPEED if fury else 0.92 if shout else 1.0)
                x = treat(synth(pv, text, speed, fury), shout, fury)
                write(path, x)
                n += 1
                print(f"{vname:6s} {cat:8s} {i} {len(x) / SR:4.2f} s  {'FÚRIA ' if fury else ''}{text}")
    print(f"{n} falas em {OUT}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
