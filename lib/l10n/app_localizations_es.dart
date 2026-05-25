// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Alzitrans — Alzira';

  @override
  String get tabMap => 'Mapa';

  @override
  String get tabRoutes => 'Rutas';

  @override
  String get tabNfc => 'NFC';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get logoutConfirm => '¿Seguro que quieres cerrar sesión?';

  @override
  String get profile => 'Mi perfil';

  @override
  String get editEmail => 'Cambiar email';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get update => 'Actualizar';

  @override
  String get retry => 'Reintentar';

  @override
  String get profileLoadError => 'No se pudo cargar el perfil';

  @override
  String get accountInfo => 'Información de cuenta';

  @override
  String get lastAccess => 'Último acceso';

  @override
  String get memberSince => 'Miembro desde';

  @override
  String get totalTrips => 'Total viajes';

  @override
  String get mostUsedLine => 'Línea favorita';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get notices => 'Avisos';

  @override
  String get noActiveNotices => 'Sin avisos activos';

  @override
  String get serviceNormal => 'El servicio funciona con normalidad';

  @override
  String get noticeTitle => 'Título';

  @override
  String get noticeBody => 'Descripción';

  @override
  String get validUntil => 'Hasta';

  @override
  String get tripHistory => 'Historial de viajes';

  @override
  String get activeAlerts => 'Alertas activas';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get activateNotifications => 'Activar notificaciones';

  @override
  String get notificationsSubtitle => 'Recibir avisos al acercarse a paradas';

  @override
  String get alertDistance => 'Distancia de aviso';

  @override
  String get timeBetweenNotifications => 'Tiempo entre notificaciones';

  @override
  String get vibration => 'Vibración';

  @override
  String get vibrationSubtitle => 'Vibrar con las notificaciones';

  @override
  String minutesSuffix(int n) {
    return '$n minutos';
  }

  @override
  String metersSuffix(int n) {
    return '$n metros';
  }

  @override
  String get map => 'Mapa';

  @override
  String get showSimulatedBuses => 'Mostrar buses en el mapa';

  @override
  String get showSimulatedBusesSubtitle =>
      'Ver posición simulada de los autobuses';

  @override
  String get autoRefreshTimes => 'Actualizar tiempos automáticamente';

  @override
  String get autoRefreshTimesSubtitle => 'Refrescar cada 30 segundos';

  @override
  String get serviceStatus => 'Estado del servicio';

  @override
  String get serviceActive => 'Servicio activo';

  @override
  String get serviceStopped => 'Servicio detenido';

  @override
  String get lastCheck => 'Último chequeo';

  @override
  String get activeAlertsCount => 'Alertas activas';

  @override
  String get lastBus => 'Último bus';

  @override
  String get refreshButton => 'Actualizar';

  @override
  String get testNotification => 'Probar notificación';

  @override
  String get resetAlerts => 'Reiniciar alertas';

  @override
  String get checkNow => 'Verificar buses AHORA';

  @override
  String get information => 'Información';

  @override
  String get appDescription =>
      'Aplicación para ver paradas de bus en Alzira, Valencia.';

  @override
  String get didYouTakeTheBus => '¿Cogiste el bus?';

  @override
  String get yes => '¡Sí!';

  @override
  String get no => 'No';

  @override
  String get tripRegistered => '¡Viaje registrado!';

  @override
  String get delete => 'Eliminar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get never => 'Nunca';

  @override
  String get loginTitle => 'Iniciar Sesión en Alzitrans';

  @override
  String get enterEmail => 'Introduce tu email';

  @override
  String get invalidEmail => 'El email no tiene un formato válido';

  @override
  String get enterPassword => 'Introduce tu contraseña';

  @override
  String get passwordTooShort =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get loginButton => 'Entrar';

  @override
  String get noAccount => '¿No tienes cuenta? Regístrate';

  @override
  String get incorrectCredentials => 'Email o contraseña incorrectos.';

  @override
  String get noServerConnection =>
      'Sin conexión al servidor. Comprueba tu red.';

  @override
  String get accountDisabled => 'Esta cuenta está desactivada.';

  @override
  String get activeAlertsTitle => 'Alertas Activas';

  @override
  String get noActiveAlerts => 'Sin alertas activas';

  @override
  String get noActiveAlertsHint =>
      'Pulsa \"Avisar\" en una parada\npara recibir notificaciones';

  @override
  String get goToMap => 'Ir al mapa';

  @override
  String get cancelAlert => '¿Cancelar alerta?';

  @override
  String get cancelAlertBody => 'Dejarás de recibir avisos para esta línea';

  @override
  String get cancelAlertYes => 'Sí, cancelar';

  @override
  String get noData => 'Sin datos';

  @override
  String get noService => 'Sin servicio';

  @override
  String alertActivatedMinAgo(int n) {
    return 'Activada hace $n min';
  }

  @override
  String get viewStopOnMap => 'Ver parada en mapa';

  @override
  String get cancelAlertTooltip => 'Cancelar alerta';

  @override
  String get statusWaiting => '⏳ Esperando';

  @override
  String get statusNotified => '✅ Avisado';

  @override
  String get statusClose => '⚠️ Muy cerca';

  @override
  String get statusArriving => '🔔 Llegando';

  @override
  String get newNoticePopupTitle => 'Nuevo Aviso';

  @override
  String get understood => 'Entendido';

  @override
  String get tripHistoryTitle => 'Historial de Viajes';

  @override
  String get tabStats => 'Estadísticas';

  @override
  String get tabHistory => 'Historial';

  @override
  String get clearHistory => 'Borrar historial';

  @override
  String get clearHistoryConfirmTitle => '¿Borrar historial?';

  @override
  String get clearHistoryConfirmBody =>
      'Se eliminarán todos los viajes guardados.';

  @override
  String get noTripsRegistered => 'Sin viajes registrados';

  @override
  String get noTripsHint =>
      'Activa alertas de bus para empezar\na registrar tus viajes';

  @override
  String get noTripsHistory => 'Sin viajes en el historial';

  @override
  String get streakTitle => '🔥 Rachas y Progreso';

  @override
  String get streak => 'Racha';

  @override
  String get bestStreak => 'Mejor';

  @override
  String get vsPrevMonth => 'vs mes ant.';

  @override
  String streakMessage(int n) {
    return '¡$n días seguidos viajando! 🎉';
  }

  @override
  String get tripsPerMonth => '📊 Viajes por Mes';

  @override
  String get weekdaysTitle => '📅 Días de la Semana';

  @override
  String get weekdays => 'Entre semana';

  @override
  String get weekends => 'Fin de semana';

  @override
  String get summaryTitle => '📈 Resumen';

  @override
  String get totalTripsLabel => 'Viajes totales';

  @override
  String get favouriteStop => 'Parada favorita';

  @override
  String get usualTime => 'Horario habitual';

  @override
  String get topLines => '🚌 Líneas más usadas';

  @override
  String get line => 'Línea';

  @override
  String get topStops => '🚏 Paradas más frecuentes';

  @override
  String get recentActivity => '📅 Actividad reciente';

  @override
  String get last7days => 'Últimos 7 días';

  @override
  String get last30days => 'Últimos 30 días';

  @override
  String get forgotPassword => 'Olvidé mi contraseña';

  @override
  String get forgotPasswordTitle => 'Recuperar Contraseña';

  @override
  String get forgotPasswordInstructions =>
      'Introduce tu email para recibir un código de recuperación.';

  @override
  String get sendCode => 'Enviar código';

  @override
  String get enterCode => 'Introduce el código';

  @override
  String get codeSent => 'Código enviado a tu email';

  @override
  String get resetPasswordTitle => 'Nueva Contraseña';

  @override
  String get resetPasswordButton => 'Restablecer Contraseña';

  @override
  String get passwordResetSuccess => 'Contraseña actualizada correctamente';

  @override
  String get verifyCode => 'Verificar código';

  @override
  String get accessibilityVoice => 'Modo Accesibilidad (Voz)';

  @override
  String get accessibilityVoiceSubtitle => 'Lee las paradas al seleccionarlas';

  @override
  String get highVisibilityMode => 'Modo Alta Visibilidad';

  @override
  String get highVisibilitySubtitle => 'Optimizado para mejor legibilidad';

  @override
  String get helpAndSupport => 'Ayuda y Soporte';

  @override
  String get helpAndSupportSubtitle => 'Preguntas frecuentes y contacto';

  @override
  String get privacyAndPermissions => 'PERMISOS Y PRIVACIDAD';

  @override
  String get backgroundAlerts => 'Alertas en segundo plano';

  @override
  String get backgroundAlertsSubtitle =>
      'Configura el rastreo de bus fuera de la app';

  @override
  String get permissionActivated => 'Ya tienes este permiso activado ✅';

  @override
  String get configure => 'Configurar';

  @override
  String get privacyPolicy => 'Política de Privacidad';

  @override
  String get privacyPolicySubtitle => 'Consulta cómo protegemos tus datos';

  @override
  String get dataCredits => 'Créditos y fuentes de datos';

  @override
  String get dataCreditsSubtitle => 'De dónde vienen los horarios y avisos';

  @override
  String get dataCreditsTitle => 'Fuentes de datos';

  @override
  String get dataCreditsBusOperator => 'Tiempos de autobús';

  @override
  String get dataCreditsBusOperatorBody =>
      'Los horarios y tiempos de paso de las líneas L1, L2 y L3 son cortesía de Autocares Lozano S.L.U., concesionaria del servicio urbano de Alzira. Alzitrans consulta la información pública directamente desde el dispositivo de cada usuario; no almacena ni redistribuye los datos. Alzitrans no está afiliada con Autocares Lozano S.L.U.';

  @override
  String get dataCreditsRenfe => 'Trenes Cercanías';

  @override
  String get dataCreditsRenfeBody =>
      'Los horarios de Cercanías C2 provienen de Renfe Operadora.';

  @override
  String get dataCreditsThanks =>
      'Gracias a Autocares Lozano S.L.U. por hacer pública esta información, sin la cual esta app no podría existir.';

  @override
  String get creditsLineLozano => 'Datos por Autocares Lozano';

  @override
  String get removeAdsTitle => 'Quitar Anuncios (30 min)';

  @override
  String get removeAdsSubtitle => 'Ver un vídeo corto para ocultar banners';

  @override
  String get adsHiddenSuccess =>
      '¡Anuncios ocultos por 30 minutos! Disfruta 🎉';

  @override
  String get adNotAvailable =>
      'Anuncio no disponible en este momento. Inténtalo más tarde.';

  @override
  String get deleteAccountTitle => 'Eliminar cuenta';

  @override
  String get deleteAccountSubtitle => 'Borrado permanente de todos tus datos';

  @override
  String get deleteAccountDialogTitle => '¿Eliminar tu cuenta?';

  @override
  String get deleteAccountIrreversible =>
      'Esta acción es irreversible. Se borrarán permanentemente:';

  @override
  String get deleteAccountBullet1 => '• Tu historial de viajes y estadísticas.';

  @override
  String get deleteAccountBullet2 => '• Tus paradas favoritas.';

  @override
  String deleteAccountConfirm(String email) {
    return '¿Estás totalmente seguro de que quieres eliminar la cuenta de $email?';
  }

  @override
  String get deleteAccountConfirmButton => 'SÍ, ELIMINAR TODO';

  @override
  String get accountDeletedSuccess =>
      'Cuenta eliminada con éxito. Sentimos que te vayas.';

  @override
  String get emailUpdatedSuccess => '✅ Email actualizado';

  @override
  String get passwordUpdatedSuccess => '✅ Contraseña actualizada';

  @override
  String genericError(String message) {
    return 'Error: $message';
  }

  @override
  String get loginWithBiometrics => 'Entrar con huella';

  @override
  String biometricLoginError(String error) {
    return 'Error en acceso biométrico: $error';
  }

  @override
  String unexpectedError(String error) {
    return 'Error inesperado: $error';
  }

  @override
  String get registerTitle => 'Registro en Alzibus';

  @override
  String get registerInfoBox =>
      'Te enviaremos un código al iniciar sesión. Si no inicias sesión en 7 días, la cuenta se eliminará automáticamente.';

  @override
  String get accountCreatedSnack =>
      'Cuenta creada. Inicia sesión en los próximos 7 días o se eliminará automáticamente.';

  @override
  String get registerButton => 'Registrarse';

  @override
  String get verifyEmailTitle => 'Verificar Correo';

  @override
  String get confirmYourEmail => 'Confirma tu correo';

  @override
  String codeSentToEmail(String email) {
    return 'Hemos enviado un código de 6 dígitos a:\n$email';
  }

  @override
  String get codeExpiresIn15Min => 'El código caduca en 15 minutos.';

  @override
  String get verifyCodeButton => 'Verificar Código';

  @override
  String resendCodeWithLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reenviar código ($count restantes)',
      one: 'Reenviar código (1 restante)',
    );
    return '$_temp0';
  }

  @override
  String get noResendsLeft => 'Sin reenvíos disponibles';

  @override
  String get enableBiometricsDialog => '¿Activar Huella?';

  @override
  String get enableBiometricsBody =>
      '¿Quieres entrar más rápido la próxima vez usando tu huella dactilar?';

  @override
  String get notNow => 'Ahora no';

  @override
  String get yesActivate => '¡Sí, activar!';

  @override
  String get stopAddedToFavorites => '⭐ Parada añadida a favoritos';

  @override
  String alertSetForLine(String line) {
    return '✅ Te avisaremos cuando llegue la línea $line';
  }

  @override
  String get requiresInternet => '(Requiere conexión a internet)';

  @override
  String get mapView => 'Mapa';

  @override
  String get satelliteView => 'Satélite';

  @override
  String get satelliteViewUnavailable => 'Vista satelital no disponible';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get addToFavorites => 'Añadir a favoritos';

  @override
  String get nextBuses => '⏱️ Próximos buses:';

  @override
  String get noUpcomingBuses => 'No hay buses próximos';

  @override
  String get nearbyTrainsC2 => '🚆 Trenes Cercanías C2:';

  @override
  String get noUpcomingTrains => 'No hay trenes próximos';

  @override
  String get refresh => 'Actualizar';

  @override
  String get refreshTrains => 'Actualizar trenes';

  @override
  String get linesLabel => 'Líneas:';

  @override
  String get lines => 'Líneas';

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count días',
      one: 'Hace 1 día',
      zero: 'Hoy',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count minutos',
      one: 'Hace 1 minuto',
      zero: 'Ahora mismo',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count horas',
      one: 'Hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String lineWithNumber(String line) {
    return 'Línea $line';
  }

  @override
  String oneTripWillBeDeducted(int remaining) {
    return 'Se descontará 1 viaje de tu tarjeta (te quedan $remaining)';
  }

  @override
  String get unlimitedTrips => 'Tienes viajes ILIMITADOS';

  @override
  String get noTripsOnCard => 'No tienes viajes en la tarjeta';

  @override
  String get noTripUnderstood => '👍 Entendido, no se registró';

  @override
  String get iDidntGetOn => 'No he subido';

  @override
  String get yesIGotOn => 'Sí, registrar';

  @override
  String get cardTripRegistered => '¡Viaje con Tarjeta registrado!';

  @override
  String get cashTripRegistered => '¡Viaje en Efectivo registrado!';

  @override
  String get viewHistory => 'Ver historial';

  @override
  String get playWhileWaiting => '¡Echa una partida mientras esperas!';

  @override
  String get welcomeGreeting => '¡Hola! 👋';

  @override
  String get welcomeMessage => '¡Espero que te sea de mucha utilidad!';

  @override
  String get busInService => 'Autobús en servicio';

  @override
  String get nextStop => 'Próxima parada';

  @override
  String get welcomeThanks => 'Gracias por descargar Alzi Trans.';

  @override
  String get welcomeStudent =>
      'Soy un estudiante de 2º de DAM y he creado esta app de forma independiente para mejorar nuestro transporte.';

  @override
  String get welcomeDevelopmentNotice =>
      'Ten en cuenta que es un proyecto en desarrollo y puede contener errores.';

  @override
  String get understoodCaps => 'ENTENDIDO';

  @override
  String get estimatedTime => 'Tiempo estimado';

  @override
  String get statusLabel => 'Estado';

  @override
  String get atStop => '🛑 En parada';

  @override
  String get inMovement => '🚌 En movimiento';

  @override
  String get nfcCardReadSuccess => 'Tarjeta leída correctamente';

  @override
  String nfcBalanceAnnounce(String balance, int trips) {
    return 'Saldo de $balance euros. Te quedan $trips viajes.';
  }

  @override
  String get nfcUnlimitedAnnounce => 'Bono ilimitado activo.';

  @override
  String busArrivalAnnounce(
      String line, String destination, String stop, int minutes) {
    return 'El autobús de la línea $line con destino $destination llegará a $stop en $minutes minutos.';
  }

  @override
  String busArrivingAnnounce(Object destination, Object line, Object stop) {
    return 'El autobús de la línea $line con destino $destination está llegando a $stop.';
  }

  @override
  String stopAnnounce(Object name) {
    return 'Parada $name.';
  }

  @override
  String get teHemosApuntado => 'Te hemos apuntado al bus';

  @override
  String get alertaActiva => '(Alerta activa)';

  @override
  String personasInteresadas(int n) {
    return '$n personas interesadas';
  }

  @override
  String get rankingTitle => 'Ranking de Viajeros';

  @override
  String get rankingSubtitle => 'Compite con otros viajeros de Alzira';

  @override
  String yourPosition(int pos, int trips) {
    return 'Tu posición: #$pos · $trips viajes';
  }

  @override
  String get thisMonthToggle => 'Este mes';

  @override
  String get allTimeToggle => 'Todo el tiempo';

  @override
  String get rankingLoadError => 'No se pudo cargar el ranking';

  @override
  String get noTripsRankingMonth =>
      'Nadie ha viajado este mes aún. ¡Sé el primero!';

  @override
  String get noTripsRankingAll => 'Aún no hay viajes registrados.';

  @override
  String get travelersRankingHeader => '🏆 Ranking de Viajeros';
}
