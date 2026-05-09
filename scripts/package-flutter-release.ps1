param(
    [string]$NamePrefix = "OutlookMailManager-Flutter"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$native = Join-Path $root "native-mail-api"
$flutter = Join-Path $root "mail_linear_flutter"
$release = Join-Path $flutter "build\windows\x64\runner\Release"
$nativeExe = Join-Path $native "target\release\outlook-mail-native.exe"
$releaseNativeDir = Join-Path $release "runtime\native"
$dist = Join-Path $root "dist"

Push-Location $native
try {
    cargo build --release
} finally {
    Pop-Location
}

Push-Location $flutter
try {
    flutter build windows --release --no-pub
} finally {
    Pop-Location
}

New-Item -ItemType Directory -Force -Path $releaseNativeDir | Out-Null
Copy-Item -Path $nativeExe -Destination (Join-Path $releaseNativeDir "outlook-mail-native.exe") -Force

New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$sha = (git -C $root rev-parse --short HEAD).Trim()
$name = "$NamePrefix-$stamp-$sha"
$outDir = Join-Path $dist $name
$zip = "$outDir.zip"

if (Test-Path $outDir) {
    Remove-Item -LiteralPath $outDir -Recurse -Force
}
if (Test-Path $zip) {
    Remove-Item -LiteralPath $zip -Force
}

Copy-Item -LiteralPath $release -Destination $outDir -Recurse
Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $zip -Force
Get-Item $zip
