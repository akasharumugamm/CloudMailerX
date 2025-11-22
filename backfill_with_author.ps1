<#
backfill_with_author.ps1
Usage:
  # preview only
  .\backfill_with_author.ps1 -Start "2024-12-01" -End "2025-05-14" -Count 20 -Preview

  # apply (creates commits)
  .\backfill_with_author.ps1 -Start "2024-12-01" -End "2025-05-14" -Count 20
#>

param(
  [Parameter(Mandatory=$false)][string]$Start = "2024-12-01",
  [Parameter(Mandatory=$false)][string]$End   = "2025-05-14",
  [Parameter(Mandatory=$false)][int]$Count = 20,
  [Parameter(Mandatory=$false)][int]$WeekdayBias = 80,  # prefer weekdays
  [switch]$Preview
)

# AUTHOR (same author used for all commits)
$authorName  = "akasharumugamm"
$authorEmail = "akasharumugam321@gmail.com"

# message pool
$msgPool = @(
  "chore: housekeeping",
  "fix: minor tweak",
  "docs: small note",
  "feat: tiny improvement",
  "style: formatting",
  "refactor: small cleanup",
  "test: add simple case",
  "perf: micro-optimise",
  "ci: tweak workflow",
  "chore: update config"
)

# parse dates
$startDt = Get-Date $Start
$endDt   = Get-Date $End
if ($endDt -lt $startDt) { Write-Error "End date must be >= Start date"; exit 1 }

# helper: pick date with weekday bias
function Get-RandDate($s, $e, $weekdayBias) {
  $maxAttempts = 1000
  for ($i=0; $i -lt $maxAttempts; $i++) {
    $span = ($e - $s).Days
    $offset = Get-Random -Minimum 0 -Maximum ($span + 1)
    $cand = $s.AddDays($offset).Date
    $dow = [int]$cand.DayOfWeek  # 0=Sun .. 6=Sat
    if ($dow -ge 1 -and $dow -le 5) { return $cand }
    else {
      $roll = Get-Random -Minimum 1 -Maximum 101
      if ($roll -gt $weekdayBias) { return $cand }
    }
  }
  return $s
}

# build dates list
$dates = @()
while ($dates.Count -lt $Count) {
  $d = Get-RandDate -s $startDt -e $endDt -weekdayBias $WeekdayBias
  if (($dates -contains $d) -and (Get-Random -Minimum 1 -Maximum 101 -le 25)) {
    $dates += $d
  } elseif (-not ($dates -contains $d)) {
    $dates += $d
  }
}
$dates = $dates | Get-Random -Count $dates.Count

if ($Preview) {
  Write-Host "Preview: $Count commit dates (local timezone):" -ForegroundColor Cyan
  $i=1
  foreach ($d in $dates) {
    if ((Get-Random -Minimum 1 -Maximum 101) -le 12) { $h = Get-Random -Minimum 19 -Maximum 23 } else { $h = Get-Random -Minimum 9 -Maximum 18 }
    $m = Get-Random -Minimum 0 -Maximum 59; $s = Get-Random -Minimum 0 -Maximum 59
    $dt = Get-Date -Year $d.Year -Month $d.Month -Day $d.Day -Hour $h -Minute $m -Second $s
    Write-Host ("{0:D2}. {1}" -f $i, $dt.ToString("yyyy-MM-dd (ddd) HH:mm:ss"))
    $i++
  }
  Write-Host "`nIf this looks good, run without -Preview to create commits." -ForegroundColor Green
  return
}

if (-not (Test-Path .git)) { Write-Error "No .git in current folder. Run from repo root."; exit 1 }

$count = 0
foreach ($d in $dates) {
  if ((Get-Random -Minimum 1 -Maximum 101) -le 12) { $hour = Get-Random -Minimum 19 -Maximum 23 } else { $hour = Get-Random -Minimum 9 -Maximum 18 }
  $minute = Get-Random -Minimum 0 -Maximum 59; $second = Get-Random -Minimum 0 -Maximum 59
  $commitDt = Get-Date -Year $d.Year -Month $d.Month -Day $d.Day -Hour $hour -Minute $minute -Second $second

  # timezone offset string (avoid ternary; use if/else for compatibility)
    $tz = (Get-TimeZone).BaseUtcOffset
    $rawHours = [math]::Floor([math]::Abs($tz.TotalHours))
    $rawMinutes = [math]::Abs($tz.TotalMinutes) % 60

    if ($tz.TotalMinutes -ge 0) {
        $sign = "+"
    } else {
        $sign = "-"
    }

    $offsetStr = "$sign{0}{1}" -f `
        $rawHours.ToString("00"), `
        (":" + $rawMinutes.ToString("00"))


  $commitTimeStr = $commitDt.ToString("yyyy-MM-dd HH:mm:ss") + " " + $offsetStr
  $message = ($msgPool | Get-Random) + " - " + $commitDt.ToString("yyyy-MM-dd")

  $env:GIT_AUTHOR_NAME = $authorName
  $env:GIT_AUTHOR_EMAIL = $authorEmail
  $env:GIT_COMMITTER_NAME = $authorName
  $env:GIT_COMMITTER_EMAIL = $authorEmail
  $env:GIT_AUTHOR_DATE = $commitTimeStr
  $env:GIT_COMMITTER_DATE = $commitTimeStr

  git commit --allow-empty -m $message | Out-Null

  $count++
  Write-Host ("Created $count / $Count at $commitTimeStr")
  Start-Sleep -Milliseconds (Get-Random -Minimum 120 -Maximum 420)
}

Remove-Item Env:\GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
Remove-Item Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue

Write-Host "Done: created $count commits between $Start and $End." -ForegroundColor Green
Write-Host "Verify: ( git log --since='$Start' --pretty=oneline ) | Measure-Object -Line"
