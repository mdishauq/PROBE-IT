$ErrorActionPreference = 'Stop'

Set-Location "$PSScriptRoot\.."

Write-Host "[1/3] Building Flutter Windows release..."
flutter clean
flutter pub get
flutter build windows --release

Write-Host "[2/3] Locating Inno Setup compiler..."
$isccCandidates = @(
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  'C:\Program Files\Inno Setup 6\ISCC.exe'
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
  throw 'Inno Setup 6 not found. Install from https://jrsoftware.org/isinfo.php'
}

Write-Host "[3/3] Building installer EXE..."
& $iscc 'installer\probeit_installer.iss'

Write-Host ''
Write-Host 'SUCCESS: Installer created in example\installer\dist'
