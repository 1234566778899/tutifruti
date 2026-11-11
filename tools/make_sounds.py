"""Genera los efectos de sonido de Tutifruti (WAV 44.1 kHz mono) sintetizados desde cero.

Uso: python3 tools/make_sounds.py  → escribe en Tutifruti/Resources/Sounds/
"""
import math
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Tutifruti", "Resources", "Sounds")


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1, curve=4.0):
    """Ataque lineal corto + caída exponencial."""
    x = np.arange(n) / SR
    e = np.minimum(1.0, x / max(a, 1e-4))
    total = n / SR
    e *= np.exp(-curve * np.maximum(0, x - a) / max(r, 1e-4) * (r / total if total else 1))
    fade = np.minimum(1.0, (total - x) / 0.01)  # sin clics al final
    return e * np.clip(fade, 0, 1)


def tone(freq, d, kind="sine", decay=6.0, a=0.004, harmonics=(1.0,)):
    x = t(d)
    f = np.full_like(x, freq) if np.isscalar(freq) else freq
    phase = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        w = sum(h * np.sin((i + 1) * phase) for i, h in enumerate(harmonics))
    elif kind == "square":
        w = np.sign(np.sin(phase)) * 0.5
    elif kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(phase))
    else:
        raise ValueError(kind)
    e = np.minimum(1, x / a) * np.exp(-decay * x)
    fade = np.clip((d - x) / 0.012, 0, 1)
    return w * e * fade


def bell(freq, d=0.6, decay=5.0):
    # campana suave: fundamental + parciales inarmónicos
    return (tone(freq, d, decay=decay) + 0.35 * tone(freq * 2.01, d, decay=decay * 1.6)
            + 0.15 * tone(freq * 3.02, d, decay=decay * 2.4))


def seq(parts, gap=0.0):
    """Concatena (o solapa si gap<0) segmentos."""
    out = np.zeros(0)
    pos = 0
    for p in parts:
        start = pos
        end = start + len(p)
        if end > len(out):
            out = np.pad(out, (0, end - len(out)))
        out[start:end] += p
        pos = end + int(gap * SR)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(np.pad(p, (0, n - len(p))) for p in parts)


def at(p, sec, total=None):
    pad = int(sec * SR)
    out = np.pad(p, (pad, 0))
    if total:
        out = np.pad(out, (0, max(0, int(total * SR) - len(out))))
    return out


def noise(d, decay=20.0, lp=0.0):
    x = t(d)
    n = np.random.default_rng(7).uniform(-1, 1, len(x))
    if lp:
        # filtro paso bajo de un polo
        y = np.zeros_like(n)
        acc = 0.0
        for i, v in enumerate(n):
            acc += lp * (v - acc)
            y[i] = acc
        n = y
    return n * np.exp(-decay * x) * np.clip((d - x) / 0.01, 0, 1)


def save(name, s, gain=0.8):
    s = s / (np.max(np.abs(s)) + 1e-9) * gain
    data = (s * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


N = {n: 440 * 2 ** ((i - 9) / 12) for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def note(name, octave=5):
    return N[name] * 2 ** (octave - 4)


# Toque de botón: "pop" corto
pop_f = np.linspace(900, 500, int(SR * 0.07))
save("tap", tone(pop_f, 0.07, decay=45), 0.5)

# Tic de la ruleta de letras
save("tick", mix(tone(1800, 0.03, decay=120), 0.4 * noise(0.03, decay=200)), 0.45)

# Letra revelada: acorde brillante ascendente
save("reveal", seq([bell(note("C", 5), 0.12, 14), bell(note("E", 5), 0.12, 14), bell(note("G", 5), 0.12, 14),
                    bell(note("C", 6), 0.7, 4)], gap=-0.06), 0.8)

# Cuenta regresiva (3, 2, 1) y salida
save("count", tone(note("A", 4), 0.18, kind="tri", decay=14), 0.6)
save("go", mix(tone(note("A", 5), 0.45, kind="tri", decay=5), 0.5 * tone(note("E", 6), 0.45, decay=6)), 0.7)

# STOP: golpe + sirena corta descendente
siren = np.concatenate([np.linspace(1200, 700, int(SR * 0.18)), np.linspace(1200, 600, int(SR * 0.28))])
save("stop", mix(0.9 * noise(0.25, decay=18, lp=0.15), tone(siren, len(siren) / SR, kind="square", decay=3.5),
                 tone(np.linspace(160, 60, int(SR * 0.3)), 0.3, decay=9)), 0.85)

# Últimos segundos: tic urgente
save("hurry", tone(1320, 0.06, kind="square", decay=60), 0.35)

# Respuesta válida / inválida / dudosa
save("valid", seq([bell(note("E", 6), 0.1, 18), bell(note("B", 6), 0.45, 7)], gap=-0.04), 0.65)
save("invalid", mix(tone(np.linspace(220, 150, int(SR * 0.28)), 0.28, kind="tri", decay=8),
                    0.4 * tone(np.linspace(233, 160, int(SR * 0.28)), 0.28, kind="tri", decay=8)), 0.6)
save("doubtful", seq([tone(note("G", 5), 0.12, kind="tri", decay=14), tone(note("F#", 5), 0.22, kind="tri", decay=9)]), 0.5)

# Moneda / puntos
save("coin", seq([tone(note("B", 5), 0.06, kind="square", decay=10), tone(note("E", 6), 0.35, kind="square", decay=9)]), 0.4)

# Victoria: fanfarria
fan = seq([bell(note("C", 5), 0.14, 10), bell(note("E", 5), 0.14, 10), bell(note("G", 5), 0.14, 10),
           bell(note("C", 6), 0.22, 8), bell(note("G", 5), 0.12, 10), bell(note("C", 6), 0.9, 3)], gap=-0.02)
pad = mix(tone(note("C", 4), 1.6, decay=1.5), tone(note("G", 4), 1.6, decay=1.5), tone(note("E", 5), 1.6, decay=1.5))
save("win", mix(fan, 0.35 * at(pad, 0.55)), 0.85)

# Subida de nivel: arpegio rápido hacia arriba con brillo
arp = seq([bell(note(n, o), 0.09, 16) for n, o in [("C", 5), ("E", 5), ("G", 5), ("C", 6), ("E", 6), ("G", 6)]], gap=-0.02)
save("levelup", seq([arp, bell(note("C", 7), 0.8, 4)], gap=-0.03), 0.75)

# Notificación / mensaje de chat
save("notify", seq([bell(note("G", 5), 0.1, 16), bell(note("D", 6), 0.35, 8)], gap=-0.03), 0.55)
save("message", tone(np.linspace(700, 1000, int(SR * 0.08)), 0.08, decay=30), 0.4)

# Jugador entra a la sala
save("join", seq([tone(note("C", 6), 0.07, decay=30), tone(note("G", 6), 0.18, decay=16)]), 0.5)

# Perder / sin puntos
save("lose", seq([tone(note("G", 4), 0.2, kind="tri", decay=6), tone(note("F#", 4), 0.2, kind="tri", decay=6),
                  tone(note("F", 4), 0.55, kind="tri", decay=3)], gap=-0.02), 0.55)

print("ok", sorted(os.listdir(OUT)))
