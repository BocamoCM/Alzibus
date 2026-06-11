Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 ALZITRANS - AUTO-BUILD PARA GOOGLE PLAY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ─── Cargar API_KEY ────────────────────────────────────────────────
# Desde la auditoría de seguridad (P2), la API_KEY ya NO tiene defaultValue
# en lib/constants/app_config.dart. Hay que pasarla con --dart-define o el
# header X-API-Key viaja vacío y el backend responde 401 "api key invalida".
#
# Orden de búsqueda:
#   1. Variable de entorno $env:ALZITRANS_API_KEY (CI/CD)
#   2. backend/.env línea API_KEY=... (entorno local del autor)
#   3. Error explícito si no se encuentra.
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

Write-Host "`n[1/4] Descargando ultimos cambios de git..." -ForegroundColor Yellow
git pull

Write-Host "`n[2/4] Limpiando builds anteriores (flutter clean)..." -ForegroundColor Yellow
flutter clean

Write-Host "`n[3/4] Obteniendo dependencias (flutter pub get)..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[4/4] Compilando AppBundle Personalizado..." -ForegroundColor Yellow
# Explicacion de los parametros personalizados:
# --release: Compila en modo produccion (maximo rendimiento).
# --no-pub: Salta la comprobacion de `flutter pub get` (ya la hicimos arriba).
# --no-tree-shake-icons: Vital si tu app usa iconos dinamicos. Evita que Flutter borre iconos que cree que no usas (evita crashes visuales).
# --no-shrink: Mantiene el codigo intacto sin borrar clases inactivas (muy util si usas Sentry, AdMob o NFC nativo para que proguard no rompa nada).
# --dart-define=API_KEY=...: inyecta la clave que valida el backend en el header X-API-Key.
flutter build appbundle --release --no-pub --no-tree-shake-icons --no-shrink --dart-define=API_KEY=$ApiKey

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "✅ COMPILACION TERMINADA CON EXITO." -ForegroundColor Green
Write-Host "Sube el archivo .aab de esta ruta a tu Consola de Google Play:" -ForegroundColor White
Write-Host "C:\Users\borji\Alzibus\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan
