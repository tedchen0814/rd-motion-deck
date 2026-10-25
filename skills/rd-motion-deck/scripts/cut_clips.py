"""Cut one clip per animated slide out of the silent render, plus a poster PNG for each.

Each storyboard frame is a scene in index.html: id="el-<frame>", data-composition-src=
"compositions/frames/<frame>.html", data-start, data-duration. A transition (crossfade, push-slide,
zoom-through, blur-crossfade, ...) is the time two neighbouring scenes overlap, whatever its type.
So each clip runs from the END of the overlap with the previous scene to the START of the overlap
with the next one, and never shows a neighbour. Hard cuts have no overlap and need no trimming.

  python cut_clips.py --project <film> --video <film>-silent/renders/silent.mp4 \
      --map p03=02-squares p06=04-proof p09=06-myths@first --out <film>/deck/media

NAME=FRAME[@POSTER]: FRAME is the storyboard frame's file name without .html (the `src` in
STORYBOARD.md), e.g. compositions/frames/04-proof.html -> 04-proof. POSTER, per clip, overrides
--poster: last (default, the settled conclusion), first, or seconds into the clip (e.g. 2.5).
Writes <name>.mp4 (H.264, yuv420p, no audio, faststart: plays in PowerPoint and Keynote) and
<name>.png, and prints a duration table to paste into the speaker notes.
Tested with HyperFrames 0.8.168 (assemble-index.mjs / transitions.mjs of the faceless-explainer skill).
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path
sys.stdout.reconfigure(errors="replace")  # never crash printing Chinese or accented names on a non-UTF-8 console


def scenes(index_html):
    """[(frame, start, end)] for every storyboard frame scene, sorted by start."""
    out = []
    for m in re.finditer(r"<div\b[^>]*>", index_html):
        tag = m.group(0)
        idm = re.search(r'\bid="el-([^"]+)"', tag)
        src = re.search(r'\bdata-composition-src="([^"]+)"', tag)
        st = re.search(r'\bdata-start="([\d.]+)"', tag)
        du = re.search(r'\bdata-duration="([\d.]+)"', tag)
        if idm and src and st and du and "/frames/" in src.group(1):
            s = float(st.group(1))
            out.append((idm.group(1), s, s + float(du.group(1))))
    return sorted(out, key=lambda x: x[1])


def window(sc, frame):
    i = [f for f, _, _ in sc].index(frame)
    _, s, e = sc[i]
    t0 = max([s] + [pe for _, ps, pe in sc[:i] if pe > s])          # end of overlap with earlier scenes
    t1 = min([e] + [ns for _, ns, _ in sc[i + 1:] if ns < e])       # start of overlap with later scenes
    return t0, t1


def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode:
        sys.exit(r.stderr[-2000:])
    return r.stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--project", required=True, help="narrated project (its index.html gives the timing)")
    ap.add_argument("--video", required=True, help="silent render of the twin project")
    ap.add_argument("--map", nargs="+", required=True, metavar="NAME=FRAME[@POSTER]", help="e.g. p03=02-squares")
    ap.add_argument("--out", required=True, help="output folder, usually <film>/deck/media")
    ap.add_argument("--poster", default="last", help="default poster for every clip: last | first | <seconds>")
    ap.add_argument("--crf", type=int, default=20)
    a = ap.parse_args()

    sc = scenes((Path(a.project) / "index.html").read_text(encoding="utf-8"))
    if not sc:
        sys.exit("no storyboard frame scenes (compositions/frames/*.html) found in index.html")
    known = [f for f, _, _ in sc]
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    print(f"{'clip':<8}{'frame':<22}{'from':>8}{'to':>8}{'len':>7}  poster")
    for pair in a.map:
        if "=" not in pair:
            sys.exit(f"--map entry '{pair}' must look like NAME=FRAME, e.g. p03=02-squares")
        name, frame = pair.split("=", 1)
        frame, _, poster = frame.partition("@")
        poster = poster or a.poster
        if frame not in known:
            sys.exit(f"frame '{frame}' not in index.html; known frames: {', '.join(known)}")
        t0, t1 = window(sc, frame)
        length = t1 - t0
        if length < 0.5:
            sys.exit(f"{frame}: only {length:.2f} s left between its transitions — make the frame longer")
        mp4, png = out / f"{name}.mp4", out / f"{name}.png"
        run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t0:.3f}", "-to", f"{t1:.3f}", "-i", a.video, "-an",
             "-c:v", "libx264", "-crf", str(a.crf), "-preset", "slow", "-pix_fmt", "yuv420p",
             "-movflags", "+faststart", str(mp4)])
        if poster == "last":
            seek = ["-sseof", "-0.1"]
        elif poster == "first":
            seek = ["-ss", "0"]
        else:
            try:
                at = float(poster)
            except ValueError:
                sys.exit(f"poster '{poster}' must be last, first or seconds")
            seek = ["-ss", f"{min(max(at, 0.0), max(length - 0.1, 0.0)):.3f}"]
        run(["ffmpeg", "-v", "error", "-y", *seek, "-i", str(mp4), "-frames:v", "1", "-update", "1", str(png)])
        if not png.exists():
            sys.exit(f"poster for {name} was not written")
        print(f"{name:<8}{frame:<22}{t0:>8.2f}{t1:>8.2f}{length:>6.1f}s  {poster}")


if __name__ == "__main__":
    main()
