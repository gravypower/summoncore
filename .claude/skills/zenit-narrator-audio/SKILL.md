---
name: zenit-narrator-audio
description: Render, re-voice or extend the Zennit and the Index narrator takes (the "British RP" Kokoro voice) with local text-to-speech, then bundle them in the Summon Core addon and rebuild the intro audio and cues. Use when narration wording changes, a new scene needs a voice-over, a take must be re-rendered, or the voice or pacing changes.
---

# Zennit narrator audio

The intro narration is synthetic speech generated locally with the Kokoro English model (via `sherpa-onnx`),
not a cloud service, and not cloned from a real person or the BBC Hitchhiker's Guide recording. The target is a
description only: a dry, authoritative, detached British RP narrator, mid-to-low baritone, measured pace, poised
pauses, and falling intonation at the end of each sentence.

## What is installed on this machine (as of 2026-10-04)

- Python 3.13 at `C:\Users\aaron\AppData\Local\Programs\Python\Python313\python.exe` (winget `Python.Python.3.13`;
  not on PATH in older shells) with `sherpa-onnx`, `soundfile`, `numpy`.
- The Kokoro English v0.19 model at `C:\Users\aaron\tts-models\kokoro-en-v0_19` (305 MB download from the sherpa-onnx
  GitHub `tts-models` release). `render_takes.py` defaults to that path (or env `KOKORO_DIR`).
- ffmpeg 9.0.2 (winget `Gyan.FFmpeg`, includes `rubberband` and `libvorbis`) under
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages`.
- If anything is missing on another machine, installing it is a download: **ask the user first** and name the source
  and size. Hugging Face was blocked in the original (Linux) workspace; GitHub releases worked.

## The recipe (`scripts/render_takes.py` does all of it)

- Kokoro speaker `sid=9` ("george", British male; `10` is "lewis"; the numbers came from the published list and
  behaved as described), `lang="en-gb-x-rp"` for Received Pronunciation. (`en-gb` gave broken audio.) Speed `0.85`.
- Render **one sentence at a time** and join with silence: 1.05 s after a short sentence (nine words or fewer),
  0.7 s after a longer one, 0.45 s of padding at each end.
- A gentle falling inflection on the last 0.5 s of each sentence (`fall()`: pitch glide down and fade).
- ffmpeg: `rubberband=pitch=0.917:formant=preserved` (about 1.5 semitones lower), high-pass 65 Hz, +3 dB at 140 Hz,
  -2.5 dB at 5.5 kHz, compressor, `loudnorm` to -18 LUFS with -2 dB true peak, Ogg Vorbis `-q:a 4`.
- Speech text spells words for the voice: **"Zenit"** (the established pronunciation of Zennit), **"the letter Zed"**,
  "Form 27B slash 6". The captions in `Intro.lua` and the artwork use the real spellings (Zennit, Z).
- This reproduces the shipped "rp" takes: re-rendering take 2 gave the same 9.80 s length, the same sentence gaps to
  within 0.01 s and the same -18.0 dB average level.

## Steps

The words live in one place: the caption in `Intro.lua` (a scene) or the `LINES` of `Ledger.lua` ("The Index today").
`scripts/narration_source.py` turns a caption into what the voice is given ("Zenit", "the letter Zed"). Every clip
is tagged `SRC_HASH`, a hash of its words and the recipe, so the question "what needs re-recording?" has an answer
without git. Set `PYTHONIOENCODING=utf-8` on Windows.

1. Change the wording in `Intro.lua` or `Ledger.lua`. (A new scene: add its entry to `scenes` in `Intro.lua`, its
   artwork in `tools/intro/source.html`, and its key phrases and highlight boxes in `tools/intro/build_audio.ps1`.)
2. **See what is out of date:** `python tools/intro/check_audio.py`. It lists stale, missing and untagged clips
   (exit status 1 if any need rendering).
3. **Render only those:** `python scripts/render_takes.py --stale --install` (scene takes, installed as
   `tools/intro/narration/voice_NN.ogg`) and `python tools/intro/build_ledger_audio.py --stale` (ledger lines, which
   also rewrites `LedgerClips.lua`). `--only 10` renders a named take whatever its state. A take whose text is not in
   `Intro.lua` yet can come from `--extra file.txt` (lines `N|text`). Rendering is not bit-for-bit repeatable, so do
   not re-render clips that are current: that is what the tag avoids.
   **Spliced lines.** The lines of "The Index today" that carry only numbers ("The group leads the season, 3 to 2") are
   said like a station announcement: `Ledger.Splice` joins short recordings, each started when the one before ends.
   The phrases are the `FRAGMENTS` table in `Ledger.lua`; the numbers 0 to 99 are generated (`n<k>c`/`n<k>f`, and `t<k>c`,
   `t<k>f`, `t<k>m` for the tens: c = more follows, f = the sentence ends, m = a tens word with its units to come, so
   "twenty-one" is `t20m` + `n1f`). A phrase's last mark sets how it is said: a comma keeps the voice level, a full stop
   falls. Fragments are rendered with no pad or pause and the silence trimmed (`render_takes.py --fragments`, driven by
   `build_ledger_audio.py`), and their hash covers `FRAGMENT_RECIPE` as well as the recipe. Names are not recordable, so a
   line with a name in it stays typed and silent; so does a number beyond 99. Phrases are only ever played whole, so add a
   new one to `FRAGMENTS` rather than cutting an existing one, and use `Ledger.Splice` so the text shown is built from the
   same parts as the clips.
4. **Rebuild the mixes:** `tools/intro/build_audio.ps1`. It mixes only the scenes whose `MIX_HASH` no longer
   matches (their voice, where their slice of the music starts, their length, the mix filter, the music source), leaves
   the sound effects alone unless `-Sfx`, and always rewrites `IntroCues.lua`. A scene that grows or shrinks moves the
   music for every scene after it, so those are rebuilt too. `-SceneList "10,11"` (text, not `10,11`, which `-File`
   flattens into 1011) mixes exactly those; `-Force` mixes all. Artwork only changes with a new or redrawn scene:
   `tools/intro/render_intro.ps1 -Style lines -SceneList "9,10"` and the same for `-Style storybook`.
5. **Prove nothing else moved:** `git status` lists every re-encoded file, because encoding the same sound twice gives
   different bytes. `python tools/intro/check_audio.py --verify` compares what files decode to (and their tags) with
   `HEAD` and says which really changed; `--restore` puts back the ones that did not. `git diff` on `IntroCues.lua`
   and `LedgerClips.lua` is exact: it should show only the scenes you touched and the ones after them.
6. Bump the version in `summoncore.toc` and `Core.lua`, update the README, and tell the user to restart WoW fully
   (new media files are not picked up by `/reload`) and run `/sc intro check` then `/sc intro`.

First time on a checkout whose clips pre-date the tags: `check_audio.py --stamp` tags the clips you know are current
without re-rendering (it asserts they match), and `build_audio.ps1 -Stamp -SceneList "1,2,3"` does the same for mixes.

## Honest limits

- **Nothing here has been listened to by Claude.** Check levels and lengths with ffmpeg (`volumedetect`,
  `silencedetect`) and tell the user the real judgement is theirs.
- A synthetic voice cannot match a human actor's timing; a recorded take is a drop-in replacement
  (`tools/intro/narration/voice_NN.ogg`, then `check_audio.py --stamp` for its tag, then step 4).
- Changing a take's wording or speed changes its length; `IntroCues.lua` carries the lengths, so just rerun step 4.
- Only the real client proves the clips play and stay in sync with the scenes.
