#!/usr/bin/env bash
# rd-motion-deck one-step installer (macOS / Linux / Git Bash on Windows)
#
# Installs, into the agent's skills folder:
#   rd-motion-deck                                  (this repo)
#   motion-explainer, motion-design, review-loop    (mathruffian-dot/claude-motion-explainer, pinned)
#   HyperFrames CLI + official skills (hyperframes*, faceless-explainer, media-use)
#   Python packages: edge-tts, pillow, fonttools, brotli
# then runs an environment check.
#
# Usage (from a clone):  bash install.sh [options]
# Usage (no clone):      curl -fsSL https://raw.githubusercontent.com/tedchen0814/rd-motion-deck/main/install.sh | bash -s -- [options]
#
# Options:
#   --agent claude|codex|both   where to put skills (default claude -> ~/.claude/skills; codex -> ~/.agents/skills)
#   --latest                    use the latest claude-motion-explainer instead of the tested commit
#   --disable-telemetry         turn off HyperFrames anonymous usage statistics
#   --skip-hyperframes          do not install/update the HyperFrames CLI and its skills
#   --check-only                only report what is installed; change nothing
set -euo pipefail

REPO_URL="https://github.com/tedchen0814/rd-motion-deck.git"
ME_REPO_URL="https://github.com/mathruffian-dot/claude-motion-explainer.git"
ME_COMMIT="94dd90b59d06a533afde8566a22e8e954b9df3e8"   # tested 2026-10-25
HYPERFRAMES_VER="0.8.168"
PY_PACKAGES=(edge-tts pillow fonttools brotli)
ME_SKILLS=(motion-explainer motion-design review-loop)
# HyperFrames retired its workflow skills (incl. faceless-explainer, which motion-explainer needs)
# on 2026-10-21 (heygen-com/hyperframes 6882293). Install its skills from the commit just before that.
HF_REPO_URL="https://github.com/heygen-com/hyperframes.git"
HF_COMMIT="207c8a4daf6480d697f203784f1fd422727569e3"
HF_SKILLS=(hyperframes hyperframes-animation hyperframes-audio hyperframes-cli hyperframes-core
           hyperframes-creative hyperframes-keyframes hyperframes-registry hyperframes-studio
           media-use faceless-explainer)

AGENT=claude; LATEST=0; NO_TELEMETRY=0; SKIP_HF=0; CHECK_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --latest) LATEST=1; shift ;;
    --disable-telemetry) NO_TELEMETRY=1; shift ;;
    --skip-hyperframes) SKIP_HF=1; shift ;;
    --check-only) CHECK_ONLY=1; shift ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
done

say()  { printf '\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m[ok]\033[0m   %s\n' "$*"; }
warn() { printf '  \033[33m[warn]\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m[miss]\033[0m %s\n' "$*"; }
has()  { command -v "$1" >/dev/null 2>&1; }

find_python() {
  for c in "py -3" python3 python; do
    set -- $c
    has "$1" || continue
    if v=$("$@" -c 'import sys; print("%d %d" % sys.version_info[:2])' 2>/dev/null); then
      read -r maj min <<<"$v"
      if [ "$maj" = 3 ] && [ "$min" -ge 9 ]; then echo "$c"; return 0; fi
    fi
  done
  return 1
}

# ---------------------------------------------------------------- 1. prerequisites
say "Checking prerequisites"
missing=()
has git && ok "git" || { bad "git"; missing+=(git); }
if has node; then
  nm=$(node --version | sed 's/^v//; s/\..*//')
  [ "$nm" -ge 22 ] && ok "node v$nm" || { bad "node v$nm (need 22+)"; missing+=(node); }
else bad "node"; missing+=(node); fi
has ffmpeg && has ffprobe && ok "ffmpeg / ffprobe" || { bad "ffmpeg / ffprobe"; missing+=(ffmpeg); }
PY=$(find_python || true)
[ -n "$PY" ] && ok "python: $PY" || { bad "python 3.9+"; missing+=(python); }

if [ ${#missing[@]} -gt 0 ] && [ $CHECK_ONLY = 0 ]; then
  echo
  echo "Missing tools: ${missing[*]}. Install them, then run this installer again."
  if has brew; then echo "  brew install git node ffmpeg python"
  elif has apt-get; then echo "  sudo apt-get install -y git ffmpeg python3 python3-pip  # plus Node.js 22+ from https://nodejs.org"
  elif has winget; then echo "  winget install --id Git.Git -e; winget install --id OpenJS.NodeJS.LTS -e; winget install --id Gyan.FFmpeg -e; winget install --id Python.Python.3.12 -e"
  fi
  exit 1
fi

# ---------------------------------------------------------------- 2. skills folders
targets=()
case "$AGENT" in
  claude) targets=("$HOME/.claude/skills") ;;
  codex)  targets=("$HOME/.agents/skills") ;;
  both)   targets=("$HOME/.claude/skills" "$HOME/.agents/skills") ;;
  *) echo "--agent must be claude, codex or both"; exit 2 ;;
esac

if [ $CHECK_ONLY = 1 ]; then
  say "Installed skills"
  for t in "${targets[@]}"; do
    for s in rd-motion-deck "${ME_SKILLS[@]}" "${HF_SKILLS[@]}"; do
      [ -f "$t/$s/SKILL.md" ] && ok "$t/$s" || bad "$t/$s"
    done
  done
  has hyperframes && ok "hyperframes $(hyperframes --version | tail -1)" || bad "hyperframes CLI"
  [ "${HYPERFRAMES_SKIP_SKILLS:-}" = 1 ] && ok "HYPERFRAMES_SKIP_SKILLS=1" || warn "HYPERFRAMES_SKIP_SKILLS is not set: 'hyperframes init' may delete faceless-explainer"
  if [ -n "$PY" ]; then $PY -c "import edge_tts, PIL, fontTools" 2>/dev/null && ok "python packages" || bad "python packages (${PY_PACKAGES[*]})"; fi
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
BACKUP_ROOT="$HOME/.claude/skill-backups/$(date +%Y%m%d-%H%M%S)"

install_skill() {  # src name target
  mkdir -p "$3"
  if [ -e "$3/$2" ]; then
    # Keep backups OUTSIDE the skills folder, or the agent would load two copies of the same skill.
    mkdir -p "$BACKUP_ROOT"
    mv "$3/$2" "$BACKUP_ROOT/$(basename "$(dirname "$3")")-$2"
  fi
  cp -R "$1" "$3/$2"
  ok "$2 -> $3/$2"
}

# ---------------------------------------------------------------- 3. this repo
say "Getting rd-motion-deck"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$HERE" ] && [ -f "$HERE/skills/rd-motion-deck/SKILL.md" ]; then
  REPO="$HERE"; ok "using local copy: $REPO"
else
  REPO="$WORK/rd-motion-deck"
  git -c core.longpaths=true clone --quiet --depth 1 "$REPO_URL" "$REPO"
  ok "cloned $REPO_URL"
fi

# ---------------------------------------------------------------- 4. claude-motion-explainer
say "Getting claude-motion-explainer"
ME="$WORK/claude-motion-explainer"
if [ $LATEST = 1 ]; then
  git -c core.longpaths=true clone --quiet --depth 1 "$ME_REPO_URL" "$ME"
  ok "latest commit $(git -C "$ME" rev-parse --short HEAD)"
else
  mkdir -p "$ME"; git -C "$ME" init --quiet
  git -C "$ME" -c core.longpaths=true fetch --quiet --depth 1 "$ME_REPO_URL" "$ME_COMMIT"
  git -C "$ME" -c core.longpaths=true checkout --quiet FETCH_HEAD
  ok "tested commit ${ME_COMMIT:0:7}"
fi

# ---------------------------------------------------------------- 5. copy skills
say "Installing skills"
for t in "${targets[@]}"; do
  install_skill "$REPO/skills/rd-motion-deck" rd-motion-deck "$t"
  cp "$REPO/LICENSE" "$REPO/NOTICE.md" "$t/rd-motion-deck/"
  for s in "${ME_SKILLS[@]}"; do install_skill "$ME/skills/$s" "$s" "$t"; done
done
[ -d "$BACKUP_ROOT" ] && warn "previous versions were moved to $BACKUP_ROOT"

# ---------------------------------------------------------------- 6. HyperFrames
if [ $SKIP_HF = 0 ]; then
  say "Installing HyperFrames $HYPERFRAMES_VER"
  cur=""; has hyperframes && cur=$(hyperframes --version | tail -1 | tr -d '[:space:]')
  if [ "$cur" = "$HYPERFRAMES_VER" ]; then ok "hyperframes $cur already installed"
  else npm install -g "hyperframes@$HYPERFRAMES_VER"; ok "hyperframes $HYPERFRAMES_VER"; fi
  # Do NOT run "hyperframes skills update": it removes skills that are no longer published,
  # which today includes faceless-explainer.
  say "Installing HyperFrames skills (pinned ${HF_COMMIT:0:7}, includes faceless-explainer)"
  HF="$WORK/hyperframes"; mkdir -p "$HF"; git -C "$HF" init --quiet
  git -C "$HF" config core.longpaths true; git -C "$HF" config core.sparseCheckout true
  echo "/skills/" > "$HF/.git/info/sparse-checkout"
  git -C "$HF" fetch --quiet --depth 1 "$HF_REPO_URL" "$HF_COMMIT"
  git -C "$HF" checkout --quiet FETCH_HEAD
  for t in "${targets[@]}"; do for s in "${HF_SKILLS[@]}"; do install_skill "$HF/skills/$s" "$s" "$t"; done; done
  # "hyperframes init" otherwise re-syncs skills with GitHub on every run and would delete faceless-explainer.
  export HYPERFRAMES_SKIP_SKILLS=1
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ] || [ "$rc" = "$HOME/.bashrc" ]; then
      grep -q 'HYPERFRAMES_SKIP_SKILLS=1' "$rc" 2>/dev/null || echo 'export HYPERFRAMES_SKIP_SKILLS=1  # rd-motion-deck: keep pinned HyperFrames skills' >> "$rc"
    fi
  done
  ok "HYPERFRAMES_SKIP_SKILLS=1 added to shell profile (keeps init from replacing these skills)"
  if command -v setx >/dev/null 2>&1; then setx HYPERFRAMES_SKIP_SKILLS 1 >/dev/null && ok "Windows user environment variable set"; fi
  [ $NO_TELEMETRY = 1 ] && { hyperframes telemetry disable; ok "HyperFrames telemetry disabled"; }
fi

# ---------------------------------------------------------------- 7. Python packages
say "Installing Python packages: ${PY_PACKAGES[*]}"
$PY -m pip install --quiet --disable-pip-version-check "${PY_PACKAGES[@]}" \
  || $PY -m pip install --quiet --disable-pip-version-check --user "${PY_PACKAGES[@]}"
$PY -c "import edge_tts, PIL, fontTools" && ok "python packages"

# ---------------------------------------------------------------- 8. verify
say "Environment check"
for t in "${targets[@]}"; do
  for s in rd-motion-deck "${ME_SKILLS[@]}"; do [ -f "$t/$s/SKILL.md" ] && ok "$s" || bad "$s (in $t)"; done
done
if [ $SKIP_HF = 0 ]; then
  for t in "${targets[@]}"; do for s in "${HF_SKILLS[@]}"; do [ -f "$t/$s/SKILL.md" ] && ok "$s" || bad "$s (in $t)"; done; done
  hyperframes doctor || true
fi

echo
printf '\033[32mDone.\033[0m\n'
echo "Restart your agent (Claude Code / Codex) so it loads the new skills, then try:"
echo "  /rd-motion-deck  (or just describe a tech-sharing deck that needs animations)"
echo "Optional fonts: GenSeki Gothic (https://github.com/ButTaiwan/genseki-font). Without it, decks fall back to Microsoft JhengHei."
