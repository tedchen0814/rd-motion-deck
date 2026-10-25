# Installing rd-motion-deck — instructions for AI agents

Follow these steps when the user asks you to install this repo (for example: "install this skill: https://github.com/tedchen0814/rd-motion-deck"). Talk to the user in their language (Traditional Chinese if they wrote in Chinese).

## What gets installed

- Skill `rd-motion-deck` (this repo)
- Skills `motion-explainer`, `motion-design`, `review-loop` from mathruffian-dot/claude-motion-explainer, at a tested commit
- HyperFrames CLI 0.8.168 (npm, global)
- 11 HyperFrames skills (`hyperframes`, `hyperframes-*`, `media-use`, `faceless-explainer`) from heygen-com/hyperframes at commit `207c8a4`, the last commit before HyperFrames retired `faceless-explainer` (which motion-explainer needs)
- User environment variable `HYPERFRAMES_SKIP_SKILLS=1`, so `hyperframes init` does not re-sync and replace those skills
- Python packages `edge-tts`, `pillow`, `fonttools`, `brotli`

Existing skills with the same names are moved to `~/.claude/skill-backups/<timestamp>/`, not deleted.

**Never run `hyperframes skills update`** for this setup: it deletes skills that are no longer published, including `faceless-explainer`. If it was run by mistake, run this installer again.

## Steps

1. **Pick the skills folder.** Claude Code → default (`~/.claude/skills`). Codex → add `-Agent codex` / `--agent codex`. If unsure, ask the user.

2. **Check first, change nothing.** Run the installer in check mode and read its output:
   - Windows (PowerShell):
     ```powershell
     & ([scriptblock]::Create((irm https://raw.githubusercontent.com/tedchen0814/rd-motion-deck/main/install.ps1))) -CheckOnly
     ```
   - macOS / Linux / Git Bash:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/tedchen0814/rd-motion-deck/main/install.sh | bash -s -- --check-only
     ```

3. **Missing prerequisites (Git, Node.js 22+, ffmpeg, Python 3.9+)?** Tell the user what is missing. Installing system software needs the user's OK. On Windows, with their OK, rerun with `-InstallPrereqs` (uses winget). On macOS/Linux, give them the `brew` / `apt-get` command the script prints, or run it if they agree.

4. **Ask about telemetry once.** HyperFrames sends anonymous usage statistics by default. If the user wants it off, add `-DisableTelemetry` / `--disable-telemetry`.

5. **Run the installer** (same command as step 2, without the check flag). It takes a few minutes (npm + pip + HyperFrames skills). Use a timeout of at least 10 minutes. Tell the user it sets the user environment variable `HYPERFRAMES_SKIP_SKILLS=1` (see above for why).

6. **Report** the "Environment check" section: every skill should show `[ok]`. `hyperframes doctor` failures for whisper-cpp, Kokoro, MusicGen and Docker are optional components and can be ignored.

7. **Tell the user to restart the agent** so the new skills load, and give one example:
   ```text
   /rd-motion-deck 下週讀書會分享 ESD 防護設計，30 分鐘，聽眾是 EE 和 ME，放電路徑那頁要做成動畫
   ```

## If something fails

- `git clone` fails with "Filename too long" (Windows): the script already sets `core.longpaths=true`; if it still fails, run `git config --global core.longpaths true` with the user's OK and retry.
- "is not digitally signed" (Windows): group policy enforces `RemoteSigned`, which `-ExecutionPolicy Bypass` cannot override, for scripts on network or cloud drives. Use the `irm` scriptblock one-liner (it does not run a file), or clone the repo to a local disk such as `C:\` and run it there.
- `python` exits with code 49 (Windows): that is the Microsoft Store stub. The script tries `py -3` first; if no real Python exists, install one (step 3).
- `npm install -g` permission error (macOS/Linux): do not use `sudo` without asking; suggest fixing npm's global prefix (`npm config set prefix ~/.npm-global` and adding it to PATH).
- Behind a proxy or without internet: the installer needs github.com, raw.githubusercontent.com, registry.npmjs.org and pypi.org.

Do not edit the downloaded skill files during installation.
