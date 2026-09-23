param([Parameter(Mandatory = $true)][string]$Game, [string]$BackupRoot)
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest = Get-Content -LiteralPath (Join-Path $Here 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$GameDir = Join-Path $Game 'media\lua\client\pzopt'
$ProjectRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'PZOPT-Korean'
if (-not $BackupRoot) { $BackupRoot = Join-Path $ProjectRoot 'backups' }
$LocalMods = Join-Path $env:USERPROFILE 'Zomboid\mods'
$LocalMod = Join-Path $LocalMods 'PZOptKorean'
$LegacyMod = Join-Path $LocalMods 'PZOptKOSmokeV3'
$NewMod = Join-Path $Here 'local_mod\PZOptKorean'
$NewLua = Join-Path $Here 'media\lua\client\pzopt'
function CheckFile([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) { throw "Unexpected file hash: $Path" }
}
function CheckLua([string]$Root, [string]$Field) {
    foreach ($prop in $Manifest.lua.PSObject.Properties) {
        CheckFile (Join-Path $Root $prop.Name) $prop.Value.$Field
    }
}
function CheckMod([string]$Root) {
    foreach ($lang in @('EN','KO')) {
        CheckFile (Join-Path $Root "common\media\lua\shared\Translate\$lang\UI.json") $Manifest.translation.$lang
    }
    CheckFile (Join-Path $Root 'common\mod.info') $Manifest.mod_info_sha256
    $count = @(Get-ChildItem -LiteralPath $Root -Recurse -File).Count
    if ($count -ne 3) { throw "Unexpected local mod files ($count): $Root" }
}
$Running = @(Get-CimInstance Win32_Process | Where-Object {
    $line = [string]$_.CommandLine
    (($_.Name -match '^ProjectZomboid.*\.exe$') -or ($_.Name -match '^javaw?\.exe$' -and $line -match 'ProjectZomboid|zombie\.GameWindow')) -and
    ($line -notmatch 'zombie\.network\.GameServer')
})
if ($Running.Count -ne 0) { throw 'Close the game client before installing; do not stop the dedicated server.' }
$BuildInfoPath = Join-Path $Game 'pzopt\build-info.properties'
if (-not (Test-Path -LiteralPath $BuildInfoPath -PathType Leaf)) { throw "Missing upstream build info: $BuildInfoPath" }
$BuildInfo = [IO.File]::ReadAllText($BuildInfoPath)
if ($BuildInfo -notmatch '(?m)^revision=b0bbce05d5\s*$' -or $BuildInfo -notmatch '(?m)^commit=5c72380\s*$') {
    throw "Upstream version mismatch. Required: revision=b0bbce05d5 commit=5c72380. Found: $BuildInfo"
}
if (Test-Path -LiteralPath $LegacyMod) { throw 'Old PZOptKOSmokeV3 remains. Restore and disable v4/v3 first.' }
if (Test-Path -LiteralPath $LocalMod) { throw "Existing translation mod: $LocalMod. Refusing to overwrite." }
if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) { throw "Game directory missing: $GameDir" }
CheckLua $GameDir 'upstream_sha256'
CheckLua $NewLua 'patch_sha256'
CheckMod $NewMod
CheckFile (Join-Path $GameDir 'pzopt_optimizations_classes.lua') $Manifest.unmodified_classes_sha256
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$Backup = Join-Path $BackupRoot "5c72380-KO-RC2-$Stamp"
if (Test-Path -LiteralPath $Backup) { throw "Existing backup path: $Backup" }
$SavedLua = Join-Path $Backup 'lua'
New-Item -ItemType Directory -Path $SavedLua -Force | Out-Null
foreach ($prop in $Manifest.lua.PSObject.Properties) {
    Copy-Item -LiteralPath (Join-Path $GameDir $prop.Name) -Destination (Join-Path $SavedLua $prop.Name) -ErrorAction Stop
}
Copy-Item -LiteralPath (Join-Path $Here 'manifest.json') -Destination (Join-Path $Backup 'manifest.json')
CheckLua $SavedLua 'upstream_sha256'
try {
    foreach ($prop in $Manifest.lua.PSObject.Properties) {
        Copy-Item -LiteralPath (Join-Path $NewLua $prop.Name) -Destination (Join-Path $GameDir $prop.Name) -Force -ErrorAction Stop
    }
    New-Item -ItemType Directory -Path $LocalMods -Force | Out-Null
    Copy-Item -LiteralPath $NewMod -Destination $LocalMods -Recurse -ErrorAction Stop
    CheckLua $GameDir 'patch_sha256'
    CheckMod $LocalMod
} catch {
    $Problem = $_
    foreach ($prop in $Manifest.lua.PSObject.Properties) {
        Copy-Item -LiteralPath (Join-Path $SavedLua $prop.Name) -Destination (Join-Path $GameDir $prop.Name) -Force -ErrorAction Stop
    }
    if (Test-Path -LiteralPath $LocalMod) { Remove-Item -LiteralPath $LocalMod -Recurse -Force }
    CheckLua $GameDir 'upstream_sha256'
    throw "Install failed; source files restored: $Problem"
}
Write-Host 'Korean translation 5c72380 RC2 installed. Enable PZOptKorean in the main-menu Mods list.' -ForegroundColor Green
Write-Host "Backup: $Backup"
Write-Host 'Restart the client. Dedicated server, Java classes, saves and user options were not changed.'
Write-Host 'Restore this patch before running the upstream updater.'
