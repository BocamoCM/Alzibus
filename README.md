# Alzibus — Prototipo Flutter

Aplicación Flutter para Android que muestra el mapa de Alzira (Valencia) con paradas de bus y notificaciones de proximidad. Incluye funcionalidad básica para escanear tarjetas NFC.

## Características

- **Mapa interactivo**: Visualiza paradas de bus en Alzira usando OpenStreetMap
- **Notificaciones de proximidad**: Recibe alertas cuando te acercas a una parada (≤80m)
- **Lector NFC básico**: Escanea tarjetas NFC y muestra información del tag

## Instalación

### Requisitos previos
- Flutter SDK instalado (https://flutter.dev/docs/get-started/install)
- Dispositivo Android con NFC habilitado
- Cable USB para conectar el dispositivo

### Pasos de instalación

1. Abre PowerShell en la carpeta del proyecto:
```powershell
cd C:\Users\borji\Alzibus
```

2. Obtén las dependencias:
```powershell
flutter pub get
```

3. Conecta tu dispositivo Android y habilita la depuración USB

4. Ejecuta la aplicación:
```powershell
flutter run
```

## Uso

### Mapa
- La aplicación se abre mostrando el mapa de Alzira
- Los marcadores rojos indican las paradas de bus
- Si te acercas a menos de 80 metros de una parada, recibirás una notificación

### NFC
- Pulsa la pestaña "NFC" en la parte inferior
- Pulsa "Iniciar escaneo NFC"
- Acerca la tarjeta NFC al teléfono
- Verás la información del tag detectado

## Personalización

### Añadir más paradas
Edita el archivo `assets/stops.json`:
```json
[
  {
    "id": 1,
    "name": "Nombre de la parada",
    "lat": 39.1478,
    "lng": -0.4505,
    "lines": ["L1", "L2"]
  }
]
```

### Cambiar distancia de notificación
En `lib/main.dart`, línea ~122, modifica:
```dart
const double thresholdMeters = 80; // Cambiar este valor
```

## Limitaciones actuales

- **Lectura MIFARE Classic 1K**: La lectura completa de tarjetas MIFARE Classic (para ver viajes restantes) requiere código nativo Android adicional y conocer las claves de autenticación del operador de transporte
- **Notificaciones en background**: Actualmente funcionan solo con la app en primer plano
- **Paradas de ejemplo**: Las coordenadas son aproximadas, debes actualizarlas con datos reales

## Próximos pasos

Para implementar la lectura completa de tarjetas MIFARE Classic 1K:
1. Añadir código nativo en `MainActivity.kt` usando `android.nfc.tech.MifareClassic`
2. Implementar autenticación con claves sectoriales
3. Parsear el formato específico del operador de transporte

## Permisos

La aplicación solicita:
- **Ubicación**: Para detectar proximidad a paradas
- **NFC**: Para leer tarjetas
- **Notificaciones**: Para alertas de proximidad

## Problemas comunes

- **"No se detecta el dispositivo"**: Asegúrate de tener la depuración USB habilitada
- **"NFC no disponible"**: Verifica que tu teléfono tenga NFC y esté activado
- **Las notificaciones no llegan**: Revisa los permisos de la app en Configuración > Aplicaciones
