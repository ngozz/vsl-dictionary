import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
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

  /// "Xoá tất cả dữ liệu đã tải?" — the cleanup confirmation.
  static Future<bool> confirmDeleteAll(
      BuildContext context, DownloadService dl) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.deleteTitle),
            content: Text(l.deleteBody(
                dl.downloadedCount, _fmtBytes(dl.downloadedBytes))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// "Sẽ tải N video (~X MB)" — the big warning before download-all.
  static Future<bool> confirmBatch(
      BuildContext context, int fileCount, int bytes) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.batchTitle),
            content: Text(l.batchBody(fileCount, _fmtBytes(bytes))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.later),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.download),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Second gate when no Wi-Fi is visible: keep bytes flowing consciously.
  static Future<bool> confirmMobileData(
      BuildContext context, int bytes) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.noWifiTitle),
            content: Text(l.noWifiBody(_fmtBytes(bytes))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.continueLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// The dismissible startup prompt: changed-file counts, [Cập nhật] applies.
  static Future<void> showUpdatePrompt(
      BuildContext context, int changedCount, int bytes) async {
    final l = context.l10n;
    // Resolve the messenger before the dialog closes: looking it up from the
    // dialog's own (then deactivated) context is unsafe.
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.new_releases_outlined),
        title: Text(l.updateTitle),
        content: Text(
            l.updateBody(changedCount, _fmtBytes(bytes)),
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () {
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
            },
            child: Text(l.later),
          ),
          FilledButton(
            onPressed: () {
              final n = App.downloads
                  .enqueueAll(App.updates.changedEntriesFor(App.downloads));
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
              messenger.showSnackBar(
                  SnackBar(content: Text(l.updateStarted(n))));
            },
            child: Text(l.update),
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
