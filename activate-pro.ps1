param(
  [Parameter(Mandatory=$true)][string]$Email,
  [ValidateSet("basic","pro")][string]$Plan = "pro",
  [int]$Months = 1
)
# Activates a paid Shortify user: hashes their email, adds it to pro.json, pushes live.
# Usage:  .\activate-pro.ps1 -Email customer@gmail.com -Plan pro -Months 1
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$norm = $Email.Trim().ToLower()
$sha  = [System.Security.Cryptography.SHA256]::Create()
$hash = ([System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($norm))) -replace "-","").ToLower()
$until = (Get-Date).AddMonths($Months).ToString("yyyy-MM-dd")

$f = Join-Path $root "pro.json"
$json = Get-Content $f -Raw | ConvertFrom-Json
$json | Add-Member -NotePropertyName $hash -NotePropertyValue ([pscustomobject]@{ plan = $Plan; until = $until }) -Force
($json | ConvertTo-Json -Depth 5) | Set-Content $f -Encoding utf8

# private local record (email <-> hash) — NOT committed
"$((Get-Date).ToString('yyyy-MM-dd HH:mm')) | $norm | $Plan | until $until | $hash" |
  Add-Content (Join-Path $root "activations-private.log")

Write-Host "Activated $norm as $Plan until $until" -ForegroundColor Green
git -C $root add pro.json
git -C $root commit -m "Activate $Plan tier (Shortify)"
git -C $root push
Write-Host "Pushed live - customer refreshes the page and Pro is on." -ForegroundColor Green
