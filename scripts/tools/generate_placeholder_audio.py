"""Original, deterministic synthesized placeholders; no external recordings."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "assets/audio"
RATE = 22050
DURATIONS = {"shot": .14, "reload": .5, "hurt": .16, "step": .09,
             "alert": .25, "empty": .07, "jump": .13, "land": .12, "victory": .7}

ROOT.mkdir(parents=True, exist_ok=True)
for index, (name, duration) in enumerate(DURATIONS.items()):
    rng = random.Random(20261028 + index)
    samples = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        decay = math.exp(-t * 35)
        if name in ("shot", "step", "land", "hurt"):
            frequency = 75 if name == "shot" else 130
            value = (rng.uniform(-1, 1) * .65 + math.sin(2 * math.pi * frequency * t) * .35) * decay
        elif name == "reload":
            pulse = min(abs(t - .02), abs(t - .32))
            value = rng.uniform(-1, 1) * math.exp(-pulse * 140)
        else:
            frequency = {"alert": 620, "empty": 900, "jump": 220, "victory": 440}[name]
            if name == "victory":
                frequency *= [1, 1.25, 1.5][min(2, int(t / .23))]
            value = math.sin(2 * math.pi * frequency * t) * math.sin(math.pi * t / duration) * .5
        samples.append(struct.pack("<h", int(max(-1, min(1, value)) * 9000)))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(samples))
print("Generated 9 original mono PCM placeholder sounds at 22050Hz")
