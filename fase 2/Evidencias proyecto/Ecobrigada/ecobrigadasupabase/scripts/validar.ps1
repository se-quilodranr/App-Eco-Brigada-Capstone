$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter pub get
if ($LASTEXITCODE -ne 0) {throw 'Falló flutter pub get'}
dart format lib test
flutter analyze
if ($LASTEXITCODE -ne 0) {throw 'Falló flutter analyze'}
flutter test
if ($LASTEXITCODE -ne 0) {throw 'Falló flutter test'}
Write-Host 'Validación finalizada.' -ForegroundColor Green
