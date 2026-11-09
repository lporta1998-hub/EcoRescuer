"""Original background music for EcoRescuer, composed and synthesized here.

    python3 music.py OUT_DIR [track ...]

Writes 24 kHz mono WAV files with a loop point (smpl chunk), so Godot loops
them seamlessly (they go to Audio/Music_Levels/Eco/):

  menu        "Verde speranza"          C major, 96 bpm     main menu
  forest      "Sentiero verde"          G major, 116 bpm    Forest
  snow        "Cristalli spenti"        A major, 84 bpm     Snow Path
  city        "La citta' comprata"      F major swing, 108  City
  lake        "Il lago dimenticato"     D major bossa, 100  Beach
  ruins       "Pietre antiche"          D dorian, 92 bpm    Ruins
  factory     "Ciminiere"               E minor, 126 bpm    Factory
  harbor      "Il porto nero"           A minor shanty, 104 Harbor
  datacenter  "Il cervello"             F# minor, 132 bpm   AI DataCenter
  fortress    "La fortezza del Barone"  G minor march, 112  Fortress
  boss        "Il Barone"               C minor, 140 bpm    the Baron's fight
  victory     level complete jingle (no loop)
  gameover    game over jingle (no loop)

Everything (melodies, chords, instruments) is written in this file: pure
Python, no packages, same result every run.

Melodies are written one bar per string, eight 8th-notes per bar:
a note name starts a note, "-" holds it, "." is a rest.
"""
import math
import os
import random
import struct
import sys

SR = 24000
TAU = 2 * math.pi
random.seed(5)

# ---------------------------------------------------------------- notes

PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'C#5' -> 73."""
    pc = PC[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        pc += 1 if name[i] == "#" else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + pc


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def chord(name, octave=3):
    """'Am' -> [57, 60, 64] (root in `octave`). Also 'G/B', 'Bdim', 'D7', 'Csus4'."""
    bass = None
    if "/" in name:
        name, bass = name.split("/")
    r = 1
    while r < len(name) and name[r] in "#b":
        r += 1
    root = midi(name[:r] + str(octave))
    q = name[r:]
    if q == "m":
        iv = [0, 3, 7]
    elif q == "dim":
        iv = [0, 3, 6]
    elif q == "7":
        iv = [0, 4, 7, 10]
    elif q == "maj7":
        iv = [0, 4, 7, 11]
    elif q == "m7":
        iv = [0, 3, 7, 10]
    elif q == "sus4":
        iv = [0, 5, 7]
    else:
        iv = [0, 4, 7]
    notes = [root + i for i in iv]
    if bass:
        b = midi(bass + str(octave))
        if b > root:
            b -= 12
        notes = [b] + notes
    return notes


def parse_bar(bar):
    """'E5 - G5 .' -> [(step, midi, length_in_steps)]"""
    toks = bar.split()
    out = []
    cur = None
    for i, t in enumerate(toks):
        if t == "-":
            if cur:
                cur[2] += 1
        elif t == ".":
            cur = None
        else:
            cur = [i, midi(t), 1]
            out.append(cur)
    return [tuple(c) for c in out]


# ---------------------------------------------------------------- instruments

def env(n, held, a, d, s, r):
    """ADSR envelope as a list of n samples; note held for `held` samples."""
    A = max(1, int(a * SR))
    D = max(1, int(d * SR))
    R = max(1, n - held)
    out = [0.0] * n
    rel_from = 0.0
    for i in range(n):
        if i < held:
            if i < A:
                e = i / A
            elif i < A + D:
                e = 1.0 - (1.0 - s) * (i - A) / D
            else:
                e = s
            rel_from = e
        else:
            e = rel_from * (1.0 - (i - held) / R)
        out[i] = e
    return out


def lp_alpha(cut):
    return 1.0 - math.exp(-TAU * cut / SR)


_cache = {}


def render(inst, m, dur):
    key = (inst, m, round(dur, 3))
    if key not in _cache:
        _cache[key] = INSTRUMENTS[inst](hz(m), dur)
    return _cache[key]


def pulse(f, dur, duty=0.25, rel=0.07, a=0.008, d=0.12, s=0.7, cut=4200.0, vib=0.006):
    held = int(dur * SR)
    n = held + int(rel * SR)
    e = env(n, held, a, d, s, rel)
    out = [0.0] * n
    ph = 0.0
    y = 0.0
    al = lp_alpha(cut)
    for i in range(n):
        t = i / SR
        v = vib * math.sin(TAU * 5.5 * t) * min(1.0, max(0.0, (t - 0.18) / 0.25))
        ph += f * (1 + v) / SR
        x = 1.0 if (ph % 1.0) < duty else -1.0
        y += al * (x - y)
        out[i] = y * e[i]
    return out


def lead(f, dur):
    return pulse(f, dur, 0.25)


def chip(f, dur):  # rounder, softer square for happy tunes
    return pulse(f, dur, 0.5, cut=2600.0, s=0.6)


def flute(f, dur):
    rel = 0.12
    held = int(dur * SR)
    n = held + int(rel * SR)
    e = env(n, held, 0.05, 0.1, 0.8, rel)
    out = [0.0] * n
    ph = 0.0
    br = 0.0
    al = lp_alpha(1800)
    for i in range(n):
        t = i / SR
        v = 0.005 * math.sin(TAU * 5.0 * t) * min(1.0, t / 0.3)
        ph += f * (1 + v) / SR
        br += al * (random.uniform(-1, 1) - br)
        x = math.sin(TAU * ph) + 0.18 * math.sin(2 * TAU * ph) + 0.06 * math.sin(3 * TAU * ph)
        out[i] = (x + br * 0.25) * e[i]
    return out


def bell(f, dur):  # marimba-ish mallet
    n = int(max(dur, 0.6) * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        out[i] = (math.sin(TAU * f * t) * math.exp(-t * 5.0)
                  + 0.35 * math.sin(TAU * f * 3.98 * t) * math.exp(-t * 18.0)
                  + 0.15 * math.sin(TAU * f * 9.2 * t) * math.exp(-t * 40.0)) * min(1.0, i / 30)
    return out


def pluck(f, dur):  # short square pluck for arpeggios
    n = int(min(dur + 0.08, 0.5) * SR)
    out = [0.0] * n
    ph = 0.0
    y = 0.0
    for i in range(n):
        t = i / SR
        ph += f / SR
        x = 1.0 if (ph % 1.0) < 0.125 else -1.0
        cut = 600 + 4000 * math.exp(-t * 18)
        y += (1 - math.exp(-TAU * cut / SR)) * (x - y)
        out[i] = y * math.exp(-t * 9.0) * min(1.0, i / 20)
    return out


def bass_tri(f, dur):
    rel = 0.05
    held = int(dur * SR)
    n = held + int(rel * SR)
    e = env(n, held, 0.005, 0.2, 0.75, rel)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        ph += f / SR
        x = ph % 1.0
        out[i] = (4 * abs(x - 0.5) - 1) * e[i]
    return out


def bass_saw(f, dur):
    rel = 0.04
    held = int(dur * SR)
    n = held + int(rel * SR)
    e = env(n, held, 0.004, 0.15, 0.6, rel)
    out = [0.0] * n
    ph = 0.0
    y = 0.0
    y2 = 0.0
    for i in range(n):
        t = i / SR
        ph += f / SR
        x = 2 * (ph % 1.0) - 1
        cut = 280 + 1400 * math.exp(-t * 14)
        a = 1 - math.exp(-TAU * cut / SR)
        y += a * (x - y)
        y2 += a * (y - y2)
        out[i] = (y2 * 1.6 + 0.5 * math.sin(TAU * f * t)) * e[i]
    return out


def pad(f, dur):
    rel = 0.6
    held = int(dur * SR)
    n = held + int(rel * SR)
    e = env(n, held, 0.35, 0.3, 0.85, rel)
    out = [0.0] * n
    p1 = random.random()
    p2 = random.random()
    y = 0.0
    al = lp_alpha(1100)
    for i in range(n):
        p1 += f * 1.004 / SR
        p2 += f * 0.996 / SR
        x = (2 * (p1 % 1.0) - 1) + (2 * (p2 % 1.0) - 1)
        y += al * (x - y)
        out[i] = y * 0.5 * e[i]
    return out


def stab(f, dur):  # short dark chord hit for the boss
    n = int(min(dur, 0.35) * SR) + int(0.05 * SR)
    out = [0.0] * n
    p1 = p2 = 0.0
    y = 0.0
    for i in range(n):
        t = i / SR
        p1 += f * 1.006 / SR
        p2 += f * 0.994 / SR
        x = (2 * (p1 % 1.0) - 1) + (2 * (p2 % 1.0) - 1)
        cut = 500 + 2500 * math.exp(-t * 10)
        y += (1 - math.exp(-TAU * cut / SR)) * (x - y)
        out[i] = y * 0.5 * math.exp(-t * 6) * min(1.0, i / 40)
    return out


def steel(f, dur):  # steel pan
    n = int(max(dur, 0.5) * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += f * (1 + 0.012 * math.exp(-t * 40)) / SR
        out[i] = (math.sin(TAU * ph) + 0.45 * math.sin(2 * TAU * ph) * math.exp(-t * 3)
                  + 0.2 * math.sin(3.01 * TAU * ph) * math.exp(-t * 6)) * math.exp(-t * 3.2) * min(1.0, i / 15)
    return out


def accordion(f, dur):
    rel = 0.08
    held = int(dur * SR)
    n = held + int(rel * SR)
    e = env(n, held, 0.03, 0.1, 0.85, rel)
    out = [0.0] * n
    p1 = p2 = 0.0
    y = 0.0
    al = lp_alpha(2400)
    for i in range(n):
        t = i / SR
        p1 += f * 1.003 / SR
        p2 += f * 0.997 / SR
        x = (1.0 if (p1 % 1.0) < 0.3 else -1.0) + (1.0 if (p2 % 1.0) < 0.3 else -1.0)
        y += al * (x - y)
        out[i] = y * 0.5 * e[i] * (0.85 + 0.15 * math.sin(TAU * 6.0 * t))
    return out


def brass(f, dur):
    rel = 0.1
    held = int(dur * SR)
    n = held + int(rel * SR)
    e = env(n, held, 0.04, 0.2, 0.8, rel)
    out = [0.0] * n
    ph = 0.0
    y = y2 = 0.0
    for i in range(n):
        t = i / SR
        v = 0.006 * math.sin(TAU * 5.0 * t) * min(1.0, max(0.0, (t - 0.2) / 0.2))
        ph += f * (1 + v) / SR
        x = 2 * (ph % 1.0) - 1
        cut = 900 + 2200 * min(1.0, t / 0.06) * math.exp(-max(0.0, t - 0.06) * 6) + 400
        a = 1 - math.exp(-TAU * cut / SR)
        y += a * (x - y)
        y2 += a * (y - y2)
        out[i] = y2 * e[i]
    return out


def waves(sec):
    """Slow sea swell: filtered noise breathing every ~5 s."""
    n = int(sec * SR)
    out = [0.0] * n
    y = y2 = 0.0
    for i in range(n):
        t = i / SR
        sw = 0.5 + 0.5 * math.sin(TAU * t / 5.3) * math.sin(TAU * t / 11.7 + 1.0)
        cut = 300 + 900 * sw
        a = 1 - math.exp(-TAU * cut / SR)
        y += a * (random.uniform(-1, 1) - y)
        y2 += a * (y - y2)
        out[i] = y2 * (0.3 + 0.7 * sw)
    return out


def wind(sec):
    n = int(sec * SR)
    out = [0.0] * n
    y = lo = 0.0
    for i in range(n):
        t = i / SR
        g = 0.5 + 0.5 * math.sin(TAU * t / 7.1) * math.sin(TAU * t / 3.3 + 2.0)
        cut = 700 + 1500 * g
        y += (1 - math.exp(-TAU * cut / SR)) * (random.uniform(-1, 1) - y)
        lo += lp_alpha(250) * (y - lo)
        out[i] = (y - lo) * (0.2 + 0.8 * g)
    return out


INSTRUMENTS = {"steel": steel, "accordion": accordion, "brass": brass, "lead": lead, "chip": chip, "flute": flute, "bell": bell, "pluck": pluck,
               "bass_tri": bass_tri, "bass_saw": bass_saw, "pad": pad, "stab": stab}


# drums (each rendered once)
def _noise(n):
    return [random.uniform(-1, 1) for _ in range(n)]


def kick():
    n = int(0.3 * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 45 + 110 * math.exp(-t * 30)
        ph += f / SR
        out[i] = math.sin(TAU * ph) * math.exp(-t * 9) * min(1.0, i / 10)
    return out


def snare():
    n = int(0.22 * SR)
    nz = _noise(n)
    out = [0.0] * n
    y = 0.0
    lo = 0.0
    for i in range(n):
        t = i / SR
        y += lp_alpha(5000) * (nz[i] - y)
        lo += lp_alpha(700) * (y - lo)
        out[i] = (y - lo) * math.exp(-t * 16) * 0.9 + 0.5 * math.sin(TAU * 185 * t) * math.exp(-t * 25)
    return out


def hat(open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    nz = _noise(n)
    out = [0.0] * n
    lo = 0.0
    for i in range(n):
        t = i / SR
        lo += lp_alpha(6000) * (nz[i] - lo)
        out[i] = (nz[i] - lo) * math.exp(-t * (10 if open_ else 60))
    return out


def shaker():
    n = int(0.09 * SR)
    nz = _noise(n)
    out = [0.0] * n
    lo = 0.0
    y = 0.0
    for i in range(n):
        t = i / SR
        y += lp_alpha(7000) * (nz[i] - y)
        lo += lp_alpha(2500) * (y - lo)
        out[i] = (y - lo) * math.sin(math.pi * min(1.0, t / 0.09)) ** 2
    return out


def tom(f):
    n = int(0.35 * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += f * (1 + 0.5 * math.exp(-t * 20)) / SR
        out[i] = math.sin(TAU * ph) * math.exp(-t * 8) * min(1.0, i / 10)
    return out


def clank():  # metallic hit (industrial)
    n = int(0.3 * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        out[i] = (math.sin(TAU * 523 * t + 2.5 * math.sin(TAU * 1307 * t) * math.exp(-t * 12))
                  * math.exp(-t * 14) * 0.7 + 0.3 * math.sin(TAU * 1740 * t) * math.exp(-t * 30))
    return out


DRUMS = {}


def drum(ch):
    if not DRUMS:
        DRUMS.update({"k": kick(), "s": snare(), "h": hat(), "o": hat(True), "x": shaker(),
                      "t": tom(110), "T": tom(170), "c": clank()})
    return DRUMS[ch]


# ---------------------------------------------------------------- song

class Song:
    def __init__(self, bpm, bars, loop=True):
        self.beat = 60.0 / bpm
        self.bar = self.beat * 4
        self.loop = loop
        self.n = int(round(bars * self.bar * SR))
        tail = int(4 * SR)
        self.dry = [0.0] * (self.n + tail)
        self.wet = [0.0] * (self.n + tail)

    def add(self, samples, t, gain, echo=0.0):
        s = int(t * SR)
        dry, wet = self.dry, self.wet
        L = len(dry)
        g2 = gain * echo
        for i, v in enumerate(samples):
            j = s + i
            if j >= L:
                break
            dry[j] += v * gain
            if echo:
                wet[j] += v * g2

    def note(self, inst, t, m, dur, gain, echo=0.0):
        self.add(render(inst, m, dur), t, gain, echo)

    def melody(self, inst, bar0, bars, gain, echo=0.25, transpose=0, swing=0.0):
        step = self.beat / 2
        for b, line in enumerate(bars):
            for st, m, ln in parse_bar(line):
                sw = swing * step if st % 2 == 1 else 0.0
                self.note(inst, (bar0 + b) * self.bar + st * step + sw, m + transpose, ln * step * 0.95, gain, echo)

    def bed(self, maker, gain):
        """Ambience under the whole loop (waves, wind...), crossfaded at the loop point."""
        xf = int(2 * SR)
        src = maker((self.n + xf) / SR + 0.1)
        out = src[:self.n]
        for i in range(xf):
            k = i / xf
            out[i] = src[i] * k + src[self.n + i] * (1 - k)
        for i, v in enumerate(out):
            self.dry[i] += v * gain

    def drums(self, bar0, nbars, pattern, gains, swing=0.0):
        """pattern: {char: 16-step string}, e.g. {'k': 'k...k...'}."""
        step = self.beat / 4
        for b in range(nbars):
            for ch, line in pattern.items():
                for i, c in enumerate(line):
                    if c != ".":
                        sw = swing * step if i % 2 == 1 else 0.0
                        self.add(drum(c), (bar0 + b) * self.bar + i * step + sw, gains.get(c, 0.3))

    def chords(self, inst, bar0, prog, gain, octave=4, beats=4):
        for b, name in enumerate(prog):
            for m in chord(name, octave):
                self.note(inst, (bar0 + b) * self.bar, m, self.beat * beats * 0.98, gain)

    def bass(self, inst, bar0, prog, pattern, gain, octave=2, steps=8):
        """pattern: one entry per step: None = rest, or semitones above the root (12 = octave)."""
        step = self.bar / steps
        for b, name in enumerate(prog):
            root = chord(name.split("/")[-1] if "/" in name else name, octave)[0]
            if "/" in name:
                root = midi(name.split("/")[1] + str(octave))
            for i, p in enumerate(pattern):
                if p is None:
                    continue
                ln = 1
                while i + ln < len(pattern) and pattern[i + ln] == "-":
                    ln += 1
                if p == "-":
                    continue
                self.note(inst, (bar0 + b) * self.bar + i * step, root + p, step * ln * 0.9, gain)

    def arp(self, inst, bar0, prog, order, gain, octave=4, steps=8, echo=0.3):
        """order: indexes into the chord tones (+3 = next octave), one per step."""
        step = self.bar / steps
        for b, name in enumerate(prog):
            tones = chord(name, octave)
            if len(tones) > 3 and "/" in name:
                tones = tones[1:]
            for i, k in enumerate(order):
                if k is None:
                    continue
                m = tones[k % len(tones)] + 12 * (k // len(tones))
                self.note(inst, (bar0 + b) * self.bar + i * step, m, step, gain, echo)

    def finish(self, delay_beats=0.75, feedback=0.35):
        d = int(self.beat * delay_beats * SR)
        wet = self.wet
        y = 0.0
        al = lp_alpha(2500)
        out = [0.0] * len(wet)
        for i in range(len(wet)):
            fb = out[i - d] if i >= d else 0.0
            y += al * (fb - y)
            out[i] = wet[i] + feedback * y
        mix = [a + b * 0.8 for a, b in zip(self.dry, out)]
        if self.loop:
            # wrap the tail (echoes, releases) onto the start: seamless loop
            for i in range(len(mix) - self.n):
                mix[i] += mix[self.n + i]
            mix = mix[:self.n]
        else:
            end = len(mix)
            quiet = 0.003 * max(abs(v) for v in mix)
            while end > 0 and abs(mix[end - 1]) < quiet:
                end -= 1
            mix = mix[:end + int(0.05 * SR)]
        peak = max(1e-9, max(abs(v) for v in mix))
        k = 1.4 / peak
        out = [math.tanh(v * k) / math.tanh(1.4) * 0.88 for v in mix]
        if not self.loop:
            f = int(0.01 * SR)
            for i in range(f):
                out[-1 - i] *= i / f
        return out


# ---------------------------------------------------------------- tracks

def menu():
    s = Song(96, 28)
    intro = ["C", "G/B", "Am", "F"]
    A = ["C", "G/B", "Am", "F", "C", "G", "F", "G"]
    B = ["Am", "F", "C", "G", "Am", "F", "Dm", "G"]
    melA = ["E5 - - D5 C5 - D5 E5", "D5 - - - G4 - - -", "C5 - - B4 A4 - B4 C5", "A4 - - - - - . .",
            "E5 - - D5 C5 - E5 G5", "A5 - G5 - D5 - - -", "C5 - D5 - E5 - F5 -", "D5 - - - - - . ."]
    melB = ["A5 - - G5 E5 - - -", "F5 - E5 - C5 - - -", "G5 - - E5 C5 - E5 -", "D5 - - - B4 - D5 -",
            "A5 - - B5 C6 - B5 A5", "A5 - G5 - F5 - E5 -", "F5 - E5 - D5 - C5 -", "D5 - - - G5 - - -"]
    prog = intro + A + B + A
    s.chords("pad", 0, prog, 0.10)
    s.bass("bass_tri", 0, prog, [0, "-", "-", "-", 7, "-", 12, "-"], 0.30)
    s.arp("bell", 0, prog, [0, 1, 2, 3, 2, 1, 2, 4], 0.10, octave=4, echo=0.35)
    s.melody("flute", 4, melA, 0.26, 0.3)
    s.melody("flute", 12, melB, 0.26, 0.3)
    s.melody("flute", 20, melA, 0.26, 0.3)
    s.melody("bell", 20, melA, 0.08, 0.2, transpose=12)
    soft = {"k": "k.......k.......", "x": "x.x.x.x.x.x.x.x."}
    s.drums(4, 8, soft, {"k": 0.35, "x": 0.07})
    s.drums(12, 16, {"k": "k.......k.....k.", "s": "....s.......s...", "x": "x.x.x.x.x.x.x.x."},
            {"k": 0.38, "s": 0.12, "x": 0.07})
    return s.finish()


def forest():
    s = Song(116, 28)
    intro = ["G", "Em", "C", "D"]
    A = ["G", "Em", "C", "D", "G", "Em", "C", "D"]
    B = ["C", "D", "Bm", "Em", "C", "D", "G", "D"]
    melA = ["B4 - D5 - G5 - F#5 G5", "E5 - - - B4 - - -", "C5 - E5 - G5 - E5 C5", "D5 - - - A4 - - -",
            "B4 - D5 - G5 - A5 B5", "G5 - - E5 - - B4 -", "C5 - E5 G5 A5 - G5 E5", "F#5 - - - D5 - . ."]
    melB = ["E5 - G5 - C6 - B5 A5", "F#5 - - - D5 - - -", "D5 - F#5 - B5 - A5 F#5", "G5 - - - E5 - - -",
            "E5 - - G5 - - C6 -", "A5 - - F#5 - - D5 -", "G5 - D5 - B4 - D5 -", "F#5 - A5 - D6 - - -"]
    prog = intro + A + B + A
    s.chords("pad", 4, A + B + A, 0.06)
    s.bass("bass_tri", 0, prog, [0, None, 12, None, 7, None, 12, None], 0.32)
    s.arp("pluck", 0, prog, [0, 1, 2, 1, 3, 2, 1, 2], 0.11, echo=0.3)
    s.melody("chip", 4, melA, 0.17, 0.3)
    s.melody("chip", 12, melB, 0.17, 0.3)
    s.melody("chip", 20, melA, 0.17, 0.3)
    s.melody("bell", 20, melA, 0.10, 0.2, transpose=12)
    s.drums(0, 4, {"k": "k.......k.......", "h": "..h...h...h...h."}, {"k": 0.4, "h": 0.06})
    s.drums(4, 24, {"k": "k.......k.k.....", "s": "....s.......s...", "h": "h.h.h.h.h.h.h.hh"},
            {"k": 0.42, "s": 0.18, "h": 0.06}, swing=0.12)
    return s.finish()


def ruins():
    s = Song(92, 28)
    intro = ["Dm", "C", "Bb", "C"]
    A = ["Dm", "C", "Bb", "C", "Dm", "F", "G", "A"]
    B = ["Bb", "C", "Dm", "Dm", "Bb", "C", "A", "A"]
    melA = ["D5 - - - A4 - - -", "G4 - - - E4 - G4 -", "F4 - - - D4 - F4 -", "E4 - - - - - - -",
            "A4 - - - D5 - - -", "C5 - - - A4 - F4 -", "B4 - - - G4 - D5 -", "C#5 - - - E5 - - -"]
    melB = ["F5 - - - D5 - - -", "E5 - - - G5 - - -", "A5 - - - - - F5 -", "E5 - D5 - - - - -",
            "D5 - - - F5 - - -", "G5 - - - E5 - C5 -", "E5 - - - C#5 - - -", "A4 - - - - - . ."]
    prog = intro + A + B + A
    s.chords("pad", 0, prog, 0.10, octave=3)
    s.bass("bass_tri", 0, prog, [0, "-", "-", "-", "-", "-", 7, "-"], 0.30)
    s.arp("bell", 0, prog, [0, None, 2, 4, None, 3, 1, None], 0.11, octave=4, echo=0.45)
    s.melody("flute", 4, melA, 0.24, 0.4)
    s.melody("flute", 12, melB, 0.24, 0.4)
    s.melody("flute", 20, melA, 0.24, 0.4, transpose=12)
    hand = {"t": "t.....t...t.....", "T": "......T.......T.", "x": "..x...x...x...x."}
    s.drums(4, 24, hand, {"t": 0.28, "T": 0.14, "x": 0.06})
    return s.finish(delay_beats=1.0, feedback=0.45)


def factory():
    s = Song(126, 28)
    intro = ["Em", "Em", "C", "D"]
    A = ["Em", "Em", "C", "D", "Em", "Em", "C", "D"]
    B = ["Am", "C", "Em", "D", "Am", "C", "B", "B"]
    melA = ["E5 - - - B4 - E5 -", "G5 - F#5 - E5 - D5 -", "E5 - - - C5 - - -", "D5 - - - F#5 - A5 -",
            "B5 - - - G5 - E5 -", "G5 - A5 - B5 - - -", "C6 - B5 - A5 - G5 -", "F#5 - - - D5 - - -"]
    melB = ["A5 - - - E5 - A5 -", "G5 - - - E5 - C5 -", "B5 - - - G5 - E5 -", "F#5 - A5 - D6 - - -",
            "C6 - - - A5 - E5 -", "G5 - E5 - G5 - C6 -", "B5 - - - D#5 - F#5 -", "B5 - - - . . . ."]
    prog = intro + A + B + A
    s.bass("bass_saw", 0, prog, [0, 0, 12, 0, 0, 12, 0, 10], 0.30)
    s.arp("pluck", 4, A + B + A, [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1, 2, 3], 0.07, steps=16, echo=0.2)
    s.chords("pad", 12, B, 0.07, octave=3)
    s.melody("lead", 4, melA, 0.15, 0.25)
    s.melody("lead", 12, melB, 0.15, 0.25)
    s.melody("lead", 20, melA, 0.15, 0.25)
    s.drums(0, 4, {"k": "k...k...k...k...", "c": "............c..."}, {"k": 0.45, "c": 0.12})
    s.drums(4, 24, {"k": "k...k...k...k...", "s": "....s.......s...", "h": "..h...h...h...h.",
                    "o": "..............o.", "c": "...........c...."},
            {"k": 0.45, "s": 0.2, "h": 0.07, "o": 0.05, "c": 0.1})
    return s.finish(delay_beats=0.75, feedback=0.3)


def snow():
    """Snow Path, "Cristalli spenti": A major, 84 bpm, bells and wind."""
    s = Song(84, 20)
    intro = ["A", "E/G#", "F#m", "D"]
    A = ["A", "E/G#", "F#m", "D", "A", "E", "D", "E"]
    B = ["F#m", "D", "A", "E", "F#m", "D", "Bm", "E"]
    melA = ["C#5 - - - E5 - C#5 -", "B4 - - - G#4 - - -", "A4 - - - C#5 - F#5 -", "E5 - - - D5 - - -",
            "C#5 - - - E5 - A5 -", "G#5 - - - E5 - B4 -", "F#5 - E5 - D5 - C#5 -", "B4 - - - - - . ."]
    melB = ["A5 - - - F#5 - C#5 -", "D5 - - - F#5 - A5 -", "E5 - - - C#5 - A4 -", "B4 - - - E5 - G#5 -",
            "A5 - - - C#6 - A5 -", "F#5 - - - A5 - F#5 -", "D5 - - - F#5 - B5 -", "G#5 - - - E5 - - -"]
    prog = intro + A + B
    s.bed(wind, 0.10)
    s.chords("pad", 0, prog, 0.09)
    s.bass("bass_tri", 0, prog, [0, "-", "-", "-", 7, "-", "-", "-"], 0.26)
    s.arp("bell", 0, prog, [0, 2, 4, 2, 3, 2, 4, 5], 0.08, octave=5, echo=0.45)
    s.melody("flute", 4, melA, 0.24, 0.35)
    s.melody("flute", 12, melB, 0.22, 0.35)
    s.melody("bell", 12, melB, 0.07, 0.3, transpose=12)
    s.drums(4, 8, {"x": "x...x...x...x..."}, {"x": 0.06})
    s.drums(12, 8, {"k": "k.......k.......", "x": "x.x.x.x.x.x.x.x."}, {"k": 0.3, "x": 0.06})
    return s.finish(delay_beats=1.0, feedback=0.45)


def city():
    """City, "La citta' comprata": swingy F major, 108 bpm, walking bass."""
    s = Song(108, 28)
    intro = ["F", "Dm", "Gm", "C7"]
    A = ["F", "Dm", "Gm", "C7", "F", "Dm", "Gm", "C7"]
    B = ["Bb", "Bb", "F", "F", "Gm", "C7", "F", "C7"]
    melA = ["F5 . A5 C6 - A5 F5 .", "D5 - - F5 - - A5 -", "Bb5 - A5 - G5 - F5 -", "E5 - - - G5 - - -",
            "F5 . A5 C6 - A5 F5 .", "D6 - C6 - A5 - F5 -", "G5 - Bb5 - D6 - C6 Bb5", "C6 - - - - - . ."]
    melB = ["D6 - - Bb5 - - F5 -", "G5 - A5 - Bb5 - D6 -", "C6 - - A5 - - F5 -", "A5 - G5 - F5 - - -",
            "Bb5 - - G5 - - D5 -", "E5 - G5 - Bb5 - C6 -", "A5 - - - F5 - C5 -", "E5 - G5 - C6 - - -"]
    prog = intro + A + B + A
    sw = 0.3
    s.bass("bass_tri", 0, prog, [0, "-", 7, "-", 12, "-", 7, "-"], 0.32)
    s.arp("pluck", 0, prog, [None, 0, None, 1, None, 2, None, 1], 0.10, echo=0.15)
    s.chords("pad", 12, B, 0.06)
    s.melody("chip", 4, melA, 0.16, 0.2, swing=sw)
    s.melody("chip", 12, melB, 0.16, 0.2, swing=sw)
    s.melody("chip", 20, melA, 0.16, 0.2, swing=sw)
    s.melody("bell", 20, melA, 0.07, 0.15, transpose=-12, swing=sw)
    s.drums(0, 4, {"k": "k.......k.......", "h": "h.h.h.h.h.h.h.h."}, {"k": 0.4, "h": 0.05}, swing=sw)
    s.drums(4, 24, {"k": "k.......k.....k.", "s": "....s.......s...", "h": "h.h.h.h.h.h.h.h.", "o": "..............o."},
            {"k": 0.42, "s": 0.2, "h": 0.06, "o": 0.04}, swing=sw)
    return s.finish(delay_beats=0.75, feedback=0.25)


def lake():
    """Beach, "Il lago dimenticato": D major bossa, 100 bpm, steel pan and waves."""
    s = Song(100, 28)
    intro = ["Dmaj7", "Bm7", "Em7", "A7"]
    A = ["Dmaj7", "Bm7", "Em7", "A7", "Dmaj7", "Bm7", "Em7", "A7"]
    B = ["Gmaj7", "F#m7", "Em7", "A7", "Gmaj7", "F#m7", "Em7", "A7"]
    melA = ["F#5 - A5 - - C#6 - A5", "B5 - - - F#5 - - -", "G5 - B5 - - D6 - B5", "C#6 - - - A5 - - -",
            "F#5 - A5 - - C#6 - E6", "D6 - - B5 - - F#5 -", "G5 - F#5 - E5 - D5 -", "E5 - - - - - . ."]
    melB = ["B5 - - D6 - - F#6 -", "E6 - - - C#6 - A5 -", "D6 - - B5 - - G5 -", "A5 - - C#6 - - E6 -",
            "F#6 - - D6 - - B5 -", "A5 - - - C#6 - - -", "B5 - - G5 - - E5 -", "G5 - - - E5 - C#5 -"]
    prog = intro + A + B + A
    s.bed(waves, 0.16)
    s.chords("pad", 0, prog, 0.07)
    s.bass("bass_tri", 0, prog, [0, "-", "-", 7, 12, "-", "-", 7], 0.30)
    s.arp("bell", 0, prog, [None, 1, 2, None, 3, None, 2, 1], 0.07, echo=0.3)
    s.melody("steel", 4, melA, 0.22, 0.3, transpose=-12)
    s.melody("steel", 12, melB, 0.22, 0.3, transpose=-12)
    s.melody("steel", 20, melA, 0.22, 0.3)
    s.drums(0, 28, {"x": "xxxxxxxxxxxxxxxx", "k": "k.......k.......", "s": "s..s..s...s..s.."},
            {"x": 0.035, "k": 0.3, "s": 0.06})
    return s.finish(delay_beats=0.75, feedback=0.3)


def harbor():
    """Harbor, "Il porto nero": a dark sea shanty, A minor, 104 bpm, accordion."""
    s = Song(104, 28)
    intro = ["Am", "Am", "E", "E"]
    A = ["Am", "Am", "G", "G", "F", "F", "E", "E"]
    B = ["Am", "Dm", "G", "C", "F", "Dm", "E", "E"]
    melA = ["A4 - - B4 C5 - - D5", "E5 - - - A4 - - -", "G4 - - A4 B4 - - C5", "D5 - - - G4 - - -",
            "F4 - - G4 A4 - - C5", "A4 - - G4 F4 - - -", "E4 - - F4 G#4 - - B4", "E5 - - - - - . ."]
    melB = ["C5 - - - E5 - - -", "F5 - - E5 D5 - - -", "B4 - - - D5 - G5 -", "E5 - - D5 C5 - - -",
            "A4 - - C5 F5 - - -", "D5 - - - F5 - A5 -", "G#5 - - - E5 - B4 -", "E5 - - - G#4 - - -"]
    prog = intro + A + B + A
    s.bed(waves, 0.12)
    s.bass("bass_tri", 0, prog, [0, None, None, None, -5, None, None, None], 0.34)
    for b, name in enumerate(prog):  # "pah" chords on 2 and 4
        for beat in (1, 3):
            for m in chord(name, 4):
                s.note("accordion", b * s.bar + beat * s.beat, m, s.beat * 0.45, 0.05)
    s.melody("accordion", 4, melA, 0.22, 0.2, swing=0.2)
    s.melody("accordion", 12, melB, 0.22, 0.2, swing=0.2)
    s.melody("accordion", 20, melA, 0.22, 0.2, transpose=12, swing=0.2)
    for b in (0, 12, 20):  # ship bell
        s.note("bell", b * s.bar, midi("A4"), 1.5, 0.12, 0.4)
        s.note("bell", b * s.bar + s.beat * 0.5, midi("A4"), 1.5, 0.08, 0.4)
    s.drums(4, 24, {"t": "t.......t.......", "s": "....s.......s...", "x": "..x...x...x...x."},
            {"t": 0.3, "s": 0.08, "x": 0.05})
    return s.finish(delay_beats=1.0, feedback=0.35)


def datacenter():
    """AI DataCenter, "Il cervello": F# minor electronica, 132 bpm."""
    s = Song(132, 28)
    intro = ["F#m", "D", "A", "E"]
    A = ["F#m", "D", "A", "E", "F#m", "D", "A", "E"]
    B = ["Bm", "D", "F#m", "C#", "Bm", "D", "E", "C#"]
    melA = ["F#5 - - - C#5 - F#5 -", "A5 - - - F#5 - - -", "E5 - - - C#5 - E5 -", "G#5 - - - B5 - - -",
            "C#6 - - - A5 - F#5 -", "A5 - B5 - A5 - F#5 -", "E5 - F#5 - E5 - C#5 -", "B4 - - - - - . ."]
    melB = ["D6 - - - B5 - F#5 -", "A5 - - - F#5 - D5 -", "C#6 - - - A5 - F#5 -", "E#5 - - - G#5 - C#6 -",
            "B5 - - - D6 - B5 -", "A5 - - - F#5 - A5 -", "G#5 - - - B5 - E6 -", "E#6 - - - C#6 - - -"]
    prog = intro + A + B + A
    s.bass("bass_saw", 0, prog, [None, 0, None, 0, None, 0, None, 12], 0.30)
    s.arp("pluck", 0, prog, [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 1, 2, 3, 2, 1], 0.08, steps=16, echo=0.3)
    s.chords("pad", 4, A + B + A, 0.06)
    s.melody("lead", 4, melA, 0.13, 0.3)
    s.melody("lead", 12, melB, 0.13, 0.3)
    s.melody("lead", 20, melA, 0.13, 0.3, transpose=12)
    s.melody("chip", 20, melA, 0.08, 0.1)
    s.drums(0, 4, {"k": "k...k...k...k...", "h": "hhhhhhhhhhhhhhhh"}, {"k": 0.42, "h": 0.03})
    s.drums(4, 24, {"k": "k...k...k...k...", "s": "....s.......s...", "h": "hhhhhhhhhhhhhhhh", "o": "..o...o...o...o."},
            {"k": 0.45, "s": 0.16, "h": 0.03, "o": 0.05})
    return s.finish(delay_beats=0.75, feedback=0.35)


def fortress():
    """Fortress, "La fortezza del Barone": G minor march, 112 bpm, brass and timpani."""
    s = Song(112, 28)
    intro = ["Gm", "Gm", "Eb", "D"]
    A = ["Gm", "Gm", "Eb", "D", "Gm", "Gm", "Eb", "D"]
    B = ["Cm", "Gm", "Eb", "D", "Cm", "Gm", "Ab", "D"]
    melA = ["G4 - - - D5 - - -", "Bb4 - A4 - G4 - D4 -", "Eb5 - - - D5 - C5 -", "D5 - - - - - . .",
            "G4 - - - D5 - G5 -", "F5 - Eb5 - D5 - Bb4 -", "C5 - D5 - Eb5 - G5 -", "F#5 - - - - - . ."]
    melB = ["G5 - - - Eb5 - C5 -", "D5 - - - Bb4 - G4 -", "G5 - - - Bb5 - G5 -", "F#5 - - - A5 - D5 -",
            "Eb5 - - - G5 - C6 -", "Bb5 - - - G5 - D5 -", "C6 - - - Ab5 - Eb5 -", "D5 - F#5 - A5 - - -"]
    prog = intro + A + B + A
    s.chords("pad", 0, prog, 0.09, octave=3)
    s.bass("bass_saw", 0, prog, [0, None, 7, None, 0, None, 7, None], 0.30)
    s.melody("brass", 4, melA, 0.20, 0.2)
    s.melody("brass", 12, melB, 0.20, 0.2)
    s.melody("brass", 20, melA, 0.20, 0.2, transpose=12)
    s.melody("brass", 20, melA, 0.10, 0.0)
    march = {"k": "k.......k.......", "t": "t.......t...t...", "s": "s.sss.s.s.sss.s."}
    s.drums(0, 4, {"t": "t...t...t...t.tt"}, {"t": 0.35})
    s.drums(4, 24, march, {"k": 0.35, "t": 0.3, "s": 0.10})
    return s.finish(delay_beats=0.5, feedback=0.25)


def boss():
    s = Song(140, 28)
    intro = ["Cm", "Ab", "Bb", "G"]
    A = ["Cm", "Ab", "Bb", "G", "Cm", "Ab", "Bb", "G"]
    B = ["Fm", "Ab", "Cm", "G", "Fm", "Ab", "Bb", "G"]
    melA = ["C5 - - G4 C5 - Eb5 -", "Eb5 - D5 - C5 - Ab4 -", "Bb4 - - F4 Bb4 - D5 -", "D5 - - - B4 - G4 -",
            "C5 - - G4 C5 - Eb5 -", "F5 - Eb5 - D5 - C5 -", "D5 - Eb5 - F5 - D5 -", "G5 - - - - - . ."]
    melB = ["Ab5 - - - G5 - F5 -", "Eb5 - - - C5 - Eb5 -", "G5 - - - Eb5 - C5 -", "B4 - D5 - G5 - F5 -",
            "Ab5 - - - C6 - Ab5 -", "G5 - - - Eb5 - C5 -", "D5 - F5 - Bb5 - Ab5 -", "G5 - - - B5 - D6 -"]
    prog = intro + A + B + A
    s.bass("bass_saw", 0, prog, [0, 0, 12, 0, 0, 12, 0, 12], 0.30)
    s.chords("stab", 0, intro, 0.12, octave=4, beats=1)
    for b, name in enumerate(prog[4:]):
        for beat in (0, 1.5, 3):
            for m in chord(name, 4):
                s.note("stab", (4 + b) * s.bar + beat * s.beat, m, s.beat * 0.4, 0.06)
    s.melody("lead", 4, melA, 0.15, 0.2)
    s.melody("lead", 12, melB, 0.15, 0.2)
    s.melody("lead", 20, melA, 0.15, 0.2, transpose=12)
    s.melody("lead", 20, melA, 0.08, 0.0)
    s.drums(0, 3, {"k": "k.......k.......", "t": "............t.t."}, {"k": 0.5, "t": 0.3})
    s.drums(3, 1, {"k": "k...............", "T": "T.T.t.t.T.T.t.t."}, {"k": 0.5, "T": 0.3, "t": 0.3})
    main = {"k": "k.....k.k.......", "s": "....s.......s...", "h": "hhhhhhhhhhhhhhhh"}
    for sec in (4, 12, 20):
        s.drums(sec, 7, main, {"k": 0.5, "s": 0.24, "h": 0.04})
        s.drums(sec + 7, 1, {"k": "k.....k.k.......", "s": "....s...ssss", "T": "............T.t."},
                {"k": 0.5, "s": 0.22, "T": 0.3, "t": 0.3})
    return s.finish(delay_beats=0.5, feedback=0.25)


def victory():
    s = Song(140, 3, loop=False)
    s.melody("lead", 0, ["C5 E5 G5 C6 - G5 C6 -", "D6 - - - E6 - - -", "C6 - - - - - - -"], 0.2, 0.25)
    s.chords("pad", 0, ["C", "G", "C"], 0.1)
    s.bass("bass_tri", 0, ["C", "G", "C"], [0, None, 12, None, 7, None, 12, None], 0.3)
    s.arp("bell", 2, ["C"], [0, 1, 2, 3, 4, 5, 6, 7], 0.1)
    s.drums(0, 2, {"k": "k...k...k...k...", "s": "....s.......s.ss"}, {"k": 0.45, "s": 0.2})
    s.drums(2, 1, {"k": "k...............", "o": "o..............."}, {"k": 0.5, "o": 0.1})
    return s.finish()


def gameover():
    s = Song(100, 3, loop=False)
    s.melody("flute", 0, ["E5 - D5 - C5 - B4 -", "A4 - - - G#4 - - -", "A4 - - - - - - -"], 0.26, 0.4)
    s.chords("pad", 0, ["Am", "E", "Am"], 0.12, octave=3)
    s.bass("bass_tri", 0, ["Am", "E", "Am"], [0, "-", "-", "-", "-", "-", "-", "-"], 0.3)
    return s.finish(delay_beats=1.0, feedback=0.4)


TRACKS = {"menu": menu, "forest": forest, "snow": snow, "city": city, "lake": lake, "ruins": ruins,
          "factory": factory, "harbor": harbor, "datacenter": datacenter, "fortress": fortress,
          "boss": boss, "victory": victory, "gameover": gameover}


def save(track, path, loop):
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in track)
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(track) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    chunks += b"data" + struct.pack("<I", len(data)) + data
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "music_out"
    names = sys.argv[2:] or list(TRACKS)
    os.makedirs(out, exist_ok=True)
    for name in names:
        _cache.clear()
        t = TRACKS[name]()
        save(t, os.path.join(out, name + ".wav"), name not in ("victory", "gameover"))
        print(name, "%.1f s" % (len(t) / SR))
