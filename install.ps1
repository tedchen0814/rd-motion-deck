# rd-motion-deck one-step installer (Windows PowerShell 5.1+ / PowerShell 7)
#
# Installs, into the agent's skills folder:
#   rd-motion-deck                         (this repo)
#   motion-explainer, motion-design, review-loop   (mathruffian-dot/claude-motion-explainer, pinned)
#   HyperFrames CLI + official skills (hyperframes*, faceless-explainer, media-use)
#   Python packages: edge-tts, pillow, fonttools, brotli
# then runs an environment check.
#
# Usage (from a clone):   powershell -ExecutionPolicy Bypass -File .\install.ps1 [options]
# Usage (no clone):       & ([scriptblock]::Create((irm https://raw.githubusercontent.com/tedchen0814/rd-motion-deck/main/install.ps1))) [options]
#
# Options:
#   -Agent claude|codex|both   where to put skills (default: claude -> ~\.claude\skills; codex -> ~\.agents\skills)
#   -InstallPrereqs            install missing Git / Node.js / ffmpeg / Python with winget
#   -Latest                    use the latest claude-motion-explainer instead of the tested commit
#   -DisableTelemetry          turn off HyperFrames anonymous usage statistics
#   -SkipHyperFrames           do not install/update the HyperFrames CLI and its skills
#   -CheckOnly                 only report what is installed; change nothing

[CmdletBinding()]
param(
  [ValidateSet("claude", "codex", "both")] [string]$Agent = "claude",
  [switch]$InstallPrereqs,
  [switch]$Latest,
  [switch]$DisableTelemetry,
  [switch]$SkipHyperFrames,
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

# ---- versions this repo was tested with ----
$RepoUrl        = "https://github.com/tedchen0814/rd-motion-deck.git"
$MeRepoUrl      = "https://github.com/mathruffian-dot/claude-motion-explainer.git"
$MeCommit       = "94dd90b59d06a533afde8566a22e8e954b9df3e8"   # tested 2026-10-25
$HyperFramesVer = "0.8.168"
$PyPackages     = @("edge-tts", "pillow", "fonttools", "brotli")
$MeSkills       = @("motion-explainer", "motion-design", "review-loop")
# HyperFrames retired its workflow skills (incl. faceless-explainer, which motion-explainer needs)
# on 2026-10-21 (heygen-com/hyperframes 6882293). Install its skills from the commit just before that.
$HfRepoUrl      = "https://github.com/heygen-com/hyperframes.git"
$HfCommit       = "207c8a4daf6480d697f203784f1fd422727569e3"
$HfSkills       = @("hyperframes", "hyperframes-animation", "hyperframes-audio", "hyperframes-cli", "hyperframes-core",
                    "hyperframes-creative", "hyperframes-keyframes", "hyperframes-registry", "hyperframes-studio",
                    "media-use", "faceless-explainer")

function Say($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [warn] $msg" -ForegroundColor Yellow }
function Bad($msg)  { Write-Host "  [miss] $msg" -ForegroundColor Red }

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

function Has($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Find-Python {
  # The Microsoft Store "python" stub exits with code 49, so test each candidate for real.
  $candidates = @(@("py", "-3"), @("python"), @("python3"))
  foreach ($c in $candidates) {
    if (-not (Has $c[0])) { continue }
    try {
      $pyArgs = @()
      if ($c.Count -gt 1) { $pyArgs += $c[1..($c.Count - 1)] }
      $v = & $c[0] @pyArgs -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
      if ($LASTEXITCODE -eq 0 -and $v -match '^3\.(\d+)$' -and [int]$Matches[1] -ge 9) { return ,$c }
    } catch { }
  }
  return $null
}

function Node-Major {
  if (-not (Has "node")) { return 0 }
  $v = (& node --version) -replace '^v', ''
  return [int]($v.Split('.')[0])
}

# ---------------------------------------------------------------- 1. prerequisites
Say "Checking prerequisites"
$missing = @()
if (Has "git") { Ok "git $((& git --version) -replace 'git version ', '')" } else { Bad "git"; $missing += "git" }
$nm = Node-Major
if ($nm -ge 22) { Ok "node v$nm" } elseif ($nm -gt 0) { Bad "node v$nm (need 22+)"; $missing += "node" } else { Bad "node"; $missing += "node" }
if ((Has "ffmpeg") -and (Has "ffprobe")) { Ok "ffmpeg / ffprobe" } else { Bad "ffmpeg / ffprobe"; $missing += "ffmpeg" }
$py = Find-Python
if ($py) { Ok "python: $($py -join ' ')" } else { Bad "python 3.9+"; $missing += "python" }

$winget = @{ git = "Git.Git"; node = "OpenJS.NodeJS.LTS"; ffmpeg = "Gyan.FFmpeg"; python = "Python.Python.3.12" }
if ($missing.Count -gt 0) {
  if ($CheckOnly) {
    Warn "missing: $($missing -join ', ')"
  } elseif ($InstallPrereqs -and (Has "winget")) {
    foreach ($m in $missing) {
      Say "Installing $m with winget ($($winget[$m]))"
      & winget install --id $winget[$m] -e --accept-source-agreements --accept-package-agreements
    }
    Refresh-Path
    $py = Find-Python
    if (-not (Has "git") -or (Node-Major) -lt 22 -or -not (Has "ffmpeg") -or -not $py) {
      Write-Host ""
      Warn "Some tools are still not on PATH. Open a NEW terminal and run this installer again."
      exit 1
    }
  } else {
    Write-Host ""
    Write-Host "Missing tools: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Install them, then run this installer again. With winget:"
    foreach ($m in $missing) { Write-Host "  winget install --id $($winget[$m]) -e" }
    Write-Host "Or rerun with -InstallPrereqs to let this script do it."
    exit 1
  }
}

# ---------------------------------------------------------------- 2. skills folders
$targets = @()
if ($Agent -in @("claude", "both")) { $targets += (Join-Path $HOME ".claude\skills") }
if ($Agent -in @("codex", "both"))  { $targets += (Join-Path $HOME ".agents\skills") }

if ($CheckOnly) {
  Say "Installed skills"
  foreach ($t in $targets) {
    foreach ($s in @("rd-motion-deck") + $MeSkills + $HfSkills) {
      if (Test-Path (Join-Path $t "$s\SKILL.md")) { Ok "$t\$s" } else { Bad "$t\$s" }
    }
  }
  if (Has "hyperframes") { Ok "hyperframes $((& hyperframes --version) | Select-Object -Last 1)" } else { Bad "hyperframes CLI" }
  if ([Environment]::GetEnvironmentVariable("HYPERFRAMES_SKIP_SKILLS", "User") -eq "1") { Ok "HYPERFRAMES_SKIP_SKILLS=1" }
  else { Warn "HYPERFRAMES_SKIP_SKILLS is not set: 'hyperframes init' may delete faceless-explainer" }
  if ($py) {
    $pa = @(); if ($py.Count -gt 1) { $pa += $py[1..($py.Count - 1)] }
    & $py[0] @pa -c "import edge_tts, PIL, fontTools" 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "python packages" } else { Bad "python packages ($($PyPackages -join ', '))" }
  }
  exit 0
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("rd-motion-deck-install-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$backupRoot = Join-Path $HOME (".claude\skill-backups\" + (Get-Date -Format "yyyyMMdd-HHmmss"))

function Install-SkillDir($src, $name, $target) {
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  $dst = Join-Path $target $name
  if (Test-Path $dst) {
    # Keep backups OUTSIDE the skills folder, or the agent would load two copies of the same skill.
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    Move-Item -Path $dst -Destination (Join-Path $backupRoot ((Split-Path $target -Parent | Split-Path -Leaf) + "-" + $name))
  }
  Copy-Item -Recurse -Path $src -Destination $dst
  Ok "$name -> $dst"
}

try {
  # ---------------------------------------------------------------- 3. this repo
  Say "Getting rd-motion-deck"
  $here = $PSScriptRoot
  if ($here -and (Test-Path (Join-Path $here "skills\rd-motion-deck\SKILL.md"))) {
    $repo = $here
    Ok "using local copy: $repo"
  } else {
    $repo = Join-Path $work "rd-motion-deck"
    & git -c core.longpaths=true clone --quiet --depth 1 $RepoUrl $repo
    if ($LASTEXITCODE -ne 0) { throw "git clone $RepoUrl failed" }
    Ok "cloned $RepoUrl"
  }

  # ---------------------------------------------------------------- 4. claude-motion-explainer
  Say "Getting claude-motion-explainer"
  $me = Join-Path $work "claude-motion-explainer"
  if ($Latest) {
    & git -c core.longpaths=true clone --quiet --depth 1 $MeRepoUrl $me
    if ($LASTEXITCODE -ne 0) { throw "git clone $MeRepoUrl failed" }
    Ok "latest commit $((& git -C $me rev-parse --short HEAD))"
  } else {
    New-Item -ItemType Directory -Force -Path $me | Out-Null
    & git -C $me init --quiet
    & git -C $me -c core.longpaths=true fetch --quiet --depth 1 $MeRepoUrl $MeCommit
    if ($LASTEXITCODE -ne 0) { throw "git fetch $MeRepoUrl $MeCommit failed" }
    & git -C $me -c core.longpaths=true checkout --quiet FETCH_HEAD
    Ok "tested commit $($MeCommit.Substring(0, 7))"
  }

  # ---------------------------------------------------------------- 5. copy skills
  Say "Installing skills"
  foreach ($t in $targets) {
    Install-SkillDir (Join-Path $repo "skills\rd-motion-deck") "rd-motion-deck" $t
    Copy-Item (Join-Path $repo "LICENSE") (Join-Path $t "rd-motion-deck\LICENSE") -Force
    Copy-Item (Join-Path $repo "NOTICE.md") (Join-Path $t "rd-motion-deck\NOTICE.md") -Force
    foreach ($s in $MeSkills) { Install-SkillDir (Join-Path $me "skills\$s") $s $t }
  }
  if (Test-Path $backupRoot) { Warn "previous versions were moved to $backupRoot" }

  # ---------------------------------------------------------------- 6. HyperFrames
  if (-not $SkipHyperFrames) {
    Say "Installing HyperFrames $HyperFramesVer"
    $cur = ""
    if (Has "hyperframes") { $cur = ((& hyperframes --version) | Select-Object -Last 1).Trim() }
    if ($cur -eq $HyperFramesVer) {
      Ok "hyperframes $cur already installed"
    } else {
      & npm install -g "hyperframes@$HyperFramesVer"
      if ($LASTEXITCODE -ne 0) { throw "npm install -g hyperframes@$HyperFramesVer failed" }
      Refresh-Path
      Ok "hyperframes $HyperFramesVer"
    }
    # Do NOT run "hyperframes skills update": it removes skills that are no longer published,
    # which today includes faceless-explainer.
    Say "Installing HyperFrames skills (pinned $($HfCommit.Substring(0, 7)), includes faceless-explainer)"
    $hf = Join-Path $work "hyperframes"
    New-Item -ItemType Directory -Force -Path $hf | Out-Null
    & git -C $hf init --quiet
    & git -C $hf config core.longpaths true
    & git -C $hf config core.sparseCheckout true
    Set-Content -Path (Join-Path $hf ".git\info\sparse-checkout") -Value "/skills/" -Encoding ascii
    & git -C $hf fetch --quiet --depth 1 $HfRepoUrl $HfCommit
    if ($LASTEXITCODE -ne 0) { throw "git fetch $HfRepoUrl $HfCommit failed" }
    & git -C $hf checkout --quiet FETCH_HEAD
    foreach ($t in $targets) {
      foreach ($s in $HfSkills) { Install-SkillDir (Join-Path $hf "skills\$s") $s $t }
    }
    # "hyperframes init" otherwise re-syncs skills with GitHub on every run and would delete faceless-explainer.
    [Environment]::SetEnvironmentVariable("HYPERFRAMES_SKIP_SKILLS", "1", "User")
    $env:HYPERFRAMES_SKIP_SKILLS = "1"
    Ok "user environment variable HYPERFRAMES_SKIP_SKILLS=1 (keeps init from replacing these skills)"
    if ($DisableTelemetry) { & hyperframes telemetry disable; Ok "HyperFrames telemetry disabled" }
  }

  # ---------------------------------------------------------------- 7. Python packages
  Say "Installing Python packages: $($PyPackages -join ', ')"
  $pa = @(); if ($py.Count -gt 1) { $pa += $py[1..($py.Count - 1)] }
  & $py[0] @pa -m pip install --quiet --disable-pip-version-check @PyPackages
  if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
  & $py[0] @pa -c "import edge_tts, PIL, fontTools; print('ok')" | Out-Null
  Ok "python packages"

  # ---------------------------------------------------------------- 8. verify
  Say "Environment check"
  foreach ($t in $targets) {
    foreach ($s in @("rd-motion-deck") + $MeSkills) {
      if (Test-Path (Join-Path $t "$s\SKILL.md")) { Ok "$s" } else { Bad "$s (in $t)" }
    }
  }
  if (-not $SkipHyperFrames) {
    foreach ($t in $targets) {
      foreach ($s in $HfSkills) {
        if (Test-Path (Join-Path $t "$s\SKILL.md")) { Ok "$s" } else { Bad "$s (in $t)" }
      }
    }
  }
  if (-not $SkipHyperFrames) { & hyperframes doctor }

  Write-Host ""
  Write-Host "Done." -ForegroundColor Green
  Write-Host "Restart your agent (Claude Code / Codex) so it loads the new skills, then try:"
  Write-Host "  /rd-motion-deck  (or just describe a tech-sharing deck that needs animations)"
  Write-Host "Optional fonts: GenSeki Gothic (https://github.com/ButTaiwan/genseki-font). Without it, decks fall back to Microsoft JhengHei."
} finally {
  Remove-Item -Recurse -Force -Path $work -ErrorAction SilentlyContinue
}
