"""Render the Zennit narrator takes: Kokoro "george" with British RP pronunciation, then ffmpeg processing.

This is the final "British RP" recipe: sentence-by-sentence rendering with pauses, speed 0.85, a gentle falling
inflection at the end of each sentence, then a pitch drop, EQ, compression and loudness normalisation, and
Ogg Vorbis out. Output files are named narrator_backstory_NN_rp.ogg, ready to copy to
tools/intro/narration/voice_NN.ogg.

    python render_takes.py --stale --install    # only the takes whose words (or the recipe) changed since they were rendered
    python render_takes.py --only 2             # just take 2
    python render_takes.py                      # every scene
    python render_takes.py --only 9 --extra scene9.txt   # a take whose text is in a file ("9|text" per line)

The words come from the captions in Intro.lua (spelled for the voice by narration_source.speech), so there is one
place to edit. Each take is tagged SRC_HASH, a hash of its words and the recipe, which `--stale` and
tools/intro/check_audio.py compare against the current text.

Needs: sherpa-onnx, soundfile, numpy, ffmpeg (with the rubberband filter) and the Kokoro model folder
(kokoro-en-v0_19: model.onnx, voices.bin, tokens.txt, espeak-ng-data).
The speech text deliberately spells some words for the voice: "Zenit" (the voice's established pronunciation of
Zennit) and "the letter Zed" (British); see narration_source.speech. The captions keep the real spellings.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

import numpy as np
import sherpa_onnx
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import narration_source as ns
from narration_source import find_ffmpeg   # re-exported: tools/intro/build_ledger_audio.py uses render_takes.find_ffmpeg

# The recipe lives in narration_source.RECIPE (it is part of every clip's hash). Speaker 9 = "george" (British male);
# 10 = "lewis". Unverified numbers, but behaves as described.
R = ns.RECIPE
SID, SPEED, AF = R["sid"], R["speed"], R["af"]

def fall(x, sr, tail=R["fall_tail"], end_rate=R["fall_rate"]):
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
        gap = R["gap_short"] if len(s.split()) <= R["short_words"] else R["gap_long"]                 # a longer beat after short punchlines
        parts += [y, np.zeros(int(sr * gap), dtype=np.float32)]
    pad = np.zeros(int(sr * R["pad"]), dtype=np.float32)
    return np.concatenate([pad] + parts[:-1] + [pad]), sr


def trim(x, sr):
    """Cuts the silence off both ends of a fragment, keeping a short margin, so spliced pieces butt up against each other."""
    loud = np.where(np.abs(x) > ns.FRAGMENT_RECIPE["trim_peak"])[0]
    if len(loud) == 0:
        return x
    m = int(sr * ns.FRAGMENT_RECIPE["margin"])
    return x[max(0, loud[0] - m): loud[-1] + 1 + m]


def render_fragment(tts, text):
    """One short phrase or number, spoken as part of a longer line (Ledger.Splice): no pad, no pause, and a falling ending
    only when the text ends in a full stop (a comma, or no mark, leaves the voice level, ready for what follows)."""
    a = tts.generate(text, sid=SID, speed=SPEED)
    y = np.array(a.samples, dtype=np.float32)
    if text.rstrip().endswith("."):
        y = fall(y, a.sample_rate, tail=min(R["fall_tail"], 0.4 * len(y) / a.sample_rate))
    return trim(y, a.sample_rate), a.sample_rate


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.environ.get("KOKORO_DIR", r"C:\Users\aaron\tts-models\kokoro-en-v0_19"))
    ap.add_argument("--out", default=".")
    ap.add_argument("--only", help="comma-separated take numbers to render")
    ap.add_argument("--stale", action="store_true", help="render only the takes whose text or recipe changed (see tools/intro/check_audio.py)")
    ap.add_argument("--install", action="store_true", help="also copy each take to tools/intro/narration/voice_NN.ogg")
    ap.add_argument("--extra", help="file of extra takes, one per line as 'N|text'")
    ap.add_argument("--fragments", default="", help="comma-separated take numbers to render as fragments (spliced pieces of a line)")
    args = ap.parse_args()
    fragments = {int(n) for n in args.fragments.split(",") if n}

    takes = ns.scene_speech()
    if args.extra:
        for line in open(args.extra, encoding="utf-8"):
            if "|" in line:
                n, text = line.split("|", 1)
                takes[int(n)] = text.strip()
    if args.stale:
        wanted = ns.stale_ids("scene")
        if not wanted:
            return print("every scene take is up to date")
    else:
        wanted = sorted(int(n) for n in args.only.split(",")) if args.only else sorted(takes)
    ffmpeg = find_ffmpeg()
    os.makedirs(args.out, exist_ok=True)

    m = args.model
    cfg = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                model=f"{m}/model.onnx", voices=f"{m}/voices.bin", tokens=f"{m}/tokens.txt",
                data_dir=f"{m}/espeak-ng-data",
                lang=R["lang"],       # British Received Pronunciation ("en-gb" gave broken audio)
            ),
            num_threads=4,
        )
    )
    tts = sherpa_onnx.OfflineTts(cfg)

    for n in wanted:
        wav = os.path.join(args.out, f"narrator_backstory_{n:02d}.wav")
        ogg = os.path.join(args.out, f"narrator_backstory_{n:02d}_rp.ogg")
        tag = f"{ns.TAG}={ns.src_hash(takes[n], fragment=n in fragments)}"
        if n in fragments:
            audio, sr = render_fragment(tts, takes[n])
            sf.write(wav, audio, sr)
            # the processing can add a little silence (the pitch shift has a latency), so trim again before encoding
            done = os.path.join(args.out, f"narrator_backstory_{n:02d}_processed.wav")
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-af", AF, done], check=True)
            data, rate = sf.read(done, dtype="float32")
            sf.write(done, trim(data, rate), rate)
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", done, "-c:a", "libvorbis",
                            "-q:a", str(ns.FRAGMENT_RECIPE["vorbis_q"]), "-metadata", tag, ogg], check=True)
        else:
            audio, sr = render(tts, takes[n])
            sf.write(wav, audio, sr)
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-af", AF, "-c:a", "libvorbis", "-q:a", str(R["vorbis_q"]),
                            "-metadata", tag, ogg], check=True)
        print(f"take {n}: raw {len(audio) / sr:.1f} s -> {ogg}")
        if args.install:
            shutil.copyfile(ogg, ns.scene_path(n))
            print(f"          installed as {os.path.relpath(ns.scene_path(n), ns.ROOT)}")


if __name__ == "__main__":
    main()
