Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 ALZITRANS - AUTO-BUILD PARA GOOGLE PLAY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

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
flutter build appbundle --release --no-pub --no-tree-shake-icons --no-shrink

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "✅ COMPILACION TERMINADA CON EXITO." -ForegroundColor Green
Write-Host "Sube el archivo .aab de esta ruta a tu Consola de Google Play:" -ForegroundColor White
Write-Host "C:\Users\borji\Alzibus\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan
