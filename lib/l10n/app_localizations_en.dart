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
  String get dataCredits => 'Credits & data sources';

  @override
  String get dataCreditsSubtitle => 'Where schedules and notices come from';

  @override
  String get dataCreditsTitle => 'Data sources';

  @override
  String get dataCreditsBusOperator => 'Bus arrival times';

  @override
  String get dataCreditsBusOperatorBody =>
      'Timetables and arrival times for lines L1, L2 and L3 are courtesy of Autocares Lozano S.L.U., the operator of Alzira\'s urban bus service. Alzitrans queries this public information directly from each user\'s device; it does not store or redistribute the data. Alzitrans is not affiliated with Autocares Lozano S.L.U.';

  @override
  String get dataCreditsRenfe => 'Commuter trains';

  @override
  String get dataCreditsRenfeBody =>
      'Cercanías C2 schedules are provided by Renfe Operadora.';

  @override
  String get dataCreditsThanks =>
      'Thanks to Autocares Lozano S.L.U. for making this information publicly available — without it this app could not exist.';

  @override
  String get creditsLineLozano => 'Data by Autocares Lozano';

  @override
  String get removeAdsTitle => 'Remove Ads (30 min)';

  @override
  String get removeAdsSubtitle => 'Watch a short video to hide banners';

  @override
  String get adsHiddenSuccess => 'Ads hidden for 30 minutes! Enjoy 🎉';

  @override
  String get adNotAvailable => 'Ad not available right now. Try again later.';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountSubtitle => 'Permanent deletion of all your data';

  @override
  String get deleteAccountDialogTitle => 'Delete your account?';

  @override
  String get deleteAccountIrreversible =>
      'This action cannot be undone. The following will be permanently deleted:';

  @override
  String get deleteAccountBullet1 => '• Your trip history and statistics.';

  @override
  String get deleteAccountBullet2 => '• Your favourite stops.';

  @override
  String deleteAccountConfirm(String email) {
    return 'Are you absolutely sure you want to delete the account for $email?';
  }

  @override
  String get deleteAccountConfirmButton => 'YES, DELETE EVERYTHING';

  @override
  String get accountDeletedSuccess =>
      'Account successfully deleted. Sorry to see you go.';

  @override
  String get emailUpdatedSuccess => '✅ Email updated';

  @override
  String get passwordUpdatedSuccess => '✅ Password updated';

  @override
  String genericError(String message) {
    return 'Error: $message';
  }

  @override
  String get loginWithBiometrics => 'Log in with fingerprint';

  @override
  String biometricLoginError(String error) {
    return 'Biometric login error: $error';
  }

  @override
  String unexpectedError(String error) {
    return 'Unexpected error: $error';
  }

  @override
  String get registerTitle => 'Register in Alzibus';

  @override
  String get registerInfoBox =>
      'We\'ll send you a code when you log in. If you don\'t log in within 7 days, the account will be deleted automatically.';

  @override
  String get accountCreatedSnack =>
      'Account created. Log in within the next 7 days or it will be deleted automatically.';

  @override
  String get registerButton => 'Sign up';

  @override
  String get verifyEmailTitle => 'Verify Email';

  @override
  String get confirmYourEmail => 'Confirm your email';

  @override
  String codeSentToEmail(String email) {
    return 'We\'ve sent a 6-digit code to:\n$email';
  }

  @override
  String get codeExpiresIn15Min => 'The code expires in 15 minutes.';

  @override
  String get verifyCodeButton => 'Verify Code';

  @override
  String resendCodeWithLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resend code ($count left)',
      one: 'Resend code (1 left)',
    );
    return '$_temp0';
  }

  @override
  String get noResendsLeft => 'No resends available';

  @override
  String get enableBiometricsDialog => 'Enable Fingerprint?';

  @override
  String get enableBiometricsBody =>
      'Want to log in faster next time using your fingerprint?';

  @override
  String get notNow => 'Not now';

  @override
  String get yesActivate => 'Yes, enable!';

  @override
  String get stopAddedToFavorites => '⭐ Stop added to favourites';

  @override
  String alertSetForLine(String line) {
    return '✅ We\'ll notify you when line $line arrives';
  }

  @override
  String get requiresInternet => '(Requires internet connection)';

  @override
  String get mapView => 'Map';

  @override
  String get satelliteView => 'Satellite';

  @override
  String get satelliteViewUnavailable => 'Satellite view unavailable';

  @override
  String get removeFromFavorites => 'Remove from favourites';

  @override
  String get addToFavorites => 'Add to favourites';

  @override
  String get nextBuses => '⏱️ Upcoming buses:';

  @override
  String get noUpcomingBuses => 'No buses coming';

  @override
  String get nearbyTrainsC2 => '🚆 Cercanías C2 trains:';

  @override
  String get noUpcomingTrains => 'No trains coming';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshTrains => 'Refresh trains';

  @override
  String get linesLabel => 'Lines:';

  @override
  String get lines => 'Lines';

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
      zero: 'Today',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
      zero: 'Just now',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String lineWithNumber(String line) {
    return 'Line $line';
  }

  @override
  String oneTripWillBeDeducted(int remaining) {
    return '1 trip will be deducted from your card ($remaining left)';
  }

  @override
  String get unlimitedTrips => 'You have UNLIMITED trips';

  @override
  String get noTripsOnCard => 'You have no trips on your card';

  @override
  String get noTripUnderstood => '👍 Got it, not registered';

  @override
  String get iDidntGetOn => 'I didn\'t get on';

  @override
  String get yesIGotOn => 'Yes, register';

  @override
  String get cardTripRegistered => 'Card trip registered!';

  @override
  String get cashTripRegistered => 'Cash trip registered!';

  @override
  String get viewHistory => 'View history';

  @override
  String get watchAdSubtitle => 'Watch a short video and enjoy without banners';

  @override
  String get adNotReadyYet => 'Ad not ready yet. Try again in a few seconds.';

  @override
  String get adsHiddenShort => 'Ads hidden for 30 minutes! 🎉';

  @override
  String get dailyAdLimitReached =>
      'You\'ve reached today\'s ad limit. Come back tomorrow!';

  @override
  String coinsEarnedThanks(int count) {
    return '+$count coins 🪙 Thanks!';
  }

  @override
  String get dailyEarningsExplained =>
      'Each day you can earn up to 30 coins by playing + 60 by watching ads. It\'s a slow but steady pace: come back daily to fill up the wallet.';

  @override
  String get dailyMaxReached =>
      'You\'ve reached today\'s maximum. Come back tomorrow!';

  @override
  String confirmSpendCoins(int cost, String skin) {
    return 'Do you confirm you want to spend $cost 🪙 to unlock $skin?';
  }

  @override
  String skinUnlockedAndEquipped(String skin) {
    return '$skin unlocked and equipped! 🎉';
  }

  @override
  String wearingSkin(String skin) {
    return 'Wearing \"$skin\"';
  }

  @override
  String unlockSkinTitle(String skin) {
    return 'Unlock $skin';
  }

  @override
  String unlockSkinBody(int cost) {
    return 'Do you confirm you want to spend $cost 🪙 to unlock this skin? Once unlocked, it\'s yours forever.';
  }

  @override
  String get unlockButton => 'Unlock';

  @override
  String get notEnoughCoins => 'Not enough coins.';

  @override
  String skinEquipped(String skin) {
    return '$skin equipped';
  }

  @override
  String get mifareClassicInfo =>
      'Mifare Classic 1K cards require special authentication to read the balance. Most Android phones can\'t read them without specialised hardware.';

  @override
  String get featureNotAvailableWeb => 'Feature not available in browser';

  @override
  String get featureAndroidOnly => 'Android-only feature';

  @override
  String get nfcWebExplained =>
      'NFC card reading requires hardware access that\'s not available in the web version.\n\nInstall the app to use this feature.';

  @override
  String get nfcIosExplained =>
      'Due to Apple restrictions with Mifare Classic cards, balance reading isn\'t supported on iPhone.\n\nUse the map and schedules to plan your trip.';

  @override
  String get publicTransportAlzira => 'Alzira Public Transport';

  @override
  String get validateTripPrompt =>
      'Do you want to validate a trip now? 1 will be deducted from your counter.';

  @override
  String get confirmTripTitle => 'Confirm trip';

  @override
  String get shareTripIntro =>
      'Want someone to know where you are? Start the shared trip and I\'ll give you a link to send them.';

  @override
  String get creatingSharedTrip => 'Creating your shared trip...';

  @override
  String get noLocationPermissionShare =>
      'Without location permission I can\'t share the trip.';

  @override
  String get needLocationPermissionAlbus =>
      'I need permission to see where you are!';

  @override
  String get tripReadyShareIt =>
      'Ready! Share the link and people will see where you are in real time.';

  @override
  String couldntCreateTrip(String error) {
    return 'Couldn\'t create the trip: $error';
  }

  @override
  String get somethingBrokeRetry => 'Something broke. Want to try again?';

  @override
  String get endingSharedTrip => 'Ending the shared trip...';

  @override
  String get tripEnded => 'Trip finished! Safe travels 👋';

  @override
  String shareMessageWithDest(String url) {
    return 'I\'m on the bus! Track me live: $url';
  }

  @override
  String shareMessage(String url) {
    return 'Follow my live bus trip! $url';
  }

  @override
  String shareSubjectWithDest(String destination) {
    return 'On my way to $destination · Alzitrans';
  }

  @override
  String get shareSubject => 'My live trip · Alzitrans';

  @override
  String get linkShared => 'Link shared! 🚌';

  @override
  String linkCopied(String url) {
    return 'Link copied: $url';
  }

  @override
  String destinationLabel(String name) {
    return 'Destination: $name';
  }

  @override
  String get lineLabelSingular => 'Line: ';

  @override
  String get shareTripExplanation =>
      'When you start, a public link will be generated that you can send to anyone. They\'ll see your position and estimated arrival time updated every 30 seconds.';

  @override
  String get linkExpires6Hours => 'The link expires after 6 hours.';

  @override
  String get startingButton => 'Starting...';

  @override
  String get startSharingButton => 'Start sharing';

  @override
  String get sharingLive => 'Sharing live';

  @override
  String get destination => 'Destination';

  @override
  String get lineSingular => 'Line';

  @override
  String get etaLabel => 'Estimated arrival';

  @override
  String get lastPosition => 'Last position';

  @override
  String get linkToShare => 'Link to share';

  @override
  String get copy => 'Copy';

  @override
  String get seeAsOthersSee => 'See it as others do';

  @override
  String get endingButton => 'Ending...';

  @override
  String get stopSharingButton => 'Stop sharing';

  @override
  String get minimizeBackgroundNotice =>
      'You can minimise the app safely: location pings keep being sent in the background every 30 s.';

  @override
  String minutesShort(int n) {
    return '$n min';
  }

  @override
  String get plannerTitle => 'Planner with Albus';

  @override
  String get albusGreeting =>
      'Hi! I\'m Albus 🚌. Tell me where you\'re leaving from and where you\'re going, and I\'ll tell you which bus to take.';

  @override
  String get chooseOriginAndDest =>
      'Choose origin and destination before searching.';

  @override
  String get albusNeedsOriginDest =>
      'Oh! I need to know where you\'re leaving from and where you\'re going.';

  @override
  String get sameStopError => 'Origin and destination are the same stop.';

  @override
  String get albusAlreadyThere => 'But… you\'re already there! 😅';

  @override
  String get albusSearchingRoute => 'Let me check which bus takes you there...';

  @override
  String get albusNoRoute =>
      'Well... I can\'t find a direct route. Maybe it\'s worth walking.';

  @override
  String get albusOneRoute =>
      'I\'ve got a route! I\'ll explain it step by step 👇';

  @override
  String albusMultipleRoutes(int count) {
    return 'I\'ve got $count options! The first one is the fastest.';
  }

  @override
  String searchError(String error) {
    return 'Something broke while searching ($error). Try again.';
  }

  @override
  String get albusCantCalculate =>
      'Oops, I couldn\'t calculate the route. Want to try again?';

  @override
  String get albusSwapped => 'Swapped! Want to look up this new route?';

  @override
  String get albusFindingYou => 'Let\'s see where you are...';

  @override
  String get enableLocationRetry =>
      'Turn on the phone\'s location and try again.';

  @override
  String get noLocationPermission =>
      'Without location permission I can\'t tell where you are.';

  @override
  String get noStopsNearYou => 'No stops near you — are you in Alzira?';

  @override
  String veryCloseToStop(String name) {
    return 'You\'re very close to $name. Where are we going?';
  }

  @override
  String nearestStopIs(String name, int dist) {
    return 'The nearest stop is $name ($dist m away). Where are we going?';
  }

  @override
  String get couldntFindYou => 'I couldn\'t tell where you are 😢';

  @override
  String okFromStop(String name) {
    return 'OK, you\'re leaving from $name. Where to?';
  }

  @override
  String askDestRoute(String name) {
    return 'Shall we look up how to get to $name?';
  }

  @override
  String okToStop(String name) {
    return 'OK, you\'re going to $name. Where from?';
  }

  @override
  String get readyToSearch => 'Ready. Tap \"Search route\" whenever you want.';

  @override
  String get searchingYourLocation => 'Searching for your location...';

  @override
  String get usingYourLocation => 'Using your current location';

  @override
  String get useMyLocationButton => 'Use my location as origin';

  @override
  String get fromNearestStop => 'From (nearest stop)';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get swap => 'Swap';

  @override
  String get searchRoute => 'Search route';

  @override
  String errorLoadingStops(String error) {
    return 'Error loading stops: $error';
  }

  @override
  String get searchStopByName => 'Search stop by name…';

  @override
  String linesWithList(String lines) {
    return 'Lines: $lines';
  }

  @override
  String get shareThisTripLive => 'Share this trip live';

  @override
  String get bestOption => 'BEST OPTION';

  @override
  String optionN(int n) {
    return 'OPTION $n';
  }

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
    );
    return '$_temp0';
  }

  @override
  String walkingStep(int dist, int duration) {
    return 'Walking · $dist m · $duration min';
  }

  @override
  String busStepDetail(int stops, int duration) {
    return '$stops stops · $duration min';
  }

  @override
  String boardAt(String name) {
    return 'Board at: $name';
  }

  @override
  String alightAt(String name) {
    return 'Get off at: $name';
  }

  @override
  String transferAt(String name) {
    return 'Transfer at $name';
  }

  @override
  String transferStep(String from, String to, int duration) {
    return 'From $from to $to · ~$duration min';
  }

  @override
  String get triviaTitle => 'Alzira Trivia';

  @override
  String questionXofY(int current, int total) {
    return 'Question $current/$total';
  }

  @override
  String get skipQuestionAd => 'Skip question (watch ad)';

  @override
  String get triviaCompleted => 'Trivia completed';

  @override
  String scoreLabel(int score) {
    return 'Score: $score';
  }

  @override
  String get newRecord => '🏆 New record!';

  @override
  String currentRecord(int score) {
    return 'Record: $score';
  }

  @override
  String coinsAddedWallet(int count) {
    return '+$count 🪙 to wallet';
  }

  @override
  String get playAgain => 'Play again';

  @override
  String get backToMenu => 'Back to menu';

  @override
  String get memoryStopsTitle => 'Stops Memory';

  @override
  String get catchTheBusTitle => 'Catch the Bus';

  @override
  String get gamesHubTitle => 'Mini-Games';

  @override
  String get playGame => 'Play';

  @override
  String highScore(int score) {
    return 'Record: $score';
  }

  @override
  String get memoryStopsHowTo => 'Memorise the order and replay it';

  @override
  String get catchTheBusHowTo => 'Tap the bus as it passes the stop';

  @override
  String get triviaHowTo => '10 questions about Alzira and the app';

  @override
  String get gameOver => 'Game over!';

  @override
  String get tapToStart => 'Tap to start';

  @override
  String reachedRound(int round) {
    return 'You reached round $round';
  }

  @override
  String currentRecordRounds(int score) {
    return 'Record: $score rounds';
  }

  @override
  String get repeatSequenceAd => 'Repeat sequence (watch ad)';

  @override
  String get watchAdForCoinsLabel => 'Watch ad +30 🪙';

  @override
  String get missedGreenBus => 'A green bus got away';

  @override
  String get reviveWatchAd => 'Revive by watching an ad';

  @override
  String get gamesHubHeading => 'Games · Kill time';

  @override
  String get wardrobeTooltip => 'Albus wardrobe';

  @override
  String get availableGames => 'Available';

  @override
  String get catchTheBusDesc =>
      'Tap green buses 🚌 before they escape. Dodge the red ones 🚒. How long can you last?';

  @override
  String currentRecordPrefix(int score) {
    return '🏆 Current record: $score';
  }

  @override
  String currentRecordPts(int score) {
    return '🏆 Current record: $score pts';
  }

  @override
  String get beTheFirstRecord => 'Be the first to set a record!';

  @override
  String get triviaDesc =>
      'Questions about the bus, the city and the region. 10 questions, 15s each.';

  @override
  String get howMuchYouKnow => 'How much do you know about Alzira?';

  @override
  String get memoryStopsDesc =>
      'Albus shows stops in order. You repeat them. Each round adds one more.';

  @override
  String bestRound(int round) {
    return '🏆 Best: round $round';
  }

  @override
  String get simonAlziraStyle => 'Simon Says, Alzira style';

  @override
  String get gamesLegalNotice =>
      'Games may show optional ads (revive, bonus). Coins are decorative — future versions will let you redeem them for content.';

  @override
  String get albusGamesIntro =>
      'Waiting for the bus? Let\'s play a game! Earn coins while you wait.';

  @override
  String get rechargeYourCardSoon => 'Top up your card soon!';

  @override
  String get playWhileWaiting => 'Play a quick game while you wait!';

  @override
  String get welcomeGreeting => 'Hi! 👋';

  @override
  String get welcomeMessage => 'Hope you find it really useful!';

  @override
  String get busInService => 'Bus in service';

  @override
  String get nextStop => 'Next stop';

  @override
  String get welcomeThanks => 'Thanks for downloading Alzi Trans.';

  @override
  String get welcomeStudent =>
      'I\'m a 2nd-year DAM student and I built this app independently to improve our public transport.';

  @override
  String get welcomeDevelopmentNotice =>
      'Keep in mind that this is a project under development and may contain bugs.';

  @override
  String get understoodCaps => 'GOT IT';

  @override
  String get estimatedTime => 'Estimated time';

  @override
  String get statusLabel => 'Status';

  @override
  String get atStop => '🛑 At stop';

  @override
  String get inMovement => '🚌 Moving';

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

  @override
  String get rankingTitle => 'Traveler Ranking';

  @override
  String get rankingSubtitle => 'Compete with other travelers from Alzira';

  @override
  String yourPosition(int pos, int trips) {
    return 'Your position: #$pos · $trips trips';
  }

  @override
  String get thisMonthToggle => 'This month';

  @override
  String get allTimeToggle => 'All time';

  @override
  String get rankingLoadError => 'Could not load ranking';

  @override
  String get noTripsRankingMonth =>
      'No one has traveled this month yet. Be the first!';

  @override
  String get noTripsRankingAll => 'No trips registered yet.';

  @override
  String get travelersRankingHeader => '🏆 Traveler Ranking';
}
