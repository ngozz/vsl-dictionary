// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VSL Dictionary';

  @override
  String get appWindowTitle => 'Vietnamese Sign Language Dictionary';

  @override
  String get favoritesShow => 'Show favorites';

  @override
  String get favoritesHide => 'Show all';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get searchHint => 'Search words…';

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”';
  }

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String loadError(String error) {
    return 'Could not load data:\n$error';
  }

  @override
  String get cdnUnavailable =>
      'CDN unavailable — downloads and streaming are disabled.';

  @override
  String get tabAll => 'All';

  @override
  String get tabWords => 'Words';

  @override
  String get tabNumbers => 'Numbers';

  @override
  String get tabAlphabet => 'Alphabet';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsRegion => 'Default sign region';

  @override
  String get regionNorth => 'North';

  @override
  String get regionCentral => 'Central';

  @override
  String get regionSouth => 'South';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeBlack => 'Black';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsDownloads => 'Downloads & updates';

  @override
  String downloadedSummary(int done, int total, String size) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Downloaded: $doneString/$totalString videos ($size)';
  }

  @override
  String get checkUpdates => 'Check for updates on launch';

  @override
  String get checkUpdatesOff => 'Off = fully offline once downloaded';

  @override
  String get downloadAll => 'Download the whole dictionary';

  @override
  String get checkNow => 'Check for updates';

  @override
  String get deleteDownloaded => 'Delete downloaded data';

  @override
  String get replayIntro => 'View the guide again';

  @override
  String wordCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Words: $countString';
  }

  @override
  String get dataCredit => 'Data from the “NgonTay” project.';

  @override
  String get allDownloaded => 'Everything is already downloaded.';

  @override
  String get downloadOnWifi => 'Will download on Wi-Fi (reopen this screen).';

  @override
  String downloadStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Started downloading $countString videos…';
  }

  @override
  String deletedVideos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Deleted $countString videos.';
  }

  @override
  String updateCheckFailed(String error) {
    return 'Could not check: $error';
  }

  @override
  String get upToDate => 'Content is up to date.';

  @override
  String bannerDeleting(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Deleting $doneString/$totalString videos…';
  }

  @override
  String get bannerCanceling => 'Cancelling…';

  @override
  String bannerDownloading(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Downloading $doneString/$totalString videos…';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteTitle => 'Delete downloaded data';

  @override
  String deleteBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Delete $countString downloaded videos (~$size)? Videos will stream from the CDN.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get batchTitle => 'Download content';

  @override
  String batchBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Will download $countString videos (~$size).\nWi-Fi recommended. Continue?';
  }

  @override
  String get later => 'Later';

  @override
  String get download => 'Download';

  @override
  String get noWifiTitle => 'No Wi-Fi detected';

  @override
  String noWifiBody(String size) {
    return 'This device is on mobile data. Continue downloading (~$size)?';
  }

  @override
  String get continueLabel => 'Continue';

  @override
  String get updateTitle => 'Content update available';

  @override
  String updateBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString videos have new versions (~$size). Update to get the latest.';
  }

  @override
  String get update => 'Update';

  @override
  String updateStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Re-downloading $countString updated videos…';
  }

  @override
  String get meaning => 'Meaning (Vietnamese)';

  @override
  String get replay => 'Replay';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get slowMotion => 'Slow motion';

  @override
  String get variantMain => 'Main';

  @override
  String get variantNorth => 'Northern';

  @override
  String get variantCentral => 'Central';

  @override
  String get variantSouth => 'Southern';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Continue';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get languageTitle => 'Choose your language';

  @override
  String get languageSubtitle => 'You can change this any time in Settings.';

  @override
  String get introWelcomeTitle => 'Welcome to VSL Dictionary';

  @override
  String get introWelcomeBody =>
      'The Vietnamese Sign Language dictionary — look up over 4,300 signs, grouped by region (North / Central / South).';

  @override
  String get introOfflineTitle => 'Fully offline';

  @override
  String get introOfflineBody =>
      'Open Settings → “Download the whole dictionary” (~513 MB) to save every video. Then turn off “Check for updates on launch” — the app needs no network after that.';

  @override
  String get introSourceTitle => 'Data source';

  @override
  String get introSourceBody =>
      'Data from the “NgonTay” project — a digitisation of the Vietnamese Sign Language Dictionary (qipedc.moet.gov.vn, Vietnam Sign Language Centre / Ministry of Education and Training). This is a personal-use app, not the original work. Happy learning!';

  @override
  String get notifRunningTitle => 'Downloading in background';

  @override
  String notifRunningBody(int total, String size) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString videos (~$size)';
  }

  @override
  String get notifCompleteTitle => 'Download complete';

  @override
  String notifCompleteBody(String token) {
    return '$token videos downloaded';
  }

  @override
  String get notifErrorTitle => 'Dictionary download failed';

  @override
  String notifErrorBody(String token) {
    return '$token failed';
  }
}
