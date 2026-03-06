# Manual de Usuario — Alzitrans (Alzi Trans)

**Versión:** 3.0  
**Plataforma:** Android (compatible con iOS de forma parcial)  
**Idiomas disponibles:** Español, Valencià, English

---

## Índice

1. [Introducción](#1-introducción)
2. [Requisitos e Instalación](#2-requisitos-e-instalación)
3. [Primer inicio](#3-primer-inicio)
4. [Registro e Inicio de Sesión](#4-registro-e-inicio-de-sesión)
5. [Pantalla Principal y Navegación](#5-pantalla-principal-y-navegación)
6. [Mapa Interactivo](#6-mapa-interactivo)
7. [Información de Parada](#7-información-de-parada)
8. [Rutas de Autobús](#8-rutas-de-autobús)
9. [Lector de Tarjeta NFC](#9-lector-de-tarjeta-nfc)
10. [Avisos y Notificaciones](#10-avisos-y-notificaciones)
11. [Alertas Activas](#11-alertas-activas)
12. [Perfil de Usuario](#12-perfil-de-usuario)
13. [Historial de Viajes](#13-historial-de-viajes)
14. [Ajustes](#14-ajustes)
15. [Accesibilidad](#15-accesibilidad)
16. [Solución de Problemas](#16-solución-de-problemas)
17. [Preguntas Frecuentes (FAQ)](#17-preguntas-frecuentes-faq)

---

## 1. Introducción

**Alzitrans** es una aplicación de transporte público diseñada para los usuarios del servicio de autobuses de **Alzira (Valencia)**. La app permite:

- Ver en tiempo real la posición de los autobuses en el mapa.
- Consultar las paradas y rutas de las **líneas L1, L2 y L3**.
- Leer el saldo de la tarjeta de transporte NFC (MIFARE Classic 1K).
- Recibir notificaciones de proximidad a las paradas.
- Consultar horarios de trenes de **Cercanías Renfe (línea C2)**.
- Registrar y llevar un historial de tus viajes.
- Recibir avisos del servicio en tiempo real.

---

## 2. Requisitos e Instalación

### Requisitos mínimos

| Requisito | Detalle |
|-----------|---------|
| **Sistema operativo** | Android 6.0 o superior |
| **NFC** | Necesario para leer la tarjeta de transporte (solo Android) |
| **GPS/Ubicación** | Necesario para el mapa y las alertas de proximidad |
| **Conexión a Internet** | Necesaria para horarios en tiempo real, avisos y cuenta de usuario |

### Instalación

1. Descarga la app desde la fuente proporcionada (APK o tienda de aplicaciones).
2. Si instalas desde APK, habilita **"Orígenes desconocidos"** o **"Instalar apps de fuentes externas"** en los ajustes de tu dispositivo.
3. Abre la app tras la instalación.

> **Nota para usuarios de iOS:** La lectura de tarjetas NFC MIFARE Classic no está disponible en iPhone debido a restricciones de hardware de Apple. El resto de funciones del mapa, rutas, avisos y perfil funcionan con normalidad.

---

## 3. Primer inicio

Al abrir Alzitrans por primera vez:

1. **Pantalla de carga (Splash):** Verás el logotipo de Alzitrans con un icono de autobús sobre un fondo granate. La aplicación se cargará automáticamente en unos segundos.

2. **Permiso de batería:** En el primer uso, la app te pedirá desactivar la optimización de batería para que las notificaciones en segundo plano funcionen correctamente. **Se recomienda aceptar** para garantizar el correcto funcionamiento de las alertas.

3. **Mensaje de bienvenida:** Aparecerá un diálogo explicando que la app ha sido creada por un estudiante y que puede contener errores. Este mensaje solo se muestra una vez.

4. **Permisos de ubicación:** La app solicitará acceso a tu ubicación para mostrarte en el mapa y enviarte alertas de proximidad a las paradas.

---

## 4. Registro e Inicio de Sesión

### Crear una cuenta

1. En la pantalla de inicio de sesión, pulsa **"¿No tienes cuenta?"**.
2. Introduce tu **correo electrónico** y una **contraseña** (mínimo 6 caracteres).
3. Pulsa **"Registrarse"**.
4. Recibirás un **código de verificación** en tu correo electrónico.
5. Introduce el código en la pantalla de verificación OTP para activar tu cuenta.

### Iniciar sesión

1. Introduce tu **correo electrónico** y **contraseña**.
2. Pulsa **"Iniciar sesión"**.
3. Si los datos son correctos, accederás a la pantalla principal.

### Recuperar contraseña

1. En la pantalla de inicio de sesión, pulsa **"¿Olvidaste tu contraseña?"**.
2. Introduce tu correo electrónico y pulsa **"Enviar código"**.
3. Recibirás un código por correo electrónico.
4. Introduce el código y escribe tu nueva contraseña en la pantalla de restablecimiento.

---

## 5. Pantalla Principal y Navegación

La pantalla principal tiene una **barra de navegación inferior** con 5 pestañas:

| Icono | Pestaña | Función |
|-------|---------|---------|
| 🗺️ Mapa | **Mapa** | Mapa interactivo con paradas y autobuses |
| 🚌 Ruta | **Rutas** | Listado de todas las paradas por línea |
| 📱 NFC | **NFC** | Lector de tarjeta de transporte |
| 📢 Megáfono | **Avisos** | Noticias e incidencias del servicio |
| 👤 Persona | **Perfil** | Tu cuenta, ajustes e historial |

### Barra superior

- **Título:** "Alzitrans"
- **Icono de campana (🔔):** Accede a la pantalla de **Alertas Activas** (alertas de llegada de autobuses que hayas configurado).
- **Badge de avisos:** Si hay avisos nuevos sin leer, aparecerá un indicador numérico en la pestaña de Avisos.

### Confirmación de viaje

Cuando la app detecta que has estado cerca de una parada de autobús, te mostrará automáticamente un diálogo preguntando:

> **"¿Has cogido el autobús?"**

Con los datos del viaje detectado (línea, parada, destino y hace cuánto tiempo). Pulsa **"Sí"** para registrar el viaje en tu historial o **"No"** para descartarlo.

---

## 6. Mapa Interactivo

### Vista general

El mapa muestra la zona de Alzira centrada en las coordenadas del municipio, con:

- **Marcadores de paradas:** Puntos de colores según la línea a la que pertenecen.
  - 🔴 **L1** — Color rojo/granate
  - 🟢 **L2** — Color verde
  - 🔵 **L3** — Color azul
- **Tu ubicación:** Un punto azul que indica tu posición actual, con indicador de dirección.
- **Autobuses simulados:** Iconos de autobuses animados moviéndose por las rutas en tiempo real.

### Filtro de líneas

En la parte superior del mapa hay **botones de filtro** para cada línea (L1, L2, L3). Pulsa sobre cada uno para mostrar u ocultar las paradas de esa línea.

### Buscar parada

Utiliza la **barra de búsqueda** en la parte superior para buscar una parada por nombre. Al seleccionar un resultado, el mapa se desplazará y hará zoom sobre la parada seleccionada.

### Interacciones

- **Pulsar una parada:** Se abre la hoja de información de la parada (ver sección 7).
- **Pulsar un autobús:** Se muestra información del bus (línea, próxima parada, tiempo estimado de llegada).
- **Pellizcar para hacer zoom:** Acerca o aleja la vista del mapa.
- **Arrastrar:** Mueve el mapa para explorar la zona.

---

## 7. Información de Parada

Al pulsar sobre una parada en el mapa se despliega una **hoja de información** desde la parte inferior de la pantalla con:

### Mapa de ubicación

Un mini-mapa centrado en la parada. Puedes alternar entre **vista de mapa** y **vista satélite** pulsando el icono correspondiente.

### Datos de la parada

- **Nombre de la parada** con un icono de estrella (⭐) para marcarla como **favorita**.
- **Líneas** que pasan por la parada (indicadores de colores).
- **Coordenadas GPS** de la parada.
- **Distancia** desde tu ubicación actual.

### Horarios en tiempo real

Se muestra una lista de las próximas llegadas de autobuses:

- **Línea** (indicador de color).
- **Destino** del autobús.
- **Tiempo estimado de llegada** (ETA).

Los horarios se actualizan automáticamente cada 30 segundos. También puedes pulsar el botón de **actualizar** manualmente.

### Alertas de llegada

Para cada autobús en la lista, puedes pulsar **"Avísame cuando llegue"** para recibir una notificación cuando el autobús esté cerca de esa parada. Un botón de **"Cancelar"** aparecerá si la alerta ya está activa.

### Trenes Renfe (Cercanías C2)

Si la parada seleccionada es también una estación de Cercanías Renfe, aparecerá una sección adicional con los **horarios de trenes de la línea C2**, incluyendo retrasos si los hubiera.

### Otras acciones

- **"Ver en Google Maps":** Abre la ubicación de la parada en Google Maps.
- **Lectura por voz (TTS):** Si la accesibilidad por voz está activada, la app anunciará en voz alta el nombre de la parada y la próxima llegada.

---

## 8. Rutas de Autobús

La pestaña **Rutas** muestra las tres líneas de autobús en pestañas separadas: **L1**, **L2** y **L3**.

### Para cada línea

- **Banner de bus activo:** Si hay un autobús circulando en esa línea, se muestra un banner en la parte superior con:
  - Estado: **"En parada"** o **"En ruta"**.
  - Nombre de la **próxima parada**.
  - **Porcentaje de recorrido** completado.

- **Línea temporal vertical:** Se muestra un listado vertical de todas las paradas de la ruta en orden, con:
  - **Círculo relleno (●):** El autobús ya ha pasado por esta parada.
  - **Círculo vacío (○):** El autobús aún no ha llegado.
  - **Icono de autobús:** Posición actual del bus en la ruta.

### Interacciones

- **Pulsar una parada:** La app cambia a la pestaña del Mapa y hace zoom sobre esa parada, mostrando su información.

---

## 9. Lector de Tarjeta NFC

La pestaña **NFC** permite leer tu tarjeta de transporte de Alzira (tarjetas MIFARE Classic 1K).

### Tarjeta virtual

En la parte superior se muestra una **representación visual** de tu tarjeta con:

- **Nombre del tipo de tarjeta** (Normal o Ilimitada/Contrato JP).
- **Número de viajes restantes** (número grande) o **"ILIMITADO"** si es una tarjeta sin límite.
- **UID de la tarjeta** (identificador único).
- **Icono NFC animado** durante el escaneo.

### Leer la tarjeta

1. Pulsa el botón **"Leer Tarjeta NFC"** (o **"Actualizar / Leer Tarjeta"** si ya se ha leído previamente).
2. **Acerca tu tarjeta de transporte** a la parte trasera del teléfono.
3. Mantén la tarjeta quieta durante unos segundos mientras la app lee los datos.
4. Los datos de saldo y viajes se actualizarán en la tarjeta virtual.

### Validar un viaje

1. Pulsa el botón verde **"Confirmar / Validar Viaje"**.
2. Aparecerá un diálogo de confirmación: *"¿Desea validar un viaje? Se restará 1 del total."*
3. Pulsa **"Sí"** para confirmar o **"No"** para cancelar.
4. La tarjeta virtual se actualizará con el nuevo saldo.

> **Nota:** El botón de validar está deshabilitado para tarjetas ilimitadas, ya que no requieren descuento de viajes.

### Aviso de saldo bajo

Si tu saldo de viajes está por debajo del umbral configurado, aparecerá un aviso naranja en la pantalla y recibirás una notificación con vibración.

### Configuración de avisos NFC

Pulsa el **botón de engranaje (⚙️)** en la esquina inferior derecha para:

- **Activar/desactivar** los avisos de saldo bajo.
- **Ajustar el umbral** de viajes para el aviso (entre 1 y 20 viajes).

> **Nota para iOS:** Los usuarios de iPhone verán un mensaje indicando que la lectura NFC de tarjetas MIFARE Classic no está disponible en dispositivos Apple debido a restricciones de hardware.

---

## 10. Avisos y Notificaciones

La pestaña **Avisos** muestra las noticias e incidencias del servicio de transporte.

### Contenido de cada aviso

- **Icono de advertencia** y **fecha/hora** (formato relativo: "hace 5 min", "hace 2h", o fecha completa).
- **Línea afectada** (si aplica), con indicador de color (L1, L2, L3).
- **Título** del aviso.
- **Descripción** detallada.
- **Fecha de validez** (si tiene fecha de expiración): *"Válido hasta: ..."*

### Cuando no hay avisos

Si no hay incidencias activas, se muestra un mensaje verde con un icono de verificación:

> **"Sin incidencias activas — El servicio funciona con normalidad."**

### Actualizar avisos

- **Desliza hacia abajo** (pull-to-refresh) para recargar los avisos.
- También puedes pulsar el botón de **Actualizar** en la barra superior.

---

## 11. Alertas Activas

Accede a las Alertas Activas pulsando el **icono de campana (🔔)** en la barra superior de la pantalla principal.

### ¿Qué son las alertas?

Las alertas son notificaciones personalizadas que configuras tú desde la información de una parada (ver sección 7). Te avisan cuando un autobús específico se acerca a una parada seleccionada.

### Información de cada alerta

- **Línea** del autobús (indicador de color).
- **Destino** del autobús.
- **Nombre de la parada** donde esperas.
- **Tiempo estimado de llegada** (en tiempo real).
- **Estado de la alerta:**
  - ⏳ **Esperando** — El autobús aún está lejos.
  - ⚠️ **Muy cerca** — El autobús está a punto de llegar.
  - 🔔 **Llegando** — El autobús está llegando a tu parada.
  - ✅ **Notificado** — Ya has sido avisado.
- **Tiempo activa:** *"Activada hace X minutos"*.

### Acciones

- **Cancelar alerta:** Pulsa la **X** en la alerta. Aparecerá un diálogo de confirmación antes de eliminarla.
- **Ver parada en el mapa:** Pulsa **"Ver parada en el mapa"** para navegar directamente a la parada en el mapa.

### Cuando no hay alertas

Se muestra un mensaje informativo:

> **"No tienes alertas activas."**

Con un botón **"Ir al mapa"** para configurar una desde la información de una parada.

---

## 12. Perfil de Usuario

La pestaña **Perfil** muestra la información de tu cuenta y te permite acceder a varias funciones.

### Información mostrada

- **Avatar** con la inicial de tu correo electrónico.
- **Correo electrónico** registrado.
- **Fecha de alta:** *"Miembro desde..."*

### Estadísticas

Tres tarjetas resumen con:

- **Total de viajes** registrados.
- **Línea más usada** (la línea con la que más has viajado).
- **Viajes este mes** (conteo del mes actual).

### Acciones disponibles

| Acción | Descripción |
|--------|-------------|
| **Historial de viajes** | Accede a tu historial completo y estadísticas |
| **Ajustes** | Abre la página de configuración |
| **Editar correo** | Cambia tu dirección de email |
| **Cambiar contraseña** | Actualiza tu contraseña (requiere la contraseña actual) |
| **Cerrar sesión** | Cierra tu sesión con diálogo de confirmación |
| **Borrar cuenta** | Elimina permanentemente tu cuenta y todos tus datos |

> **⚠️ Atención:** Al borrar tu cuenta se eliminarán permanentemente tu historial de viajes y tus favoritos. Esta acción no se puede deshacer.

---

## 13. Historial de Viajes

Accede desde el perfil pulsando **"Historial de viajes"**. Tiene dos pestañas: **Estadísticas** e **Historial**.

### Pestaña: Estadísticas

Información detallada sobre tus patrones de uso:

- **Resumen:** Total de viajes, parada favorita y hora habitual de viaje.
- **Racha de viaje:** 🔥 Racha actual (días consecutivos viajando), 🏆 mejor racha histórica, y comparación con el mes anterior (📈 o 📉). Si llevas 3+ días seguidos, aparece un mensaje motivacional.
- **Gráfico mensual:** Diagrama de barras con el número de viajes por mes (últimos 6 meses). El mes actual aparece resaltado.
- **Líneas más usadas:** Ranking (🥇🥈🥉) de tus líneas favoritas con barras de progreso.
- **Paradas más visitadas:** Listado de las paradas donde más has viajado.
- **Distribución semanal:** Gráfico de barras (Lun-Dom) mostrando tu patrón de viaje semanal, con leyenda de días laborables vs. fin de semana.
- **Actividad reciente:** Comparativa de viajes en los últimos 7 días frente a los últimos 30 días.

### Pestaña: Historial

Lista cronológica de todos tus viajes, agrupados por fecha:

- **Hoy / Ayer / Fecha** (formato: "Lun 5 Mar").
- Cada viaje muestra:
  - **Indicador de línea** (color).
  - **Nombre de la parada.**
  - **Destino.**
  - **Hora** del viaje.
  - **Estado:** ✅ Confirmado (verde) / ❓ Sin confirmar (naranja).

### Acciones

- **Deslizar para eliminar:** Desliza un viaje hacia la izquierda para borrarlo individualmente.
- **Borrar historial completo:** En el menú de opciones (⋮) de la barra superior, selecciona **"Limpiar historial"**. Aparecerá un diálogo de confirmación.

---

## 14. Ajustes

Accede desde el perfil pulsando **"Ajustes"**. La página está organizada en secciones.

### Notificaciones

| Ajuste | Descripción | Rango |
|--------|-------------|-------|
| **Activar notificaciones** | Activa o desactiva las alertas de proximidad | On / Off |
| **Distancia de alerta** | Distancia a la que se dispara la notificación | 20 - 200 metros |
| **Tiempo entre notificaciones** | Intervalo mínimo entre notificaciones consecutivas | 1 - 30 minutos |
| **Vibración** | Activa o desactiva la vibración en las notificaciones | On / Off |

### Accesibilidad

| Ajuste | Descripción |
|--------|-------------|
| **Accesibilidad por voz (TTS)** | Lee en voz alta los nombres de paradas, llegadas de autobuses y saldo NFC |
| **Modo personas mayores (👵🏼)** | Aumenta el tamaño de texto y botones en toda la app (escala ×1.6) |

### Idioma

Selecciona el idioma de la app entre:

- 🇪🇸 **Español**
- 🏳️ **Valencià**
- 🇬🇧 **English**

El cambio se aplica inmediatamente sin reiniciar la app.

### Mapa

| Ajuste | Descripción |
|--------|-------------|
| **Mostrar buses simulados** | Muestra u oculta los autobuses en tiempo real en el mapa |
| **Actualización automática de horarios** | Actualiza automáticamente los tiempos de llegada |

### Información

- **Versión de la app** con número de compilación.
- **Guía para Samsung/Xiaomi:** Instrucciones para desactivar la optimización de batería en dispositivos Samsung y Xiaomi, lo que asegura que las notificaciones en segundo plano funcionen correctamente.
- **Botón "Enviar notificación de prueba":** Envía una notificación local para verificar que las notificaciones funcionan en tu dispositivo.

---

## 15. Accesibilidad

Alzitrans incluye varias funciones de accesibilidad:

### Modo Personas Mayores (👵🏼)

- Actívalo en **Ajustes > Accesibilidad > Modo personas mayores**.
- Aumenta el tamaño del texto a ×1.6 en toda la app.
- Agranda botones e iconos para facilitar la interacción.
- Se mantiene activo entre sesiones.

### Lectura por Voz (TTS)

- Actívalo en **Ajustes > Accesibilidad > Accesibilidad por voz**.
- La app leerá en voz alta:
  - El nombre de la parada al ver su información.
  - La próxima llegada de autobús.
  - El saldo y número de viajes al leer la tarjeta NFC.
- Funciona en el idioma seleccionado de la app.

### Soporte multilingüe

- La interfaz completa está disponible en **Español**, **Valencià** e **Inglés**.
- Cambia el idioma en tiempo real desde **Ajustes > Idioma**.

---

## 16. Solución de Problemas

### Las notificaciones no funcionan en segundo plano

En algunos dispositivos (especialmente **Samsung** y **Xiaomi**), el sistema operativo cierra las aplicaciones en segundo plano para ahorrar batería. Para solucionarlo:

**Samsung:**
1. Ve a **Ajustes del teléfono > Aplicaciones > Alzitrans**.
2. Pulsa en **Batería**.
3. Selecciona **"Sin restricciones"**.

**Xiaomi:**
1. Ve a **Ajustes del teléfono > Aplicaciones > Alzitrans > Inicio automático > Activar**.
2. Ve a **Seguridad > Batería > Sin restricciones** para Alzitrans.

### La lectura NFC no funciona

- Asegúrate de que el **NFC está activado** en los ajustes de tu teléfono.
- Coloca la tarjeta en la **parte trasera** del teléfono, cerca del sensor NFC (normalmente en el centro o la parte superior).
- Mantén la tarjeta **quieta** durante unos segundos.
- Si el problema persiste, comprueba que tu tarjeta sea de tipo **MIFARE Classic 1K** (las tarjetas estándar de transporte de Alzira lo son).

### No puedo ver mi ubicación en el mapa

- Comprueba que el **permiso de ubicación** está concedido a la app.
- Asegúrate de que el **GPS está activado** en tu dispositivo.
- Si estás en interiores, sal al exterior para mejorar la señal GPS.

### Los horarios de autobús no se cargan

- Comprueba tu **conexión a Internet** (WiFi o datos móviles).
- Pulsa el botón de **actualizar** en la información de la parada.
- Activa la opción **"Actualización automática de horarios"** en Ajustes > Mapa.

### La app se cierra inesperadamente

- Asegúrate de tener la **última versión** de la app instalada.
- Reinicia la aplicación.
- Si el problema persiste, los errores se reportan automáticamente al equipo de desarrollo.

---

## 17. Preguntas Frecuentes (FAQ)

**P: ¿La app es oficial del ayuntamiento de Alzira?**  
R: No. Alzitrans es un proyecto independiente creado por un estudiante de 2.º de DAM para mejorar la experiencia de transporte público en Alzira.

**P: ¿Puedo usar la app en iPhone?**  
R: Sí, pero la función de lectura de tarjetas NFC no está disponible en iOS debido a las restricciones de hardware de Apple con tarjetas MIFARE Classic. El resto de funciones (mapa, rutas, avisos, perfil) funcionan con normalidad.

**P: ¿Los datos de mi tarjeta NFC se envían por Internet?**  
R: No. La lectura de la tarjeta NFC se procesa localmente en tu dispositivo. No se envían datos de tu tarjeta a ningún servidor.

**P: ¿Puedo usar la app sin crear una cuenta?**  
R: Necesitas registrarte para acceder a todas las funciones, incluyendo el historial de viajes y la sincronización de datos.

**P: ¿Qué líneas de autobús cubre la app?**  
R: Actualmente cubre las líneas **L1**, **L2** y **L3** del transporte público de Alzira.

**P: ¿Cómo puedo eliminar mi cuenta?**  
R: Desde **Perfil > Borrar cuenta**. Se te pedirá confirmación. Ten en cuenta que se borrarán todos tus datos de forma permanente.

**P: ¿La posición de los autobuses en el mapa es en tiempo real?**  
R: Los autobuses que se muestran en el mapa son **simulaciones** basadas en las rutas y horarios. Pueden no reflejar la posición exacta del autobús en ese momento.

**P: ¿Puedo cambiar el idioma de la app?**  
R: Sí. Ve a **Ajustes > Idioma** y selecciona entre Español, Valencià o English. El cambio se aplica al instante.

---

*Manual de usuario de Alzitrans v3.0 — Última actualización: Marzo 2026*
