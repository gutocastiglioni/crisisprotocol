"""Falas dos guerrilheiros (game/assets/voices/<voz>_<fala>_<n>.wav), geradas por TTS local (Piper, sem rede na hora de
gerar) e tratadas para o jogo: corta o silêncio das pontas, abafa como voz atrás da balaclava, dá corpo às que são
gritadas e acerta o volume por RMS. WAV mono 16 bits a 22050 Hz, como os efeitos de make_sounds.py.

Vozes (art/voice_models/, fora do git; baixar com
`python -m piper.download_voices --data-dir art/voice_models pt_BR-cadu-medium pt_BR-faber-medium pt_BR-jeff-medium`):
pt_BR cadu / faber / jeff do repositório rhasspy/piper-voices, todas com dataset CC0 (MODEL_CARD de cada uma). A edresson
ficou de fora (CC BY 4.0 e qualidade baixa). Requer `pip install piper-tts`.

A tabela LINES tem que bater com `Voice.LINES` (game/scripts/voice.gd): mesmas falas, mesma quantidade de variações (o teste
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

# fala -> (frases, gritada). Gritada = mais rápida, saturada e mais alta; as outras são murmúrio (baixo, sem pressa).
LINES = {
    "huh": (["Ahn?", "Hum?", "O que foi isso?", "Ouviu isso?"], False),  # desconfiou (nível 1 "?")
    "check": (["Vou dar uma olhada.", "Tem alguém aí?", "Quem está aí?"], False),  # vai ver (busca amarela)
    "nothing": (["Não era nada.", "Deve ter sido um bicho.", "Hum... nada."], False),  # a busca amarela acabou
    "spot": (["Ali!", "Intrusa!", "Achei ela!", "Lá está ela!"], True),  # viu ela (o "!")
    "lost": (["Cadê ela?", "Perdi ela de vista!", "Onde ela se meteu?"], True),  # sumiu no meio da luta
    "search": (["Vasculhem a área!", "Ela não foi longe!", "Procurem ela!"], True),  # chegou ao lugar da busca ativa
    "corpse": (["Homem no chão!", "Temos um morto aqui!", "Mataram ele!"], True),  # grito de quem acha um corpo
    "hit": (["Fui atingido!", "Atirador!", "Estão atirando!"], True),  # ferido sem tê-la visto
    "giveup": (["Ela sumiu. Voltem aos postos.", "Perdemos ela.", "Fiquem atentos."], False),  # a busca ativa acabou
    "ack": (["Entendido!", "Indo pra lá!", "Na escuta!"], True),  # saiu para atender o alarme de outro
}

SHOUT_RMS = -15.0  # dBFS
MURMUR_RMS = -19.0


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


def treat(x: np.ndarray, shout: bool) -> np.ndarray:
    """Voz atrás da balaclava, jeito PS2: sem o grave de microfone nem o agudo fino, presença no meio; gritada satura um pouco."""
    x = _trim(x)
    x = hp(x, 140.0)
    x = lp(x, 4200.0)
    x = x + 0.35 * bp(x, 1800.0, 1.2)  # presença: a voz atravessa o tiroteio
    if shout:
        x = soft_clip(x / (np.abs(x).max() or 1.0), 1.8)
    x = _rms_to(x - np.mean(x), SHOUT_RMS if shout else MURMUR_RMS)
    peak = float(np.abs(x).max())
    if peak > 0.89:  # só baixa o pico que passou (finish() normalizaria e desfaria o volume por RMS)
        x = soft_clip(x / peak, 1.2) * 0.89
    f = int(0.012 * SR)
    x[-f:] *= np.linspace(1.0, 0.0, f)
    x[:f // 3] *= np.linspace(0.0, 1.0, f // 3)
    return x


def synth(voice, text: str, speed: float):
    from piper import SynthesisConfig

    cfg = SynthesisConfig(length_scale=speed, normalize_audio=True)
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
    try:
        from piper import PiperVoice
    except ImportError:
        sys.exit("falta o Piper: pip install piper-tts")
    OUT.mkdir(parents=True, exist_ok=True)
    n = 0
    for vname, v in VOICES.items():
        model = MODELS / f"{v['model']}.onnx"
        if not model.exists():
            sys.exit(f"falta o modelo {model} (ver o cabeçalho deste arquivo)")
        pv = PiperVoice.load(str(model))
        for cat, (texts, shout) in LINES.items():
            for i, text in enumerate(texts, 1):
                x = treat(synth(pv, text, v["speed"] * (0.92 if shout else 1.0)), shout)
                write(OUT / f"{vname}_{cat}_{i}.wav", x)
                n += 1
                print(f"{vname:6s} {cat:8s} {i} {len(x) / SR:4.2f} s  {text}")
    print(f"{n} falas em {OUT}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
