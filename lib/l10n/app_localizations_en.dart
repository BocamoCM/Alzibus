// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Alzitrans — Alzira';

  @override
  String get tabMap => 'Map';

  @override
  String get tabRoutes => 'Routes';

  @override
  String get tabNfc => 'NFC';

  @override
  String get tabSettings => 'Settings';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Sign up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get profile => 'My profile';

  @override
  String get editEmail => 'Change email';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get update => 'Update';

  @override
  String get retry => 'Retry';

  @override
  String get profileLoadError => 'Could not load profile';

  @override
  String get accountInfo => 'Account information';

  @override
  String get lastAccess => 'Last access';

  @override
  String get memberSince => 'Member since';

  @override
  String get totalTrips => 'Total trips';

  @override
  String get mostUsedLine => 'Favourite line';

  @override
  String get thisMonth => 'This month';

  @override
  String get notices => 'Notices & Alerts';

  @override
  String get noActiveNotices => 'No active notices';

  @override
  String get serviceNormal => 'Service is running normally';

  @override
  String get noticeTitle => 'Title';

  @override
  String get noticeBody => 'Description';

  @override
  String get validUntil => 'Until';

  @override
  String get tripHistory => 'Trip history';

  @override
  String get activeAlerts => 'Active alerts';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get activateNotifications => 'Enable notifications';

  @override
  String get notificationsSubtitle => 'Get alerts when approaching stops';

  @override
  String get alertDistance => 'Alert distance';

  @override
  String get timeBetweenNotifications => 'Time between notifications';

  @override
  String get vibration => 'Vibration';

  @override
  String get vibrationSubtitle => 'Vibrate with notifications';

  @override
  String minutesSuffix(int n) {
    return '$n minutes';
  }

  @override
  String metersSuffix(int n) {
    return '$n metres';
  }

  @override
  String get map => 'Map';

  @override
  String get showSimulatedBuses => 'Show buses on map';

  @override
  String get showSimulatedBusesSubtitle => 'View simulated bus positions';

  @override
  String get autoRefreshTimes => 'Auto-refresh times';

  @override
  String get autoRefreshTimesSubtitle => 'Refresh every 30 seconds';

  @override
  String get serviceStatus => 'Service status';

  @override
  String get serviceActive => 'Service active';

  @override
  String get serviceStopped => 'Service stopped';

  @override
  String get lastCheck => 'Last check';

  @override
  String get activeAlertsCount => 'Active alerts';

  @override
  String get lastBus => 'Last bus';

  @override
  String get refreshButton => 'Refresh';

  @override
  String get testNotification => 'Test notification';

  @override
  String get resetAlerts => 'Reset alerts';

  @override
  String get checkNow => 'Check buses NOW';

  @override
  String get information => 'Information';

  @override
  String get appDescription => 'App to check bus stops in Alzira, Valencia.';

  @override
  String get didYouTakeTheBus => 'Did you take the bus?';

  @override
  String get yes => 'Yes!';

  @override
  String get no => 'No';

  @override
  String get tripRegistered => 'Trip registered!';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get never => 'Never';

  @override
  String get loginTitle => 'Sign in to Alzitrans';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get invalidEmail => 'Invalid email format';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get loginButton => 'Sign in';

  @override
  String get noAccount => 'Don\'t have an account? Sign up';

  @override
  String get incorrectCredentials => 'Incorrect email or password.';

  @override
  String get noServerConnection =>
      'No connection to server. Check your network.';

  @override
  String get accountDisabled => 'This account has been disabled.';

  @override
  String get activeAlertsTitle => 'Active Alerts';

  @override
  String get noActiveAlerts => 'No active alerts';

  @override
  String get noActiveAlertsHint =>
      'Tap \"Alert\" on a stop\nto receive notifications';

  @override
  String get goToMap => 'Go to map';

  @override
  String get cancelAlert => 'Cancel alert?';

  @override
  String get cancelAlertBody => 'You will stop receiving alerts for this line';

  @override
  String get cancelAlertYes => 'Yes, cancel';

  @override
  String get noData => 'No data';

  @override
  String get noService => 'No service';

  @override
  String alertActivatedMinAgo(int n) {
    return 'Activated $n min ago';
  }

  @override
  String get viewStopOnMap => 'View stop on map';

  @override
  String get cancelAlertTooltip => 'Cancel alert';

  @override
  String get statusWaiting => '⏳ Waiting';

  @override
  String get statusNotified => '✅ Notified';

  @override
  String get statusClose => '⚠️ Very close';

  @override
  String get statusArriving => '🔔 Arriving';

  @override
  String get newNoticePopupTitle => 'New Notice';

  @override
  String get understood => 'Got it';

  @override
  String get tripHistoryTitle => 'Trip History';

  @override
  String get tabStats => 'Statistics';

  @override
  String get tabHistory => 'History';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryConfirmTitle => 'Clear history?';

  @override
  String get clearHistoryConfirmBody => 'All saved trips will be deleted.';

  @override
  String get noTripsRegistered => 'No trips registered';

  @override
  String get noTripsHint => 'Enable bus alerts to start\nrecording your trips';

  @override
  String get noTripsHistory => 'No trips in history';

  @override
  String get streakTitle => '🔥 Streaks & Progress';

  @override
  String get streak => 'Streak';

  @override
  String get bestStreak => 'Best';

  @override
  String get vsPrevMonth => 'vs prev. month';

  @override
  String streakMessage(int n) {
    return '$n days travelling in a row! 🎉';
  }

  @override
  String get tripsPerMonth => '📊 Trips per Month';

  @override
  String get weekdaysTitle => '📅 Days of the Week';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get weekends => 'Weekends';

  @override
  String get summaryTitle => '📈 Summary';

  @override
  String get totalTripsLabel => 'Total trips';

  @override
  String get favouriteStop => 'Favourite stop';

  @override
  String get usualTime => 'Usual time';

  @override
  String get topLines => '🚌 Most used lines';

  @override
  String get line => 'Line';

  @override
  String get topStops => '🚏 Most frequent stops';

  @override
  String get recentActivity => '📅 Recent activity';

  @override
  String get last7days => 'Last 7 days';

  @override
  String get last30days => 'Last 30 days';

  @override
  String get forgotPassword => 'Forgot my password';

  @override
  String get forgotPasswordTitle => 'Recover Password';

  @override
  String get forgotPasswordInstructions =>
      'Enter your email to receive a recovery code.';

  @override
  String get sendCode => 'Send code';

  @override
  String get enterCode => 'Enter the code';

  @override
  String get codeSent => 'Code sent to your email';

  @override
  String get resetPasswordTitle => 'New Password';

  @override
  String get resetPasswordButton => 'Reset Password';

  @override
  String get passwordResetSuccess => 'Password updated successfully';

  @override
  String get verifyCode => 'Verify code';

  @override
  String get accessibilityVoice => 'Accessibility Mode (Voice)';

  @override
  String get accessibilityVoiceSubtitle => 'Read stops when selecting them';

  @override
  String get highVisibilityMode => 'High Visibility Mode';

  @override
  String get highVisibilitySubtitle => 'Optimized for better readability';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get helpAndSupportSubtitle => 'FAQ and contact';

  @override
  String get privacyAndPermissions => 'PERMISSIONS & PRIVACY';

  @override
  String get backgroundAlerts => 'Background Alerts';

  @override
  String get backgroundAlertsSubtitle =>
      'Configure bus tracking outside the app';

  @override
  String get permissionActivated =>
      'You already have this permission enabled ✅';

  @override
  String get configure => 'Configure';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle => 'See how we protect your data';

  @override
  String get nfcCardReadSuccess => 'Card read successfully';

  @override
  String nfcBalanceAnnounce(String balance, int trips) {
    return 'Balance of $balance euros. You have $trips trips left.';
  }

  @override
  String get nfcUnlimitedAnnounce => 'Unlimited pass active.';

  @override
  String busArrivalAnnounce(
      String line, String destination, String stop, int minutes) {
    return 'The line $line bus to $destination will arrive at $stop in $minutes minutes.';
  }

  @override
  String busArrivingAnnounce(Object destination, Object line, Object stop) {
    return 'The line $line bus to $destination is arriving at $stop.';
  }

  @override
  String stopAnnounce(Object name) {
    return 'Stop $name.';
  }

  @override
  String get teHemosApuntado => 'You\'ve been joined to the bus';

  @override
  String get alertaActiva => '(Active alert)';

  @override
  String personasInteresadas(int n) {
    return '$n people interested';
  }
}
