# Export every slide of a .pptx to PNG through PowerPoint (for layout review).
param([string]$Pptx, [string]$OutDir, [int]$Width = 1280)
$ErrorActionPreference = "Stop"
$pp = New-Object -ComObject PowerPoint.Application
try {
  $pres = $pp.Presentations.Open((Resolve-Path $Pptx).Path, $true, $false, $false)  # read-only, no window
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $h = [int]($Width * 9 / 16)
  for ($i = 1; $i -le $pres.Slides.Count; $i++) {
    $pres.Slides.Item($i).Export((Join-Path (Resolve-Path $OutDir).Path ("slide{0:D2}.png" -f $i)), "PNG", $Width, $h)
  }
  "exported $($pres.Slides.Count) slides"
  $pres.Close()
} finally {
  $pp.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($pp) | Out-Null
}
