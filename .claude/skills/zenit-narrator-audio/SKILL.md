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

1. Put the wording in `TAKES` in `scripts/render_takes.py`, or, for a new scene, in a text file with lines
   `N|text` and pass `--extra file.txt`. Keep it in step with the caption in `Intro.lua`.
2. Render: `python scripts/render_takes.py --only 9,10 --extra file.txt --out <dir>` (or no `--only` for all). It writes
   `narrator_backstory_NN_rp.ogg`. Set `PYTHONIOENCODING=utf-8` on Windows.
3. Copy each take to `tools/intro/narration/voice_NN.ogg` (two digits).
4. Add the scene to the viewer: an entry in `scenes` in `Intro.lua` (label, text) and artwork in
   `tools/intro/source.html`, plus its key phrases and highlight boxes in `tools/intro/build_audio.ps1`
   (`$cueSpec`, `$highlightSpec`). The number of scenes is the number of `voice_NN.ogg` files.
5. Run `tools/intro/build_audio.ps1` (music, effects, mixes, scene lengths, cues, sentence times, highlights;
   writes `IntroCues.lua`), then `tools/intro/render_intro.ps1 -Style lines -SceneList "9,10"` and the same for
   `-Style storybook`. **Pass the scene list as text**: through `-File`, `9,10` would be flattened into 910.
6. Bump the version in `summoncore.toc` and `Core.lua`, update the README, and tell the user to restart WoW fully
   (new media files are not picked up by `/reload`) and run `/st intro check` then `/st intro`.

## Honest limits

- **Nothing here has been listened to by Claude.** Check levels and lengths with ffmpeg (`volumedetect`,
  `silencedetect`) and tell the user the real judgement is theirs.
- A synthetic voice cannot match a human actor's timing; a recorded take is a drop-in replacement
  (`tools/intro/narration/voice_NN.ogg`, then step 5).
- Changing a take's wording or speed changes its length; `IntroCues.lua` carries the lengths, so just rerun step 5.
- Only the real client proves the clips play and stay in sync with the scenes.
