param(
  [Parameter(Mandatory=$true)][string]$Email,
  [ValidateSet("basic","pro")][string]$Plan = "pro",
  [int]$Months = 1,
  [switch]$Remove
)
# Shortify Pro activation (manual subscription).
#   Activate:   .\activate-pro.ps1 -Email customer@gmail.com -Plan pro -Months 1
#   Cancel:     .\activate-pro.ps1 -Email customer@gmail.com -Remove
$root = $PSScriptRoot
$norm = $Email.Trim().ToLower()
$sha  = [System.Security.Cryptography.SHA256]::Create()
$hash = ([System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($norm))) -replace "-","").ToLower()

$f = Join-Path $root "pro.json"
$json = Get-Content $f -Raw | ConvertFrom-Json
if (-not $json) { $json = [pscustomobject]@{} }

if ($Remove) {
  $json.PSObject.Properties.Remove($hash) | Out-Null
  $note = "REMOVED"
  Write-Host "Deactivated $norm" -ForegroundColor Yellow
} else {
  $until = (Get-Date).AddMonths($Months).ToString("yyyy-MM-dd")
  $json | Add-Member -NotePropertyName $hash -NotePropertyValue ([pscustomobject]@{ plan = $Plan; until = $until }) -Force
  $note = "$Plan until $until"
  Write-Host "Activated $norm as $Plan until $until" -ForegroundColor Green
}

# write pro.json WITHOUT a BOM (PS 5.1 utf8 adds one, which can break JSON.parse)
$out = ($json | ConvertTo-Json -Depth 5)
[System.IO.File]::WriteAllText($f, $out, (New-Object System.Text.UTF8Encoding $false))

# private local log (email <-> hash) — gitignored, never pushed
"$((Get-Date).ToString('yyyy-MM-dd HH:mm')) | $norm | $note | $hash" |
  Add-Content (Join-Path $root "activations-private.log")

# push live (git writes progress to stderr — suppress so it doesn't look like an error)
git -C $root add pro.json 2>&1 | Out-Null
git -C $root commit -m "Update Pro access (Shortify)" 2>&1 | Out-Null
git -C $root push 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Host "Pushed live - customer refreshes the page (~1 min) and it takes effect." -ForegroundColor Green }
else { Write-Host "Push failed - open PowerShell here and run:  git push" -ForegroundColor Red }
