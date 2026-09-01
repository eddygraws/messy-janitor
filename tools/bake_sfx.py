#!/usr/bin/env python3
"""Bake original short SFX WAVs into res://audio/sfx/ (16-bit mono)."""

from __future__ import annotations

import math
import os
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")


def clamp(x: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return lo if x < lo else hi if x > hi else x


def env_exp(t: float, speed: float) -> float:
    return math.exp(-t * speed)


def noise(state: list[float]) -> float:
    state[0] = (state[0] * 1103515245.0 + 12345.0) % 2147483647.0
    return state[0] / 2147483647.0 * 2.0 - 1.0


def write_wav(name: str, samples: list[float]) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{name}.wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(clamp(s) * 32767.0)) for s in samples)
        w.writeframes(frames)


def alloc(duration: float) -> tuple[int, list[float]]:
    n = max(1, int(RATE * duration))
    return n, [0.0] * n


def hit() -> list[float]:
    """Wet mop slap: low thud + mid scrape."""
    n, out = alloc(0.16)
    st = [91.0]
    lp = 0.0
    for i in range(n):
        t = i / RATE
        u = i / n
        thud = math.sin(t * 92.0 * math.tau) * env_exp(t, 22.0)
        thud += math.sin(t * 48.0 * math.tau) * env_exp(t, 18.0) * 0.7
        nse = noise(st)
        lp = lp * 0.72 + nse * 0.28
        scrape = lp * math.sin(u * math.pi) * (0.55 if u < 0.45 else 0.2)
        out[i] = thud * 0.55 + scrape * 0.38
    return out


def pickup() -> list[float]:
    n, out = alloc(0.12)
    st = [3.0]
    for i in range(n):
        t = i / RATE
        u = i / n
        a = math.sin(t * 310.0 * math.tau) * math.sin(u * math.pi)
        b = math.sin(t * 490.0 * math.tau) * math.sin(u * math.pi) * 0.45
        cardboard = noise(st) * (1.0 - u) * 0.18
        out[i] = (a + b) * 0.34 + cardboard
    return out


def drop() -> list[float]:
    n, out = alloc(0.14)
    st = [11.0]
    for i in range(n):
        t = i / RATE
        u = i / n
        thud = math.sin(t * 118.0 * math.tau) * env_exp(t, 16.0)
        flap = noise(st) * env_exp(t, 28.0) * 0.35
        out[i] = thud * 0.5 + flap + math.sin(t * 210.0 * math.tau) * env_exp(t, 24.0) * 0.15
        if u > 0.55:
            out[i] *= 1.0 - (u - 0.55) / 0.45
    return out


def throw() -> list[float]:
    n, out = alloc(0.15)
    st = [21.0]
    lp = 0.0
    for i in range(n):
        u = i / n
        env = math.sin(u * math.pi) * (0.4 + 0.6 * (1.0 - u))
        lp = lp * 0.55 + noise(st) * 0.45
        out[i] = lp * env * 0.42
    return out


def dash() -> list[float]:
    n, out = alloc(0.12)
    st = [33.0]
    lp = 0.0
    for i in range(n):
        t = i / RATE
        u = i / n
        env = math.sin(u * math.pi) ** 0.7
        lp = lp * 0.48 + noise(st) * 0.52
        air = math.sin(t * 180.0 * math.tau) * env * 0.12
        out[i] = lp * env * 0.36 + air
    return out


def rinse() -> list[float]:
    """Bucket water: bubbles + drip."""
    n, out = alloc(0.28)
    st = [7.0]
    lp = 0.0
    for i in range(n):
        t = i / RATE
        u = i / n
        nse = noise(st)
        lp = lp * 0.82 + nse * 0.18
        water = lp * (0.35 + 0.65 * math.sin(u * math.pi))
        drip = 0.0
        for k, (at, f) in enumerate(((0.04, 980.0), (0.11, 720.0), (0.19, 1100.0))):
            dt = t - at
            if dt > 0.0:
                drip += math.sin(dt * f * math.tau) * env_exp(dt, 28.0 + k * 4.0) * 0.22
        out[i] = water * 0.32 + drip
    return out


def dispose() -> list[float]:
    """Metal bin clank."""
    n, out = alloc(0.22)
    partials = (212.0, 318.0, 507.0, 890.0)
    for i in range(n):
        t = i / RATE
        s = 0.0
        for p, f in enumerate(partials):
            s += math.sin(t * f * math.tau) * env_exp(t, 9.0 + p * 3.5) / (p + 1.4)
        out[i] = s * 0.48
    return out


def switch() -> list[float]:
    n, out = alloc(0.05)
    for i in range(n):
        t = i / RATE
        u = i / n
        click = math.sin(t * 1850.0 * math.tau) * env_exp(t, 70.0)
        tick = math.sin(t * 920.0 * math.tau) * env_exp(t, 55.0) * 0.4
        out[i] = (click + tick) * (1.0 - u) * 0.28
    return out


def dance() -> list[float]:
    n, out = alloc(0.18)
    notes = (330.0, 415.0, 523.0)
    for i in range(n):
        t = i / RATE
        s = 0.0
        for k, f in enumerate(notes):
            dt = t - k * 0.045
            if dt > 0.0:
                s += math.sin(dt * f * math.tau) * env_exp(dt, 14.0) * 0.28
        out[i] = s
    return out


def bump() -> list[float]:
    n, out = alloc(0.16)
    st = [44.0]
    for i in range(n):
        t = i / RATE
        body = math.sin(t * 72.0 * math.tau) * env_exp(t, 14.0)
        body += math.sin(t * 38.0 * math.tau) * env_exp(t, 11.0) * 0.6
        out[i] = body * 0.52 + noise(st) * env_exp(t, 30.0) * 0.12
    return out


def task() -> list[float]:
    n, out = alloc(0.09)
    for i in range(n):
        t = i / RATE
        u = i / n
        out[i] = math.sin(t * 640.0 * math.tau) * math.sin(u * math.pi) * 0.32
        out[i] += math.sin(t * 960.0 * math.tau) * math.sin(u * math.pi) * 0.12
    return out


def task_ok() -> list[float]:
    n, out = alloc(0.2)
    for i in range(n):
        t = i / RATE
        a = math.sin(t * 392.0 * math.tau) * env_exp(t, 8.0)
        b = math.sin(t * 494.0 * math.tau) * env_exp(max(0.0, t - 0.04), 9.0)
        out[i] = (a * 0.28 + b * 0.3) * (1.0 if t < 0.16 else (0.2 - t) / 0.04)
        if t > 0.16:
            out[i] *= max(0.0, (0.2 - t) / 0.04)
    return out


def task_fail() -> list[float]:
    n, out = alloc(0.32)
    for i in range(n):
        t = i / RATE
        a = math.sin(t * 98.0 * math.tau) * env_exp(t, 6.0)
        b = math.sin(t * 73.0 * math.tau) * env_exp(t, 5.5)
        buzz = math.sin(t * 40.0 * math.tau) * env_exp(t, 4.0) * 0.35
        out[i] = (a + b) * 0.38 + buzz
    return out


def phase() -> list[float]:
    n, out = alloc(0.22)
    for i in range(n):
        t = i / RATE
        u = i / n
        f = 160.0 + u * 520.0
        out[i] = math.sin(t * f * math.tau) * (u**0.6) * (1.0 - u) * 1.15 * 0.4
        out[i] += math.sin(t * f * 2.0 * math.tau) * u * (1.0 - u) * 0.12
    return out


def stop() -> list[float]:
    n, out = alloc(0.28)
    for i in range(n):
        t = i / RATE
        pulse = 0.55 + 0.45 * math.sin(t * 12.0 * math.tau)
        out[i] = math.sin(t * 55.0 * math.tau) * env_exp(t, 4.2) * pulse * 0.5
        out[i] += math.sin(t * 82.0 * math.tau) * env_exp(t, 5.0) * 0.18
    return out


BANK = {
    "hit": hit,
    "pickup": pickup,
    "drop": drop,
    "throw": throw,
    "dash": dash,
    "rinse": rinse,
    "dispose": dispose,
    "switch": switch,
    "dance": dance,
    "bump": bump,
    "task": task,
    "task_ok": task_ok,
    "task_fail": task_fail,
    "phase": phase,
    "stop": stop,
}


def main() -> None:
    for name, fn in BANK.items():
        write_wav(name, fn())
        print("wrote", name)


if __name__ == "__main__":
    main()
