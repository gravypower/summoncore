"""Render the Zennit narrator takes: Kokoro "george" with British RP pronunciation, then ffmpeg processing.

This is the final "British RP" recipe: sentence-by-sentence rendering with pauses, speed 0.85, a gentle falling
inflection at the end of each sentence, then a pitch drop, EQ, compression and loudness normalisation, and
Ogg Vorbis out. Output files are named narrator_backstory_NN_rp.ogg, ready to copy to
tools/intro/narration/voice_NN.ogg.

    python render_takes.py                      # all eight takes
    python render_takes.py --only 2             # just take 2
    python render_takes.py --only 9 --extra scene9.txt   # a new take whose text is in a file ("9|text" per line)

Needs: sherpa-onnx, soundfile, numpy, ffmpeg (with the rubberband filter) and the Kokoro model folder
(kokoro-en-v0_19: model.onnx, voices.bin, tokens.txt, espeak-ng-data).
The speech text deliberately spells some words for the voice: "Zenit" (the voice's established pronunciation of
Zennit), "the letter Zed" (British), "Form 27B slash 6". The captions in Intro.lua use the real spellings.
Keep TAKES in step with those captions.
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys

import numpy as np
import sherpa_onnx
import soundfile as sf

SID, SPEED = 9, 0.85   # 9 = "george" (British male); 10 = "lewis". Unverified numbers, but behaves as described.
AF = ("rubberband=pitch=0.917:formant=preserved,highpass=f=65,equalizer=f=140:t=q:w=1:g=3,"
      "equalizer=f=5500:t=q:w=1:g=-2.5,acompressor=threshold=-20dB:ratio=2.5:attack=15:release=250,"
      "loudnorm=I=-18:TP=-2")

TAKES = {
    1: "The Cosmic Index of Summonable Persons is, by general agreement, the most important document in Azeroth that nobody has ever read. It lists every being that may legally be summoned, in alphabetical order, and it was compiled by a single clerk who had, at the time, been on shift for nine thousand years.",
    2: "Somewhere around the letter Zed, the clerk sneezed. This is generally accepted to be the origin of the entire problem.",
    3: "As a result of the sneeze, a Licensed Summoning Liaison, Third Class, named Zenit was entered into the Index as the default recipient of every Ritual of Summoning completed within range of his name. This includes rituals meant for other people. It includes rituals meant for nobody. It includes at least one ritual intended for a goat.",
    4: "Zenit did what any reasonable person would do. He looked for the form. The form turned out to be Form 27B slash 6, which is referenced throughout the Index and has never been seen. Several scholars believe it does not exist. Zenit believes that is exactly what a form would say.",
    5: "Meanwhile, the Ritual of Summoning, a spell with a great deal of free time and a fragile sense of self, had formed an attachment. It does not want gold. It wants, in its own words, attention and closure. It will, however, accept fifty silver as a gesture.",
    6: "And so every completed summon is recorded as an installment on a debt Zenit never agreed to, cannot find the paperwork for, and is nevertheless making definite progress on.",
    7: "You, meanwhile, are a party of friends who have noticed that Zenit is, technically, very easy to summon. The Index has no objection. The Index has never been asked.",
    8: "This is the story of his week, and every week after that. If the form is ever found, you will be the first to know. Or the last. The Index is unclear.",
    9: "The rules, such as they are. Only summons of Zenit count; summons between friends are a pleasant way to spend an evening, and count for nothing. Each week, the group earns points for the summons that land, with more points for places that are remote, or dangerous, or frankly unreasonable. The Index files ten summons a week. Anything more, it files under enthusiasm. Zenit, for his part, holds a secret list of five places, which he will not discuss. A summons to a place on it earns him the points as well. If the group has more points at the end of the week, the Index records a victory for persistence.",
    10: "If Zenit is not behind when the week ends, he wins the week, and goes on leave for the seven days that follow, when summons of him are filed as filler. He may refuse a summons. He may demand fifty silver, in cash, with no receipt. Or he may suggest dice, three times a week, though each helper may lean on the summoner's side. Once five summons are filed, he may also close the Index until Monday. When one side runs well ahead, the Index, which takes no sides, will lean toward the other. Some weeks it has a whim. The first to five weeks takes the season. The Ritual, which has always wanted closure, approves. The Index accepts most things.",
}


def find_ffmpeg():
    found = shutil.which("ffmpeg")
    if found:
        return found
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages")
    hits = glob.glob(os.path.join(base, "**", "ffmpeg.exe"), recursive=True)
    if hits:
        return hits[0]
    sys.exit("ffmpeg not found (winget install Gyan.FFmpeg)")


def fall(x, sr, tail=0.5, end_rate=0.90):
    """Gentle downward pitch glide plus fade over the last 0.5 s of a sentence."""
    n = int(sr * tail)
    if len(x) <= n * 2:
        return x
    head, t = x[:-n], x[-n:]
    rate = np.linspace(1.0, end_rate, n)
    pos = np.concatenate([[0], np.cumsum(rate)[:-1]])
    pos = pos[pos < n - 1]
    out = np.interp(pos, np.arange(n), t)
    out *= np.linspace(1, 0.6, len(out))
    return np.concatenate([head, out]).astype(np.float32)


def render(tts, text):
    parts, sr = [], 24000
    for s in re.split(r"(?<=[.!?])\s+", text.strip()):          # one sentence at a time
        a = tts.generate(s, sid=SID, speed=SPEED)
        sr = a.sample_rate
        y = fall(np.array(a.samples, dtype=np.float32), sr)
        gap = 1.05 if len(s.split()) <= 9 else 0.7                 # a longer beat after short punchlines
        parts += [y, np.zeros(int(sr * gap), dtype=np.float32)]
    pad = np.zeros(int(sr * 0.45), dtype=np.float32)
    return np.concatenate([pad] + parts[:-1] + [pad]), sr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.environ.get("KOKORO_DIR", r"C:\Users\aaron\tts-models\kokoro-en-v0_19"))
    ap.add_argument("--out", default=".")
    ap.add_argument("--only", help="comma-separated take numbers to render")
    ap.add_argument("--extra", help="file of extra takes, one per line as 'N|text'")
    args = ap.parse_args()

    takes = dict(TAKES)
    if args.extra:
        for line in open(args.extra, encoding="utf-8"):
            if "|" in line:
                n, text = line.split("|", 1)
                takes[int(n)] = text.strip()
    wanted = sorted(int(n) for n in args.only.split(",")) if args.only else sorted(takes)
    ffmpeg = find_ffmpeg()
    os.makedirs(args.out, exist_ok=True)

    m = args.model
    cfg = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                model=f"{m}/model.onnx", voices=f"{m}/voices.bin", tokens=f"{m}/tokens.txt",
                data_dir=f"{m}/espeak-ng-data",
                lang="en-gb-x-rp",       # British Received Pronunciation ("en-gb" gave broken audio)
            ),
            num_threads=4,
        )
    )
    tts = sherpa_onnx.OfflineTts(cfg)

    for n in wanted:
        audio, sr = render(tts, takes[n])
        wav = os.path.join(args.out, f"narrator_backstory_{n:02d}.wav")
        ogg = os.path.join(args.out, f"narrator_backstory_{n:02d}_rp.ogg")
        sf.write(wav, audio, sr)
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-af", AF, "-c:a", "libvorbis", "-q:a", "4", ogg],
                       check=True)
        print(f"take {n}: raw {len(audio) / sr:.1f} s -> {ogg}")


if __name__ == "__main__":
    main()
