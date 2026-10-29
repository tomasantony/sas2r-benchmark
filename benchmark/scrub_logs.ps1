<#
.SYNOPSIS
  Remove licence-holder, site and machine identifiers from SAS logs and listings before they are published.
.DESCRIPTION
  SAS writes "Licensed to <HOLDER>, Site <NUMBER>." and "executing on the <PLATFORM> platform" into every log.
  This script rewrites those lines in place (default) or, with -Check, only reports files that still contain
  them and exits 1, so it can serve as a pre-publish gate.
.EXAMPLE
  .\scrub_logs.ps1                       # scrub output\ and benchmark\ under the repo root
  .\scrub_logs.ps1 -Check                # report only; exit code 1 if anything is left
  .\scrub_logs.ps1 -Roots 'D:\somewhere' # scrub another tree
#>
param(
  [string[]]$Roots,
  [switch]$Check,
  [string[]]$Extensions = @('*.log', '*.lst', '*.txt', '*.md', '*.csv')
)
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Roots) { $Roots = @((Join-Path $RepoRoot 'output'), (Join-Path $RepoRoot 'benchmark'), (Join-Path $RepoRoot 'docs')) }

# Patterns that identify a licence holder, site or machine. Keep them generic so any licence is caught.
$patterns = @(
  @{ re = '^(\s*)Licensed to .*?, Site \d+\.\s*$';            rep = '$1Licensed to [licence holder removed], Site [removed].' },
  @{ re = 'executing on the \S+\s+platform';                   rep = 'executing on the [platform removed] platform' },
  @{ re = 'NORTH CAROLINA STATE UNIVERSITY[^,\r\n]*';           rep = '[licence holder removed]' },
  @{ re = '\b70085778\b';                                       rep = '[site removed]' },
  @{ re = '^(\s*)X64_\S+\s+WIN\s+[\d.]+.*$';            rep = '$1[platform removed]' }
)
$detect = '(?im)Licensed to [^\r\n]*Site \d+|NORTH CAROLINA STATE|\b70085778\b|executing on the X64_\S+|^\s*X64_\S+\s+WIN\s'

$files = foreach ($r in $Roots) { if (Test-Path $r) { Get-ChildItem $r -Recurse -File -Include $Extensions } }
$hit = 0; $changed = 0
foreach ($f in $files) {
  $text = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
  if ($null -eq $text) { continue }
  if ($text -match $detect) {
    $hit++
    if ($Check) { Write-Host "contains identifiers: $($f.FullName)"; continue }
    $new = $text
    foreach ($p in $patterns) { $new = [regex]::Replace($new, $p.re, $p.rep, [System.Text.RegularExpressions.RegexOptions]::Multiline) }
    if ($new -ne $text) { [System.IO.File]::WriteAllText($f.FullName, $new); $changed++ }
  }
}
if ($Check) {
  if ($hit -gt 0) { Write-Host "$hit file(s) still contain licence/site/machine identifiers"; exit 1 }
  Write-Host 'clean: no licence, site or machine identifiers found'; exit 0
}
Write-Host "scanned $(@($files).Count) files, $hit contained identifiers, $changed rewritten"

