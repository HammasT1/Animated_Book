#!/usr/bin/env python3
"""Synthesizes the page-turn sounds in assets/sounds/.

The sounds are generated rather than recorded so the app ships no
third-party audio. Each one is band-limited noise shaped into a paper
"swish" (with a little flutter and crackle), ending in a soft tap as the
page lands. Three seeded variations keep repeated turns from sounding
mechanical. Pure Python, no dependencies:

    python3 tool/generate_page_sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def one_pole_lowpass(samples, cutoff):
    a = math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y = (1 - a) * x + a * y
        out.append(y)
    return out


def one_pole_highpass(samples, cutoff):
    low = one_pole_lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def page_turn(seed, duration=0.42):
    rnd = random.Random(seed)
    n = int(RATE * duration)

    # Paper "swish": noise in roughly the 1-6 kHz band.
    noise = [rnd.uniform(-1, 1) for _ in range(n)]
    band = one_pole_highpass(noise, 900 + rnd.uniform(-150, 150))
    band = one_pole_lowpass(one_pole_lowpass(band, 5500), 7000)

    peak_t = 0.15 + rnd.uniform(-0.02, 0.02)
    end_t = 0.31 + rnd.uniform(-0.02, 0.02)
    flutter_hz = 26 + rnd.uniform(-5, 5)
    phase = rnd.uniform(0, 2 * math.pi)

    swish = []
    for i, x in enumerate(band):
        t = i / RATE
        rise = smoothstep(t / peak_t) ** 1.5
        fall = 1 - smoothstep((t - peak_t) / (end_t - peak_t))
        env = rise if t < peak_t else fall
        flutter = 0.72 + 0.28 * math.sin(2 * math.pi * flutter_hz * t + phase)
        swish.append(x * env * flutter)

    # Crackle: sparse, quickly decaying clicks while the paper moves.
    crackle = [0.0] * n
    for i in range(n):
        t = i / RATE
        if 0.03 < t < end_t and rnd.random() < 0.0016:
            amp = rnd.uniform(0.25, 0.6)
            for k in range(min(90, n - i)):
                crackle[i + k] += amp * math.exp(-k / 14) * rnd.uniform(-1, 1)
    crackle = one_pole_highpass(crackle, 1800)

    # The page landing: a short, soft, low thump.
    tap_t = end_t - 0.01
    tap_noise = [rnd.uniform(-1, 1) for _ in range(n)]
    tap = one_pole_lowpass(one_pole_lowpass(tap_noise, 500), 700)
    for i in range(n):
        t = i / RATE - tap_t
        tap[i] *= 0.0 if t < 0 else math.exp(-t / 0.018)

    mix = [s + 0.35 * c + 2.2 * tp for s, c, tp in zip(swish, crackle, tap)]

    # 4 ms fades so nothing clicks at the edges, then normalize to -6 dBFS.
    fade = int(0.004 * RATE)
    for i in range(fade):
        mix[i] *= i / fade
        mix[-1 - i] *= i / fade
    peak = max(abs(v) for v in mix) or 1.0
    return [v / peak * 0.5 for v in mix]


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(v * 32767)) for v in samples)
        )


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for index, seed in enumerate((7, 21, 42), start=1):
        path = os.path.join(OUT_DIR, f"page_turn_{index}.wav")
        write_wav(path, page_turn(seed))
        print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
