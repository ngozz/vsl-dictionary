import 'package:flutter/material.dart';

import '../main.dart';
import '../services/download_service.dart';

/// Shared confirmations for the download & update UX:
/// large-batch warning → Wi-Fi check → explicit mobile-data confirmation.
abstract final class DownloadDialogs {
  /// Wi-Fi fast-path; on mobile data shows the warning once per app session
  /// (the flag lives on [DownloadService] and resets on app start).
  static Future<bool> ensureNetworkOk(
      BuildContext context, DownloadService dl, int bytes) async {
    if (await dl.onWifi()) return true;
    if (dl.mobileDataConfirmedThisSession) return true;
    if (!context.mounted) return false;
    if (!(await confirmMobileData(context, bytes))) return false;
    dl.mobileDataConfirmedThisSession = true;
    return true;
  }

  /// "Sẽ tải N video (~X MB)" — the big warning before download-all.
  static Future<bool> confirmBatch(
      BuildContext context, int fileCount, int bytes) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tải xuống nội dung'),
            content: Text(
                'Sẽ tải $fileCount video (~${_fmtBytes(bytes)}).\n'
                'Nên dùng Wi-Fi. Tiếp tục?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tải'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Second gate when no Wi-Fi is visible: keep bytes flowing consciously.
  static Future<bool> confirmMobileData(
      BuildContext context, int bytes) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Không thấy Wi-Fi'),
            content: Text(
                'Thiết bị đang dùng dữ liệu di động. '
                'Tiếp tục tải (~${_fmtBytes(bytes)})?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// The dismissible startup prompt: changed-file counts, [Cập nhật] applies.
  static Future<void> showUpdatePrompt(
      BuildContext context, int changedCount, int bytes) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.new_releases_outlined),
        title: const Text('Có bản cập nhật nội dung'),
        content: Text(
            '$changedCount video có bản mới (~${_fmtBytes(bytes)}). '
            'Cập nhật để dùng bản mới nhất.',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () {
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
            },
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () {
              final n = App.downloads
                  .enqueueAll(App.updates.changedEntriesFor(App.downloads));
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đang tải lại $n video cập nhật…')));
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  static String _fmtBytes(int b) {
    if (b <= 0) return '0 B';
    final mb = b / 1048576;
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.round()} MB';
  }
}
