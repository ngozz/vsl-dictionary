import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

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
    Locale('en'),
    Locale('vi'),
  ];

  /// App bar title on the home screen.
  ///
  /// In vi, this message translates to:
  /// **'Từ điển Ký hiệu'**
  String get appTitle;

  /// Window / browser tab title.
  ///
  /// In vi, this message translates to:
  /// **'Từ điển Ký hiệu Việt Nam'**
  String get appWindowTitle;

  /// App bar button tooltip: switch the list to favorites only.
  ///
  /// In vi, this message translates to:
  /// **'Xem yêu thích'**
  String get favoritesShow;

  /// App bar button tooltip: leave the favorites-only list.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get favoritesHide;

  /// No description provided for @settingsTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTooltip;

  /// Search field placeholder.
  ///
  /// In vi, this message translates to:
  /// **'Tìm từ…'**
  String get searchHint;

  /// Shown when a search returns nothing.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy “{query}”'**
  String searchNoResults(String query);

  /// Empty state of the favorites list.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có từ nào được yêu thích'**
  String get favoritesEmpty;

  /// Fatal error while loading the bundled dictionary.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi tải dữ liệu:\n{error}'**
  String loadError(String error);

  /// Snackbar when the downloader could not start and CDN mode is on.
  ///
  /// In vi, this message translates to:
  /// **'CDN không khả dụng — tải/phát trực tuyến bị tắt.'**
  String get cdnUnavailable;

  /// No description provided for @tabAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get tabAll;

  /// No description provided for @tabWords.
  ///
  /// In vi, this message translates to:
  /// **'Từ vựng'**
  String get tabWords;

  /// No description provided for @tabNumbers.
  ///
  /// In vi, this message translates to:
  /// **'Số đếm'**
  String get tabNumbers;

  /// No description provided for @tabAlphabet.
  ///
  /// In vi, this message translates to:
  /// **'Bảng chữ cái'**
  String get tabAlphabet;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTitle;

  /// Settings heading for the default sign region.
  ///
  /// In vi, this message translates to:
  /// **'Vùng ký hiệu mặc định'**
  String get settingsRegion;

  /// No description provided for @regionNorth.
  ///
  /// In vi, this message translates to:
  /// **'Bắc'**
  String get regionNorth;

  /// No description provided for @regionCentral.
  ///
  /// In vi, this message translates to:
  /// **'Trung'**
  String get regionCentral;

  /// No description provided for @regionSouth.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get regionSouth;

  /// Settings heading for the colour theme.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsTheme;

  /// No description provided for @themeDark.
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get themeDark;

  /// No description provided for @themeBlack.
  ///
  /// In vi, this message translates to:
  /// **'Đen'**
  String get themeBlack;

  /// No description provided for @themeLight.
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get themeLight;

  /// Settings heading for the interface language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get settingsLanguage;

  /// Language name — never translated.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnamese;

  /// Language name — never translated.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageMixed.
  ///
  /// In vi, this message translates to:
  /// **'Kết hợp'**
  String get languageMixed;

  /// Settings heading for downloading / updating content.
  ///
  /// In vi, this message translates to:
  /// **'Tải xuống & cập nhật'**
  String get settingsDownloads;

  /// How many videos are stored locally and their total size.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải: {done}/{total} video ({size})'**
  String downloadedSummary(int done, int total, String size);

  /// No description provided for @checkUpdates.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra cập nhật khi mở ứng dụng'**
  String get checkUpdates;

  /// No description provided for @checkUpdatesOff.
  ///
  /// In vi, this message translates to:
  /// **'Tắt = app hoàn toàn ngoại tuyến sau khi đã tải'**
  String get checkUpdatesOff;

  /// No description provided for @downloadAll.
  ///
  /// In vi, this message translates to:
  /// **'Tải toàn bộ từ điển'**
  String get downloadAll;

  /// No description provided for @checkNow.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra cập nhật'**
  String get checkNow;

  /// No description provided for @deleteDownloaded.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dữ liệu đã tải'**
  String get deleteDownloaded;

  /// No description provided for @replayIntro.
  ///
  /// In vi, this message translates to:
  /// **'Xem lại hướng dẫn'**
  String get replayIntro;

  /// Footer line with the number of dictionary entries.
  ///
  /// In vi, this message translates to:
  /// **'Số từ: {count}'**
  String wordCount(int count);

  /// Footer line crediting the source data.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu từ dự án “NgonTay”.'**
  String get dataCredit;

  /// No description provided for @allDownloaded.
  ///
  /// In vi, this message translates to:
  /// **'Toàn bộ nội dung đã được tải về máy.'**
  String get allDownloaded;

  /// No description provided for @downloadOnWifi.
  ///
  /// In vi, this message translates to:
  /// **'Sẽ tải khi có Wi-Fi (mở lại màn hình này).'**
  String get downloadOnWifi;

  /// No description provided for @downloadStarted.
  ///
  /// In vi, this message translates to:
  /// **'Đã bắt đầu tải {count} video…'**
  String downloadStarted(int count);

  /// No description provided for @deletedVideos.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá {count} video.'**
  String deletedVideos(int count);

  /// No description provided for @updateCheckFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kiểm tra: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @upToDate.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung đã là bản mới nhất.'**
  String get upToDate;

  /// No description provided for @bannerDeleting.
  ///
  /// In vi, this message translates to:
  /// **'Đang xoá {done}/{total} video…'**
  String bannerDeleting(int done, int total);

  /// No description provided for @bannerCanceling.
  ///
  /// In vi, this message translates to:
  /// **'Đang huỷ tải…'**
  String get bannerCanceling;

  /// No description provided for @bannerDownloading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải {done}/{total} video…'**
  String bannerDownloading(int done, int total);

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get cancel;

  /// No description provided for @deleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dữ liệu đã tải'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Xoá {count} video đã tải (~{size})? Video sẽ phát trực tuyến từ CDN.'**
  String deleteBody(int count, String size);

  /// No description provided for @delete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get delete;

  /// No description provided for @batchTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tải xuống nội dung'**
  String get batchTitle;

  /// No description provided for @batchBody.
  ///
  /// In vi, this message translates to:
  /// **'Sẽ tải {count} video (~{size}).\nNên dùng Wi-Fi. Tiếp tục?'**
  String batchBody(int count, String size);

  /// No description provided for @later.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get later;

  /// No description provided for @download.
  ///
  /// In vi, this message translates to:
  /// **'Tải'**
  String get download;

  /// No description provided for @noWifiTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không thấy Wi-Fi'**
  String get noWifiTitle;

  /// No description provided for @noWifiBody.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị đang dùng dữ liệu di động. Tiếp tục tải (~{size})?'**
  String noWifiBody(String size);

  /// No description provided for @continueLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get continueLabel;

  /// No description provided for @updateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Có bản cập nhật nội dung'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In vi, this message translates to:
  /// **'{count} video có bản mới (~{size}). Cập nhật để dùng bản mới nhất.'**
  String updateBody(int count, String size);

  /// No description provided for @update.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get update;

  /// No description provided for @updateStarted.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải lại {count} video cập nhật…'**
  String updateStarted(int count);

  /// Label above the definition in the word detail sheet.
  ///
  /// In vi, this message translates to:
  /// **'Nghĩa'**
  String get meaning;

  /// No description provided for @replay.
  ///
  /// In vi, this message translates to:
  /// **'Phát lại'**
  String get replay;

  /// No description provided for @pause.
  ///
  /// In vi, this message translates to:
  /// **'Tạm dừng'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In vi, this message translates to:
  /// **'Phát'**
  String get play;

  /// No description provided for @exitFullscreen.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhỏ'**
  String get exitFullscreen;

  /// No description provided for @fullscreen.
  ///
  /// In vi, this message translates to:
  /// **'Toàn màn hình'**
  String get fullscreen;

  /// No description provided for @slowMotion.
  ///
  /// In vi, this message translates to:
  /// **'Phát chậm'**
  String get slowMotion;

  /// No description provided for @variantMain.
  ///
  /// In vi, this message translates to:
  /// **'Chính'**
  String get variantMain;

  /// No description provided for @variantNorth.
  ///
  /// In vi, this message translates to:
  /// **'Miền Bắc'**
  String get variantNorth;

  /// No description provided for @variantCentral.
  ///
  /// In vi, this message translates to:
  /// **'Miền Trung'**
  String get variantCentral;

  /// No description provided for @variantSouth.
  ///
  /// In vi, this message translates to:
  /// **'Miền Nam'**
  String get variantSouth;

  /// No description provided for @onboardingSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get onboardingStart;

  /// First onboarding step: interface language.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể đổi lại bất cứ lúc nào trong Cài đặt.'**
  String get languageSubtitle;

  /// No description provided for @introWelcomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng đến với VSL Dictionary'**
  String get introWelcomeTitle;

  /// No description provided for @introWelcomeBody.
  ///
  /// In vi, this message translates to:
  /// **'Từ điển Ký hiệu Việt Nam — tra cứu nhanh hơn 4.300 từ ký hiệu, phân theo vùng miền (Bắc / Trung / Nam).'**
  String get introWelcomeBody;

  /// No description provided for @introOfflineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dùng offline hoàn toàn'**
  String get introOfflineTitle;

  /// No description provided for @introOfflineBody.
  ///
  /// In vi, this message translates to:
  /// **'Vào Cài đặt → “Tải toàn bộ từ điển” (~513 MB) để tải mọi video về máy. Sau đó tắt “Kiểm tra cập nhật khi mở ứng dụng” — khi đó app không cần mạng nữa.'**
  String get introOfflineBody;

  /// No description provided for @introSourceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nguồn dữ liệu'**
  String get introSourceTitle;

  /// No description provided for @introSourceBody.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu từ dự án “NgonTay” — bản số hóa của Từ điển Ký hiệu Việt Nam (qipedc.moet.gov.vn, Trung tâm Ký hiệu Việt Nam / Bộ Giáo dục và Đào tạo). Ứng dụng dùng làm cá nhân, không phải tác phẩm gốc. Chúc học tốt!'**
  String get introSourceBody;

  /// Android download notification title while a batch runs.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải trong nền'**
  String get notifRunningTitle;

  /// Android download notification body; total is the batch size.
  ///
  /// In vi, this message translates to:
  /// **'{total} video (~{size})'**
  String notifRunningBody(int total, String size);

  /// No description provided for @notifCompleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất tải'**
  String get notifCompleteTitle;

  /// Android notification body at 100%.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải xong {token} video'**
  String notifCompleteBody(String token);

  /// No description provided for @notifErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi tải từ điển'**
  String get notifErrorTitle;

  /// Android notification body when downloads failed.
  ///
  /// In vi, this message translates to:
  /// **'{token} lỗi'**
  String notifErrorBody(String token);
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
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
