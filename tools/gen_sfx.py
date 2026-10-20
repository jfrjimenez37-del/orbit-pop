#!/usr/bin/env python3
"""Synthesizes ORBIT POP's original retro sound effects and music loop (WAV, mono 16-bit)."""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def write(name, samples, vol=0.6):
    peak = max(1e-6, max(abs(s) for s in samples))
    k = vol / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))

def sq(ph, duty=0.5):
    return 1.0 if (ph % 1.0) < duty else -1.0

def tri(ph):
    p = ph % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p

def tone(f0, f1, dur, wave_fn, env_pow=1.0, attack=0.004):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        ph += f / SR
        env = min(1.0, i / (SR * attack + 1)) * (1 - t) ** env_pow
        out.append(wave_fn(ph) * env)
    return out

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]

def cat(*parts):
    r = []
    for p in parts:
        r += p
    return r

def noise(dur, env_pow=2.0, lp=0.3):
    n = int(SR * dur); out = []; y = 0.0
    for i in range(n):
        t = i / n
        y += (random.uniform(-1, 1) - y) * (lp * (1 - t) + 0.02)
        out.append(y * (1 - t) ** env_pow)
    return out

write("flip", tone(520, 980, 0.07, lambda p: sq(p, 0.25), 1.5), 0.45)
write("score", cat(tone(988, 988, 0.05, lambda p: sq(p, 0.25), 0.3), tone(1319, 1319, 0.11, lambda p: sq(p, 0.25), 1.2)), 0.35)
write("close", mix(tone(1200, 2600, 0.16, tri, 1.2), [s * 0.25 for s in noise(0.12, 1.5, 0.6)]), 0.5)
write("pop", mix(tone(380, 1500, 0.06, lambda p: math.sin(2 * math.pi * p), 1.0), tone(1800, 2400, 0.03, lambda p: sq(p, 0.5), 2.0)), 0.55)
write("hit", mix(noise(0.35, 1.6, 0.5), tone(320, 50, 0.35, lambda p: sq(p, 0.5), 1.4)), 0.7)
arp = [523, 659, 784, 1047, 1319]
write("record", cat(*[tone(f, f, 0.07, lambda p: sq(p, 0.25), 0.4) for f in arp[:4]], tone(1047, 1047, 0.32, lambda p: 0.6 * sq(p, 0.5) + 0.4 * tri(p * 2), 1.0)), 0.4)
write("unlock", cat(*[tone(f * 1.5, f * 1.5, 0.06, tri, 0.3) for f in arp], tone(1568, 1568, 0.25, tri, 1.0)), 0.45)
write("select", tone(880, 1175, 0.045, tri, 1.0), 0.45)
write("deny", cat(tone(220, 200, 0.06, lambda p: sq(p, 0.5), 0.5), tone(180, 160, 0.09, lambda p: sq(p, 0.5), 1.0)), 0.35)
write("tick", tone(660, 660, 0.06, lambda p: sq(p, 0.5), 1.2), 0.35)
write("go", tone(990, 1320, 0.12, lambda p: sq(p, 0.25), 1.0), 0.4)
write("warn", tone(1500, 1300, 0.035, tri, 1.0), 0.18)

# ---- cheerful chiptune loop: C - G - Am - F, 128 bpm, 8 bars
BPM = 128
beat = 60 / BPM
step = beat / 4
chords = [[48, 52, 55], [43, 47, 50], [45, 48, 52], [41, 45, 48]]
melody = [
    76, -1, 79, -1, 76, 74, 72, -1, 74, -1, 76, -1, 72, -1, -1, -1,
    74, -1, 79, -1, 74, 72, 71, -1, 72, -1, 74, -1, 67, -1, -1, -1,
    72, -1, 76, -1, 72, 71, 69, -1, 71, -1, 72, -1, 76, -1, -1, -1,
    77, -1, 76, -1, 74, -1, 72, -1, 74, -1, 72, -1, 69, -1, 71, -1,
]
def midi(m):
    return 440 * 2 ** ((m - 69) / 12)
bars = 8
n = int(SR * step * 16 * bars)
buf = [0.0] * n
def add(start, dur, f, fn, vol, decay=2.0):
    s0 = int(start * SR); ln = int(dur * SR); ph = 0.0
    for i in range(ln):
        if s0 + i >= n:
            break
        ph += f / SR
        t = i / ln
        buf[s0 + i] += fn(ph) * vol * min(1, i / 60) * (1 - t) ** decay
for bar in range(bars):
    ch = chords[bar % 4]
    for s in range(16):
        t0 = (bar * 16 + s) * step
        if s % 4 == 0:
            add(t0, step * 3.5, midi(ch[0] - 12), tri, 0.55, 0.6)
        if s % 4 == 2:
            add(t0, step * 1.5, midi(ch[0]), tri, 0.35, 1.0)
        add(t0, step * 0.9, midi(ch[s % 3] + 12), lambda p: sq(p, 0.125), 0.07, 1.5)
        m = melody[(bar % 4) * 16 + s] if bar >= 4 else (melody[(bar % 4) * 16 + s] if s % 4 == 0 else -1)
        if m > 0:
            add(t0, step * 2.6, midi(m), lambda p: sq(p, 0.25), 0.16, 1.2)
        if s % 4 == 0 or s == 10:
            nz = noise(0.05, 3.0, 0.9)
            for i, v in enumerate(nz):
                j = int(t0 * SR) + i
                if j < n:
                    buf[j] += v * (0.25 if s % 8 == 4 else 0.12)
write("music", buf, 0.5)
# in-run coin pickup: bright two-note "ding" (added last so earlier sounds stay identical)
write("coin", cat(tone(1568, 1568, 0.04, lambda p: sq(p, 0.25), 0.4), tone(2093, 2093, 0.12, lambda p: sq(p, 0.25), 1.3)), 0.32)
print("sfx ok")
