"""Original sound effects for EcoRescuer, synthesized from scratch.

    python3 sfx.py OUT_DIR

Writes 16-bit mono 44.1 kHz WAV files (they go to Audio/SFX/Eco/ in the
game). Pure Python, no extra packages. Seeded: same result every run.

  hit      leafy thwack when a hero hits a polluter
  hurt     toxic squelch when the hero is hit
  purify   smog whoosh that clears into a rising chime (polluter defeated)
  pickup   bright two-note chime (items)
  heal     soft rising arpeggio
  blast    barrel explosion with a bubbling tail
  splash   sludge splat
  lob      "blorp" of the sprayer throwing sludge
  fuse     fizzing fuse (Kamikaze)
  charge   Bruto steaming up: rumble + rising hiss
  stun     crash into a wall + dizzy "boing"
  stomp    heavy ground thud (Bruto slam, Boarman rocks)
  laser    NEXUS drone bolt
  alert    short "!" blip when a polluter spots you
"""
import math
import os
import random
import struct
import sys
import wave

SR = 44100
random.seed(11)


def n_samples(sec):
    return int(sec * SR)


def silence(sec):
    return [0.0] * n_samples(sec)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def at(track, sec):
    return silence(sec) + track


def gain(track, g):
    return [v * g for v in track]


def env_exp(track, decay, attack=0.002):
    """Fast attack, exponential decay (decay = time constant in seconds)."""
    a = max(1, n_samples(attack))
    return [v * min(1.0, i / a) * math.exp(-i / (decay * SR)) for i, v in enumerate(track)]


def env_lin(track, attack, release):
    n = len(track)
    a = max(1, n_samples(attack))
    r = max(1, n_samples(release))
    out = []
    for i, v in enumerate(track):
        g = min(1.0, i / a, (n - i) / r)
        out.append(v * g)
    return out


def osc(sec, f0, f1=None, shape="sine", curve=1.0, vib=0.0, vib_rate=0.0):
    """Oscillator sweeping from f0 to f1 (curve > 1 = sweep late)."""
    n = n_samples(sec)
    f1 = f0 if f1 is None else f1
    ph = 0.0
    out = []
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** curve)
        if vib:
            f *= 1.0 + vib * math.sin(2 * math.pi * vib_rate * i / SR)
        ph += f / SR
        x = ph % 1.0
        if shape == "sine":
            v = math.sin(2 * math.pi * x)
        elif shape == "square":
            v = 1.0 if x < 0.5 else -1.0
        elif shape == "pulse":
            v = 1.0 if x < 0.25 else -1.0
        elif shape == "tri":
            v = 4 * abs(x - 0.5) - 1
        else:  # saw
            v = 2 * x - 1
        out.append(v)
    return out


def noise(sec):
    return [random.uniform(-1, 1) for _ in range(n_samples(sec))]


def lowpass(track, cutoff0, cutoff1=None):
    """One-pole low-pass, cutoff may sweep."""
    cutoff1 = cutoff0 if cutoff1 is None else cutoff1
    n = len(track)
    y = 0.0
    out = []
    for i, v in enumerate(track):
        c = cutoff0 + (cutoff1 - cutoff0) * i / max(1, n)
        a = 1 - math.exp(-2 * math.pi * c / SR)
        y += a * (v - y)
        out.append(y)
    return out


def highpass(track, cutoff):
    lp = lowpass(track, cutoff)
    return [v - l for v, l in zip(track, lp)]


def bandpass(track, lo, hi):
    return lowpass(highpass(track, lo), hi)


def crush(track, levels=16):
    return [round(v * levels) / levels for v in track]


def normalize(track, peak=0.85):
    m = max(1e-9, max(abs(v) for v in track))
    out = [v / m * peak for v in track]
    # tiny fades so nothing clicks
    f = n_samples(0.003)
    for i in range(min(f, len(out))):
        out[i] *= i / f
        out[-1 - i] *= i / f
    return out


def save(track, path):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in track))


def note(sec, f, shape="tri", decay=0.15):
    return env_exp(osc(sec, f, shape=shape), decay, 0.003)


# ---------------------------------------------------------------- sounds

def hit():
    thump = env_exp(osc(0.12, 220, 70, "sine", 0.5), 0.04)
    snap = env_exp(bandpass(noise(0.08), 1500, 6000), 0.018)
    leaf = env_exp(bandpass(noise(0.14), 3000, 9000), 0.04)
    return normalize(mix(gain(thump, 0.9), gain(snap, 0.9), gain(at(leaf, 0.01), 0.35)))


def hurt():
    body = env_exp(osc(0.22, 180, 90, "square", 0.7, 0.04, 30), 0.07)
    body = lowpass(body, 1600)
    squish = env_exp(lowpass(noise(0.2), 2200, 500), 0.06)
    bub = env_exp(osc(0.08, 500, 900, "sine"), 0.03)
    return normalize(mix(gain(body, 0.7), gain(squish, 0.6), gain(at(bub, 0.07), 0.35)))


def purify():
    whoosh = env_lin(bandpass(noise(0.35), 300, 1400), 0.05, 0.2)
    whoosh = [v * (0.4 + 0.6 * math.sin(math.pi * i / len(whoosh))) for i, v in enumerate(whoosh)]
    notes = [659.25, 783.99, 987.77, 1318.5]  # E5 G5 B5 E6
    chime = mix(*[at(gain(note(0.5, f, "tri", 0.18), 0.6), 0.12 + k * 0.06) for k, f in enumerate(notes)])
    sparkle = mix(*[at(gain(note(0.2, f * 2, "sine", 0.05), 0.25), 0.18 + k * 0.06) for k, f in enumerate(notes)])
    return normalize(mix(gain(whoosh, 0.6), chime, sparkle))


def pickup():
    a = note(0.18, 1046.5, "square", 0.05)  # C6
    b = note(0.3, 1567.98, "square", 0.09)  # G6
    s = lowpass(mix(gain(a, 0.5), gain(at(b, 0.06), 0.5)), 5000)
    return normalize(s, 0.7)


def heal():
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    s = mix(*[at(gain(note(0.4, f, "tri", 0.16), 0.5), k * 0.07) for k, f in enumerate(notes)])
    shimmer = env_lin(osc(0.7, 2093, 2093, "sine", vib=0.01, vib_rate=9), 0.2, 0.4)
    return normalize(mix(s, gain(shimmer, 0.12)), 0.7)


def blast():
    boom = env_exp(osc(0.7, 90, 32, "sine", 0.4), 0.22)
    rumble = env_exp(lowpass(noise(0.9), 900, 150), 0.25)
    crack = env_exp(highpass(noise(0.1), 2000), 0.03)
    bubbles = []
    for k in range(9):
        f = random.uniform(300, 700)
        bubbles.append(at(gain(env_exp(osc(0.07, f, f * 1.8, "sine"), 0.025), 0.25 * (1 - k / 10)), 0.25 + k * 0.06 + random.uniform(0, 0.03)))
    return normalize(mix(gain(boom, 1.0), gain(rumble, 0.8), gain(crack, 0.5), *bubbles), 0.95)


def splash():
    splat = env_exp(lowpass(noise(0.25), 2500, 400), 0.05)
    blob = env_exp(osc(0.12, 160, 70, "sine"), 0.05)
    drops = [at(gain(env_exp(osc(0.05, f, f * 1.6, "sine"), 0.015), 0.3), d) for f, d in ((600, 0.06), (820, 0.1), (520, 0.14))]
    return normalize(mix(gain(splat, 0.8), gain(blob, 0.6), *drops), 0.7)


def lob():
    blorp = env_exp(osc(0.2, 140, 420, "sine", 0.6), 0.08)
    gurgle = env_exp(lowpass(noise(0.18), 900), 0.06)
    return normalize(mix(blorp, gain(gurgle, 0.4)), 0.7)


def fuse():
    hiss = bandpass(noise(0.9), 2500, 9000)
    crackle = [v if random.random() < 0.02 else 0.0 for v in noise(0.9)]
    s = mix(gain(hiss, 0.5), gain(crackle, 0.9))
    s = [v * (0.6 + 0.4 * math.sin(2 * math.pi * 14 * i / SR)) for i, v in enumerate(s)]
    return normalize(env_lin(s, 0.03, 0.08), 0.6)


def charge():
    rumble = lowpass(osc(0.7, 55, 90, "saw", 1.0), 400)
    hiss = bandpass(noise(0.7), 1500, 7000)
    hiss = [v * (i / len(hiss)) ** 1.5 for i, v in enumerate(hiss)]
    snort = env_exp(lowpass(noise(0.15), 1200), 0.05)
    s = mix(gain(env_lin(rumble, 0.05, 0.1), 0.8), gain(hiss, 0.6), gain(snort, 0.5))
    return normalize(s, 0.8)


def stun():
    crash = env_exp(osc(0.3, 120, 45, "sine", 0.5), 0.09)
    clang = env_exp(mix(osc(0.4, 740, shape="square"), gain(osc(0.4, 1110, shape="square"), 0.6)), 0.08)
    clang = lowpass(clang, 3000)
    debris = env_exp(bandpass(noise(0.3), 400, 3000), 0.07)
    boing = env_exp(osc(0.6, 380, 300, "tri", vib=0.12, vib_rate=11), 0.25)
    return normalize(mix(crash, gain(clang, 0.3), gain(debris, 0.6), at(gain(boing, 0.45), 0.12)), 0.9)


def stomp():
    thud = env_exp(osc(0.35, 110, 38, "sine", 0.4), 0.1)
    dirt = env_exp(lowpass(noise(0.35), 1800, 300), 0.08)
    pebbles = [at(gain(env_exp(bandpass(noise(0.03), 2000, 6000), 0.008), 0.3), 0.04 + k * 0.035) for k in range(5)]
    return normalize(mix(thud, gain(dirt, 0.7), *pebbles), 0.9)


def laser():
    zap = env_exp(osc(0.18, 1800, 300, "square", 0.6), 0.06)
    zap = lowpass(zap, 4500)
    buzz = env_exp(osc(0.18, 90, shape="saw"), 0.05)
    return normalize(crush(mix(zap, gain(buzz, 0.3)), 24), 0.6)


def alert():
    a = note(0.07, 880, "pulse", 0.03)
    b = note(0.12, 1318.5, "pulse", 0.05)
    return normalize(lowpass(mix(a, at(b, 0.055)), 4000), 0.5)


# ---------------------------------------------------------------- menus
# Wooden marimba clicks and leafy swishes, to match the music.

def wood(f, sec=0.35, bright=1.0):
    """Marimba-like mallet note."""
    n = n_samples(sec)
    out = []
    for i in range(n):
        t = i / SR
        out.append((math.sin(2 * math.pi * f * t) * math.exp(-t * 9)
                    + 0.3 * bright * math.sin(2 * math.pi * f * 3.98 * t) * math.exp(-t * 30)
                    + 0.12 * bright * math.sin(2 * math.pi * f * 9.2 * t) * math.exp(-t * 60))
                   * min(1.0, i / 25))
    return out


def ui_confirm():
    return normalize(mix(wood(783.99, 0.25), at(wood(1046.5, 0.35), 0.06)), 0.6)


def ui_back():
    return normalize(mix(gain(wood(1046.5, 0.25, 0.7), 0.8), at(wood(783.99, 0.35, 0.7), 0.06)), 0.5)


def ui_tab():
    return normalize(wood(1318.5, 0.12, 0.6), 0.4)


def ui_denied():
    a = wood(196.0, 0.22, 1.4)
    b = wood(185.0, 0.25, 1.4)  # a little out of tune: "no"
    thud = env_exp(lowpass(noise(0.08), 600), 0.02)
    return normalize(mix(a, gain(thud, 0.5), at(b, 0.11), at(gain(thud, 0.4), 0.11)), 0.6)


def ui_buy():
    coins = [at(gain(env_exp(osc(0.25, f, shape="square"), 0.06), 0.35), d)
             for f, d in ((1567.98, 0.0), (2093.0, 0.05))]
    coins = [lowpass(c, 6000) for c in coins]
    chime = mix(*[at(gain(wood(f, 0.5), 0.6), 0.1 + k * 0.05) for k, f in enumerate((1046.5, 1318.5, 1567.98, 2093.0))])
    leaf = env_lin(bandpass(noise(0.3), 3000, 9000), 0.1, 0.2)
    return normalize(mix(*coins, chime, at(gain(leaf, 0.12), 0.12)), 0.7)


def ui_on():
    return normalize(mix(env_exp(osc(0.12, 600, 1200, "sine"), 0.05), at(wood(1567.98, 0.25), 0.05)), 0.5)


def ui_off():
    return normalize(mix(env_exp(osc(0.12, 1000, 500, "sine"), 0.05), at(gain(wood(783.99, 0.25, 0.6), 0.8), 0.05)), 0.45)


def ui_pause():
    sw = env_lin(lowpass(noise(0.3), 3000, 400), 0.02, 0.2)
    return normalize(mix(gain(sw, 0.35), wood(659.25, 0.3, 0.6), at(wood(493.88, 0.4, 0.6), 0.08)), 0.5)


def ui_unpause():
    sw = env_lin(lowpass(noise(0.3), 400, 3000), 0.1, 0.1)
    return normalize(mix(gain(sw, 0.35), wood(493.88, 0.3, 0.6), at(wood(659.25, 0.4, 0.6), 0.08)), 0.5)


def ui_page():
    swish = bandpass(noise(0.28), 1500, 7000)
    swish = [v * math.sin(math.pi * i / len(swish)) ** 2 for i, v in enumerate(swish)]
    return normalize(mix(gain(swish, 0.5), at(gain(wood(1318.5, 0.4, 0.5), 0.6), 0.1)), 0.5)


def teleport():
    rise = env_lin(osc(0.7, 300, 1600, "sine", 0.7, vib=0.04, vib_rate=18), 0.05, 0.25)
    sparkle = mix(*[at(gain(wood(f, 0.3, 0.5), 0.35), 0.2 + k * 0.08) for k, f in enumerate((1046.5, 1318.5, 1567.98, 2093.0, 2637.0))])
    air = env_lin(bandpass(noise(0.7), 800, 5000), 0.3, 0.3)
    return normalize(mix(gain(rise, 0.5), sparkle, gain(air, 0.25)), 0.7)


def shield():
    ting = env_exp(mix(osc(0.6, 1760, shape="sine"), gain(osc(0.6, 2640, shape="sine"), 0.5)), 0.15)
    bub = env_exp(osc(0.15, 400, 900, "sine"), 0.05)
    return normalize(mix(ting, gain(bub, 0.5)), 0.6)


def deflect():
    ting = env_exp(mix(osc(0.35, 2200, shape="sine"), gain(osc(0.35, 3300, shape="tri"), 0.4)), 0.07)
    whoosh = env_lin(bandpass(noise(0.18), 1000, 6000), 0.02, 0.12)
    return normalize(mix(ting, gain(whoosh, 0.5)), 0.6)


SOUNDS = {
    "hit": hit, "hurt": hurt, "purify": purify, "pickup": pickup, "heal": heal,
    "blast": blast, "splash": splash, "lob": lob, "fuse": fuse, "charge": charge,
    "stun": stun, "stomp": stomp, "laser": laser, "alert": alert,
    "ui_confirm": ui_confirm, "ui_back": ui_back, "ui_tab": ui_tab, "ui_denied": ui_denied,
    "ui_buy": ui_buy, "ui_on": ui_on, "ui_off": ui_off, "ui_pause": ui_pause,
    "ui_unpause": ui_unpause, "ui_page": ui_page, "teleport": teleport, "shield": shield,
    "deflect": deflect,
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "sfx_out"
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        t = fn()
        save(t, os.path.join(out, name + ".wav"))
        print(name, "%.2f s" % (len(t) / SR))
