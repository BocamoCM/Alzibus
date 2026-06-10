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
  String get watchAdSubtitle => 'Ver un vídeo corto y disfrutar sin banners';

  @override
  String get adNotReadyYet =>
      'Anuncio aún no disponible. Inténtalo en unos segundos.';

  @override
  String get adsHiddenShort => '¡Anuncios ocultos por 30 minutos! 🎉';

  @override
  String get dailyAdLimitReached =>
      'Has alcanzado el límite de anuncios de hoy. ¡Vuelve mañana!';

  @override
  String coinsEarnedThanks(int count) {
    return '+$count monedas 🪙 ¡Gracias!';
  }

  @override
  String get dailyEarningsExplained =>
      'Cada día puedes ganar hasta 30 monedas jugando + 60 viendo anuncios. Es ritmo lento pero constante: vuelve cada día para subir el monedero.';

  @override
  String get dailyMaxReached => 'Has llegado al máximo de hoy. ¡Vuelve mañana!';

  @override
  String confirmSpendCoins(int cost, String skin) {
    return '¿Confirmas que quieres gastar $cost 🪙 para desbloquear $skin?';
  }

  @override
  String skinUnlockedAndEquipped(String skin) {
    return '¡$skin desbloqueado y equipado! 🎉';
  }

  @override
  String wearingSkin(String skin) {
    return 'Llevas el \"$skin\"';
  }

  @override
  String unlockSkinTitle(String skin) {
    return 'Desbloquear $skin';
  }

  @override
  String unlockSkinBody(int cost) {
    return '¿Confirmas que quieres gastar $cost 🪙 para desbloquear este vestido? Una vez desbloqueado lo tienes para siempre.';
  }

  @override
  String get unlockButton => 'Desbloquear';

  @override
  String get notEnoughCoins => 'No tienes suficientes monedas.';

  @override
  String skinEquipped(String skin) {
    return '$skin equipado';
  }

  @override
  String get mifareClassicInfo =>
      'Las tarjetas Mifare Classic 1K requieren autenticación especial para leer el saldo. La mayoría de móviles Android no pueden leerlas sin hardware especializado.';

  @override
  String get featureNotAvailableWeb => 'Función no disponible en navegador';

  @override
  String get featureAndroidOnly => 'Función exclusiva de Android';

  @override
  String get nfcWebExplained =>
      'La lectura de tarjetas NFC requiere acceso al hardware que no está disponible en la versión web.\n\nInstala la app para usar esta función.';

  @override
  String get nfcIosExplained =>
      'Debido a restricciones de Apple con las tarjetas Mifare Classic, la lectura de saldo no es compatible con iPhone.\n\nUsa el mapa y horarios para planificar tu viaje.';

  @override
  String get publicTransportAlzira => 'Transporte Público Alzira';

  @override
  String get validateTripPrompt =>
      '¿Deseas validar un viaje ahora? Se restará 1 de tu contador.';

  @override
  String get confirmTripTitle => 'Confirmar viaje';

  @override
  String get shareTripIntro =>
      '¿Quieres que alguien sepa por dónde vas? Empieza el viaje compartido y te doy un enlace para enviarles.';

  @override
  String get creatingSharedTrip => 'Creando tu viaje compartido...';

  @override
  String get noLocationPermissionShare =>
      'Sin permiso de ubicación no puedo compartir el viaje.';

  @override
  String get needLocationPermissionAlbus =>
      '¡Necesito permiso para ver dónde estás!';

  @override
  String get tripReadyShareIt =>
      '¡Listo! Comparte el enlace y la gente verá dónde vas en tiempo real.';

  @override
  String couldntCreateTrip(String error) {
    return 'No pude crear el viaje: $error';
  }

  @override
  String get somethingBrokeRetry => 'Algo se torció. ¿Probamos de nuevo?';

  @override
  String get endingSharedTrip => 'Terminando el compartido...';

  @override
  String get tripEnded => '¡Viaje terminado! Buen camino 👋';

  @override
  String shareMessageWithDest(String url) {
    return '¡Voy en el bus! Mira por dónde voy en vivo: $url';
  }

  @override
  String shareMessage(String url) {
    return '¡Sigue mi viaje en bus en vivo! $url';
  }

  @override
  String shareSubjectWithDest(String destination) {
    return 'Voy hacia $destination · Alzitrans';
  }

  @override
  String get shareSubject => 'Mi viaje en vivo · Alzitrans';

  @override
  String get linkShared => '¡Enlace compartido! 🚌';

  @override
  String linkCopied(String url) {
    return 'Enlace copiado: $url';
  }

  @override
  String destinationLabel(String name) {
    return 'Destino: $name';
  }

  @override
  String get lineLabelSingular => 'Línea: ';

  @override
  String get shareTripExplanation =>
      'Al empezar, se generará un enlace público que puedes mandar a quien quieras. Verán tu posición y la hora estimada de llegada actualizadas cada 30 segundos.';

  @override
  String get linkExpires6Hours => 'El enlace caduca solo a las 6 horas.';

  @override
  String get startingButton => 'Iniciando...';

  @override
  String get startSharingButton => 'Empezar a compartir';

  @override
  String get sharingLive => 'Compartiendo en vivo';

  @override
  String get destination => 'Destino';

  @override
  String get lineSingular => 'Línea';

  @override
  String get etaLabel => 'Llegada estimada';

  @override
  String get lastPosition => 'Última posición';

  @override
  String get linkToShare => 'Enlace para compartir';

  @override
  String get copy => 'Copiar';

  @override
  String get seeAsOthersSee => 'Ver como lo ven los demás';

  @override
  String get endingButton => 'Terminando...';

  @override
  String get stopSharingButton => 'Terminar de compartir';

  @override
  String get minimizeBackgroundNotice =>
      'Puedes minimizar la app sin problema: los pings de ubicación siguen mandándose en segundo plano cada 30 s.';

  @override
  String minutesShort(int n) {
    return '$n min';
  }

  @override
  String get plannerTitle => 'Planificador con Albus';

  @override
  String get albusGreeting =>
      '¡Hola! Soy Albus 🚌. Dime de dónde sales y a dónde vas, y te digo qué bus coger.';

  @override
  String get chooseOriginAndDest => 'Elige origen y destino antes de buscar.';

  @override
  String get albusNeedsOriginDest =>
      '¡Ay! Necesito saber de dónde sales y a dónde vas.';

  @override
  String get sameStopError => 'El origen y el destino son la misma parada.';

  @override
  String get albusAlreadyThere => 'Pero... ¡si ya estás ahí! 😅';

  @override
  String get albusSearchingRoute => 'Estoy mirando qué bus te lleva...';

  @override
  String get albusNoRoute =>
      'Vaya... no encuentro ruta directa. Quizás merezca la pena ir andando.';

  @override
  String get albusOneRoute => '¡Tengo una ruta! Te la explico paso a paso 👇';

  @override
  String albusMultipleRoutes(int count) {
    return '¡Tengo $count opciones! La primera es la más rápida.';
  }

  @override
  String searchError(String error) {
    return 'Algo se torció al buscar ($error). Inténtalo de nuevo.';
  }

  @override
  String get albusCantCalculate =>
      'Ups, no pude calcular la ruta. ¿Probamos otra vez?';

  @override
  String get albusSwapped => '¡Cambiado! ¿Buscamos esta nueva ruta?';

  @override
  String get albusFindingYou => 'A ver dónde estás...';

  @override
  String get enableLocationRetry =>
      'Activa la ubicación del móvil y vuelve a intentarlo.';

  @override
  String get noLocationPermission =>
      'Sin permiso de ubicación no puedo saber dónde estás.';

  @override
  String get noStopsNearYou => 'No hay paradas cerca de ti — ¿estás en Alzira?';

  @override
  String veryCloseToStop(String name) {
    return 'Estás muy cerca de $name. ¿A dónde vamos?';
  }

  @override
  String nearestStopIs(String name, int dist) {
    return 'La parada más cercana es $name (a $dist m). ¿A dónde vamos?';
  }

  @override
  String get couldntFindYou => 'No pude saber dónde estás 😢';

  @override
  String okFromStop(String name) {
    return 'Vale, sales de $name. ¿A dónde vas?';
  }

  @override
  String askDestRoute(String name) {
    return '¿Buscamos cómo ir a $name?';
  }

  @override
  String okToStop(String name) {
    return 'Vale, vas a $name. ¿De dónde sales?';
  }

  @override
  String get readyToSearch => 'Listos. Pulsa \"Buscar ruta\" cuando quieras.';

  @override
  String get searchingYourLocation => 'Buscando tu ubicación...';

  @override
  String get usingYourLocation => 'Usando tu ubicación actual';

  @override
  String get useMyLocationButton => 'Usar mi ubicación como origen';

  @override
  String get fromNearestStop => 'Desde (parada más cercana)';

  @override
  String get fromLabel => 'Desde';

  @override
  String get toLabel => 'Hasta';

  @override
  String get swap => 'Intercambiar';

  @override
  String get searchRoute => 'Buscar ruta';

  @override
  String errorLoadingStops(String error) {
    return 'Error cargando paradas: $error';
  }

  @override
  String get searchStopByName => 'Busca parada por nombre…';

  @override
  String linesWithList(String lines) {
    return 'Líneas: $lines';
  }

  @override
  String get shareThisTripLive => 'Compartir este viaje en vivo';

  @override
  String get bestOption => 'MEJOR OPCIÓN';

  @override
  String optionN(int n) {
    return 'OPCIÓN $n';
  }

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transbordos',
      one: '1 transbordo',
    );
    return '$_temp0';
  }

  @override
  String walkingStep(int dist, int duration) {
    return 'Andando · $dist m · $duration min';
  }

  @override
  String busStepDetail(int stops, int duration) {
    return '$stops paradas · $duration min';
  }

  @override
  String boardAt(String name) {
    return 'Sube: $name';
  }

  @override
  String alightAt(String name) {
    return 'Baja: $name';
  }

  @override
  String transferAt(String name) {
    return 'Transbordo en $name';
  }

  @override
  String transferStep(String from, String to, int duration) {
    return 'De $from a $to · ~$duration min';
  }

  @override
  String get triviaTitle => 'Trivia de Alzira';

  @override
  String questionXofY(int current, int total) {
    return 'Pregunta $current/$total';
  }

  @override
  String get skipQuestionAd => 'Saltar pregunta (ver anuncio)';

  @override
  String get triviaCompleted => 'Trivia completada';

  @override
  String scoreLabel(int score) {
    return 'Puntuación: $score';
  }

  @override
  String get newRecord => '🏆 ¡Nuevo récord!';

  @override
  String currentRecord(int score) {
    return 'Récord: $score';
  }

  @override
  String coinsAddedWallet(int count) {
    return '+$count 🪙 al monedero';
  }

  @override
  String get playAgain => 'Jugar otra vez';

  @override
  String get backToMenu => 'Volver al menú';

  @override
  String get memoryStopsTitle => 'Memoria de Paradas';

  @override
  String get catchTheBusTitle => 'Atrapa el Bus';

  @override
  String get gamesHubTitle => 'Mini-Juegos';

  @override
  String get playGame => 'Jugar';

  @override
  String highScore(int score) {
    return 'Récord: $score';
  }

  @override
  String get memoryStopsHowTo => 'Memoriza el orden y reprodúcelo';

  @override
  String get catchTheBusHowTo => 'Toca el bus cuando pase por la parada';

  @override
  String get triviaHowTo => '10 preguntas sobre Alzira y la app';

  @override
  String get gameOver => '¡Fin del juego!';

  @override
  String get tapToStart => 'Toca para empezar';

  @override
  String reachedRound(int round) {
    return 'Llegaste a la ronda $round';
  }

  @override
  String currentRecordRounds(int score) {
    return 'Récord: $score rondas';
  }

  @override
  String get repeatSequenceAd => 'Repetir secuencia (anuncio)';

  @override
  String get watchAdForCoinsLabel => 'Ver anuncio +30 🪙';

  @override
  String get missedGreenBus => 'Se te escapó un bus verde';

  @override
  String get reviveWatchAd => 'Revivir viendo un anuncio';

  @override
  String get gamesHubHeading => 'Juegos · Mata el tiempo';

  @override
  String get wardrobeTooltip => 'Vestidor de Albus';

  @override
  String get availableGames => 'Disponibles';

  @override
  String get catchTheBusDesc =>
      'Toca buses verdes 🚌 antes de que se escapen. Esquiva los rojos 🚒. ¿Cuánto aguantas?';

  @override
  String currentRecordPrefix(int score) {
    return '🏆 Récord actual: $score';
  }

  @override
  String currentRecordPts(int score) {
    return '🏆 Récord actual: $score pts';
  }

  @override
  String get beTheFirstRecord => '¡Sé el primero en marcar récord!';

  @override
  String get triviaDesc =>
      'Preguntas sobre el bus, la ciudad y la comarca. 10 preguntas, 15s cada una.';

  @override
  String get howMuchYouKnow => '¿Cuánto sabes de Alzira?';

  @override
  String get memoryStopsDesc =>
      'Albus muestra paradas en orden. Tú las repites. Cada ronda añade una más.';

  @override
  String bestRound(int round) {
    return '🏆 Mejor: ronda $round';
  }

  @override
  String get simonAlziraStyle => 'Simon Says estilo Alzira';

  @override
  String get gamesLegalNotice =>
      'Los juegos pueden mostrar anuncios opcionales (revivir, bonus). Las monedas son decorativas — futuras versiones permitirán canjearlas por contenido.';

  @override
  String get albusGamesIntro =>
      '¿Esperando el bus? ¡Echemos una partida! Gana monedas mientras llega.';

  @override
  String get skinDefaultName => 'Original';

  @override
  String get skinFalleroName => 'Fallero';

  @override
  String get skinCapurulloName => 'Capurullo';

  @override
  String get skinLluviaName => 'Lluvia';

  @override
  String get skinGraduadoName => 'Graduado';

  @override
  String get skinNavidadName => 'Navidad';

  @override
  String get skinAlziraFcName => 'UDA';

  @override
  String get feedbackTitle => 'Soporte y feedback';

  @override
  String get feedbackHeading => '¿En qué podemos ayudarte?';

  @override
  String get categoryLabel => 'Categoría';

  @override
  String get subjectLabel => 'Resumen breve (Asunto)';

  @override
  String get subjectRequired => 'El asunto es obligatorio';

  @override
  String get descriptionLabel => 'Descripción detallada';

  @override
  String get descriptionRequired => 'La descripción es obligatoria';

  @override
  String get sendTicket => 'Enviar Ticket';

  @override
  String get addComment => 'Añadir un comentario...';

  @override
  String get attachImage => 'Adjuntar imagen';

  @override
  String get conversation => 'Conversación';

  @override
  String get conversationClosedInactive =>
      'Conversación cerrada (Aviso inactivo)';

  @override
  String get noMessagesYet => 'Sin mensajes aún.\nEscribe para empezar.';

  @override
  String get couldNotSendRetry => 'No se pudo enviar. Inténtalo de nuevo.';

  @override
  String get downloadNotSupportedWeb =>
      'Descarga no soportada en web desde la app móvil';

  @override
  String get arVisionTitle => 'Visión AR';

  @override
  String get routesPageTitle => 'Rutas y líneas';

  @override
  String get planWithAlbus => 'Planifica con Albus';

  @override
  String get planWithAlbusTooltip => 'Planificador de ruta A → B con Albus';

  @override
  String albusWalkShort(String to) {
    return 'Da unos pasos hasta $to — no está lejos.';
  }

  @override
  String albusWalkMid(int dist, String to, int duration) {
    return 'Camina unos $dist metros hasta $to. ¡En $duration min lo tienes!';
  }

  @override
  String albusWalkLong(String to, int dist, int duration) {
    return 'Camina hasta $to ($dist m, unos $duration min).';
  }

  @override
  String albusBusStep(int count, String line, String from, String to) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Coge la $line en $from. Bájate $count paradas después, en $to.',
      one: 'Coge la $line en $from. Bájate 1 parada después, en $to.',
    );
    return '$_temp0';
  }

  @override
  String albusTransferStep(String at, String toLine, int duration) {
    return 'En $at bájate y coge la $toLine. ¡Échale un ojo al horario, son unos $duration min!';
  }

  @override
  String get supportTitle => 'Ayuda y Soporte';

  @override
  String get supportFaqHeading => 'Preguntas Frecuentes';

  @override
  String get supportFaqAlertsQ => '¿Cómo funcionan las alertas?';

  @override
  String get supportFaqAlertsA =>
      'Cuando activas una alerta en una llegada, la app monitoriza en segundo plano el tiempo restante. Te avisará cuando el bus esté a menos de la distancia configurada (ej: 80 metros) para que no lo pierdas.';

  @override
  String get supportFaqLocationQ => '¿Por qué pide ubicación \"Siempre\"?';

  @override
  String get supportFaqLocationA =>
      'Para que las alertas funcionen aunque tengas el móvil en el bolsillo o estés usando otra app. Alzitrans solo usa tu ubicación cuando tienes una alerta activa para avisarte justo a tiempo.';

  @override
  String get supportFaqRechargeQ => '¿Cómo recargar mi tarjeta Alzibus?';

  @override
  String get supportFaqRechargeA =>
      'Las tarjetas físicas de Alzibus se pueden recargar directamente en el autobús al subir o en los puntos de venta autorizados de la ciudad. Muy pronto podrás consultar tu saldo real aproximado desde la app.';

  @override
  String get supportFaqPointsQ => '¿Qué son los puntos y el Rank?';

  @override
  String get supportFaqPointsA =>
      'Es nuestro sistema de Gamificación. Ganarás puntos por cada viaje registrado y por abrir la app diariamente. ¡Sube de Rank para demostrar que eres el usuario #1 de Alzitrans!';

  @override
  String get supportSuggestionsHeading => '¿Tienes sugerencias?';

  @override
  String get supportSuggestionsBody =>
      'Nos encanta escuchar vuestras ideas para mejorar Alzitrans. ¡Escríbenos!';

  @override
  String get supportSendButton => 'Enviar Propuesta de Mejora';

  @override
  String get supportEmailSubject => 'Sugerencia Alzitrans - Mejora';

  @override
  String get supportEmailBody =>
      'Hola,\n\nMe gustaría sugerir lo siguiente para Alzitrans:\n\n';

  @override
  String get supportEmailError => 'No se ha podido abrir la app de correo';

  @override
  String supportVersion(String version) {
    return 'Versión $version\nHecho con ❤️ en Alzira';
  }

  @override
  String get rechargeYourCardSoon => '¡Recarga tu tarjeta pronto!';

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
