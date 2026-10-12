# Build + deploy del panel a Firebase Hosting.
# Uso (desde cualquier carpeta): pwsh admin_panel/deploy-hosting.ps1
#
# firebase.json vive en ../firebase y su "public" apunta a ../firebase/public
# (Firebase Hosting no permite servir desde fuera de la carpeta del
# firebase.json, así que copiamos el build ahí en vez de apuntar directo).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==> flutter build web" -ForegroundColor Cyan
& "C:\flutter\bin\flutter.bat" build web --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { throw "flutter build web falló" }

Write-Host "==> Copiando build a firebase/public" -ForegroundColor Cyan
New-Item -ItemType Directory -Force "$root\..\firebase\public" | Out-Null
Copy-Item -Recurse -Force "$root\build\web\*" "$root\..\firebase\public\"

Write-Host "==> firebase deploy --only hosting" -ForegroundColor Cyan
Push-Location "$root\..\firebase"
try {
  firebase deploy --only hosting --project canal7app
} finally {
  Pop-Location
}
