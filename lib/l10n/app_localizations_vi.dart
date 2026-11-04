// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Từ điển Ký hiệu';

  @override
  String get appWindowTitle => 'Từ điển Ký hiệu Việt Nam';

  @override
  String get favoritesShow => 'Xem yêu thích';

  @override
  String get favoritesHide => 'Xem tất cả';

  @override
  String get settingsTooltip => 'Cài đặt';

  @override
  String get searchHint => 'Tìm từ…';

  @override
  String searchNoResults(String query) {
    return 'Không tìm thấy “$query”';
  }

  @override
  String get favoritesEmpty => 'Chưa có từ nào được yêu thích';

  @override
  String loadError(String error) {
    return 'Lỗi tải dữ liệu:\n$error';
  }

  @override
  String get cdnUnavailable =>
      'CDN không khả dụng — tải/phát trực tuyến bị tắt.';

  @override
  String get tabAll => 'Tất cả';

  @override
  String get tabWords => 'Từ vựng';

  @override
  String get tabNumbers => 'Số đếm';

  @override
  String get tabAlphabet => 'Bảng chữ cái';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsRegion => 'Vùng ký hiệu mặc định';

  @override
  String get regionNorth => 'Bắc';

  @override
  String get regionCentral => 'Trung';

  @override
  String get regionSouth => 'Nam';

  @override
  String get settingsTheme => 'Giao diện';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeBlack => 'Đen';

  @override
  String get themeLight => 'Sáng';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsDownloads => 'Tải xuống & cập nhật';

  @override
  String downloadedSummary(int done, int total, String size) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Đã tải: $doneString/$totalString video ($size)';
  }

  @override
  String get checkUpdates => 'Kiểm tra cập nhật khi mở ứng dụng';

  @override
  String get checkUpdatesOff =>
      'Tắt = app hoàn toàn ngoại tuyến sau khi đã tải';

  @override
  String get downloadAll => 'Tải toàn bộ từ điển';

  @override
  String get checkNow => 'Kiểm tra cập nhật';

  @override
  String get deleteDownloaded => 'Xoá dữ liệu đã tải';

  @override
  String get replayIntro => 'Xem lại hướng dẫn';

  @override
  String wordCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Số từ: $countString';
  }

  @override
  String get dataCredit => 'Dữ liệu từ dự án “NgonTay”.';

  @override
  String get allDownloaded => 'Toàn bộ nội dung đã được tải về máy.';

  @override
  String get downloadOnWifi => 'Sẽ tải khi có Wi-Fi (mở lại màn hình này).';

  @override
  String downloadStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Đã bắt đầu tải $countString video…';
  }

  @override
  String deletedVideos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Đã xoá $countString video.';
  }

  @override
  String updateCheckFailed(String error) {
    return 'Không thể kiểm tra: $error';
  }

  @override
  String get upToDate => 'Nội dung đã là bản mới nhất.';

  @override
  String bannerDeleting(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Đang xoá $doneString/$totalString video…';
  }

  @override
  String get bannerCanceling => 'Đang huỷ tải…';

  @override
  String bannerDownloading(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Đang tải $doneString/$totalString video…';
  }

  @override
  String get cancel => 'Huỷ';

  @override
  String get deleteTitle => 'Xoá dữ liệu đã tải';

  @override
  String deleteBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Xoá $countString video đã tải (~$size)? Video sẽ phát trực tuyến từ CDN.';
  }

  @override
  String get delete => 'Xoá';

  @override
  String get batchTitle => 'Tải xuống nội dung';

  @override
  String batchBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Sẽ tải $countString video (~$size).\nNên dùng Wi-Fi. Tiếp tục?';
  }

  @override
  String get later => 'Để sau';

  @override
  String get download => 'Tải';

  @override
  String get noWifiTitle => 'Không thấy Wi-Fi';

  @override
  String noWifiBody(String size) {
    return 'Thiết bị đang dùng dữ liệu di động. Tiếp tục tải (~$size)?';
  }

  @override
  String get continueLabel => 'Tiếp tục';

  @override
  String get updateTitle => 'Có bản cập nhật nội dung';

  @override
  String updateBody(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString video có bản mới (~$size). Cập nhật để dùng bản mới nhất.';
  }

  @override
  String get update => 'Cập nhật';

  @override
  String updateStarted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Đang tải lại $countString video cập nhật…';
  }

  @override
  String get meaning => 'Nghĩa';

  @override
  String get replay => 'Phát lại';

  @override
  String get pause => 'Tạm dừng';

  @override
  String get play => 'Phát';

  @override
  String get exitFullscreen => 'Thu nhỏ';

  @override
  String get fullscreen => 'Toàn màn hình';

  @override
  String get slowMotion => 'Phát chậm';

  @override
  String get variantMain => 'Chính';

  @override
  String get variantNorth => 'Miền Bắc';

  @override
  String get variantCentral => 'Miền Trung';

  @override
  String get variantSouth => 'Miền Nam';

  @override
  String get onboardingSkip => 'Bỏ qua';

  @override
  String get onboardingNext => 'Tiếp tục';

  @override
  String get onboardingStart => 'Bắt đầu';

  @override
  String get languageTitle => 'Chọn ngôn ngữ';

  @override
  String get languageSubtitle =>
      'Bạn có thể đổi lại bất cứ lúc nào trong Cài đặt.';

  @override
  String get introWelcomeTitle => 'Chào mừng đến với VSL Dictionary';

  @override
  String get introWelcomeBody =>
      'Từ điển Ký hiệu Việt Nam — tra cứu nhanh hơn 4.300 từ ký hiệu, phân theo vùng miền (Bắc / Trung / Nam).';

  @override
  String get introOfflineTitle => 'Dùng offline hoàn toàn';

  @override
  String get introOfflineBody =>
      'Vào Cài đặt → “Tải toàn bộ từ điển” (~513 MB) để tải mọi video về máy. Sau đó tắt “Kiểm tra cập nhật khi mở ứng dụng” — khi đó app không cần mạng nữa.';

  @override
  String get introSourceTitle => 'Nguồn dữ liệu';

  @override
  String get introSourceBody =>
      'Dữ liệu từ dự án “NgonTay” — bản số hóa của Từ điển Ký hiệu Việt Nam (qipedc.moet.gov.vn, Trung tâm Ký hiệu Việt Nam / Bộ Giáo dục và Đào tạo). Ứng dụng dùng làm cá nhân, không phải tác phẩm gốc. Chúc học tốt!';

  @override
  String get notifRunningTitle => 'Đang tải trong nền';

  @override
  String notifRunningBody(int total, String size) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString video (~$size)';
  }

  @override
  String get notifCompleteTitle => 'Hoàn tất tải';

  @override
  String notifCompleteBody(String token) {
    return 'Đã tải xong $token video';
  }

  @override
  String get notifErrorTitle => 'Lỗi tải từ điển';

  @override
  String notifErrorBody(String token) {
    return '$token lỗi';
  }
}
