"""Which narration clips are out of date, and did a rebuild change anything it should not have?

    python tools/intro/check_audio.py              # list the clips whose words (or the recipe) changed since they were rendered
    python tools/intro/check_audio.py --stamp      # tag clips that have no SRC_HASH, asserting they match the current text
    python tools/intro/check_audio.py --verify     # after a build: which modified .ogg files really sound different
    python tools/intro/check_audio.py --verify --restore   # ... and put back the ones that only differ in their bytes

A clip carries SRC_HASH, a hash of what it says and the recipe (narration_source.py). The check compares it with the
current text in Intro.lua (scenes) and Ledger.lua (LINES); no git needed. Exit status 1 when anything is stale.

--stamp trusts you: it writes the tag without re-rendering, so use it only on clips you know are current (the first
time, to start from a known state). --verify compares decoded audio, since encoding the same sound twice gives
different bytes; it needs git only to find the committed version.
"""
import argparse
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "zenit-narrator-audio", "scripts"))
import narration_source as ns  # noqa: E402


def check():
    rows = ns.status()
    bad = [r for r in rows if r[3] != "ok"]
    for kind, i, path, state in bad:
        name = ("scene %02d" % i) if kind == "scene" else ("%s %s" % (kind, i))
        print("%-9s %-24s %s" % (state, name, os.path.relpath(path, ROOT)))
    print("%d clips, %d up to date, %d need attention" % (len(rows), len(rows) - len(bad), len(bad)))
    if any(r[3] in ("stale", "missing") for r in bad):
        print("render them:  python .claude/skills/zenit-narrator-audio/scripts/render_takes.py --stale --out <dir>   (then copy to tools/intro/narration/voice_NN.ogg)")
        print("              python tools/intro/build_ledger_audio.py --stale")
    return 1 if any(r[3] in ("stale", "missing") for r in bad) else 0


def stamp():
    n = 0
    spoken = {"scene": ns.scene_speech(), "ledger": ns.ledger_speech(), "fragment": ns.fragment_speech()}
    for kind, i, path, state in ns.status():
        if state == "untagged":
            before = ns.decoded_md5(path)
            ns.write_tag(path, ns.src_hash(spoken[kind][i], fragment=(kind == "fragment")))
            assert ns.decoded_md5(path) == before, "stamping changed the sound of " + path
            n += 1
    print("stamped %d untagged clips" % n)


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True)


def verify(restore):
    changed = [l[3:].strip().strip('"') for l in git("status", "--porcelain").stdout.decode().splitlines()
               if l[3:].strip().strip('"').endswith(".ogg")]
    real, tag_only, noise = [], [], []
    for rel in changed:
        path = os.path.join(ROOT, rel)
        old = git("show", "HEAD:" + rel)
        if old.returncode != 0 or not os.path.exists(path):
            real.append((rel, "new or removed"))
            continue
        with tempfile.NamedTemporaryFile(suffix=".ogg", delete=False) as t:
            t.write(old.stdout)
        try:
            if ns.decoded_md5(t.name) != ns.decoded_md5(path):
                real.append((rel, "sounds different"))
            elif ns.read_tags(t.name) != ns.read_tags(path):
                tag_only.append(rel)
            else:
                noise.append(rel)
        finally:
            os.unlink(t.name)
    for rel, why in real:
        print("changed    %s (%s)" % (rel, why))
    for rel in tag_only:
        print("tag only   %s" % rel)
    for rel in noise:
        print("same sound %s%s" % (rel, "  (restored)" if restore else ""))
        if restore:
            git("checkout", "--", rel)
    print("%d changed, %d tag only, %d same sound" % (len(real), len(tag_only), len(noise)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stamp", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--restore", action="store_true", help="with --verify: git checkout the files whose sound and tag are unchanged")
    args = ap.parse_args()
    if args.stamp:
        return stamp()
    if args.verify:
        return verify(args.restore)
    sys.exit(check())


if __name__ == "__main__":
    main()
