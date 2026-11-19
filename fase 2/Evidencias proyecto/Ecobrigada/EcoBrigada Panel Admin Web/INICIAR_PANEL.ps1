$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path (Join-Path $PSScriptRoot 'SERVIDOR_PANEL.py'))) {
    throw 'No se encuentra SERVIDOR_PANEL.py. Copia ambos archivos a la raiz del panel.'
}

python .\SERVIDOR_PANEL.py
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo iniciar el servidor (codigo $LASTEXITCODE). Comprueba que Python este instalado y que el puerto 8081 este libre."
}
