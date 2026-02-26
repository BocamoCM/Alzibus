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
}
