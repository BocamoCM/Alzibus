Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ALZITRANS - BUILD WEB PARA /app/" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── Cargar API_KEY ────────────────────────────────────────────────
# Tras la auditoría P2, lib/constants/app_config.dart no tiene defaultValue
# para API_KEY: hay que inyectarla con --dart-define o el backend rechazará
# las peticiones con 401 "api key invalida".
$ApiKey = $env:ALZITRANS_API_KEY
if (-not $ApiKey) {
    $EnvFile = Join-Path $ScriptDir "backend\.env"
    if (Test-Path $EnvFile) {
        $line = Select-String -Path $EnvFile -Pattern '^API_KEY=' | Select-Object -First 1
        if ($line) {
            $ApiKey = ($line.Line -replace '^API_KEY=', '').Trim('"').Trim("'")
        }
    }
}
if (-not $ApiKey) {
    Write-Host "`n❌ ERROR: no se encontró la API_KEY." -ForegroundColor Red
    Write-Host "Define `$env:ALZITRANS_API_KEY o añade API_KEY=... a backend/.env" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[1/5] Obteniendo dependencias (flutter pub get)..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[2/5] Regenerando rutas tipadas (go_router_builder)..." -ForegroundColor Yellow
flutter pub run build_runner build --delete-conflicting-outputs

Write-Host "`n[3/5] Limpiando build web previo..." -ForegroundColor Yellow
if (Test-Path "$ScriptDir\build\web") {
    Remove-Item -Recurse -Force "$ScriptDir\build\web"
}

Write-Host "`n[4/5] Compilando Flutter web con base-href=/app/..." -ForegroundColor Yellow
# --release: produccion (minificado, sin debug)
# --base-href: la app vivira bajo /app/ (Caddy enruta /app/* -> nginx -> website/app/)
# --pwa-strategy: offline-first para que el service worker cachee assets agresivamente
# --dart-define=API_KEY=...: inyecta la clave que valida el backend en X-API-Key.
flutter build web --release --base-href=/app/ --pwa-strategy=offline-first --dart-define=API_KEY=$ApiKey

Write-Host "`n[5/5] Copiando build a website/app/ ..." -ForegroundColor Yellow
$Target = "$ScriptDir\website\app"
if (Test-Path $Target) {
    Remove-Item -Recurse -Force $Target
}
New-Item -ItemType Directory -Path $Target | Out-Null
Copy-Item -Recurse -Force "$ScriptDir\build\web\*" $Target

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "BUILD WEB OK." -ForegroundColor Green
Write-Host "Desplegado en: website/app/" -ForegroundColor White
Write-Host "Para publicar en produccion:" -ForegroundColor White
Write-Host "  docker compose restart website proxy" -ForegroundColor Yellow
Write-Host "URL final: https://alzitrans.es/app/" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
