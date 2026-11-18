# EcoBrigada 3.1: ejecutar desde la carpeta del proyecto con:
# powershell -ExecutionPolicy Bypass -File .\scripts\iniciar_usuarios_prueba.ps1
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $raiz

if (-not (Test-Path -LiteralPath '.\scripts\provisionar_usuarios_prueba.py')) {
    throw 'Falta scripts/provisionar_usuarios_prueba.py. Copia ambos archivos del ZIP.'
}

$env:SUPABASE_URL = 'https://imcvutrsvudbmuzgnbyd.supabase.co'
$agregoClave = $false

try {
    if ([string]::IsNullOrWhiteSpace($env:SUPABASE_SERVICE_ROLE_KEY)) {
        Write-Host '1) En Supabase Dashboard copia tu NUEVA clave legacy service_role (JWT eyJ...).'
        Write-Host '2) No pegues la clave dentro de un comando ni la compartas por chat.'
        Read-Host 'Una vez copiada al portapapeles, presiona ENTER'
        $texto = (Get-Clipboard -Raw).Trim()
        Set-Clipboard -Value ''
        if ($texto -notmatch '^eyJ') {
            throw 'No se detecto una clave JWT valida en el portapapeles.'
        }
        $env:SUPABASE_SERVICE_ROLE_KEY = $texto
        $texto = $null
        $agregoClave = $true
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { throw 'Python no esta disponible. Comprueba: python --version' }
    & python '.\scripts\provisionar_usuarios_prueba.py'
    if ($LASTEXITCODE -ne 0) { throw "El script Python termino con codigo $LASTEXITCODE. Revisa el mensaje anterior." }
}
finally {
    Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:SUPABASE_URL -ErrorAction SilentlyContinue
    Write-Host 'La clave administrativa fue retirada de las variables de esta terminal.'
}
