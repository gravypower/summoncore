---
name: zenit-narrator-audio
description: Recreate, re-voice or edit the Zenit and the Index narrator audio (eight scene takes plus a combined read) with local Kokoro text-to-speech, then bundle the clips in the Summon Core addon. Use when the narration wording, voice, speed or pacing changes, when a take must be re-rendered, or when the intro's scene timings need updating.
---

# Zenit narrator audio

The intro narration is synthetic speech generated locally with the Kokoro English model (via
`sherpa-onnx`), not a cloud service and not cloned from a real person or the BBC Hitchhiker's Guide
recording. The style target is only a description: calm, warm, unhurried, deadpan British narrator.
A recorded human take will land the deadpan better; these files are good placeholders until then.

## Before starting

- This needs Python 3 with `sherpa-onnx`, `soundfile` and `numpy`, `ffmpeg`, and the Kokoro model
  (`kokoro-en-v0_19`, about 320 MB). **The original run was in a Linux workspace.** The Windows machine this
  addon is developed on now has ffmpeg (installed with winget as `Gyan.FFmpeg`; it is under
  `%LOCALAPPDATA%MicrosoftWinGetPackages` and may not be on PATH in an older shell) but still has no Python, so
  check first with `python --version` and `ffmpeg -version` and say what is missing rather than assuming.
- Installing packages and downloading the model are downloads: **ask the user before doing either** and name
  the source and size.
  - `pip install sherpa-onnx soundfile numpy` (add `--break-system-packages` on Debian-style Linux)
  - Model: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-en-v0_19.tar.bz2`, unpacked
    into a folder named `kokoro-en-v0_19` containing `model.onnx`, `voices.bin`, `tokens.txt`, `espeak-ng-data`
    and a README. The network allowlist may block GitHub in some sessions.
- If the tools are not available, the fallback is to leave the existing clips alone and ask the user for
  recorded or externally generated takes (see "Dropping in finished takes").

## Voices

Speaker 9 is British male, "george" (the voice currently shipped). Speaker 10 is another British male,
"lewis" (comparison takes). **These numbers and names came from memory of the Kokoro v0.19 list and were never
checked**; confirm the mapping against the model's README before relying on it. Change `SID` in
`scripts/render_takes.py` for another voice.

## Settings that mattered

- Speed 0.88 (the first attempt used 0.9).
- Render sentence by sentence and join with silence; this gave much better deadpan timing than whole takes.
- Pauses: 0.55 s after a normal sentence, 0.85 s after a short one (nine words or fewer), so punchlines get a
  beat. 0.4 s of silence at the start and end of every take.
- Speak "Form 27B slash 6" (not "27B/6") and "the letter Zed" (British).
- ffmpeg chain: high-pass 70 Hz, +2.5 dB around 160 Hz, -2 dB around 5.5 kHz, compressor (threshold -20 dB,
  ratio 2.5, attack 15 ms, release 250 ms), loudnorm to -18 LUFS with -2 dB true peak, then Ogg Vorbis `-q:a 4`.

## Steps

1. Edit the `TAKES` list in `scripts/render_takes.py` if the wording changed. The same wording lives in
   `Intro.lua` (the captions) and in the Zenit Recording Script document, section 5, so keep all three in step.
2. From the folder containing `kokoro-en-v0_19`, run `python scripts/render_takes.py`. It writes
   `narrator_backstory_01.wav` to `_08.wav` and prints each length.
3. Run `bash scripts/process.sh`. It writes `narrator_backstory_NN.ogg` and `narrator_backstory_full.ogg`.
4. Bundle the takes in the addon (below), then update the scene timings.
5. Listen to every take. **The audio was generated but never listened to**; the likeliest problems are an odd
   stress on a word and a pause that feels too long or too short. Tell the user honestly if you cannot listen.

## Bundling in the addon

- Copy take N to `tools/intro/narration/voice_0N.ogg` (N = 1 to 8), then run `tools/intro/build_audio.ps1` (needs ffmpeg). It
  measures every take, builds the music bed and sound effects, mixes `Media/intro_N.ogg` (voice plus music) and
  `Media/intro_N_voice.ogg`, times the on-screen key phrases from the audio, and writes `IntroCues.lua` with the scene
  lengths, so the `dur` values in `Intro.lua` are only a fallback now. The older manual notes below still explain why.
- `Intro.lua` plays `Interface\AddOns\summoncore\Media\intro_N`
  with `PlaySoundFile` on the Dialog channel, one clip per scene, because `PlaySoundFile` cannot start partway
  into a file.
- `narrator_backstory_full.ogg` is only for the web flipbook page (stored there as `intro.ogg`); the addon does
  not use it.
- Measure each clip's length (for example by loading it in a headless browser `<audio>` element and reading
  `duration`; no ffprobe is needed). Then set the `dur` of each scene in `Intro.lua` to that length plus
  `PAUSE` (0.6 s). A scene shorter than its clip makes the next scene cut the narration off. Keep the web
  page's scene boundaries (`tools/intro/source.html`) in step if it is still used.
- Clip lengths currently shipped (the "rp" voice, seconds): 22.10, 9.80, 26.40, 24.70, 21.90, 12.50, 14.00, 14.30 (about 145 total; the intro runs about 2:30 with the pauses). The earlier "george" set was 20.80, 9.10, 25.10, 23.00, 20.40, 12.20, 13.10, 13.30.

## Dropping in finished takes

If the user supplies per-scene `.ogg` files (for example another voice, or recordings by friends), no
synthesis is needed: copy them to `Media/intro_N.ogg`, measure their lengths, update the `dur` values in
`Intro.lua`, bump the version in `summoncore.toc` and `Core.lua`, and tell the user to test with `/st intro`.
Only the files for scenes that changed need replacing.

## Honest limits

- A synthetic voice cannot match a human actor's timing.
- Only `/st intro` in the real client proves the clips play and stay in sync with the scenes.
