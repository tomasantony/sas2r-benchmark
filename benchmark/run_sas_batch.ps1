<#
.SYNOPSIS
  Batch-run the benchmark SAS programs in SAS 9.4 and collect logs, listings and a run summary.
.EXAMPLE
  .\run_sas_batch.ps1                      # all 100
  .\run_sas_batch.ps1 -Ids P001,P016       # a subset
  .\run_sas_batch.ps1 -From P020 -To P040  # a range
  .\run_sas_batch.ps1 -DryRun              # show commands only
#>
param(
  [string]$Family,
  [string[]]$Ids,
  [string]$From,
  [string]$To,
  [int]$TimeoutMin = 15,
  [switch]$DryRun,
  [switch]$Force   # rerun ids that already have a log
)
$Root   = Split-Path -Parent $PSScriptRoot
$SasExe = 'C:\Program Files\SASHome\SASFoundation\9.4\sas.exe'
$Auto   = Join-Path $PSScriptRoot 'autoexec.sas'
$ProgDir = Join-Path $Root 'programs\sas_run'
$LogDir  = Join-Path $Root 'output\sas\logs'
$Summary = Join-Path $PSScriptRoot 'run_summary.csv'
$WorkDir = Join-Path $Root 'data\derived\saswork'
$UserDir = Join-Path $Root 'data/derived/sasuser'
New-Item -ItemType Directory -Force $LogDir, $WorkDir, $UserDir, (Join-Path $Root 'data/derived/cdisc-pilot/adam'), (Join-Path $Root 'data/derived/cdisc-pilot/sdtm') | Out-Null
if (-not (Test-Path $SasExe)) { throw "sas.exe not found at $SasExe" }

$rows = @(Import-Csv (Join-Path $PSScriptRoot 'manifest.csv'))
if ($Family) {
  $drv = Join-Path $PSScriptRoot "pipelines\$Family.sas"; $dlog = Join-Path $LogDir "_pipeline_$Family.log"
  $fam = @(Import-Csv (Join-Path $PSScriptRoot "families.csv") | Where-Object { $_.family -eq $Family } | ForEach-Object { $_.id })
  $cwd = Join-Path $Root "output\sas\datasets\_$Family"; New-Item -ItemType Directory -Force $cwd | Out-Null
  $args = @("-sysin", "`"$drv`"", "-log", "`"$dlog`"", "-autoexec", "`"$Auto`"", "-sysparm", $Family, "-work", "`"$WorkDir`"", "-sasuser", "`"$UserDir`"", "-nosplash", "-noterminal", "-nostatuswin", "-noicon", "-linesize", "132")
  Write-Host "pipeline ${Family}: $($fam.Count) programs"; if ($DryRun) { Write-Host "    sas.exe $($args -join ' ')"; return }
  $t0 = Get-Date; $p = Start-Process -FilePath $SasExe -ArgumentList $args -WorkingDirectory $cwd -PassThru -WindowStyle Hidden
  $finished = $p.WaitForExit($TimeoutMin * 60 * 1000); if (-not $finished) { try { $p.Kill() } catch {} }
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  if (-not (Test-Path $Summary)) { "id,file,started,seconds,rc,status,errors,warnings,log,lst" | Out-File $Summary -Encoding utf8 }
  foreach ($id in $fam) {
    $log = Join-Path $LogDir "$id.log"; $lst = Join-Path $LogDir "$id.lst"; $errs = 0; $warns = 0; $status = "missing-log"
    if (Test-Path $log) { $errs = @(Select-String -Path $log -Pattern "^ERROR").Count; $warns = @(Select-String -Path $log -Pattern "^WARNING").Count; if ($errs -gt 0) { $status = "error" } elseif ($warns -gt 0) { $status = "warnings" } else { $status = "ok" } }
    $file = (Import-Csv (Join-Path $PSScriptRoot "manifest.csv") | Where-Object { $_.id -eq $id }).file
    "$id,$file,$($t0.ToString('s')),$sec,$($p.ExitCode),$status,$errs,$warns,$log,$lst" | Out-File $Summary -Append -Encoding utf8
    Write-Host ("    {0} {1} errors={2} warnings={3}" -f $id, $status, $errs, $warns)
  }
  Write-Host "Summary: $Summary"; return
}
if ($Ids)  { $rows = @($rows | Where-Object { $Ids -contains $_.id }) }
if ($From) { $rows = @($rows | Where-Object { $_.id -ge $From }) }
if ($To)   { $rows = @($rows | Where-Object { $_.id -le $To }) }
if (-not (Test-Path $Summary)) {
  'id,file,started,seconds,rc,status,errors,warnings,log,lst' | Out-File $Summary -Encoding utf8
}
$n = 0
foreach ($r in $rows) {
  $n++
  $id = $r.id; $prog = Join-Path $ProgDir $r.file
  $log = Join-Path $LogDir "$id.log"; $lst = Join-Path $LogDir "$id.lst"
  if ((Test-Path $log) -and -not $Force) { Write-Host "[$n/$($rows.Count)] $id skipped (log exists; use -Force)"; continue }
  # each program runs with its own folder as the working directory so relative paths resolve
  $cwd = Join-Path $Root "output\sas\datasets\$id"
  New-Item -ItemType Directory -Force $cwd | Out-Null
  $args = @('-sysin', "`"$prog`"", '-log', "`"$log`"", '-print', "`"$lst`"", '-autoexec', "`"$Auto`"",
            '-sysparm', $id, '-termstmt', '%_bench_capture;', '-work', "`"$WorkDir`"", '-nosplash', '-noterminal', '-nostatuswin', '-noicon',
            '-sasuser', "`"$UserDir`"", '-linesize', '132')
  Write-Host "[$n/$($rows.Count)] $id  $($r.file)"
  if ($DryRun) { Write-Host "    sas.exe $($args -join ' ')"; continue }
  $t0 = Get-Date
  $p = Start-Process -FilePath $SasExe -ArgumentList $args -WorkingDirectory $cwd -PassThru -WindowStyle Hidden
  $finished = $p.WaitForExit($TimeoutMin * 60 * 1000)
  if (-not $finished) { try { $p.Kill() } catch {}; $rc = -1; $status = 'timeout' }
  else { $rc = $p.ExitCode; if ($rc -eq 0) { $status = 'ok' } elseif ($rc -eq 1) { $status = 'warnings' } else { $status = 'error' } }
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $errs = 0; $warns = 0
  if (Test-Path $log) {
    $errs  = @(Select-String -Path $log -Pattern '^ERROR' -SimpleMatch:$false).Count
    $warns = @(Select-String -Path $log -Pattern '^WARNING' -SimpleMatch:$false).Count
  }
  if ($status -ne 'timeout' -and $errs -gt 0) { $status = 'error' }
  "$id,$($r.file),$($t0.ToString('s')),$sec,$rc,$status,$errs,$warns,$log,$lst" | Out-File $Summary -Append -Encoding utf8
  Write-Host ("    {0}  rc={1}  {2}s  errors={3}  warnings={4}" -f $status, $rc, $sec, $errs, $warns)
}
Write-Host "Summary: $Summary"

# ---- pipeline mode (appended): .\run_sas_batch.ps1 -Family c2c  runs benchmark\pipelines\c2c.sas in one session ----


