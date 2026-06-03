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
  String get watchAdSubtitle => 'Mira un vídeo curt i gaudeix sense banners';

  @override
  String get adNotReadyYet =>
      'Anunci encara no disponible. Torna-ho a provar en uns segons.';

  @override
  String get adsHiddenShort => 'Anuncis ocults durant 30 minuts! 🎉';

  @override
  String get dailyAdLimitReached =>
      'Has assolit el límit d\'anuncis de hui. Torna demà!';

  @override
  String coinsEarnedThanks(int count) {
    return '+$count monedes 🪙 Gràcies!';
  }

  @override
  String get dailyEarningsExplained =>
      'Cada dia pots guanyar fins a 30 monedes jugant + 60 mirant anuncis. És un ritme lent però constant: torna cada dia per omplir el moneder.';

  @override
  String get dailyMaxReached => 'Has arribat al màxim de hui. Torna demà!';

  @override
  String confirmSpendCoins(int cost, String skin) {
    return 'Confirmes que vols gastar $cost 🪙 per desbloquejar $skin?';
  }

  @override
  String skinUnlockedAndEquipped(String skin) {
    return '$skin desbloquejat i equipat! 🎉';
  }

  @override
  String wearingSkin(String skin) {
    return 'Portes el \"$skin\"';
  }

  @override
  String unlockSkinTitle(String skin) {
    return 'Desbloquejar $skin';
  }

  @override
  String unlockSkinBody(int cost) {
    return 'Confirmes que vols gastar $cost 🪙 per desbloquejar este vestit? Una vegada desbloquejat el tens per sempre.';
  }

  @override
  String get unlockButton => 'Desbloquejar';

  @override
  String get notEnoughCoins => 'No tens prou monedes.';

  @override
  String skinEquipped(String skin) {
    return '$skin equipat';
  }

  @override
  String get mifareClassicInfo =>
      'Les targetes Mifare Classic 1K requereixen autenticació especial per llegir el saldo. La majoria de mòbils Android no poden llegir-les sense maquinari especialitzat.';

  @override
  String get featureNotAvailableWeb => 'Funció no disponible al navegador';

  @override
  String get featureAndroidOnly => 'Funció exclusiva d\'Android';

  @override
  String get nfcWebExplained =>
      'La lectura de targetes NFC requereix accés al maquinari que no està disponible a la versió web.\n\nInstal·la l\'app per usar esta funció.';

  @override
  String get nfcIosExplained =>
      'A causa de les restriccions d\'Apple amb les targetes Mifare Classic, la lectura de saldo no és compatible amb iPhone.\n\nUsa el mapa i horaris per planificar el teu viatge.';

  @override
  String get publicTransportAlzira => 'Transport Públic Alzira';

  @override
  String get validateTripPrompt =>
      'Vols validar un viatge ara? Es restarà 1 del teu comptador.';

  @override
  String get confirmTripTitle => 'Confirmar viatge';

  @override
  String get shareTripIntro =>
      'Vols que algú sàpia per on vas? Comença el viatge compartit i et done un enllaç per enviar-los.';

  @override
  String get creatingSharedTrip => 'Creant el teu viatge compartit...';

  @override
  String get noLocationPermissionShare =>
      'Sense permís d\'ubicació no puc compartir el viatge.';

  @override
  String get needLocationPermissionAlbus =>
      'Necessite permís per veure on estàs!';

  @override
  String get tripReadyShareIt =>
      'Llest! Comparteix l\'enllaç i la gent veurà per on vas en temps real.';

  @override
  String couldntCreateTrip(String error) {
    return 'No he pogut crear el viatge: $error';
  }

  @override
  String get somethingBrokeRetry =>
      'Alguna cosa s\'ha torçat. Ho tornem a provar?';

  @override
  String get endingSharedTrip => 'Acabant el compartit...';

  @override
  String get tripEnded => 'Viatge acabat! Bon camí 👋';

  @override
  String shareMessageWithDest(String url) {
    return 'Vaig al bus! Mira per on vaig en directe: $url';
  }

  @override
  String shareMessage(String url) {
    return 'Segueix el meu viatge en bus en directe! $url';
  }

  @override
  String shareSubjectWithDest(String destination) {
    return 'Vaig cap a $destination · Alzitrans';
  }

  @override
  String get shareSubject => 'El meu viatge en directe · Alzitrans';

  @override
  String get linkShared => 'Enllaç compartit! 🚌';

  @override
  String linkCopied(String url) {
    return 'Enllaç copiat: $url';
  }

  @override
  String destinationLabel(String name) {
    return 'Destí: $name';
  }

  @override
  String get lineLabelSingular => 'Línia: ';

  @override
  String get shareTripExplanation =>
      'Quan comences, es generarà un enllaç públic que pots enviar a qui vulgues. Veuran la teua posició i l\'hora estimada d\'arribada actualitzades cada 30 segons.';

  @override
  String get linkExpires6Hours => 'L\'enllaç caduca al cap de 6 hores.';

  @override
  String get startingButton => 'Començant...';

  @override
  String get startSharingButton => 'Començar a compartir';

  @override
  String get sharingLive => 'Compartint en directe';

  @override
  String get destination => 'Destí';

  @override
  String get lineSingular => 'Línia';

  @override
  String get etaLabel => 'Arribada estimada';

  @override
  String get lastPosition => 'Última posició';

  @override
  String get linkToShare => 'Enllaç per compartir';

  @override
  String get copy => 'Copiar';

  @override
  String get seeAsOthersSee => 'Mira com ho veuen els altres';

  @override
  String get endingButton => 'Acabant...';

  @override
  String get stopSharingButton => 'Acabar de compartir';

  @override
  String get minimizeBackgroundNotice =>
      'Pots minimitzar l\'app sense problema: els pings d\'ubicació segueixen enviant-se en segon pla cada 30 s.';

  @override
  String minutesShort(int n) {
    return '$n min';
  }

  @override
  String get plannerTitle => 'Planificador amb Albus';

  @override
  String get albusGreeting =>
      'Hola! Soc Albus 🚌. Dis-me d\'on ixes i a on vas, i et dic quin bus agafar.';

  @override
  String get chooseOriginAndDest => 'Tria origen i destí abans de buscar.';

  @override
  String get albusNeedsOriginDest =>
      'Ai! Necessite saber d\'on ixes i a on vas.';

  @override
  String get sameStopError => 'L\'origen i el destí són la mateixa parada.';

  @override
  String get albusAlreadyThere => 'Però... si ja estàs ahí! 😅';

  @override
  String get albusSearchingRoute => 'Estic mirant quin bus et porta...';

  @override
  String get albusNoRoute =>
      'Vaja... no trobe ruta directa. Potser val la pena anar a peu.';

  @override
  String get albusOneRoute => 'Tinc una ruta! Te l\'explique pas a pas 👇';

  @override
  String albusMultipleRoutes(int count) {
    return 'Tinc $count opcions! La primera és la més ràpida.';
  }

  @override
  String searchError(String error) {
    return 'Alguna cosa s\'ha torçat buscant ($error). Torna-ho a provar.';
  }

  @override
  String get albusCantCalculate =>
      'Ups, no he pogut calcular la ruta. Ho tornem a provar?';

  @override
  String get albusSwapped => 'Canviat! Busquem esta nova ruta?';

  @override
  String get albusFindingYou => 'A veure on estàs...';

  @override
  String get enableLocationRetry =>
      'Activa la ubicació del mòbil i torna-ho a intentar.';

  @override
  String get noLocationPermission =>
      'Sense permís d\'ubicació no puc saber on estàs.';

  @override
  String get noStopsNearYou => 'No hi ha parades prop teu — estàs a Alzira?';

  @override
  String veryCloseToStop(String name) {
    return 'Estàs molt prop de $name. A on anem?';
  }

  @override
  String nearestStopIs(String name, int dist) {
    return 'La parada més pròxima és $name (a $dist m). A on anem?';
  }

  @override
  String get couldntFindYou => 'No he pogut saber on estàs 😢';

  @override
  String okFromStop(String name) {
    return 'Val, ixes de $name. A on vas?';
  }

  @override
  String askDestRoute(String name) {
    return 'Busquem com anar a $name?';
  }

  @override
  String okToStop(String name) {
    return 'Val, vas a $name. D\'on ixes?';
  }

  @override
  String get readyToSearch => 'A punt. Polsa \"Buscar ruta\" quan vulgues.';

  @override
  String get searchingYourLocation => 'Buscant la teua ubicació...';

  @override
  String get usingYourLocation => 'Utilitzant la teua ubicació actual';

  @override
  String get useMyLocationButton => 'Utilitzar la meua ubicació com a origen';

  @override
  String get fromNearestStop => 'Des de (parada més pròxima)';

  @override
  String get fromLabel => 'Des de';

  @override
  String get toLabel => 'Fins a';

  @override
  String get swap => 'Intercanviar';

  @override
  String get searchRoute => 'Buscar ruta';

  @override
  String errorLoadingStops(String error) {
    return 'Error carregant parades: $error';
  }

  @override
  String get searchStopByName => 'Busca parada per nom…';

  @override
  String linesWithList(String lines) {
    return 'Línies: $lines';
  }

  @override
  String get shareThisTripLive => 'Compartir este viatge en directe';

  @override
  String get bestOption => 'MILLOR OPCIÓ';

  @override
  String optionN(int n) {
    return 'OPCIÓ $n';
  }

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transbordaments',
      one: '1 transbordament',
    );
    return '$_temp0';
  }

  @override
  String walkingStep(int dist, int duration) {
    return 'A peu · $dist m · $duration min';
  }

  @override
  String busStepDetail(int stops, int duration) {
    return '$stops parades · $duration min';
  }

  @override
  String boardAt(String name) {
    return 'Puja: $name';
  }

  @override
  String alightAt(String name) {
    return 'Baixa: $name';
  }

  @override
  String transferAt(String name) {
    return 'Transbordament a $name';
  }

  @override
  String transferStep(String from, String to, int duration) {
    return 'De $from a $to · ~$duration min';
  }

  @override
  String get triviaTitle => 'Trivia d\'Alzira';

  @override
  String questionXofY(int current, int total) {
    return 'Pregunta $current/$total';
  }

  @override
  String get skipQuestionAd => 'Saltar pregunta (mirar anunci)';

  @override
  String get triviaCompleted => 'Trivia completada';

  @override
  String scoreLabel(int score) {
    return 'Puntuació: $score';
  }

  @override
  String get newRecord => '🏆 Nou rècord!';

  @override
  String currentRecord(int score) {
    return 'Rècord: $score';
  }

  @override
  String coinsAddedWallet(int count) {
    return '+$count 🪙 al moneder';
  }

  @override
  String get playAgain => 'Jugar una altra vegada';

  @override
  String get backToMenu => 'Tornar al menú';

  @override
  String get memoryStopsTitle => 'Memòria de Parades';

  @override
  String get catchTheBusTitle => 'Atrapa el Bus';

  @override
  String get gamesHubTitle => 'Mini-Jocs';

  @override
  String get playGame => 'Jugar';

  @override
  String highScore(int score) {
    return 'Rècord: $score';
  }

  @override
  String get memoryStopsHowTo => 'Memoritza l\'ordre i reprodueix-lo';

  @override
  String get catchTheBusHowTo => 'Toca el bus quan passe per la parada';

  @override
  String get triviaHowTo => '10 preguntes sobre Alzira i l\'app';

  @override
  String get gameOver => 'Fi del joc!';

  @override
  String get tapToStart => 'Toca per començar';

  @override
  String reachedRound(int round) {
    return 'Has arribat a la ronda $round';
  }

  @override
  String currentRecordRounds(int score) {
    return 'Rècord: $score rondes';
  }

  @override
  String get repeatSequenceAd => 'Repetir seqüència (mirar anunci)';

  @override
  String get watchAdForCoinsLabel => 'Mirar anunci +30 🪙';

  @override
  String get missedGreenBus => 'T\'has deixat escapar un bus verd';

  @override
  String get reviveWatchAd => 'Reviure mirant un anunci';

  @override
  String get gamesHubHeading => 'Jocs · Mata el temps';

  @override
  String get wardrobeTooltip => 'Vestidor d\'Albus';

  @override
  String get availableGames => 'Disponibles';

  @override
  String get catchTheBusDesc =>
      'Toca busos verds 🚌 abans que s\'escapen. Esquiva els rojos 🚒. Quant aguantes?';

  @override
  String currentRecordPrefix(int score) {
    return '🏆 Rècord actual: $score';
  }

  @override
  String currentRecordPts(int score) {
    return '🏆 Rècord actual: $score pts';
  }

  @override
  String get beTheFirstRecord => 'Sigues el primer en marcar rècord!';

  @override
  String get triviaDesc =>
      'Preguntes sobre el bus, la ciutat i la comarca. 10 preguntes, 15s cadascuna.';

  @override
  String get howMuchYouKnow => 'Quant saps d\'Alzira?';

  @override
  String get memoryStopsDesc =>
      'Albus mostra parades en ordre. Tu les repeteixes. Cada ronda n\'afig una més.';

  @override
  String bestRound(int round) {
    return '🏆 Millor: ronda $round';
  }

  @override
  String get simonAlziraStyle => 'Simon Says estil Alzira';

  @override
  String get gamesLegalNotice =>
      'Els jocs poden mostrar anuncis opcionals (reviure, bonus). Les monedes són decoratives — futures versions permetran canviar-les per contingut.';

  @override
  String get albusGamesIntro =>
      'Esperant el bus? Fem una partida! Guanya monedes mentre arriba.';

  @override
  String get skinDefaultName => 'Original';

  @override
  String get skinFalleroName => 'Faller';

  @override
  String get skinCapurulloName => 'Capurullo';

  @override
  String get skinLluviaName => 'Pluja';

  @override
  String get skinGraduadoName => 'Graduat';

  @override
  String get skinNavidadName => 'Nadal';

  @override
  String get skinAlziraFcName => 'UDA';

  @override
  String get feedbackTitle => 'Suport i feedback';

  @override
  String get feedbackHeading => 'En què podem ajudar-te?';

  @override
  String get categoryLabel => 'Categoria';

  @override
  String get subjectLabel => 'Resum breu (Assumpte)';

  @override
  String get subjectRequired => 'L\'assumpte és obligatori';

  @override
  String get descriptionLabel => 'Descripció detallada';

  @override
  String get descriptionRequired => 'La descripció és obligatòria';

  @override
  String get sendTicket => 'Enviar Tiquet';

  @override
  String get addComment => 'Afegir un comentari...';

  @override
  String get attachImage => 'Adjuntar imatge';

  @override
  String get conversation => 'Conversa';

  @override
  String get conversationClosedInactive => 'Conversa tancada (avís inactiu)';

  @override
  String get noMessagesYet =>
      'Encara no hi ha missatges.\nEscriu per començar.';

  @override
  String get couldNotSendRetry => 'No s\'ha pogut enviar. Torna-ho a provar.';

  @override
  String get downloadNotSupportedWeb =>
      'Descàrrega no suportada a la web des de l\'app mòbil';

  @override
  String get arVisionTitle => 'Visió AR';

  @override
  String get routesPageTitle => 'Rutes i línies';

  @override
  String get rechargeYourCardSoon => 'Recarrega la teua targeta prompte!';

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
