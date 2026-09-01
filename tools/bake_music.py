#!/usr/bin/env python3
"""Original looping beds + menu stinger for res://audio/music/."""

from __future__ import annotations

import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "music")


def clamp(x: float) -> float:
    return -1.0 if x < -1.0 else 1.0 if x > 1.0 else x


def midi(n: float) -> float:
    return 440.0 * (2.0 ** ((n - 69.0) / 12.0))


def write_wav(name: str, samples: list[float]) -> None:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{name}.wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(clamp(s) * 32767.0)) for s in samples))
    print("wrote", name, len(samples))


def noise(st: list[float]) -> float:
    st[0] = (st[0] * 1103515245.0 + 12345.0) % 2147483647.0
    return st[0] / 2147483647.0 * 2.0 - 1.0


def loop_len(bpm: float, beats: int) -> int:
    return int(RATE * (60.0 / bpm) * beats)


def bed(
    bpm: float,
    beats: int,
    root: int,
    scale: list[int],
    bass_pat: list[int],
    lead_pat: list[int],
    hat: bool,
    sparkle: float,
) -> list[float]:
    n = loop_len(bpm, beats)
    beat = 60.0 / bpm
    out = [0.0] * n
    st = [root * 13.0 + 7.0]
    for i in range(n):
        t = i / RATE
        b = int(t / beat) % beats
        pos = (t / beat) - b
        s = 0.0
        # kick on 0, 4, ...
        if b % 4 == 0:
            s += math.sin(t * math.tau * (90.0 - pos * 40.0)) * math.exp(-pos * 10.0) * 0.28
        if hat and (b % 2 == 1 or pos < 0.12):
            s += noise(st) * math.exp(-pos * 22.0) * 0.06
        bass_deg = bass_pat[b % len(bass_pat)]
        bf = midi(root + scale[bass_deg % len(scale)])
        s += math.sin(t * math.tau * bf) * 0.18
        s += math.sin(t * math.tau * bf * 0.5) * 0.1
        lead_deg = lead_pat[b % len(lead_pat)]
        lf = midi(root + 12 + scale[lead_deg % len(scale)])
        env = math.sin(min(1.0, pos * 3.2) * math.pi) if pos < 0.85 else 0.0
        s += math.sin(t * math.tau * lf) * env * 0.16
        s += math.sin(t * math.tau * lf * 2.0) * env * sparkle
        # pad
        pf = midi(root + scale[(b // 4) % len(scale)] + 7)
        s += math.sin(t * math.tau * pf) * 0.05
        out[i] = s
    # fade edges for seamless-ish loop
    fade = int(RATE * 0.012)
    for i in range(fade):
        w = i / fade
        out[i] *= w
        out[n - 1 - i] *= w
    # mix start/end a bit
    for i in range(fade):
        a = out[i]
        b = out[n - fade + i]
        out[i] = a * (i / fade) + b * (1.0 - i / fade) * 0.15
    return out


def stinger() -> list[float]:
    n = int(RATE * 1.35)
    out = [0.0] * n
    notes = (55.0, 62.0, 67.0, 74.0)  # midi
    for i in range(n):
        t = i / RATE
        s = 0.0
        for k, m in enumerate(notes):
            dt = t - k * 0.11
            if dt >= 0.0:
                f = midi(m)
                s += math.sin(dt * math.tau * f) * math.exp(-dt * 4.2) * 0.22
                s += math.sin(dt * math.tau * f * 2.0) * math.exp(-dt * 6.0) * 0.06
        out[i] = s * (1.0 if t < 1.05 else max(0.0, (1.35 - t) / 0.3))
    return out


def main() -> None:
    # C min pentatonic degrees relative to root midi
    penta = [0, 3, 5, 7, 10, 12, 15, 17]
    write_wav(
        "mop_waltz",
        bed(92, 16, 48, penta, [0, 0, 4, 2, 0, 3, 4, 2, 0, 0, 5, 4, 0, 2, 4, 3], [4, 5, 4, 6, 3, 4, 5, 7, 4, 5, 6, 4, 2, 3, 4, 5], True, 0.04),
    )
    write_wav(
        "crate_trot",
        bed(108, 16, 50, penta, [0, 2, 0, 4, 0, 2, 5, 4, 0, 2, 0, 4, 3, 2, 4, 0], [5, 4, 7, 5, 4, 6, 5, 7, 4, 5, 4, 6, 7, 5, 4, 5], True, 0.055),
    )
    write_wav(
        "suds_night",
        bed(84, 16, 45, penta, [0, 0, 3, 3, 5, 5, 4, 4, 0, 0, 2, 2, 4, 5, 3, 0], [3, 4, 5, 3, 2, 4, 5, 6, 4, 3, 5, 4, 2, 3, 4, 3], False, 0.03),
    )
    write_wav(
        "last_call",
        bed(118, 16, 52, penta, [0, 4, 2, 5, 0, 4, 7, 5, 0, 3, 2, 5, 4, 2, 5, 0], [7, 6, 5, 7, 4, 5, 6, 7, 5, 6, 7, 5, 4, 6, 5, 7], True, 0.07),
    )
    write_wav(
        "menu_loop",
        bed(86, 16, 47, penta, [0, 0, 4, 4, 2, 2, 5, 5, 0, 0, 3, 3, 4, 4, 2, 0], [2, 3, 4, 2, 3, 4, 5, 3, 2, 4, 3, 2, 4, 5, 3, 2], False, 0.025),
    )
    write_wav("menu_stinger", stinger())


if __name__ == "__main__":
    main()
