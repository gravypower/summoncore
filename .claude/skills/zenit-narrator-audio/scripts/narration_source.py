"""What the narration says and how it is rendered, in one place, and the tag that says a clip is up to date.

Every rendered clip carries a Vorbis comment SRC_HASH: a hash of the words it speaks and of the recipe that
voiced them. Change the words (in Intro.lua for a scene, in the LINES of Ledger.lua for "The Index today") or the
recipe below, and the hash of the text no longer matches the tag in the file: that clip is stale and wants
re-rendering. The check (tools/intro/check_audio.py) lists them; nothing here needs git.

No sherpa-onnx here: the checks run without the voice model installed.
"""
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))

# The recipe. Changing any of this changes every clip's hash (they all become stale, which is right).
RECIPE = {
    "model": "kokoro-en-v0_19", "sid": 9, "speed": 0.85, "lang": "en-gb-x-rp",
    "gap_short": 1.05, "gap_long": 0.7, "short_words": 9, "pad": 0.45, "fall_tail": 0.5, "fall_rate": 0.90,
    "af": ("rubberband=pitch=0.917:formant=preserved,highpass=f=65,equalizer=f=140:t=q:w=1:g=3,"
           "equalizer=f=5500:t=q:w=1:g=-2.5,acompressor=threshold=-20dB:ratio=2.5:attack=15:release=250,"
           "loudnorm=I=-18:TP=-2"),
    "vorbis_q": 4,
}
TAG = "SRC_HASH"
DIGITS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]

# Fragments: the short phrases and numbers a scene line is spliced from, like a station announcement (Ledger.Splice). They
# are rendered one utterance at a time with no pad and no pause, the silence trimmed from both ends, and a falling
# inflection only when the text ends in a full stop. Kept apart from RECIPE so that changing it does not make the whole
# lines stale; a fragment's hash covers both.
FRAGMENT_RECIPE = {"trim_peak": 0.03, "margin": 0.015, "vorbis_q": 4}
UNITS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen",
         "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
TENS = {20: "twenty", 30: "thirty", 40: "forty", 50: "fifty", 60: "sixty", 70: "seventy", 80: "eighty", 90: "ninety"}


def speech(text):
    """The caption's spelling is for the eye; the voice is given the spelling it says correctly."""
    text = text.replace("Zennit", "Zenit")          # the established pronunciation of Zennit
    text = re.sub(r"\+(\d)", lambda m: "plus " + DIGITS[int(m.group(1))], text)   # "adds +8": a plus sign is not reliably said
    return re.sub(r"\bthe letter Z\b", "the letter Zed", text)   # British


def src_hash(spoken, fragment=False):
    blob = json.dumps(RECIPE, sort_keys=True) + "\n" + spoken
    if fragment:
        blob += "\n" + json.dumps(FRAGMENT_RECIPE, sort_keys=True)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def _read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return f.read()


def scene_captions():
    """{n: caption} for the intro's scenes, in order (Intro.lua's `scenes` table; the Ledger scene is added later)."""
    block = re.search(r"^local scenes = \{\n(.*?)^\}", _read("Intro.lua"), re.S | re.M).group(1)
    caps = re.findall(r"^\s+\{[^\n]*?text = \[=\[(.*?)\]=\]", block, re.S | re.M)
    return {n: c for n, c in enumerate(caps, 1)}


def ledger_lines():
    """{id: sentence} from the LINES table of Ledger.lua."""
    block = re.search(r"^local LINES = \{\n(.*?)^\}", _read("Ledger.lua"), re.S | re.M).group(1)
    return dict(re.findall(r'^\s+(\w+) = "(.*)",\s*$', block, re.M))


def number_fragments():
    """{id: spoken text} for the numbers 0 to 99, as Ledger.lua names them: n<k>c and n<k>f for 0-19, t<k>c, t<k>f and
    t<k>m for the tens (c: more follows, f: the end of the sentence, m: a tens word with its units still to come)."""
    out = {}
    for k, word in enumerate(UNITS):
        out["n%dc" % k], out["n%df" % k] = word + ",", word + "."
    for k, word in TENS.items():
        out["t%dc" % k], out["t%df" % k], out["t%dm" % k] = word + ",", word + ".", word
    return out


def ledger_fragments():
    """{id: text} of the phrases in the FRAGMENTS table of Ledger.lua."""
    block = re.search(r"^local FRAGMENTS = \{\n(.*?)^\}", _read("Ledger.lua"), re.S | re.M).group(1)
    return dict(re.findall(r'^\s+(\w+) = "(.*)",\s*$', block, re.M))


def fragment_speech():
    out = {i: speech(t) for i, t in ledger_fragments().items()}
    out.update(number_fragments())
    return out


def scene_speech():
    return {n: speech(c) for n, c in scene_captions().items()}


def ledger_speech():
    return {i: speech(t) for i, t in ledger_lines().items()}


def scene_path(n):
    return os.path.join(ROOT, "tools", "intro", "narration", "voice_%02d.ogg" % n)


def ledger_path(i):
    return os.path.join(ROOT, "Media", "ledger", i + ".ogg")


def find_ffmpeg():
    found = shutil.which("ffmpeg")
    if found:
        return found
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages")
    hits = glob.glob(os.path.join(base, "**", "ffmpeg.exe"), recursive=True)
    if hits:
        return hits[0]
    sys.exit("ffmpeg not found (winget install Gyan.FFmpeg)")


def ffprobe():
    ff = find_ffmpeg()
    return os.path.join(os.path.dirname(ff), "ffprobe" + os.path.splitext(ff)[1])


def read_tags(path):
    """Every Vorbis comment of an Ogg file as {KEY: value} (empty when there is none or no file)."""
    if not os.path.exists(path):
        return {}
    out = subprocess.run([ffprobe(), "-v", "error", "-show_entries", "stream_tags:format_tags", "-of", "json", path],
                         capture_output=True, text=True).stdout
    info = json.loads(out or "{}")
    found = [(info.get("format") or {}).get("tags") or {}] + [s.get("tags") or {} for s in info.get("streams") or []]
    return {k.upper(): v for tags in found for k, v in tags.items()}     # an Ogg keeps its comments on the stream


def read_tag(path, key=TAG):
    """One Vorbis comment (the SRC_HASH by default), or None."""
    return read_tags(path).get(key)


def write_tag(path, value, key=TAG):
    """Adds the tag to an existing file without re-encoding the audio (a stream copy; the decoded sound is unchanged)."""
    tmp = path + ".tagging.ogg"
    subprocess.run([find_ffmpeg(), "-v", "error", "-y", "-i", path, "-map_metadata", "0", "-c", "copy",
                    "-metadata", "%s=%s" % (key, value), tmp], check=True)
    os.replace(tmp, path)


def decoded_md5(source):
    """MD5 of what a file sounds like (its decoded audio), which re-encoding the same sound does not change."""
    out = subprocess.run([find_ffmpeg(), "-v", "error", "-i", source, "-f", "md5", "-"],
                         capture_output=True, text=True).stdout
    return out.strip().split("=")[-1]


def status():
    """[(kind, id, path, state)] for every clip; state is "ok", "stale", "untagged" or "missing"."""
    rows = []
    for kind, speech_by_id, path_of in (("scene", scene_speech(), scene_path), ("ledger", ledger_speech(), ledger_path),
                                        ("fragment", fragment_speech(), ledger_path)):
        for i, spoken in speech_by_id.items():
            path = path_of(i)
            tag = read_tag(path)
            want = src_hash(spoken, fragment=(kind == "fragment"))
            state = "missing" if not os.path.exists(path) else "untagged" if tag is None else "ok" if tag == want else "stale"
            rows.append((kind, i, path, state))
    return rows


def stale_ids(kind):
    """Ids that need rendering: stale or missing (an untagged clip is not rendered, it is stamped or checked by ear)."""
    return [i for k, i, _, s in status() if k == kind and s in ("stale", "missing")]
