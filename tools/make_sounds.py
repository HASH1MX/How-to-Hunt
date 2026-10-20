"""Makes the game's own sounds (ambience, water, birds, animal calls, voice blips).

Run:  python tools/make_sounds.py        (no extra libraries needed)
Writes 16-bit mono WAV files into assets/audio/synth/.
Fixed random seeds, so the same files come out every time.
"""
import math
import os
import random
import struct
import wave

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "synth")


# --- Building blocks -------------------------------------------------------------------

def silence(seconds):
    return [0.0] * int(seconds * RATE)


def noise(seconds, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def lowpass(x, cutoff):
    """One-pole low-pass. `cutoff` may be a number or a list (one value per sample)."""
    out = []
    y = 0.0
    for i, s in enumerate(x):
        c = cutoff[i] if isinstance(cutoff, list) else cutoff
        a = 1.0 - math.exp(-2.0 * math.pi * c / RATE)
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    low = lowpass(x, cutoff)
    return [s - l for s, l in zip(x, low)]


def bandpass(x, low_cut, high_cut):
    return highpass(lowpass(x, high_cut), low_cut)


def envelope(n, attack, release, curve=1.0):
    """Fade in over `attack` seconds, fade out over `release` seconds."""
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    env = []
    for i in range(n):
        v = min(1.0, i / a) * min(1.0, (n - 1 - i) / r)
        env.append(v ** curve)
    return env


def apply(x, env):
    return [s * e for s, e in zip(x, env)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def scale(x, gain):
    return [s * gain for s in x]


def normalize(x, peak=0.8):
    m = max(abs(s) for s in x) or 1.0
    return [s * peak / m for s in x]


def tone(freqs, shape="sine", seconds=None, vibrato=0.0, vibrato_rate=6.0, rng=None):
    """An oscillator. `freqs` is a number or a list of frequencies (Hz) per sample."""
    n = len(freqs) if isinstance(freqs, list) else int(seconds * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        f = freqs[i] if isinstance(freqs, list) else freqs
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2.0 * math.pi * vibrato_rate * i / RATE)
        phase += f / RATE
        p = phase % 1.0
        if shape == "sine":
            out.append(math.sin(2.0 * math.pi * p))
        elif shape == "saw":
            out.append(2.0 * p - 1.0)
        elif shape == "tri":
            out.append(4.0 * abs(p - 0.5) - 1.0)
        elif shape == "pulse":
            out.append(1.0 if p < 0.3 else -1.0)
    return out


def sweep(f0, f1, seconds, curve=1.0):
    n = int(seconds * RATE)
    return [f0 + (f1 - f0) * ((i / max(1, n - 1)) ** curve) for i in range(n)]


def loopable(x, fade_seconds):
    """Cross-fades the end into the start so the sound repeats without a click."""
    f = int(fade_seconds * RATE)
    body = x[: len(x) - f]
    for i in range(f):
        t = i / f
        body[i] = body[i] * t + x[len(x) - f + i] * (1.0 - t)
    return body


def save(name, x, peak=0.8):
    os.makedirs(OUT, exist_ok=True)
    x = normalize(x, peak)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in x))
    print("wrote", name, "%.2fs" % (len(x) / RATE))


# --- Ambience --------------------------------------------------------------------------

def make_wind(rng):
    seconds = 26.0
    n = int(seconds * RATE)
    base = noise(seconds, rng)
    # The wind's "color" and loudness drift slowly (periods divide the length so it loops).
    cutoff = [350.0 + 300.0 * (0.5 + 0.5 * math.sin(2 * math.pi * 2 * i / n)) + 120.0 * math.sin(2 * math.pi * 5 * i / n) for i in range(n)]
    shaped = lowpass(base, cutoff)
    gust = [0.55 + 0.45 * (0.5 + 0.5 * math.sin(2 * math.pi * 3 * i / n + 1.0)) * (0.7 + 0.3 * math.sin(2 * math.pi * 7 * i / n)) for i in range(n)]
    save("wind_loop", loopable(apply(shaped, gust), 2.0), 0.7)


def make_waves(rng):
    seconds = 28.0
    n = int(seconds * RATE)
    wash = lowpass(noise(seconds, rng), 700.0)
    hiss = highpass(lowpass(noise(seconds, rng), 3200.0), 900.0)
    out = []
    for i in range(n):
        t = i / n
        # Two overlapping swells, so the sea breathes irregularly.
        swell = (0.5 + 0.5 * math.sin(2 * math.pi * 4 * t)) ** 1.6 * 0.7 + (0.5 + 0.5 * math.sin(2 * math.pi * 7 * t + 2.0)) ** 2.0 * 0.5
        crest = max(0.0, swell - 0.55)
        out.append(wash[i] * (0.25 + swell) + hiss[i] * crest * 1.1)
    save("waves_loop", loopable(out, 2.5), 0.7)


def chirp(rng, notes, base, spread, note_len, gap):
    track = silence(0.02)
    for k in range(notes):
        f0 = base * rng.uniform(0.9, 1.1)
        f1 = f0 * rng.uniform(1.0 - spread, 1.0 + spread)
        n = int(note_len * rng.uniform(0.8, 1.2) * RATE)
        freqs = [f0 + (f1 - f0) * (i / n) ** 0.7 + 90.0 * math.sin(i * 0.05) for i in range(n)]
        note = apply(tone(freqs, "sine"), envelope(n, 0.008, note_len * 0.5, 1.2))
        track += note + silence(gap * rng.uniform(0.7, 1.3))
    return track


def make_birds(rng):
    specs = [
        (3, 3600, 0.25, 0.09, 0.07), (4, 4200, 0.2, 0.07, 0.05), (2, 3000, 0.35, 0.18, 0.12),
        (5, 4800, 0.15, 0.05, 0.04), (3, 3300, 0.3, 0.12, 0.09), (6, 4400, 0.12, 0.045, 0.035),
    ]
    for i, (notes, base, spread, length, gap) in enumerate(specs):
        save("bird_%d" % i, chirp(rng, notes, base, spread, length, gap), 0.5)


# --- Water -----------------------------------------------------------------------------

def make_water(rng):
    for i in range(3):
        n = noise(0.35, rng)
        s = apply(bandpass(n, 300.0, 2500.0 + i * 300), envelope(len(n), 0.01, 0.3, 1.5))
        save("splash_step_%d" % i, s, 0.6)
    for i in range(2):
        body = apply(lowpass(noise(0.9, rng), 1800.0), envelope(int(0.9 * RATE), 0.01, 0.8, 2.0))
        spray = apply(highpass(noise(0.5, rng), 2500.0), envelope(int(0.5 * RATE), 0.005, 0.45, 2.0))
        bubbles = []
        for b in range(5):
            f = rng.uniform(500, 1200)
            n2 = int(0.08 * RATE)
            blip = apply(tone(sweep(f, f * 1.8, 0.08), "sine"), envelope(n2, 0.005, 0.07))
            bubbles += silence(rng.uniform(0.03, 0.09)) + scale(blip, 0.25)
        save("splash_in_%d" % i, mix(body, scale(spray, 0.5), bubbles), 0.7)
    for i in range(3):
        n = int(0.55 * RATE)
        s = apply(lowpass(noise(0.55, rng), [500.0 + 900.0 * math.sin(math.pi * j / n) for j in range(n)]), envelope(n, 0.12, 0.4, 1.3))
        save("swim_%d" % i, s, 0.55)
    # A deep breath in when coming up for air.
    n = int(0.7 * RATE)
    gasp = apply(bandpass(noise(0.7, rng), 400.0, 3000.0), envelope(n, 0.2, 0.3, 1.2))
    save("gasp", gasp, 0.6)


# --- Player ----------------------------------------------------------------------------

def make_player(rng):
    for i in range(3):
        n = int(0.28 * RATE)
        voiced = tone(sweep(190 - i * 12, 120 - i * 8, 0.28), "saw", vibrato=0.02)
        voiced = lowpass(voiced, 900.0)
        breath = scale(bandpass(noise(0.28, rng), 500.0, 2500.0), 0.25)
        save("hurt_%d" % i, apply(mix(voiced, breath), envelope(n, 0.01, 0.2, 1.3)), 0.7)
    for i in range(3):
        n = int(0.22 * RATE)
        s = apply(bandpass(noise(0.22, rng), [900.0 + 2200.0 * math.sin(math.pi * j / n) for j in range(n)], 4200.0), envelope(n, 0.07, 0.12, 1.4))
        save("whoosh_%d" % i, s, 0.55)


# --- Animals ---------------------------------------------------------------------------

def formant(x, low, high):
    return bandpass(x, low, high)


def make_animals(rng):
    # Rabbit: tiny squeaks.
    for i in range(2):
        n = int(0.16 * RATE)
        s = apply(tone(sweep(1500, 2500, 0.16), "sine", vibrato=0.03, vibrato_rate=30), envelope(n, 0.01, 0.1, 1.2))
        save("rabbit_hurt_%d" % i, s, 0.55)
    n = int(0.45 * RATE)
    save("rabbit_die", apply(tone(sweep(2400, 900, 0.45), "sine", vibrato=0.04, vibrato_rate=22), envelope(n, 0.01, 0.35, 1.2)), 0.55)
    # Chicken: buzzy clucks and a squawk.
    for i in range(3):
        track = []
        for k in range(rng.randint(2, 3)):
            f = rng.uniform(430, 560)
            n = int(0.11 * RATE)
            note = tone(sweep(f * 1.15, f * 0.9, 0.11), "pulse")
            note = apply(formant(note, 350.0, 1800.0), envelope(n, 0.01, 0.08, 1.2))
            track += note + silence(0.07)
        save("chicken_cluck_%d" % i, track, 0.55)
    n = int(0.4 * RATE)
    squawk = tone(sweep(780, 520, 0.4), "saw", vibrato=0.06, vibrato_rate=17)
    save("chicken_hurt", apply(formant(squawk, 400.0, 2600.0), envelope(n, 0.01, 0.3, 1.1)), 0.6)
    n = int(0.6 * RATE)
    save("chicken_die", apply(formant(tone(sweep(650, 300, 0.6), "saw", vibrato=0.07, vibrato_rate=14), 300.0, 2200.0), envelope(n, 0.01, 0.5, 1.1)), 0.6)
    # Squirrel: a fast chitter.
    for i in range(2):
        track = []
        for k in range(rng.randint(6, 9)):
            n = int(0.022 * RATE)
            f = rng.uniform(2300, 3100)
            track += apply(tone(f, "sine", seconds=0.022), envelope(n, 0.002, 0.02)) + silence(rng.uniform(0.018, 0.035))
        save("squirrel_chitter_%d" % i, track, 0.5)
    n = int(0.2 * RATE)
    save("squirrel_hurt", apply(tone(sweep(2200, 3200, 0.2), "sine", vibrato=0.04, vibrato_rate=26), envelope(n, 0.01, 0.15)), 0.5)
    # Deer: a low bleat and a snort.
    n = int(0.55 * RATE)
    bleat = tone(sweep(230, 170, 0.55), "saw", vibrato=0.05, vibrato_rate=11)
    wobble = [0.7 + 0.3 * math.sin(2 * math.pi * 9 * i / RATE) for i in range(n)]
    save("deer_hurt", apply(apply(formant(bleat, 250.0, 1400.0), wobble), envelope(n, 0.02, 0.4, 1.1)), 0.7)
    n = int(0.7 * RATE)
    save("deer_die", apply(formant(tone(sweep(210, 90, 0.7), "saw", vibrato=0.05, vibrato_rate=8), 200.0, 1200.0), envelope(n, 0.02, 0.6, 1.1)), 0.7)
    n = int(0.32 * RATE)
    save("deer_snort", apply(bandpass(noise(0.32, rng), 300.0, 2200.0), envelope(n, 0.03, 0.22, 1.5)), 0.6)


# --- Talking ---------------------------------------------------------------------------

def make_blips(rng):
    """Tiny voice blips for dialogue text, like a character mumbling."""
    for i in range(6):
        f = 190 + i * 22
        n = int(0.055 * RATE)
        s = tone(f * 1.0, "tri", seconds=0.055)
        s = lowpass(s, 1200.0)
        save("blip_%d" % i, apply(s, envelope(n, 0.004, 0.045, 1.2)), 0.45)


def make_munch(rng):
    """Two crunchy bites and a gulp (Captain Gus eating)."""
    for i in range(3):
        track = silence(0.02)
        for k in range(2):
            n = int(0.09 * RATE)
            bite = apply(bandpass(noise(0.09, rng), 500.0 + 300 * i, 3500.0), envelope(n, 0.004, 0.08, 1.8))
            thump = apply(tone(sweep(200, 110, 0.09), "sine"), envelope(n, 0.003, 0.08))
            track += mix(bite, scale(thump, 0.5)) + silence(0.06)
        n = int(0.2 * RATE)
        track += apply(tone(sweep(260 - 20 * i, 90, 0.2), "sine"), envelope(n, 0.02, 0.15, 1.3))
        save("munch_%d" % i, track, 0.7)


def make_fire(rng):
    """A campfire: a soft low roar with random crackles and pops (loops)."""
    seconds = 12.0
    n = int(seconds * RATE)
    roar = scale(lowpass(noise(seconds, rng), [260.0 + 140.0 * math.sin(2 * math.pi * 3 * i / n) for i in range(n)]), 0.55)
    crackle = [0.0] * n
    for _ in range(95):
        start = rng.randrange(0, n - 400)
        length = rng.randrange(40, 260)
        amp = rng.uniform(0.15, 1.0) ** 2
        for k in range(length):
            crackle[start + k] += rng.uniform(-1.0, 1.0) * amp * (1.0 - k / length) ** 2
    crackle = highpass(crackle, 1200.0)
    save("fire_loop", loopable(mix(roar, scale(crackle, 0.9)), 1.5), 0.7)


def gunshot(rng, seconds, crack_hz, boom_hz, boom_amount, tail):
    """A gunshot: a sharp noisy crack, a low boom, and a fading tail (echo)."""
    n = int(seconds * RATE)
    crack = apply(bandpass(noise(seconds, rng), crack_hz * 0.4, crack_hz), envelope(n, 0.001, seconds * 0.9, 4.0))
    boom = apply(tone(sweep(boom_hz, boom_hz * 0.45, seconds), "sine"), envelope(n, 0.001, seconds * 0.95, 2.5))
    body = mix(crack, scale(boom, boom_amount))
    if tail > 0:
        echo = [0.0] * int(tail * RATE)
        delay = int(0.11 * RATE)
        for i in range(len(body)):
            if i + delay < len(echo):
                echo[i + delay] += body[i] * 0.35
        body = mix(body, lowpass(echo, 1500.0))
    return body


def make_guns(rng):
    for i in range(2):
        save("gun_pistol_%d" % i, gunshot(rng, 0.22, 4200 + i * 300, 160, 0.9, 0.5), 0.85)
        save("gun_smg_%d" % i, gunshot(rng, 0.11, 4600 + i * 300, 190, 0.5, 0.0), 0.75)
        save("gun_rifle_%d" % i, gunshot(rng, 0.18, 5200 + i * 300, 140, 0.8, 0.45), 0.85)
    save("gun_shotgun", gunshot(rng, 0.5, 2600, 90, 1.4, 0.8), 0.9)
    save("gun_sniper", gunshot(rng, 0.7, 3000, 70, 1.6, 1.4), 0.95)
    # Flare: a pop and a long rising hiss.
    n = int(1.3 * RATE)
    pop = gunshot(rng, 0.12, 2400, 220, 0.6, 0.0)
    hiss = apply(bandpass(noise(1.3, rng), [1500.0 + 2500.0 * j / n for j in range(n)], 6000.0), envelope(n, 0.05, 0.9, 1.4))
    save("flare_shot", mix(pop, scale(hiss, 0.5)), 0.8)
    # Click of an empty gun, and the clack-clack of reloading.
    n = int(0.06 * RATE)
    save("dry_fire", apply(bandpass(noise(0.06, rng), 1800.0, 6000.0), envelope(n, 0.001, 0.05, 3.0)), 0.6)
    clack = silence(0.05)
    for gap, freq in [(0.25, 1400.0), (0.3, 1000.0)]:
        n = int(0.07 * RATE)
        clack += apply(bandpass(noise(0.07, rng), freq * 0.6, freq * 3), envelope(n, 0.001, 0.06, 2.5)) + silence(gap)
    save("reload", clack, 0.6)
    # Radar beep.
    n = int(0.14 * RATE)
    save("beep", apply(tone(1250.0, "sine", seconds=0.14), envelope(n, 0.005, 0.1, 1.2)), 0.4)


def main():
    rng = random.Random(12345)
    make_wind(rng)
    make_waves(rng)
    make_birds(rng)
    make_water(rng)
    make_player(rng)
    make_animals(rng)
    make_blips(rng)
    make_munch(rng)
    make_fire(rng)
    make_guns(rng)


if __name__ == "__main__":
    main()
