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
  /// **'Alzitrans — Alzira'**
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
  /// **'Avisos'**
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
  /// **'Iniciar Sesión en Alzitrans'**
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

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'Olvidé mi contraseña'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar Contraseña'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstructions.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu email para recibir un código de recuperación.'**
  String get forgotPasswordInstructions;

  /// No description provided for @sendCode.
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get sendCode;

  /// No description provided for @enterCode.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código'**
  String get enterCode;

  /// No description provided for @codeSent.
  ///
  /// In es, this message translates to:
  /// **'Código enviado a tu email'**
  String get codeSent;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva Contraseña'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordButton.
  ///
  /// In es, this message translates to:
  /// **'Restablecer Contraseña'**
  String get resetPasswordButton;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In es, this message translates to:
  /// **'Contraseña actualizada correctamente'**
  String get passwordResetSuccess;

  /// No description provided for @verifyCode.
  ///
  /// In es, this message translates to:
  /// **'Verificar código'**
  String get verifyCode;

  /// No description provided for @accessibilityVoice.
  ///
  /// In es, this message translates to:
  /// **'Modo Accesibilidad (Voz)'**
  String get accessibilityVoice;

  /// No description provided for @accessibilityVoiceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Lee las paradas al seleccionarlas'**
  String get accessibilityVoiceSubtitle;

  /// No description provided for @highVisibilityMode.
  ///
  /// In es, this message translates to:
  /// **'Modo Alta Visibilidad'**
  String get highVisibilityMode;

  /// No description provided for @highVisibilitySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Optimizado para mejor legibilidad'**
  String get highVisibilitySubtitle;

  /// No description provided for @helpAndSupport.
  ///
  /// In es, this message translates to:
  /// **'Ayuda y Soporte'**
  String get helpAndSupport;

  /// No description provided for @helpAndSupportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Preguntas frecuentes y contacto'**
  String get helpAndSupportSubtitle;

  /// No description provided for @privacyAndPermissions.
  ///
  /// In es, this message translates to:
  /// **'PERMISOS Y PRIVACIDAD'**
  String get privacyAndPermissions;

  /// No description provided for @backgroundAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas en segundo plano'**
  String get backgroundAlerts;

  /// No description provided for @backgroundAlertsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Configura el rastreo de bus fuera de la app'**
  String get backgroundAlertsSubtitle;

  /// No description provided for @permissionActivated.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes este permiso activado ✅'**
  String get permissionActivated;

  /// No description provided for @configure.
  ///
  /// In es, this message translates to:
  /// **'Configurar'**
  String get configure;

  /// No description provided for @privacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de Privacidad'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Consulta cómo protegemos tus datos'**
  String get privacyPolicySubtitle;

  /// No description provided for @dataCredits.
  ///
  /// In es, this message translates to:
  /// **'Créditos y fuentes de datos'**
  String get dataCredits;

  /// No description provided for @dataCreditsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'De dónde vienen los horarios y avisos'**
  String get dataCreditsSubtitle;

  /// No description provided for @dataCreditsTitle.
  ///
  /// In es, this message translates to:
  /// **'Fuentes de datos'**
  String get dataCreditsTitle;

  /// No description provided for @dataCreditsBusOperator.
  ///
  /// In es, this message translates to:
  /// **'Tiempos de autobús'**
  String get dataCreditsBusOperator;

  /// No description provided for @dataCreditsBusOperatorBody.
  ///
  /// In es, this message translates to:
  /// **'Los horarios y tiempos de paso de las líneas L1, L2 y L3 son cortesía de Autocares Lozano S.L.U., concesionaria del servicio urbano de Alzira. Alzitrans consulta la información pública directamente desde el dispositivo de cada usuario; no almacena ni redistribuye los datos. Alzitrans no está afiliada con Autocares Lozano S.L.U.'**
  String get dataCreditsBusOperatorBody;

  /// No description provided for @dataCreditsRenfe.
  ///
  /// In es, this message translates to:
  /// **'Trenes Cercanías'**
  String get dataCreditsRenfe;

  /// No description provided for @dataCreditsRenfeBody.
  ///
  /// In es, this message translates to:
  /// **'Los horarios de Cercanías C2 provienen de Renfe Operadora.'**
  String get dataCreditsRenfeBody;

  /// No description provided for @dataCreditsThanks.
  ///
  /// In es, this message translates to:
  /// **'Gracias a Autocares Lozano S.L.U. por hacer pública esta información, sin la cual esta app no podría existir.'**
  String get dataCreditsThanks;

  /// No description provided for @creditsLineLozano.
  ///
  /// In es, this message translates to:
  /// **'Datos por Autocares Lozano'**
  String get creditsLineLozano;

  /// No description provided for @removeAdsTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar Anuncios (30 min)'**
  String get removeAdsTitle;

  /// No description provided for @removeAdsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ver un vídeo corto para ocultar banners'**
  String get removeAdsSubtitle;

  /// No description provided for @adsHiddenSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Anuncios ocultos por 30 minutos! Disfruta 🎉'**
  String get adsHiddenSuccess;

  /// No description provided for @adNotAvailable.
  ///
  /// In es, this message translates to:
  /// **'Anuncio no disponible en este momento. Inténtalo más tarde.'**
  String get adNotAvailable;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Borrado permanente de todos tus datos'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar tu cuenta?'**
  String get deleteAccountDialogTitle;

  /// No description provided for @deleteAccountIrreversible.
  ///
  /// In es, this message translates to:
  /// **'Esta acción es irreversible. Se borrarán permanentemente:'**
  String get deleteAccountIrreversible;

  /// No description provided for @deleteAccountBullet1.
  ///
  /// In es, this message translates to:
  /// **'• Tu historial de viajes y estadísticas.'**
  String get deleteAccountBullet1;

  /// No description provided for @deleteAccountBullet2.
  ///
  /// In es, this message translates to:
  /// **'• Tus paradas favoritas.'**
  String get deleteAccountBullet2;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Estás totalmente seguro de que quieres eliminar la cuenta de {email}?'**
  String deleteAccountConfirm(String email);

  /// No description provided for @deleteAccountConfirmButton.
  ///
  /// In es, this message translates to:
  /// **'SÍ, ELIMINAR TODO'**
  String get deleteAccountConfirmButton;

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada con éxito. Sentimos que te vayas.'**
  String get accountDeletedSuccess;

  /// No description provided for @emailUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Email actualizado'**
  String get emailUpdatedSuccess;

  /// No description provided for @passwordUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Contraseña actualizada'**
  String get passwordUpdatedSuccess;

  /// No description provided for @genericError.
  ///
  /// In es, this message translates to:
  /// **'Error: {message}'**
  String genericError(String message);

  /// No description provided for @loginWithBiometrics.
  ///
  /// In es, this message translates to:
  /// **'Entrar con huella'**
  String get loginWithBiometrics;

  /// No description provided for @biometricLoginError.
  ///
  /// In es, this message translates to:
  /// **'Error en acceso biométrico: {error}'**
  String biometricLoginError(String error);

  /// No description provided for @unexpectedError.
  ///
  /// In es, this message translates to:
  /// **'Error inesperado: {error}'**
  String unexpectedError(String error);

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'Registro en Alzibus'**
  String get registerTitle;

  /// No description provided for @registerInfoBox.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un código al iniciar sesión. Si no inicias sesión en 7 días, la cuenta se eliminará automáticamente.'**
  String get registerInfoBox;

  /// No description provided for @accountCreatedSnack.
  ///
  /// In es, this message translates to:
  /// **'Cuenta creada. Inicia sesión en los próximos 7 días o se eliminará automáticamente.'**
  String get accountCreatedSnack;

  /// No description provided for @registerButton.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get registerButton;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificar Correo'**
  String get verifyEmailTitle;

  /// No description provided for @confirmYourEmail.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu correo'**
  String get confirmYourEmail;

  /// No description provided for @codeSentToEmail.
  ///
  /// In es, this message translates to:
  /// **'Hemos enviado un código de 6 dígitos a:\n{email}'**
  String codeSentToEmail(String email);

  /// No description provided for @codeExpiresIn15Min.
  ///
  /// In es, this message translates to:
  /// **'El código caduca en 15 minutos.'**
  String get codeExpiresIn15Min;

  /// No description provided for @verifyCodeButton.
  ///
  /// In es, this message translates to:
  /// **'Verificar Código'**
  String get verifyCodeButton;

  /// No description provided for @resendCodeWithLeft.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Reenviar código (1 restante)} other{Reenviar código ({count} restantes)}}'**
  String resendCodeWithLeft(int count);

  /// No description provided for @noResendsLeft.
  ///
  /// In es, this message translates to:
  /// **'Sin reenvíos disponibles'**
  String get noResendsLeft;

  /// No description provided for @enableBiometricsDialog.
  ///
  /// In es, this message translates to:
  /// **'¿Activar Huella?'**
  String get enableBiometricsDialog;

  /// No description provided for @enableBiometricsBody.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres entrar más rápido la próxima vez usando tu huella dactilar?'**
  String get enableBiometricsBody;

  /// No description provided for @notNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get notNow;

  /// No description provided for @yesActivate.
  ///
  /// In es, this message translates to:
  /// **'¡Sí, activar!'**
  String get yesActivate;

  /// No description provided for @stopAddedToFavorites.
  ///
  /// In es, this message translates to:
  /// **'⭐ Parada añadida a favoritos'**
  String get stopAddedToFavorites;

  /// No description provided for @alertSetForLine.
  ///
  /// In es, this message translates to:
  /// **'✅ Te avisaremos cuando llegue la línea {line}'**
  String alertSetForLine(String line);

  /// No description provided for @requiresInternet.
  ///
  /// In es, this message translates to:
  /// **'(Requiere conexión a internet)'**
  String get requiresInternet;

  /// No description provided for @mapView.
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get mapView;

  /// No description provided for @satelliteView.
  ///
  /// In es, this message translates to:
  /// **'Satélite'**
  String get satelliteView;

  /// No description provided for @satelliteViewUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Vista satelital no disponible'**
  String get satelliteViewUnavailable;

  /// No description provided for @removeFromFavorites.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritos'**
  String get removeFromFavorites;

  /// No description provided for @addToFavorites.
  ///
  /// In es, this message translates to:
  /// **'Añadir a favoritos'**
  String get addToFavorites;

  /// No description provided for @nextBuses.
  ///
  /// In es, this message translates to:
  /// **'⏱️ Próximos buses:'**
  String get nextBuses;

  /// No description provided for @noUpcomingBuses.
  ///
  /// In es, this message translates to:
  /// **'No hay buses próximos'**
  String get noUpcomingBuses;

  /// No description provided for @nearbyTrainsC2.
  ///
  /// In es, this message translates to:
  /// **'🚆 Trenes Cercanías C2:'**
  String get nearbyTrainsC2;

  /// No description provided for @noUpcomingTrains.
  ///
  /// In es, this message translates to:
  /// **'No hay trenes próximos'**
  String get noUpcomingTrains;

  /// No description provided for @refresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get refresh;

  /// No description provided for @refreshTrains.
  ///
  /// In es, this message translates to:
  /// **'Actualizar trenes'**
  String get refreshTrains;

  /// No description provided for @linesLabel.
  ///
  /// In es, this message translates to:
  /// **'Líneas:'**
  String get linesLabel;

  /// No description provided for @lines.
  ///
  /// In es, this message translates to:
  /// **'Líneas'**
  String get lines;

  /// No description provided for @daysAgo.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Hoy} =1{Hace 1 día} other{Hace {count} días}}'**
  String daysAgo(int count);

  /// No description provided for @minutesAgo.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ahora mismo} =1{Hace 1 minuto} other{Hace {count} minutos}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Hace 1 hora} other{Hace {count} horas}}'**
  String hoursAgo(int count);

  /// No description provided for @lineWithNumber.
  ///
  /// In es, this message translates to:
  /// **'Línea {line}'**
  String lineWithNumber(String line);

  /// No description provided for @oneTripWillBeDeducted.
  ///
  /// In es, this message translates to:
  /// **'Se descontará 1 viaje de tu tarjeta (te quedan {remaining})'**
  String oneTripWillBeDeducted(int remaining);

  /// No description provided for @unlimitedTrips.
  ///
  /// In es, this message translates to:
  /// **'Tienes viajes ILIMITADOS'**
  String get unlimitedTrips;

  /// No description provided for @noTripsOnCard.
  ///
  /// In es, this message translates to:
  /// **'No tienes viajes en la tarjeta'**
  String get noTripsOnCard;

  /// No description provided for @noTripUnderstood.
  ///
  /// In es, this message translates to:
  /// **'👍 Entendido, no se registró'**
  String get noTripUnderstood;

  /// No description provided for @iDidntGetOn.
  ///
  /// In es, this message translates to:
  /// **'No he subido'**
  String get iDidntGetOn;

  /// No description provided for @yesIGotOn.
  ///
  /// In es, this message translates to:
  /// **'Sí, registrar'**
  String get yesIGotOn;

  /// No description provided for @cardTripRegistered.
  ///
  /// In es, this message translates to:
  /// **'¡Viaje con Tarjeta registrado!'**
  String get cardTripRegistered;

  /// No description provided for @cashTripRegistered.
  ///
  /// In es, this message translates to:
  /// **'¡Viaje en Efectivo registrado!'**
  String get cashTripRegistered;

  /// No description provided for @viewHistory.
  ///
  /// In es, this message translates to:
  /// **'Ver historial'**
  String get viewHistory;

  /// No description provided for @playWhileWaiting.
  ///
  /// In es, this message translates to:
  /// **'¡Echa una partida mientras esperas!'**
  String get playWhileWaiting;

  /// No description provided for @welcomeGreeting.
  ///
  /// In es, this message translates to:
  /// **'¡Hola! 👋'**
  String get welcomeGreeting;

  /// No description provided for @welcomeMessage.
  ///
  /// In es, this message translates to:
  /// **'¡Espero que te sea de mucha utilidad!'**
  String get welcomeMessage;

  /// No description provided for @busInService.
  ///
  /// In es, this message translates to:
  /// **'Autobús en servicio'**
  String get busInService;

  /// No description provided for @nextStop.
  ///
  /// In es, this message translates to:
  /// **'Próxima parada'**
  String get nextStop;

  /// No description provided for @welcomeThanks.
  ///
  /// In es, this message translates to:
  /// **'Gracias por descargar Alzi Trans.'**
  String get welcomeThanks;

  /// No description provided for @welcomeStudent.
  ///
  /// In es, this message translates to:
  /// **'Soy un estudiante de 2º de DAM y he creado esta app de forma independiente para mejorar nuestro transporte.'**
  String get welcomeStudent;

  /// No description provided for @welcomeDevelopmentNotice.
  ///
  /// In es, this message translates to:
  /// **'Ten en cuenta que es un proyecto en desarrollo y puede contener errores.'**
  String get welcomeDevelopmentNotice;

  /// No description provided for @understoodCaps.
  ///
  /// In es, this message translates to:
  /// **'ENTENDIDO'**
  String get understoodCaps;

  /// No description provided for @estimatedTime.
  ///
  /// In es, this message translates to:
  /// **'Tiempo estimado'**
  String get estimatedTime;

  /// No description provided for @statusLabel.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get statusLabel;

  /// No description provided for @atStop.
  ///
  /// In es, this message translates to:
  /// **'🛑 En parada'**
  String get atStop;

  /// No description provided for @inMovement.
  ///
  /// In es, this message translates to:
  /// **'🚌 En movimiento'**
  String get inMovement;

  /// No description provided for @nfcCardReadSuccess.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta leída correctamente'**
  String get nfcCardReadSuccess;

  /// No description provided for @nfcBalanceAnnounce.
  ///
  /// In es, this message translates to:
  /// **'Saldo de {balance} euros. Te quedan {trips} viajes.'**
  String nfcBalanceAnnounce(String balance, int trips);

  /// No description provided for @nfcUnlimitedAnnounce.
  ///
  /// In es, this message translates to:
  /// **'Bono ilimitado activo.'**
  String get nfcUnlimitedAnnounce;

  /// No description provided for @busArrivalAnnounce.
  ///
  /// In es, this message translates to:
  /// **'El autobús de la línea {line} con destino {destination} llegará a {stop} en {minutes} minutos.'**
  String busArrivalAnnounce(
      String line, String destination, String stop, int minutes);

  /// No description provided for @busArrivingAnnounce.
  ///
  /// In es, this message translates to:
  /// **'El autobús de la línea {line} con destino {destination} está llegando a {stop}.'**
  String busArrivingAnnounce(Object destination, Object line, Object stop);

  /// No description provided for @stopAnnounce.
  ///
  /// In es, this message translates to:
  /// **'Parada {name}.'**
  String stopAnnounce(Object name);

  /// No description provided for @teHemosApuntado.
  ///
  /// In es, this message translates to:
  /// **'Te hemos apuntado al bus'**
  String get teHemosApuntado;

  /// No description provided for @alertaActiva.
  ///
  /// In es, this message translates to:
  /// **'(Alerta activa)'**
  String get alertaActiva;

  /// No description provided for @personasInteresadas.
  ///
  /// In es, this message translates to:
  /// **'{n} personas interesadas'**
  String personasInteresadas(int n);

  /// No description provided for @rankingTitle.
  ///
  /// In es, this message translates to:
  /// **'Ranking de Viajeros'**
  String get rankingTitle;

  /// No description provided for @rankingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Compite con otros viajeros de Alzira'**
  String get rankingSubtitle;

  /// No description provided for @yourPosition.
  ///
  /// In es, this message translates to:
  /// **'Tu posición: #{pos} · {trips} viajes'**
  String yourPosition(int pos, int trips);

  /// No description provided for @thisMonthToggle.
  ///
  /// In es, this message translates to:
  /// **'Este mes'**
  String get thisMonthToggle;

  /// No description provided for @allTimeToggle.
  ///
  /// In es, this message translates to:
  /// **'Todo el tiempo'**
  String get allTimeToggle;

  /// No description provided for @rankingLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el ranking'**
  String get rankingLoadError;

  /// No description provided for @noTripsRankingMonth.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha viajado este mes aún. ¡Sé el primero!'**
  String get noTripsRankingMonth;

  /// No description provided for @noTripsRankingAll.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay viajes registrados.'**
  String get noTripsRankingAll;

  /// No description provided for @travelersRankingHeader.
  ///
  /// In es, this message translates to:
  /// **'🏆 Ranking de Viajeros'**
  String get travelersRankingHeader;
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
