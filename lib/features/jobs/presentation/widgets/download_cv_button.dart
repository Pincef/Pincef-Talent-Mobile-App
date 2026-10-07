import 'package:flutter/material.dart';
import 'package:talentbridge/core/utils/cv_download.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';

/// Labeled ("Download CV") or compact (icon-only, for the résumé card)
/// variant of the same in-app download flow — shows real progress instead
/// of just opening the file in another tab/app.
class DownloadCvButton extends StatefulWidget {
  const DownloadCvButton({
    super.key,
    required this.url,
    required this.fileName,
    this.compact = false,
  });

  /// Null when the candidate has no résumé on file — tapping shows a
  /// message instead of attempting a download.
  final String? url;
  final String fileName;
  final bool compact;

  @override
  State<DownloadCvButton> createState() => _DownloadCvButtonState();
}

class _DownloadCvButtonState extends State<DownloadCvButton> {
  bool _isDownloading = false;
  double _progress = 0;

  Future<void> _download() async {
    if (widget.url == null) {
      AppToast.error(context, 'No résumé is on file for this candidate.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });
    try {
      await downloadCvFile(
        url: widget.url!,
        fileName: widget.fileName,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        AppToast.success(context, 'Résumé downloaded.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, "Couldn't download résumé: $e");
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressIndicator = SizedBox(
      width: widget.compact ? 17 : 14,
      height: widget.compact ? 17 : 14,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        value: _progress > 0 ? _progress : null,
        color: widget.compact ? BrandColors.navy : null,
      ),
    );

    if (widget.compact) {
      return _isDownloading
          ? Padding(padding: const EdgeInsets.all(2), child: progressIndicator)
          : IconButton(
              onPressed: _download,
              icon: const Icon(Icons.download_outlined,
                  size: 17, color: BrandColors.navy),
            );
    }

    return OutlinedButton.icon(
      onPressed: _isDownloading ? null : _download,
      icon: _isDownloading
          ? progressIndicator
          : const Icon(Icons.download_outlined, size: 16),
      label: Text(_isDownloading ? 'Downloading...' : 'Download CV'),
    );
  }
}
