"""Copy a finished motion-explainer project into a silent, caption-free twin for slide embedding.

The twin keeps every frame, transition and timing of the narrated film, so clips cut from it line
up with the film second for second. Only the voice/BGM/SFX <audio> tracks and the captions
composition are removed from index.html.

  python make_silent.py --project <film> [--out <film>-silent]
  cd <film>-silent && hyperframes render --quality high --output renders/silent.mp4

Re-run after every change to the film (frames, theme, durations): the twin is a snapshot.
"""
import argparse
import re
import shutil
import sys
from pathlib import Path
sys.stdout.reconfigure(errors="replace")  # never crash printing Chinese or accented names on a non-UTF-8 console

SKIP = ("renders", "review", "deck", "node_modules", "voice", ".git", "capture")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--project", required=True, help="narrated motion-explainer project")
    ap.add_argument("--out", help="twin folder (default: <project>-silent)")
    a = ap.parse_args()
    src = Path(a.project).resolve()
    dst = Path(a.out).resolve() if a.out else src.with_name(src.name + "-silent")
    if not (src / "index.html").exists():
        sys.exit(f"no index.html in {src}")
    if dst == src or src in dst.parents or dst in src.parents:
        sys.exit(f"--out must be a separate folder next to the project, not {dst}")
    if dst.exists():
        if not (dst / "index.html").exists():
            sys.exit(f"{dst} exists and is not a previous twin (no index.html); remove it yourself")
        shutil.rmtree(dst)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*SKIP))

    p = dst / "index.html"
    t = p.read_text(encoding="utf-8")
    t, n_audio = re.subn(r"\s*<audio\b.*?</audio>", "", t, flags=re.S)
    t, n_cap = re.subn(r'\s*(?:<!-- captions -->\s*)?<div\b[^>]*\bid="el-captions".*?</div>', "", t, flags=re.S)
    p.write_text(t, encoding="utf-8")
    print(f"{dst}\n  removed {n_audio} audio track(s), {n_cap} captions block(s)")
    if n_cap == 0:
        print("  note: no captions block found (fine if the film has no captions)")


if __name__ == "__main__":
    main()
