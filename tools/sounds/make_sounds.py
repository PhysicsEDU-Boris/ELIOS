"""Synthesises the ELIOS 3 UI sound palette S1-S10 (Figma section 13) as
44.1 kHz mono 16-bit WAVs with a peak at or below -18 dBFS.

Run from the repo root: python3 tools/sounds/make_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
PEAK = 10 ** (-18 / 20)  # -18 dBFS
OUT = Path('assets/sounds')


def env(i, n, attack=0.005, decay=None):
    t = i / RATE
    a = min(1.0, t / attack) if attack else 1.0
    d = math.exp(-t / decay) if decay else max(0.0, 1 - i / n)
    return a * d


def tone(f, ms, decay=0.05, harm=(1.0,), f_end=None):
    n = int(RATE * ms / 1000)
    out = []
    for i in range(n):
        t = i / RATE
        freq = f if f_end is None else f + (f_end - f) * i / n
        s = sum(a * math.sin(2 * math.pi * freq * (k + 1) * t) for k, a in enumerate(harm))
        out.append(s * env(i, n, decay=decay))
    return out


def noise(ms, decay=0.01, seed=1):
    rnd = random.Random(seed)
    n = int(RATE * ms / 1000)
    return [(rnd.random() * 2 - 1) * env(i, n, attack=0.001, decay=decay) for i in range(n)]


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def cat(*parts, gap_ms=0):
    gap = [0.0] * int(RATE * gap_ms / 1000)
    out = []
    for k, p in enumerate(parts):
        if k:
            out += gap
        out += p
    return out


def note(name):
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    return 440 * 2 ** ((names[name[0]] + 12 * (int(name[1]) - 4)) / 12)


def marimba(name, ms=160):
    return tone(note(name), ms, decay=0.06, harm=(1.0, 0.0, 0.0, 0.25))


def save(name, samples):
    peak = max(abs(s) for s in samples) or 1
    data = b''.join(struct.pack('<h', int(s / peak * PEAK * 32767)) for s in samples)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save('s1_leaf_tick', mix(noise(40, decay=0.004), tone(1800, 40, decay=0.006)))
    save('s2_seed_pop', tone(520, 80, decay=0.025, f_end=780))
    save('s3_toggle_on', cat(tone(1300, 25, 0.006), tone(1640, 30, 0.008), gap_ms=8))
    save('s3_toggle_off', cat(tone(1300, 25, 0.006), tone(1030, 30, 0.008), gap_ms=8))
    save('s4_bloom_chime', cat(marimba('E5', 110), marimba('B5', 140)))
    save('s5_soft_knock', cat(tone(320, 90, 0.025, (1, 0.5)), tone(240, 110, 0.03, (1, 0.5)), gap_ms=20))
    save('s6_robot_blip', cat(tone(880, 40, 0.02), tone(1320, 45, 0.02), gap_ms=5))
    save('s7_shutter', mix(noise(70, decay=0.012, seed=7), tone(2400, 20, 0.004)))
    save('s8_rec_start', tone(380, 150, decay=0.06, f_end=760))
    save('s8_rec_stop', tone(760, 150, decay=0.06, f_end=380))
    sparkle = mix(cat(marimba('C6', 200), marimba('E6', 200), marimba('G6', 300)),
                  [0.0] * int(RATE * 0.3) + [s * 0.3 for s in noise(400, decay=0.12, seed=9)])
    save('s9_trophy_sparkle', sparkle)
    save('s9_short', cat(marimba('E6', 150), marimba('G6', 220)))
    save('s10_air', noise(120, decay=0.05, seed=3))


if __name__ == '__main__':
    main()
