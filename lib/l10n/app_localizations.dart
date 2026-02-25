import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Alzibus — Alzira'**
  String get appTitle;

  /// No description provided for @tabMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get tabMap;

  /// No description provided for @tabRoutes.
  ///
  /// In es, this message translates to:
  /// **'Rutas'**
  String get tabRoutes;

  /// No description provided for @tabNfc.
  ///
  /// In es, this message translates to:
  /// **'NFC'**
  String get tabNfc;

  /// No description provided for @tabSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get tabSettings;

  /// No description provided for @login.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get login;

  /// No description provided for @register.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get register;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que quieres cerrar sesión?'**
  String get logoutConfirm;

  /// No description provided for @profile.
  ///
  /// In es, this message translates to:
  /// **'Mi perfil'**
  String get profile;

  /// No description provided for @editEmail.
  ///
  /// In es, this message translates to:
  /// **'Cambiar email'**
  String get editEmail;

  /// No description provided for @changePassword.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña actual'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get newPassword;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @update.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get update;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @profileLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el perfil'**
  String get profileLoadError;

  /// No description provided for @accountInfo.
  ///
  /// In es, this message translates to:
  /// **'Información de cuenta'**
  String get accountInfo;

  /// No description provided for @lastAccess.
  ///
  /// In es, this message translates to:
  /// **'Último acceso'**
  String get lastAccess;

  /// No description provided for @memberSince.
  ///
  /// In es, this message translates to:
  /// **'Miembro desde'**
  String get memberSince;

  /// No description provided for @totalTrips.
  ///
  /// In es, this message translates to:
  /// **'Total viajes'**
  String get totalTrips;

  /// No description provided for @mostUsedLine.
  ///
  /// In es, this message translates to:
  /// **'Línea favorita'**
  String get mostUsedLine;

  /// No description provided for @thisMonth.
  ///
  /// In es, this message translates to:
  /// **'Este mes'**
  String get thisMonth;

  /// No description provided for @notices.
  ///
  /// In es, this message translates to:
  /// **'Avisos e Incidencias'**
  String get notices;

  /// No description provided for @noActiveNotices.
  ///
  /// In es, this message translates to:
  /// **'Sin avisos activos'**
  String get noActiveNotices;

  /// No description provided for @serviceNormal.
  ///
  /// In es, this message translates to:
  /// **'El servicio funciona con normalidad'**
  String get serviceNormal;

  /// No description provided for @noticeTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get noticeTitle;

  /// No description provided for @noticeBody.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get noticeBody;

  /// No description provided for @validUntil.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get validUntil;

  /// No description provided for @tripHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial de viajes'**
  String get tripHistory;

  /// No description provided for @activeAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas activas'**
  String get activeAlerts;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notifications;

  /// No description provided for @activateNotifications.
  ///
  /// In es, this message translates to:
  /// **'Activar notificaciones'**
  String get activateNotifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Recibir avisos al acercarse a paradas'**
  String get notificationsSubtitle;

  /// No description provided for @alertDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia de aviso'**
  String get alertDistance;

  /// No description provided for @timeBetweenNotifications.
  ///
  /// In es, this message translates to:
  /// **'Tiempo entre notificaciones'**
  String get timeBetweenNotifications;

  /// No description provided for @vibration.
  ///
  /// In es, this message translates to:
  /// **'Vibración'**
  String get vibration;

  /// No description provided for @vibrationSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Vibrar con las notificaciones'**
  String get vibrationSubtitle;

  /// No description provided for @minutesSuffix.
  ///
  /// In es, this message translates to:
  /// **'{n} minutos'**
  String minutesSuffix(int n);

  /// No description provided for @metersSuffix.
  ///
  /// In es, this message translates to:
  /// **'{n} metros'**
  String metersSuffix(int n);

  /// No description provided for @map.
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get map;

  /// No description provided for @showSimulatedBuses.
  ///
  /// In es, this message translates to:
  /// **'Mostrar buses en el mapa'**
  String get showSimulatedBuses;

  /// No description provided for @showSimulatedBusesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ver posición simulada de los autobuses'**
  String get showSimulatedBusesSubtitle;

  /// No description provided for @autoRefreshTimes.
  ///
  /// In es, this message translates to:
  /// **'Actualizar tiempos automáticamente'**
  String get autoRefreshTimes;

  /// No description provided for @autoRefreshTimesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Refrescar cada 30 segundos'**
  String get autoRefreshTimesSubtitle;

  /// No description provided for @serviceStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado del servicio'**
  String get serviceStatus;

  /// No description provided for @serviceActive.
  ///
  /// In es, this message translates to:
  /// **'Servicio activo'**
  String get serviceActive;

  /// No description provided for @serviceStopped.
  ///
  /// In es, this message translates to:
  /// **'Servicio detenido'**
  String get serviceStopped;

  /// No description provided for @lastCheck.
  ///
  /// In es, this message translates to:
  /// **'Último chequeo'**
  String get lastCheck;

  /// No description provided for @activeAlertsCount.
  ///
  /// In es, this message translates to:
  /// **'Alertas activas'**
  String get activeAlertsCount;

  /// No description provided for @lastBus.
  ///
  /// In es, this message translates to:
  /// **'Último bus'**
  String get lastBus;

  /// No description provided for @refreshButton.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get refreshButton;

  /// No description provided for @testNotification.
  ///
  /// In es, this message translates to:
  /// **'Probar notificación'**
  String get testNotification;

  /// No description provided for @resetAlerts.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar alertas'**
  String get resetAlerts;

  /// No description provided for @checkNow.
  ///
  /// In es, this message translates to:
  /// **'Verificar buses AHORA'**
  String get checkNow;

  /// No description provided for @information.
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get information;

  /// No description provided for @appDescription.
  ///
  /// In es, this message translates to:
  /// **'Aplicación para ver paradas de bus en Alzira, Valencia.'**
  String get appDescription;

  /// No description provided for @didYouTakeTheBus.
  ///
  /// In es, this message translates to:
  /// **'¿Cogiste el bus?'**
  String get didYouTakeTheBus;

  /// No description provided for @yes.
  ///
  /// In es, this message translates to:
  /// **'¡Sí!'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @tripRegistered.
  ///
  /// In es, this message translates to:
  /// **'¡Viaje registrado!'**
  String get tripRegistered;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @never.
  ///
  /// In es, this message translates to:
  /// **'Nunca'**
  String get never;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión en Alzibus'**
  String get loginTitle;

  /// No description provided for @enterEmail.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu email'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'El email no tiene un formato válido'**
  String get invalidEmail;

  /// No description provided for @enterPassword.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu contraseña'**
  String get enterPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 6 caracteres'**
  String get passwordTooShort;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get loginButton;

  /// No description provided for @noAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? Regístrate'**
  String get noAccount;

  /// No description provided for @incorrectCredentials.
  ///
  /// In es, this message translates to:
  /// **'Email o contraseña incorrectos.'**
  String get incorrectCredentials;

  /// No description provided for @noServerConnection.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión al servidor. Comprueba tu red.'**
  String get noServerConnection;

  /// No description provided for @accountDisabled.
  ///
  /// In es, this message translates to:
  /// **'Esta cuenta está desactivada.'**
  String get accountDisabled;

  /// No description provided for @activeAlertsTitle.
  ///
  /// In es, this message translates to:
  /// **'Alertas Activas'**
  String get activeAlertsTitle;

  /// No description provided for @noActiveAlerts.
  ///
  /// In es, this message translates to:
  /// **'Sin alertas activas'**
  String get noActiveAlerts;

  /// No description provided for @noActiveAlertsHint.
  ///
  /// In es, this message translates to:
  /// **'Pulsa \"Avisar\" en una parada\npara recibir notificaciones'**
  String get noActiveAlertsHint;

  /// No description provided for @goToMap.
  ///
  /// In es, this message translates to:
  /// **'Ir al mapa'**
  String get goToMap;

  /// No description provided for @cancelAlert.
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar alerta?'**
  String get cancelAlert;

  /// No description provided for @cancelAlertBody.
  ///
  /// In es, this message translates to:
  /// **'Dejarás de recibir avisos para esta línea'**
  String get cancelAlertBody;

  /// No description provided for @cancelAlertYes.
  ///
  /// In es, this message translates to:
  /// **'Sí, cancelar'**
  String get cancelAlertYes;

  /// No description provided for @noData.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get noData;

  /// No description provided for @noService.
  ///
  /// In es, this message translates to:
  /// **'Sin servicio'**
  String get noService;

  /// No description provided for @alertActivatedMinAgo.
  ///
  /// In es, this message translates to:
  /// **'Activada hace {n} min'**
  String alertActivatedMinAgo(int n);

  /// No description provided for @viewStopOnMap.
  ///
  /// In es, this message translates to:
  /// **'Ver parada en mapa'**
  String get viewStopOnMap;

  /// No description provided for @cancelAlertTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cancelar alerta'**
  String get cancelAlertTooltip;

  /// No description provided for @statusWaiting.
  ///
  /// In es, this message translates to:
  /// **'⏳ Esperando'**
  String get statusWaiting;

  /// No description provided for @statusNotified.
  ///
  /// In es, this message translates to:
  /// **'✅ Avisado'**
  String get statusNotified;

  /// No description provided for @statusClose.
  ///
  /// In es, this message translates to:
  /// **'⚠️ Muy cerca'**
  String get statusClose;

  /// No description provided for @statusArriving.
  ///
  /// In es, this message translates to:
  /// **'🔔 Llegando'**
  String get statusArriving;

  /// No description provided for @newNoticePopupTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Aviso'**
  String get newNoticePopupTitle;

  /// No description provided for @understood.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get understood;

  /// No description provided for @tripHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de Viajes'**
  String get tripHistoryTitle;

  /// No description provided for @tabStats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get tabStats;

  /// No description provided for @tabHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get tabHistory;

  /// No description provided for @clearHistory.
  ///
  /// In es, this message translates to:
  /// **'Borrar historial'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar historial?'**
  String get clearHistoryConfirmTitle;

  /// No description provided for @clearHistoryConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán todos los viajes guardados.'**
  String get clearHistoryConfirmBody;

  /// No description provided for @noTripsRegistered.
  ///
  /// In es, this message translates to:
  /// **'Sin viajes registrados'**
  String get noTripsRegistered;

  /// No description provided for @noTripsHint.
  ///
  /// In es, this message translates to:
  /// **'Activa alertas de bus para empezar\na registrar tus viajes'**
  String get noTripsHint;

  /// No description provided for @noTripsHistory.
  ///
  /// In es, this message translates to:
  /// **'Sin viajes en el historial'**
  String get noTripsHistory;

  /// No description provided for @streakTitle.
  ///
  /// In es, this message translates to:
  /// **'🔥 Rachas y Progreso'**
  String get streakTitle;

  /// No description provided for @streak.
  ///
  /// In es, this message translates to:
  /// **'Racha'**
  String get streak;

  /// No description provided for @bestStreak.
  ///
  /// In es, this message translates to:
  /// **'Mejor'**
  String get bestStreak;

  /// No description provided for @vsPrevMonth.
  ///
  /// In es, this message translates to:
  /// **'vs mes ant.'**
  String get vsPrevMonth;

  /// No description provided for @streakMessage.
  ///
  /// In es, this message translates to:
  /// **'¡{n} días seguidos viajando! 🎉'**
  String streakMessage(int n);

  /// No description provided for @tripsPerMonth.
  ///
  /// In es, this message translates to:
  /// **'📊 Viajes por Mes'**
  String get tripsPerMonth;

  /// No description provided for @weekdaysTitle.
  ///
  /// In es, this message translates to:
  /// **'📅 Días de la Semana'**
  String get weekdaysTitle;

  /// No description provided for @weekdays.
  ///
  /// In es, this message translates to:
  /// **'Entre semana'**
  String get weekdays;

  /// No description provided for @weekends.
  ///
  /// In es, this message translates to:
  /// **'Fin de semana'**
  String get weekends;

  /// No description provided for @summaryTitle.
  ///
  /// In es, this message translates to:
  /// **'📈 Resumen'**
  String get summaryTitle;

  /// No description provided for @totalTripsLabel.
  ///
  /// In es, this message translates to:
  /// **'Viajes totales'**
  String get totalTripsLabel;

  /// No description provided for @favouriteStop.
  ///
  /// In es, this message translates to:
  /// **'Parada favorita'**
  String get favouriteStop;

  /// No description provided for @usualTime.
  ///
  /// In es, this message translates to:
  /// **'Horario habitual'**
  String get usualTime;

  /// No description provided for @topLines.
  ///
  /// In es, this message translates to:
  /// **'🚌 Líneas más usadas'**
  String get topLines;

  /// No description provided for @line.
  ///
  /// In es, this message translates to:
  /// **'Línea'**
  String get line;

  /// No description provided for @topStops.
  ///
  /// In es, this message translates to:
  /// **'🚏 Paradas más frecuentes'**
  String get topStops;

  /// No description provided for @recentActivity.
  ///
  /// In es, this message translates to:
  /// **'📅 Actividad reciente'**
  String get recentActivity;

  /// No description provided for @last7days.
  ///
  /// In es, this message translates to:
  /// **'Últimos 7 días'**
  String get last7days;

  /// No description provided for @last30days.
  ///
  /// In es, this message translates to:
  /// **'Últimos 30 días'**
  String get last30days;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ca', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
