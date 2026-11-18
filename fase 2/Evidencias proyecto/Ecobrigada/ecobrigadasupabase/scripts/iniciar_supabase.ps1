$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
 throw 'Flutter no está en PATH. Abre la terminal con Flutter configurado.'
}
if (-not (Test-Path '.\supabase_config.json')) {
 throw 'Copia supabase_config.example.json a supabase_config.json y añade la URL y clave pública de tu proyecto.'
}
if (-not (Test-Path '.\web')) {
 flutter create --project-name ecobrigadasupabase --platforms=android,web .
}
$manifest = '.\android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifest) {
  $xml = Get-Content $manifest -Raw
  foreach ($perm in @('android.permission.INTERNET',
                      'android.permission.ACCESS_FINE_LOCATION',
                      'android.permission.ACCESS_COARSE_LOCATION')) {
    if ($xml -notmatch [regex]::Escape($perm)) {
      $xml = $xml -replace '<manifest([^>]*)>',
        ('<manifest$1>' + "`r`n" + '    <uses-permission android:name="' + $perm + '" />')
    }
  }
  [System.IO.File]::WriteAllText((Resolve-Path $manifest).Path, $xml)
}
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define-from-file=supabase_config.json
