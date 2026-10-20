"""The growing world's placeholder sounds: doors, footsteps, a room, a shop
bell, and the Grove's birds, river, swing and calf.

GDD §10 "Sound": water, cowbells and birds are the Grove's bed; wind,
hammering and counting are Hollow Vale's. GDD §5 names the kadamba with a
swing and the calf meadow. Everything here is synthesised from noise and
simple tones with the helpers in tools/gen_audio.py, documented so the sound
designer can replace each file 1:1. Every one is a PLACEHOLDER; the moo in
particular stands in for a recording.

Found and run by tools/gen_audio.py (see tools/audio_parts/README.md). Loops
are marked loop=true in their .import files; one-shots are not.
"""

from __future__ import annotations

import numpy as np

from gen_audio import RATE, SEED, envelope, lowpass, t


def _rng(name: str) -> np.random.Generator:
    return np.random.default_rng(SEED + sum(map(ord, name)))


def _decay(n: int, tau: float) -> np.ndarray:
    return np.exp(-np.arange(n) / (RATE * tau))


def _place(out: np.ndarray, part: np.ndarray, at: float, gain: float = 1.0) -> None:
    """Adds `part` into `out` starting at `at` seconds, wrapping round the end
    so a loop stays continuous."""
    start = int(RATE * at)
    idx = (start + np.arange(len(part))) % len(out)
    np.add.at(out, idx, part * gain)


def _seamless(x: np.ndarray, seconds: float) -> np.ndarray:
    """Cross-fades the tail into the head and drops the tail, as street_bed
    does, so the loop has no click. The result is `seconds` shorter."""
    n = int(RATE * seconds)
    x = x.copy()
    x[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    return x[: len(x) - n]


def _thunk(g: np.random.Generator, body_hz: float, seconds: float, bright: float) -> np.ndarray:
    """Wood struck: a short filtered knock over a low decaying body."""
    n = int(RATE * seconds)
    knock = lowpass(g.standard_normal(n), 700 + 1800 * bright) * _decay(n, 0.025)
    body = np.sin(2 * np.pi * body_hz * t(seconds)) * _decay(n, 0.085)
    return knock * 0.55 + body * 0.7


def _creak(g: np.random.Generator, seconds: float, f0: float, f1: float) -> np.ndarray:
    """A hinge or rope creak: a gritty saw that slides from f0 to f1 with the
    stick-slip wobble of dry wood."""
    x = t(seconds)
    n = len(x)
    freq = f0 + (f1 - f0) * (x / seconds) + 10 * np.sin(2 * np.pi * 23 * x)
    phase = np.cumsum(freq) / RATE
    saw = lowpass(2 * (phase % 1) - 1, 1800)
    grit = lowpass(g.standard_normal(n), 2500) * 0.3
    env = envelope(n, 0.05, 0.12) * (0.75 + 0.25 * np.sin(2 * np.pi * 9 * x))
    return (saw * 0.5 + grit * saw) * env


# -- doors ----------------------------------------------------------------------


def door_open() -> np.ndarray:
    """A hinge creaks up as the door swings, then the latch knocks the frame.
    0.62 s, one shot, kept short because the Place fades the view over
    0.45 s and swaps the scene (scripts/places/place.gd). PLACEHOLDER for the
    recorded doors of GDD §5's four enterable interiors."""
    g = _rng("door_open")
    out = np.zeros(int(RATE * 0.62))
    _place(out, _creak(g, 0.32, 210, 330), 0.0, 0.5)
    _place(out, _thunk(g, 110, 0.26, 0.35), 0.34, 0.8)
    return out * 0.55


def door_close() -> np.ndarray:
    """A short creak down, the door meets the frame, the latch drops a
    moment later. 0.8 s, one shot."""
    g = _rng("door_close")
    out = np.zeros(int(RATE * 0.8))
    _place(out, _creak(g, 0.28, 320, 240), 0.0, 0.4)
    _place(out, _thunk(g, 85, 0.32, 0.25), 0.3, 1.0)
    _place(out, _thunk(g, 140, 0.18, 0.7), 0.42, 0.45)
    return out * 0.6


# -- footsteps ------------------------------------------------------------------


def _steps(name: str, heel: float, scuff: float, hollow_hz: float, hollow: float) -> np.ndarray:
    """Four steps at a walking pace (one each 0.5 s), uneven by a few
    milliseconds, the loop 2 s. The player plays it at pitch 1.0 walking
    and 1.35 running (scripts/player/player.gd)."""
    g = _rng(name)
    out = np.zeros(int(RATE * 2.0))
    for i in range(4):
        at = 0.1 + 0.5 * i + g.uniform(-0.02, 0.02)
        n = int(RATE * 0.16)
        strike = lowpass(g.standard_normal(n), heel) * _decay(n, 0.018)
        drag = lowpass(g.standard_normal(n), scuff) * _decay(n, 0.05)
        body = np.sin(2 * np.pi * hollow_hz * t(0.16)) * _decay(n, 0.06) * hollow
        step = strike * 0.6 + body
        _place(out, step, at, 0.8 + 0.3 * g.random())
        _place(out, drag * 0.3, at + 0.07, 0.7 + 0.4 * g.random())
    return out * 0.5


def footsteps_pavement() -> np.ndarray:
    """Hard soles on paving: a bright strike and a short gritty scuff."""
    return _steps("steps_pavement", heel=2600, scuff=1400, hollow_hz=160, hollow=0.15)


def footsteps_wood() -> np.ndarray:
    """The same walk on floorboards: duller strike, a hollow thump beneath."""
    return _steps("steps_wood", heel=1300, scuff=900, hollow_hz=120, hollow=0.6)


# -- rooms and things -----------------------------------------------------------


def room_tone() -> np.ndarray:
    """A quiet interior: low air, a faint mains hum, a breath of the street
    through the wall. 6 s loop, peak well under -20 dB."""
    g = _rng("room")
    dur = 6.4
    noise = g.standard_normal(int(RATE * dur))
    air = lowpass(noise, 160) * 0.5
    wall = (lowpass(noise, 900) - lowpass(noise, 300)) * 0.06
    hum = np.sin(2 * np.pi * 50 * t(dur)) * 0.025 * (1 + 0.3 * np.sin(2 * np.pi * 0.17 * t(dur)))
    swell = 0.8 + 0.2 * np.sin(2 * np.pi * 0.11 * t(dur))
    return _seamless((air + wall) * swell + hum, 0.4) * 0.35


def shop_bell() -> np.ndarray:
    """A small brass bell over a shop door: inharmonic partials with their
    own decays, struck twice as it swings back. 1.6 s, one shot."""
    g = _rng("bell")
    dur = 1.6
    x = t(dur)
    f = 2350.0
    partials = ((1.0, 1.0, 0.9), (2.0, 0.55, 0.5), (2.98, 0.4, 0.45), (4.2, 0.22, 0.3), (5.4, 0.12, 0.2))
    ring = sum(amp * np.sin(2 * np.pi * f * ratio * x) * np.exp(-x / tau) for ratio, amp, tau in partials)
    clap = lowpass(g.standard_normal(len(x)), 6000) * np.exp(-x / 0.004) * 0.5
    out = np.zeros(len(x))
    _place(out, ring + clap, 0.0, 1.0)
    _place(out, (ring + clap)[: len(x) - int(RATE * 0.17)], 0.17, 0.55)
    return out * 0.3


def swing_creak() -> np.ndarray:
    """The kadamba's swing (GDD §5): the rope creaks once each way, a faint
    rub between. 3 s loop, one swing."""
    g = _rng("swing")
    dur = 3.4
    out = np.zeros(int(RATE * dur))
    _place(out, _creak(g, 0.55, 170, 240), 0.1, 0.4)
    _place(out, _creak(g, 0.5, 235, 180), 1.65, 0.34)
    rub = lowpass(g.standard_normal(len(out)), 600) * (0.5 + 0.5 * np.sin(2 * np.pi * t(dur) / 1.5)) * 0.03
    return _seamless(out + rub, 0.4) * 0.8


# -- the Grove ------------------------------------------------------------------


def bird_calls() -> np.ndarray:
    """A gentle Grove loop, 8 s: a quick high bird in short bursts, a slower
    whistler, and the hush of leaves so the gaps are not silence (GDD §10:
    "water, cowbells and birds are the Grove's bed")."""
    g = _rng("birds")
    dur = 8.4
    out = np.zeros(int(RATE * dur))
    for _ in range(5):
        start = g.uniform(0.2, 7.4)
        for k in range(int(g.integers(3, 6))):
            d = g.uniform(0.05, 0.1)
            x = t(d)
            f0 = g.uniform(3000, 4200)
            f1 = f0 * g.uniform(0.8, 1.25)
            freq = f0 + (f1 - f0) * np.sin(np.pi * x / d)
            chirp = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * envelope(len(x), 0.012, 0.025)
            _place(out, chirp, start + k * g.uniform(0.11, 0.16), g.uniform(0.12, 0.22))
    for _ in range(3):
        d = g.uniform(0.25, 0.45)
        x = t(d)
        f0 = g.uniform(1400, 1900)
        freq = (f0 + f0 * g.uniform(0.15, 0.4) * x / d) * (1 + 0.03 * np.sin(2 * np.pi * 28 * x))
        whistle = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * envelope(len(x), 0.04, 0.1)
        _place(out, whistle, g.uniform(0.5, 7.2), 0.16)
    noise = g.standard_normal(len(out))
    leaves = (lowpass(noise, 2000) - lowpass(noise, 500)) * 0.02
    return _seamless(out + leaves, 0.4)


def river_loop() -> np.ndarray:
    """The Grove's river running past the bank: broad filtered noise with a
    low rush beneath, swelling slowly. 6 s loop."""
    g = _rng("river")
    dur = 6.4
    noise = g.standard_normal(int(RATE * dur))
    water = lowpass(noise, 2800) - lowpass(noise, 300)
    rush = lowpass(g.standard_normal(len(noise)), 380) * 0.6
    x = t(dur)
    swell = 0.75 + 0.15 * np.sin(2 * np.pi * 0.31 * x) + 0.1 * np.sin(2 * np.pi * 0.73 * x + 1.0)
    return _seamless((water * 0.22 + rush * 0.12) * swell, 0.4)


def calf_moo() -> np.ndarray:
    """A soft, low moo: a gliding fundamental with harmonics shaped by two
    formants, a little breath. 1.1 s, one shot. PLACEHOLDER for a recording
    of a real calf (GDD §3 Act 1: "a calf nudges them")."""
    g = _rng("calf")
    dur = 1.1
    x = t(dur)
    n = len(x)
    freq = np.interp(x, [0, 0.12, 0.45, 0.9, dur], [140, 165, 178, 150, 118])
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    f_mean = 155.0
    voice = np.zeros(n)
    for k in range(1, 13):
        formant = 1 + 1.5 * np.exp(-(((k * f_mean - 620) / 180) ** 2)) + np.exp(-(((k * f_mean - 1100) / 220) ** 2))
        voice += np.sin(k * phase) * formant / k
    env = envelope(n, 0.09, 0.25) * (1 + 0.08 * np.sin(2 * np.pi * 6 * x))
    breath = lowpass(g.standard_normal(n), 800) * 0.04
    return (lowpass(voice, 1600) * 0.16 + breath) * env


SOUNDS = {
    "door_open": door_open,
    "door_close": door_close,
    "footsteps_pavement": footsteps_pavement,
    "footsteps_wood": footsteps_wood,
    "room_tone": room_tone,
    "shop_bell": shop_bell,
    "bird_calls": bird_calls,
    "river_loop": river_loop,
    "swing_creak": swing_creak,
    "calf_moo": calf_moo,
}
