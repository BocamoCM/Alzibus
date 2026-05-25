// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appTitle => 'Alzitrans — Alzira';

  @override
  String get tabMap => 'Mapa';

  @override
  String get tabRoutes => 'Rutes';

  @override
  String get tabNfc => 'NFC';

  @override
  String get tabSettings => 'Ajustos';

  @override
  String get login => 'Inicia sessió';

  @override
  String get register => 'Registra\'t';

  @override
  String get email => 'Correu electrònic';

  @override
  String get password => 'Contrasenya';

  @override
  String get logout => 'Tanca sessió';

  @override
  String get logoutConfirm => 'Segur que vols tancar la sessió?';

  @override
  String get profile => 'El meu perfil';

  @override
  String get editEmail => 'Canvia el correu';

  @override
  String get changePassword => 'Canvia la contrasenya';

  @override
  String get currentPassword => 'Contrasenya actual';

  @override
  String get newPassword => 'Nova contrasenya';

  @override
  String get save => 'Desar';

  @override
  String get cancel => 'Cancel·lar';

  @override
  String get update => 'Actualitzar';

  @override
  String get retry => 'Torna-ho a provar';

  @override
  String get profileLoadError => 'No s\'ha pogut carregar el perfil';

  @override
  String get accountInfo => 'Informació del compte';

  @override
  String get lastAccess => 'Últim accés';

  @override
  String get memberSince => 'Membre des de';

  @override
  String get totalTrips => 'Total viatges';

  @override
  String get mostUsedLine => 'Línia preferida';

  @override
  String get thisMonth => 'Aquest mes';

  @override
  String get notices => 'Avisos i Incidències';

  @override
  String get noActiveNotices => 'Sense avisos actius';

  @override
  String get serviceNormal => 'El servei funciona amb normalitat';

  @override
  String get noticeTitle => 'Títol';

  @override
  String get noticeBody => 'Descripció';

  @override
  String get validUntil => 'Fins a';

  @override
  String get tripHistory => 'Historial de viatges';

  @override
  String get activeAlerts => 'Alertes actives';

  @override
  String get settings => 'Ajustos';

  @override
  String get language => 'Idioma';

  @override
  String get notifications => 'Notificacions';

  @override
  String get activateNotifications => 'Activar notificacions';

  @override
  String get notificationsSubtitle => 'Rebre avisos en apropar-se a parades';

  @override
  String get alertDistance => 'Distància d\'alerta';

  @override
  String get timeBetweenNotifications => 'Temps entre notificacions';

  @override
  String get vibration => 'Vibració';

  @override
  String get vibrationSubtitle => 'Vibrar amb les notificacions';

  @override
  String minutesSuffix(int n) {
    return '$n minuts';
  }

  @override
  String metersSuffix(int n) {
    return '$n metres';
  }

  @override
  String get map => 'Mapa';

  @override
  String get showSimulatedBuses => 'Mostrar busos al mapa';

  @override
  String get showSimulatedBusesSubtitle => 'Veure posició simulada dels busos';

  @override
  String get autoRefreshTimes => 'Actualitzar temps automàticament';

  @override
  String get autoRefreshTimesSubtitle => 'Refrescar cada 30 segons';

  @override
  String get serviceStatus => 'Estat del servei';

  @override
  String get serviceActive => 'Servei actiu';

  @override
  String get serviceStopped => 'Servei aturat';

  @override
  String get lastCheck => 'Última comprovació';

  @override
  String get activeAlertsCount => 'Alertes actives';

  @override
  String get lastBus => 'Últim bus';

  @override
  String get refreshButton => 'Actualitzar';

  @override
  String get testNotification => 'Provar notificació';

  @override
  String get resetAlerts => 'Reiniciar alertes';

  @override
  String get checkNow => 'Verificar busos ARA';

  @override
  String get information => 'Informació';

  @override
  String get appDescription =>
      'Aplicació per veure parades de bus a Alzira, València.';

  @override
  String get didYouTakeTheBus => 'Has agafat el bus?';

  @override
  String get yes => 'Sí!';

  @override
  String get no => 'No';

  @override
  String get tripRegistered => 'Viatge registrat!';

  @override
  String get delete => 'Eliminar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get never => 'Mai';

  @override
  String get loginTitle => 'Inicia sessió a Alzitrans';

  @override
  String get enterEmail => 'Introdueix el teu correu';

  @override
  String get invalidEmail => 'El correu no té un format vàlid';

  @override
  String get enterPassword => 'Introdueix la teua contrasenya';

  @override
  String get passwordTooShort =>
      'La contrasenya ha de tenir almenys 6 caràcters';

  @override
  String get loginButton => 'Entrar';

  @override
  String get noAccount => 'No tens compte? Registra\'t';

  @override
  String get incorrectCredentials => 'Correu o contrasenya incorrectes.';

  @override
  String get noServerConnection =>
      'Sense connexió al servidor. Comprova la xarxa.';

  @override
  String get accountDisabled => 'Aquest compte ha sigut desactivat.';

  @override
  String get activeAlertsTitle => 'Alertes Actives';

  @override
  String get noActiveAlerts => 'Sense alertes actives';

  @override
  String get noActiveAlertsHint =>
      'Prem \"Avisar\" en una parada\nper rebre notificacions';

  @override
  String get goToMap => 'Anar al mapa';

  @override
  String get cancelAlert => 'Cancel·lar alerta?';

  @override
  String get cancelAlertBody => 'Deixaràs de rebre avisos per a esta línia';

  @override
  String get cancelAlertYes => 'Sí, cancel·lar';

  @override
  String get noData => 'Sense dades';

  @override
  String get noService => 'Sense servei';

  @override
  String alertActivatedMinAgo(int n) {
    return 'Activada fa $n min';
  }

  @override
  String get viewStopOnMap => 'Veure parada al mapa';

  @override
  String get cancelAlertTooltip => 'Cancel·lar alerta';

  @override
  String get statusWaiting => '⏳ Esperant';

  @override
  String get statusNotified => '✅ Avisat';

  @override
  String get statusClose => '⚠️ Molt a prop';

  @override
  String get statusArriving => '🔔 Arribant';

  @override
  String get newNoticePopupTitle => 'Nou Avís';

  @override
  String get understood => 'Entesos';

  @override
  String get tripHistoryTitle => 'Historial de Viatges';

  @override
  String get tabStats => 'Estadístiques';

  @override
  String get tabHistory => 'Historial';

  @override
  String get clearHistory => 'Esborrar historial';

  @override
  String get clearHistoryConfirmTitle => 'Esborrar historial?';

  @override
  String get clearHistoryConfirmBody =>
      'S\'eliminaran tots els viatges guardats.';

  @override
  String get noTripsRegistered => 'Sense viatges registrats';

  @override
  String get noTripsHint =>
      'Activa alertes de bus per a començar\na registrar els teus viatges';

  @override
  String get noTripsHistory => 'Sense viatges a l\'historial';

  @override
  String get streakTitle => '🔥 Ratxes i Progrés';

  @override
  String get streak => 'Ratxa';

  @override
  String get bestStreak => 'Millor';

  @override
  String get vsPrevMonth => 'vs mes ant.';

  @override
  String streakMessage(int n) {
    return '$n dies seguits viatjant! 🎉';
  }

  @override
  String get tripsPerMonth => '📊 Viatges per Mes';

  @override
  String get weekdaysTitle => '📅 Dies de la Setmana';

  @override
  String get weekdays => 'Entresemana';

  @override
  String get weekends => 'Cap de setmana';

  @override
  String get summaryTitle => '📈 Resum';

  @override
  String get totalTripsLabel => 'Viatges totals';

  @override
  String get favouriteStop => 'Parada preferida';

  @override
  String get usualTime => 'Horari habitual';

  @override
  String get topLines => '🚌 Línies més usades';

  @override
  String get line => 'Línia';

  @override
  String get topStops => '🚏 Parades més freqüents';

  @override
  String get recentActivity => '📅 Activitat recent';

  @override
  String get last7days => 'Últims 7 dies';

  @override
  String get last30days => 'Últims 30 dies';

  @override
  String get forgotPassword => 'He oblidat la contrasenya';

  @override
  String get forgotPasswordTitle => 'Recuperar Contrasenya';

  @override
  String get forgotPasswordInstructions =>
      'Introdueix el teu correu per a rebre un codi de recuperació.';

  @override
  String get sendCode => 'Enviar codi';

  @override
  String get enterCode => 'Introdueix el codi';

  @override
  String get codeSent => 'Codi enviat al teu correu';

  @override
  String get resetPasswordTitle => 'Nova Contrasenya';

  @override
  String get resetPasswordButton => 'Restablir Contrasenya';

  @override
  String get passwordResetSuccess => 'Contrasenya actualitzada correctament';

  @override
  String get verifyCode => 'Verificar codi';

  @override
  String get accessibilityVoice => 'Mode Accessibilitat (Veu)';

  @override
  String get accessibilityVoiceSubtitle =>
      'Llig les parades en seleccionar-les';

  @override
  String get highVisibilityMode => 'Mode d\'Alta Visibilitat';

  @override
  String get highVisibilitySubtitle => 'Optimitzat per a millor legibilitat';

  @override
  String get helpAndSupport => 'Ajuda i Suport';

  @override
  String get helpAndSupportSubtitle => 'Preguntes freqüents i contacte';

  @override
  String get privacyAndPermissions => 'PERMISOS I PRIVACITAT';

  @override
  String get backgroundAlerts => 'Alertes en segon pla';

  @override
  String get backgroundAlertsSubtitle =>
      'Configura el rastreig de bus fora de l\'app';

  @override
  String get permissionActivated => 'Ja tens este permís activat ✅';

  @override
  String get configure => 'Configurar';

  @override
  String get privacyPolicy => 'Política de Privacitat';

  @override
  String get privacyPolicySubtitle => 'Consulta com protegim les teues dades';

  @override
  String get dataCredits => 'Crèdits i fonts de dades';

  @override
  String get dataCreditsSubtitle => 'D\'on venen els horaris i avisos';

  @override
  String get dataCreditsTitle => 'Fonts de dades';

  @override
  String get dataCreditsBusOperator => 'Temps d\'autobús';

  @override
  String get dataCreditsBusOperatorBody =>
      'Els horaris i temps de pas de les línies L1, L2 i L3 són cortesia d\'Autocars Lozano S.L.U., concessionària del servei urbà d\'Alzira. Alzitrans consulta la informació pública directament des del dispositiu de cada usuari; no emmagatzema ni redistribueix les dades. Alzitrans no està afiliada amb Autocars Lozano S.L.U.';

  @override
  String get dataCreditsRenfe => 'Trens Rodalia';

  @override
  String get dataCreditsRenfeBody =>
      'Els horaris de Rodalia C2 provenen de Renfe Operadora.';

  @override
  String get dataCreditsThanks =>
      'Gràcies a Autocars Lozano S.L.U. per fer pública esta informació, sense la qual esta app no podria existir.';

  @override
  String get creditsLineLozano => 'Dades per Autocars Lozano';

  @override
  String get removeAdsTitle => 'Llevar Anuncis (30 min)';

  @override
  String get removeAdsSubtitle => 'Mira un vídeo curt per ocultar els banners';

  @override
  String get adsHiddenSuccess => 'Anuncis ocults durant 30 minuts! Gaudeix 🎉';

  @override
  String get adNotAvailable =>
      'Anunci no disponible en este moment. Torna-ho a provar més tard.';

  @override
  String get deleteAccountTitle => 'Eliminar compte';

  @override
  String get deleteAccountSubtitle =>
      'Esborrat permanent de totes les teues dades';

  @override
  String get deleteAccountDialogTitle => 'Eliminar el teu compte?';

  @override
  String get deleteAccountIrreversible =>
      'Esta acció és irreversible. S\'esborraran permanentment:';

  @override
  String get deleteAccountBullet1 =>
      '• El teu historial de viatges i estadístiques.';

  @override
  String get deleteAccountBullet2 => '• Les teues parades preferides.';

  @override
  String deleteAccountConfirm(String email) {
    return 'Estàs totalment segur que vols eliminar el compte de $email?';
  }

  @override
  String get deleteAccountConfirmButton => 'SÍ, ELIMINAR-HO TOT';

  @override
  String get accountDeletedSuccess =>
      'Compte eliminat amb èxit. Sentim que te\'n vages.';

  @override
  String get emailUpdatedSuccess => '✅ Email actualitzat';

  @override
  String get passwordUpdatedSuccess => '✅ Contrasenya actualitzada';

  @override
  String genericError(String message) {
    return 'Error: $message';
  }

  @override
  String get loginWithBiometrics => 'Entrar amb empremta';

  @override
  String biometricLoginError(String error) {
    return 'Error d\'accés biomètric: $error';
  }

  @override
  String unexpectedError(String error) {
    return 'Error inesperat: $error';
  }

  @override
  String get registerTitle => 'Registre en Alzibus';

  @override
  String get registerInfoBox =>
      'T\'enviarem un codi en iniciar sessió. Si no inicies sessió en 7 dies, el compte s\'eliminarà automàticament.';

  @override
  String get accountCreatedSnack =>
      'Compte creat. Inicia sessió en els pròxims 7 dies o s\'eliminarà automàticament.';

  @override
  String get registerButton => 'Registrar-se';

  @override
  String get verifyEmailTitle => 'Verificar Correu';

  @override
  String get confirmYourEmail => 'Confirma el teu correu';

  @override
  String codeSentToEmail(String email) {
    return 'Hem enviat un codi de 6 dígits a:\n$email';
  }

  @override
  String get codeExpiresIn15Min => 'El codi caduca en 15 minuts.';

  @override
  String get verifyCodeButton => 'Verificar Codi';

  @override
  String resendCodeWithLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reenviar codi ($count restants)',
      one: 'Reenviar codi (1 restant)',
    );
    return '$_temp0';
  }

  @override
  String get noResendsLeft => 'Sense reenviaments disponibles';

  @override
  String get enableBiometricsDialog => 'Activar Empremta?';

  @override
  String get enableBiometricsBody =>
      'Vols entrar més ràpid la pròxima vegada utilitzant la teua empremta dactilar?';

  @override
  String get notNow => 'Ara no';

  @override
  String get yesActivate => 'Sí, activar!';

  @override
  String get stopAddedToFavorites => '⭐ Parada afegida a preferides';

  @override
  String alertSetForLine(String line) {
    return '✅ T\'avisarem quan arribe la línia $line';
  }

  @override
  String get requiresInternet => '(Requereix connexió a internet)';

  @override
  String get mapView => 'Mapa';

  @override
  String get satelliteView => 'Satèl·lit';

  @override
  String get satelliteViewUnavailable => 'Vista satèl·lit no disponible';

  @override
  String get removeFromFavorites => 'Llevar de preferides';

  @override
  String get addToFavorites => 'Afegir a preferides';

  @override
  String get nextBuses => '⏱️ Pròxims busos:';

  @override
  String get noUpcomingBuses => 'No hi ha busos pròxims';

  @override
  String get nearbyTrainsC2 => '🚆 Trens Rodalia C2:';

  @override
  String get noUpcomingTrains => 'No hi ha trens pròxims';

  @override
  String get refresh => 'Actualitzar';

  @override
  String get refreshTrains => 'Actualitzar trens';

  @override
  String get linesLabel => 'Línies:';

  @override
  String get lines => 'Línies';

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fa $count dies',
      one: 'Fa 1 dia',
      zero: 'Hui',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fa $count minuts',
      one: 'Fa 1 minut',
      zero: 'Ara mateix',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fa $count hores',
      one: 'Fa 1 hora',
    );
    return '$_temp0';
  }

  @override
  String lineWithNumber(String line) {
    return 'Línia $line';
  }

  @override
  String oneTripWillBeDeducted(int remaining) {
    return 'Es descomptarà 1 viatge de la teua targeta (et queden $remaining)';
  }

  @override
  String get unlimitedTrips => 'Tens viatges IL·LIMITATS';

  @override
  String get noTripsOnCard => 'No tens viatges a la targeta';

  @override
  String get noTripUnderstood => '👍 Entés, no s\'ha registrat';

  @override
  String get iDidntGetOn => 'No he pujat';

  @override
  String get yesIGotOn => 'Sí, registrar';

  @override
  String get cardTripRegistered => 'Viatge amb Targeta registrat!';

  @override
  String get cashTripRegistered => 'Viatge en Efectiu registrat!';

  @override
  String get viewHistory => 'Veure historial';

  @override
  String get playWhileWaiting => 'Fes una partida mentre esperes!';

  @override
  String get welcomeGreeting => 'Hola! 👋';

  @override
  String get welcomeMessage => 'Espere que et siga de molta utilitat!';

  @override
  String get busInService => 'Autobús en servei';

  @override
  String get nextStop => 'Pròxima parada';

  @override
  String get welcomeThanks => 'Gràcies per descarregar Alzi Trans.';

  @override
  String get welcomeStudent =>
      'Soc un estudiant de 2n de DAM i he creat esta app de forma independent per millorar el nostre transport.';

  @override
  String get welcomeDevelopmentNotice =>
      'Tingues en compte que és un projecte en desenvolupament i pot contindre errors.';

  @override
  String get understoodCaps => 'ENTÉS';

  @override
  String get estimatedTime => 'Temps estimat';

  @override
  String get statusLabel => 'Estat';

  @override
  String get atStop => '🛑 En parada';

  @override
  String get inMovement => '🚌 En moviment';

  @override
  String get nfcCardReadSuccess => 'Targeta llegida correctament';

  @override
  String nfcBalanceAnnounce(String balance, int trips) {
    return 'Saldo de $balance euros. Et queden $trips viatges.';
  }

  @override
  String get nfcUnlimitedAnnounce => 'Abonament il·limitat actiu.';

  @override
  String busArrivalAnnounce(
      String line, String destination, String stop, int minutes) {
    return 'L\'autobús de la línia $line amb destí $destination arribarà a $stop en $minutes minuts.';
  }

  @override
  String busArrivingAnnounce(Object destination, Object line, Object stop) {
    return 'L\'autobús de la línia $line amb destí $destination està arribant a $stop.';
  }

  @override
  String stopAnnounce(Object name) {
    return 'Parada $name.';
  }

  @override
  String get teHemosApuntado => 'T\'hem apuntat al bus';

  @override
  String get alertaActiva => '(Alerta activa)';

  @override
  String personasInteresadas(int n) {
    return '$n persones interessades';
  }

  @override
  String get rankingTitle => 'Rànquing de Viatgers';

  @override
  String get rankingSubtitle => 'Compiteix amb altres viatgers d\'Alzira';

  @override
  String yourPosition(int pos, int trips) {
    return 'La teua posició: #$pos · $trips viatges';
  }

  @override
  String get thisMonthToggle => 'Aquest mes';

  @override
  String get allTimeToggle => 'Tot el temps';

  @override
  String get rankingLoadError => 'No s\'ha pogut carregar el rànquing';

  @override
  String get noTripsRankingMonth =>
      'Ningú ha viatjat aquest mes encara. Sigues el primer!';

  @override
  String get noTripsRankingAll => 'Encara no hi ha viatges registrats.';

  @override
  String get travelersRankingHeader => '🏆 Rànquing de Viatgers';
}
