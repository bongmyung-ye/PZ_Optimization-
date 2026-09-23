param([Parameter(Mandatory = $true)][string]$BackupPath, [Parameter(Mandatory = $true)][string]$Game)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest = Get-Content -LiteralPath (Join-Path $Here 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$SavedManifest = Get-Content -LiteralPath (Join-Path $BackupPath 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($SavedManifest.release_tag -ne $Manifest.release_tag) { throw 'Backup is for a different upstream release.' }
$GameDir = Join-Path $Game 'media\lua\client\pzopt'
$SavedLua = Join-Path $BackupPath 'lua'
$LocalMod = Join-Path $env:USERPROFILE 'Zomboid\mods\PZOptKorean'
function CheckFile([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) { throw "Unexpected file hash: $Path" }
}
function CheckLua([string]$Root, [string]$Field) {
    foreach ($prop in $Manifest.lua.PSObject.Properties) { CheckFile (Join-Path $Root $prop.Name) $prop.Value.$Field }
}
$Running = @(Get-CimInstance Win32_Process | Where-Object {
    $line = [string]$_.CommandLine
    (($_.Name -match '^ProjectZomboid.*\.exe$') -or ($_.Name -match '^javaw?\.exe$' -and $line -match 'ProjectZomboid|zombie\.GameWindow')) -and
    ($line -notmatch 'zombie\.network\.GameServer')
})
if ($Running.Count -ne 0) { throw 'Close the game client before restoring.' }
CheckLua $SavedLua 'upstream_sha256'
CheckLua $GameDir 'patch_sha256'
foreach ($lang in @('EN','KO')) {
    CheckFile (Join-Path $LocalMod "common\media\lua\shared\Translate\$lang\UI.json") $Manifest.translation.$lang
}
CheckFile (Join-Path $LocalMod 'common\mod.info') $Manifest.mod_info_sha256
if (@(Get-ChildItem -LiteralPath $LocalMod -Recurse -File).Count -ne 3) { throw 'Unexpected files in translation mod. Refusing to remove.' }
foreach ($prop in $Manifest.lua.PSObject.Properties) {
    Copy-Item -LiteralPath (Join-Path $SavedLua $prop.Name) -Destination (Join-Path $GameDir $prop.Name) -Force -ErrorAction Stop
}
CheckLua $GameDir 'upstream_sha256'
Remove-Item -LiteralPath $LocalMod -Recurse -Force -ErrorAction Stop
Write-Host 'Original 5c72380 Lua files restored. Translation mod removed.' -ForegroundColor Green
Write-Host 'Restart the client. User options and dedicated server were not changed.'
