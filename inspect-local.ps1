param([Parameter(Mandatory = $true)][string]$Game)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest = Get-Content -LiteralPath (Join-Path $Here 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$GameDir = Join-Path $Game 'media\lua\client\pzopt'
$ModDir = Join-Path $env:USERPROFILE 'Zomboid\mods'
$BuildInfoPath = Join-Path $Game 'pzopt\build-info.properties'
if (Test-Path -LiteralPath $BuildInfoPath -PathType Leaf) {
    Write-Host 'Installed build info:'
    Select-String -LiteralPath $BuildInfoPath -Pattern '^(revision|commit)=' | ForEach-Object { Write-Host $_.Line }
} else { Write-Host 'Installed build info: NOT FOUND' }
Write-Host "Game: $Game"
Write-Host "Target release: $($Manifest.release_tag)"
Write-Host "Game revision: $($Manifest.game_revision)"
Write-Host "Legacy test mod: $(Test-Path -LiteralPath (Join-Path $ModDir 'PZOptKOSmokeV3'))"
Write-Host "New translation mod: $(Test-Path -LiteralPath (Join-Path $ModDir 'PZOptKorean'))"
Write-Host "`n=== LUA STATUS (READ ONLY) ==="
foreach ($prop in $Manifest.lua.PSObject.Properties) {
    $Path = Join-Path $GameDir $prop.Name
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        [PSCustomObject]@{ File=$prop.Name; Status='MISSING'; SHA256='' }
        continue
    }
    $Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    $Status = if ($Hash -eq $prop.Value.upstream_sha256) { '5c72380 ORIGINAL' } elseif ($Hash -eq $prop.Value.patch_sha256) { 'KOREAN RC2' } else { 'OTHER / OLDER / MODIFIED' }
    [PSCustomObject]@{ File=$prop.Name; Status=$Status; SHA256=$Hash }
}
Write-Host "`n=== USER OPTIONS ==="
$Options = Join-Path $env:USERPROFILE 'Zomboid\pzopt\options.ini'
if (Test-Path -LiteralPath $Options) {
    Select-String -LiteralPath $Options -Pattern '^\s*(fogPass|lazyOptionsScreen)\s*=' | ForEach-Object { $_.Line }
} else { Write-Host 'No options.ini' }
Write-Host 'No files were changed.'
