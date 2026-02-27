# Alzitrans — Sistema Integral de Gestión de Transporte

Alzitrans es un ecosistema tecnológico completo diseñado para el transporte público de Alzira (Valencia). El proyecto abarca desde la lectura avanzada de tarjetas NFC hasta una infraestructura de backend persistente y un panel de administración web.

## 🚀 Componentes del Proyecto

### 1. App Móvil (Flutter)
- **Mapa en tiempo real**: Visualización de paradas y rutas de bus integradas con OpenStreetMap.
- **Lectura NFC Avanzada**: Soporte completo para tarjetas **MIFARE Classic 1K**.
  - Lectura de saldo y viajes restantes (Bloque 8).
  - Validación de integridad mediante checksum XOR (Bloque 10).
  - Detección automática de tarjetas **Ilimitadas (Contrato JP)**.
- **Validación de Viajes**: Sistema de validación local con sincronización inteligente.
- **Compatibilidad Multiplataforma**: Optimizada para Android (NFC completo) e iOS (aviso de hardware restringido).
- **Notificaciones Geofencing**: Alertas de proximidad al acercarse a las paradas.

### 2. Backend (Node.js & Raspberry Pi)
- **Servidor de Producción**: Desplegado en una Raspberry Pi con persistencia mediante **PM2**.
- **API REST**: Gestión de usuarios, validación de dispositivos y logs financieros.
- **Seguridad**: Implementación de Helmet, CORS securizado y validación de API Keys.
- **Despliegue Automatizado**: Scripts de control (`start.sh`, `stop.sh`) para una gestión eficiente del servicio.

### 3. Panel de Administración (Web)
- Visualización de estadísticas de uso en tiempo real.
- Gestión de flotas y monitoreo de validaciones.
- Interfaz moderna integrada con el backend de producción.

## 🛠️ Detalles Técnicos NFC

El proyecto ha realizado ingeniería inversa de las tarjetas de transporte de Alzira, identificando la siguiente estructura de datos:
- **Sector 2, Bloque 8**: Almacena el saldo de viajes en formato Little Endian.
- **Sector 2, Bloque 10**: Checksum de seguridad basado en una operación XOR del bloque de datos.
- **Autenticación**: Manejo de llaves sectoriales específicas para acceso seguro a los datos del operador.

## 📦 CI/CD y Compilación

Contamos con una canalización de **GitHub Actions** que automatiza la generación de binarios:
- **Android**: Generación de APK optimizada en modo `--release`.
- **iOS**: Compilación en nube (`macos-latest`) para verificación de integridad y generación de artefactos empaquetados.

## 🔧 Instalación y Desarrollo

1. **Dependencias**:
   ```bash
   flutter pub get
   ```
2. **Ejecución**:
   ```bash
   flutter run --release
   ```

## 🔐 Requisitos de Seguridad
Para el despliegue en producción, asegúrese de configurar las variables de entorno (`.env`) en el backend, incluyendo:
- `API_KEY`: Para la validación de la App.
- `PORT`: Puerto de escucha del servidor.
- `DATABASE_URL`: Conexión a la base de datos persistente.

---
**Desarrollado para la modernización del transporte público de Alzira.** Ver documentación técnica detallada en la carpeta `brain/` para análisis profundos del protocolo NFC y arquitectura del sistema.
