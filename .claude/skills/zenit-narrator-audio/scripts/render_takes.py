"""Render the eight Zennit narrator takes with the Kokoro model via sherpa-onnx.

Run from the folder that contains `kokoro-en-v0_19`:
    python render_takes.py
Writes narrator_backstory_01.wav .. _08.wav and prints each length in seconds.
Keep TAKES in step with the captions in Intro.lua.
"""
import re

import numpy as np
import soundfile as sf
import sherpa_onnx

M = "kokoro-en-v0_19"
SID = 9          # 9 = "george" (British male), 10 = "lewis". Unverified; check the model README.
SPEED = 0.88

cfg = sherpa_onnx.OfflineTtsConfig(
    model=sherpa_onnx.OfflineTtsModelConfig(
        kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
            model=f"{M}/model.onnx",
            voices=f"{M}/voices.bin",
            tokens=f"{M}/tokens.txt",
            data_dir=f"{M}/espeak-ng-data",
        ),
        num_threads=4,
    )
)
tts = sherpa_onnx.OfflineTts(cfg)

TAKES = [
    "The Cosmic Index of Summonable Persons is, by general agreement, the most important document in Azeroth that nobody has ever read. It lists every being that may legally be summoned, in alphabetical order, and it was compiled by a single clerk who had, at the time, been on shift for nine thousand years.",
    "Somewhere around the letter Zed, the clerk sneezed. This is generally accepted to be the origin of the entire problem.",
    "As a result of the sneeze, a Licensed Summoning Liaison, Third Class, named Zennit was entered into the Index as the default recipient of every Ritual of Summoning completed within range of his name. This includes rituals meant for other people. It includes rituals meant for nobody. It includes at least one ritual intended for a goat.",
    "Zennit did what any reasonable person would do. He looked for the form. The form turned out to be Form 27B slash 6, which is referenced throughout the Index and has never been seen. Several scholars believe it does not exist. Zennit believes that is exactly what a form would say.",
    "Meanwhile, the Ritual of Summoning, a spell with a great deal of free time and a fragile sense of self, had formed an attachment. It does not want gold. It wants, in its own words, attention and closure. It will, however, accept fifty silver as a gesture.",
    "And so every completed summon is recorded as an installment on a debt Zennit never agreed to, cannot find the paperwork for, and is nevertheless making definite progress on.",
    "You, meanwhile, are a party of friends who have noticed that Zennit is, technically, very easy to summon. The Index has no objection. The Index has never been asked.",
    "This is the story of his week, and the week after that. If the form is ever found, you will be the first to know. Or the last. The Index is unclear.",
]


def render(text):
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    parts, sr = [], 24000
    for s in sentences:
        a = tts.generate(s, sid=SID, speed=SPEED)
        sr = a.sample_rate
        parts.append(np.array(a.samples, dtype=np.float32))
        gap = 0.85 if len(s.split()) <= 9 else 0.55   # short sentences (punchlines) get a longer beat
        parts.append(np.zeros(int(sr * gap), dtype=np.float32))
    pad = np.zeros(int(sr * 0.4), dtype=np.float32)
    return np.concatenate([pad] + parts[:-1] + [pad]), sr


for i, text in enumerate(TAKES, 1):
    audio, sr = render(text)
    sf.write(f"narrator_backstory_{i:02d}.wav", audio, sr)
    print(i, round(len(audio) / sr, 1), "s")
