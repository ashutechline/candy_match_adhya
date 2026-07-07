#!/usr/bin/env python3
"""Procedurally synthesize small game SFX + a music loop as 16-bit mono WAVs.
No external deps (pure stdlib), so we ship real sound without licensing art."""
import wave, struct, math, os, random

SR = 44100
OUT = os.environ.get("OUT_DIR", "assets/audio")
os.makedirs(OUT, exist_ok=True)

def write_wav(name, samples):
    # clamp + int16
    frames = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(v * 32767))
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"  {name}: {len(samples)/SR:.2f}s")

def env_ad(n, attack=0.005, decay=0.12, curve=4.0):
    """Attack then exponential-ish decay envelope of length n samples."""
    out = []
    a = int(attack * SR)
    for i in range(n):
        if i < a:
            out.append(i / max(1, a))
        else:
            t = (i - a) / max(1, (n - a))
            out.append(math.exp(-curve * t) * (1 - t * 0.15))
    return out

def tone(freq, dur, vol=0.6, harmonics=(1.0,), attack=0.005, decay=4.0, pitch_drop=0.0):
    n = int(dur * SR)
    e = env_ad(n, attack=attack, curve=decay)
    out = []
    for i in range(n):
        t = i / SR
        f = freq * (1.0 - pitch_drop * (i / n))
        s = 0.0
        for k, amp in enumerate(harmonics, start=1):
            s += amp * math.sin(2 * math.pi * f * k * t)
        out.append(vol * e[i] * s / sum(harmonics))
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out

def seq(*segments):
    out = []
    for s in segments:
        out.extend(s)
    return out

def pad(dur):
    return [0.0] * int(dur * SR)

def normalize(samples, peak=0.9):
    m = max(1e-6, max(abs(s) for s in samples))
    return [s / m * peak for s in samples]

# --- tap: tiny click ---------------------------------------------------------
write_wav("tap.wav", tone(880, 0.045, vol=0.5, harmonics=(1.0, 0.3), decay=9))

# --- swap: quick upward blip -------------------------------------------------
write_wav("swap.wav", tone(520, 0.09, vol=0.45, harmonics=(1.0, 0.4), decay=7, pitch_drop=-0.5))

# --- invalid: low buzzy thud -------------------------------------------------
write_wav("invalid.wav", tone(150, 0.17, vol=0.5, harmonics=(1.0, 0.6, 0.3), decay=5, pitch_drop=0.25))

# --- pops: pitched by cascade depth -----------------------------------------
pop_freqs = [523, 622, 740, 880, 1046, 1244]  # C5 up the scale-ish
for i, f in enumerate(pop_freqs):
    write_wav(f"pop_{i}.wav",
              tone(f, 0.11, vol=0.55, harmonics=(1.0, 0.5, 0.25), decay=8, pitch_drop=0.18))

# --- special: bright sparkle arpeggio ---------------------------------------
sp = seq(
    tone(784, 0.06, vol=0.4, harmonics=(1.0, 0.5), decay=7),
    tone(988, 0.06, vol=0.4, harmonics=(1.0, 0.5), decay=7),
    tone(1319, 0.07, vol=0.4, harmonics=(1.0, 0.6), decay=6),
    tone(1568, 0.14, vol=0.45, harmonics=(1.0, 0.7, 0.3), decay=5),
)
write_wav("special.wav", sp)

# --- star: shiny chime -------------------------------------------------------
write_wav("star.wav", normalize(mix(
    tone(1318, 0.32, vol=0.5, harmonics=(1.0, 0.5, 0.25), attack=0.002, decay=4),
    tone(1976, 0.32, vol=0.25, harmonics=(1.0, 0.4), attack=0.002, decay=4),
), 0.85))

# --- win: major arpeggio fanfare --------------------------------------------
def note(f, d, v=0.5):
    return tone(f, d, vol=v, harmonics=(1.0, 0.5, 0.25), attack=0.004, decay=3.5)
win = seq(
    note(523, 0.12), note(659, 0.12), note(784, 0.12),
    mix(note(1046, 0.5, 0.55), tone(1568, 0.5, vol=0.2, harmonics=(1.0, 0.4), decay=3.5)),
)
write_wav("win.wav", normalize(win, 0.9))

# --- lose: gentle descending minor ------------------------------------------
lose = seq(
    note(440, 0.16, 0.45), note(392, 0.16, 0.45),
    note(349, 0.16, 0.45), note(262, 0.5, 0.4),
)
write_wav("lose.wav", normalize(lose, 0.8))

# --- music: soft looping arpeggio pad (default OFF in-app) -------------------
def soft(f, d, v):
    return tone(f, d, vol=v, harmonics=(1.0, 0.5, 0.2), attack=0.02, decay=2.0)
# I - vi - IV - V feel in C, gentle 8th-note arpeggios, ~8s loop.
chords = [
    [262, 330, 392, 523],  # C
    [220, 262, 330, 440],  # Am
    [175, 262, 349, 440],  # F
    [196, 247, 392, 494],  # G
]
music = []
step = 0.25
for ch in chords:
    pattern = [ch[0], ch[2], ch[1], ch[3], ch[2], ch[3], ch[1], ch[2]]
    for f in pattern:
        music.extend(soft(f, step * 1.05, 0.16))
        # trim to step length so timing stays even
        music = music[:int((len(music)))]
# layer a very soft low drone
drone = []
for ch in chords:
    drone.extend(tone(ch[0] / 2, 2.0, vol=0.06, harmonics=(1.0, 0.3), attack=0.3, decay=0.4))
music = normalize(mix(music, drone), 0.5)
write_wav("music.wav", music)

print("done")
