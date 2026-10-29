<#
.SYNOPSIS
  Audit every reference output: log status, files written, file integrity, RTF page fit, listing width, dataset rows.
.DESCRIPTION
  Writes benchmark\output_audit.csv (one row per produced file plus one 'log' row per program) and prints a summary.
  Dataset row counts come from benchmark\dataset_obs.csv if present (produced by audit_datasets.sas).
  Checks: log has no ERROR; every file the log says it wrote exists; RTF/PDF/PNG/HTML files are complete;
  RTF tables are no wider than the printable page (catches portrait pages that cut off wide tables);
  listings that hit the 132-column line size; datasets with zero rows; programs that produced nothing.
#>
$Root = Split-Path -Parent $PSScriptRoot
$Out  = Join-Path $Root 'output\sas'
$rows = New-Object System.Collections.Generic.List[string]
$obs = @{}
$obsFile = Join-Path $PSScriptRoot 'dataset_obs.csv'
if (Test-Path $obsFile) { Import-Csv $obsFile | ForEach-Object { $obs[$_.path.ToLower()] = "$($_.nobs) obs, $($_.nvar) vars" } }

function Add-Row($id, $file, $type, $bytes, $check, $detail) {
  $rows.Add(('{0},{1},{2},{3},{4},"{5}"' -f $id, $file, $type, $bytes, $check, ($detail -replace '"', "'")))
}
function Test-Rtf($id, $f) {
  $t = Get-Content $f.FullName -Raw
  $ok = $t.TrimEnd().EndsWith('}')
  $land = ([regex]::Matches($t, '\\lndscpsxn')).Count -gt 0
  $paperw = if ($t -match '\\paperw(\d+)') { [int]$Matches[1] } else { 12240 }
  $margl  = if ($t -match '\\margl(\d+)')  { [int]$Matches[1] } else { 1800 }
  $margr  = if ($t -match '\\margr(\d+)')  { [int]$Matches[1] } else { 1800 }
  if ($land -and $paperw -eq 12240) { $paperw = 15840 }
  $usable = $paperw - $margl - $margr
  $cells  = [regex]::Matches($t, '\\cellx(-?\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
  $maxcell = if ($cells) { ($cells | Measure-Object -Maximum).Maximum } else { 0 }
  $tables = ([regex]::Matches($t, '\\trowd')).Count
  $pics = ([regex]::Matches($t, '\\pict')).Count
  $detail = "orientation=$(if ($land) {'landscape'} else {'portrait'}); usable=$usable twips; widest row=$maxcell twips; rows=$tables; images=$pics"
  if (-not $ok) { Add-Row $id $f.Name 'rtf' $f.Length 'FAIL-truncated-file' $detail }
  elseif ($maxcell -gt $usable) { Add-Row $id $f.Name 'rtf' $f.Length 'FAIL-wider-than-page' $detail }
  elseif ($tables -eq 0 -and $pics -eq 0) { Add-Row $id $f.Name 'rtf' $f.Length 'WARN-no-table-no-image' $detail }
  else { Add-Row $id $f.Name 'rtf' $f.Length 'ok' $detail }
}
function Test-Pdf($id, $f) {
  $b = [System.IO.File]::ReadAllBytes($f.FullName)
  $tail = [System.Text.Encoding]::ASCII.GetString($b, [Math]::Max(0, $b.Length-64), [Math]::Min(64, $b.Length))
  $t = [System.Text.Encoding]::ASCII.GetString($b); $pages = ([regex]::Matches($t, '/Type\s*/Page[^s]')).Count
  if ($tail -notmatch '%%EOF') { Add-Row $id $f.Name 'pdf' $f.Length 'FAIL-truncated-file' "pages=$pages" } else { Add-Row $id $f.Name 'pdf' $f.Length 'ok' "pages=$pages" }
}
function Test-Png($id, $f) {
  $b = [System.IO.File]::ReadAllBytes($f.FullName)
  $sig = ($b.Length -ge 8 -and $b[0] -eq 0x89 -and $b[1] -eq 0x50)
  $end = $b.Length -ge 8 -and [System.Text.Encoding]::ASCII.GetString($b, $b.Length-8, 8) -match 'IEND'
  if ($sig -and $end) { Add-Row $id $f.Name 'png' $f.Length 'ok' '' } else { Add-Row $id $f.Name 'png' $f.Length 'FAIL-bad-png' "signature=$sig iend=$end" }
}
function Test-Html($id, $f) {
  $t = Get-Content $f.FullName -Raw
  if ($t -match '</html>\s*$') { Add-Row $id $f.Name 'html' $f.Length 'ok' "tables=$(([regex]::Matches($t,'<table')).Count)" } else { Add-Row $id $f.Name 'html' $f.Length 'FAIL-truncated-file' '' }
}
function Test-Lst($id, $f) {
  if ($f.Length -eq 0) { Add-Row $id $f.Name 'lst' 0 'empty' 'no listing output'; return }
  $lines = Get-Content $f.FullName; $max = ($lines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
  $pages = ($lines | Where-Object { $_ -match '^\f' }).Count + 1
  $check = if ($max -ge 132) { 'WARN-at-linesize-limit' } else { 'ok' }
  Add-Row $id $f.Name 'lst' $f.Length $check "max line=$max; pages=$pages"
}
function Test-Other($id, $f) {
  $ext = $f.Extension.TrimStart('.').ToLower()
  if ($f.Length -eq 0) { Add-Row $id $f.Name $ext 0 'FAIL-empty-file' ''; return }
  switch ($ext) {
    'sas7bdat' { $k = ("datasets/{0}/{1}" -f $id, $f.Name).ToLower(); $d = if ($obs.ContainsKey($k)) { $obs[$k] } else { 'not profiled' }
                 $c = if ($d -match '^0 obs') { 'WARN-zero-obs' } else { 'ok' }; Add-Row $id $f.Name $ext $f.Length $c $d }
    'rtf'  { Test-Rtf $id $f }
    'pdf'  { Test-Pdf $id $f }
    'png'  { Test-Png $id $f }
    'gif'  { Add-Row $id $f.Name $ext $f.Length 'ok' '' }
    'html' { Test-Html $id $f }
    'htm'  { Test-Html $id $f }
    'xlsx' { $b = [System.IO.File]::ReadAllBytes($f.FullName); $c = if ($b[0] -eq 0x50 -and $b[1] -eq 0x4B) {'ok'} else {'FAIL-bad-xlsx'}; Add-Row $id $f.Name $ext $f.Length $c '' }
    'xpt'  { Add-Row $id $f.Name $ext $f.Length 'ok' '' }
    default { Add-Row $id $f.Name $ext $f.Length 'ok' 'not inspected' }
  }
}

$manifest = Import-Csv (Join-Path $PSScriptRoot 'manifest.csv')
foreach ($m in $manifest) {
  $id = $m.id
  $log = Join-Path $Out "logs\$id.log"
  if (-not (Test-Path $log)) { Add-Row $id "$id.log" 'log' 0 'FAIL-missing-log' ''; continue }
  $lt = Get-Content $log
  $errs = ($lt | Where-Object { $_ -match '^ERROR' }).Count; $warns = ($lt | Where-Object { $_ -match '^WARNING' }).Count
  $written = $lt | Where-Object { $_ -match '^NOTE: (Writing|.*written to|.*output to)' } | ForEach-Object { $_ -replace '^NOTE:\s*', '' } | Select-Object -Unique
  $c = if ($errs -gt 0) { 'FAIL-errors' } elseif ($warns -gt 0) { 'warnings' } else { 'ok' }
  Add-Row $id "$id.log" 'log' (Get-Item $log).Length $c ("errors=$errs warnings=$warns; declared=$($m.outputs); writes=" + ($written -join ' | '))
  $lst = Join-Path $Out "logs\$id.lst"; if (Test-Path $lst) { Test-Lst $id (Get-Item $lst) }
  $dir = Join-Path $Out "datasets\$id"
  if (Test-Path $dir) { Get-ChildItem $dir -File | Where-Object { $_.Extension -ne '.sas7bndx' } | ForEach-Object { Test-Other $id $_ } }
  foreach ($w in $written) {
    if ($w -match '([A-Za-z]:[^"'' ]+\.(rtf|pdf|png|html?|xlsx|docx|xml|csv))') {
      $p = $Matches[1]
      if ($p -match '[\\/]tlf[\\/]') { if (Test-Path $p) { Test-Other $id (Get-Item $p) } else { Add-Row $id (Split-Path $p -Leaf) 'tlf' 0 'FAIL-missing-file' $p } }
    }
  }
}
foreach ($m in $manifest) {
  $id = $m.id
  $n = ($rows | Where-Object { $_ -like "$id,*" -and $_ -notlike "$id,$id.log,*" -and $_ -notmatch ',lst,0,empty,' }).Count
  if ($n -eq 0) { Add-Row $id '' 'none' 0 'FAIL-no-output' "declared=$($m.outputs)" }
}
@('id,file,type,bytes,check,detail') + $rows | Set-Content (Join-Path $PSScriptRoot 'output_audit.csv') -Encoding utf8
$all = Import-Csv (Join-Path $PSScriptRoot 'output_audit.csv')
"rows: $($all.Count)"
$all | Group-Object check | Sort-Object Name | ForEach-Object { "{0,-26} {1}" -f $_.Name, $_.Count }
"--- problems ---"
$all | Where-Object { $_.check -like 'FAIL*' -or $_.check -clike 'WARN*' } | ForEach-Object { "{0} {1,-40} {2,-24} {3}" -f $_.id, $_.file, $_.check, $_.detail }
