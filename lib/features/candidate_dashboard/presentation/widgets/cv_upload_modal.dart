import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/utils/breakpoints.dart';
import '../../application/candidate_dashboard_provider.dart';

const _maxCvBytes = 5 * 1024 * 1024;
const _maxCoverLetterChars = 2000;

/// Below this width the footer buttons stack instead of sitting side by side.
/// This is a dialog-local threshold, independent of [kMobileBreakpoint]
/// (which governs app-wide sidebar vs. bottom-nav layout).
const double _stackedButtonsBreakpoint = 360;

/// Shared candidate uploader for dashboard controls and the shell action.
void showCandidateCvUploadModal(
  BuildContext context,
  WidgetRef ref, {
  String? jobTitle,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _CvUploadModal(jobTitle: jobTitle),
  );
}

class _CvUploadModal extends ConsumerStatefulWidget {
  const _CvUploadModal({this.jobTitle});

  final String? jobTitle;

  @override
  ConsumerState<_CvUploadModal> createState() => _CvUploadModalState();
}

class _CvUploadModalState extends ConsumerState<_CvUploadModal> {
  PlatformFile? _file;
  String? _error;
  final _coverLetterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _coverLetterController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.single;
    if (picked.bytes == null) {
      setState(() =>
          _error = 'The selected file could not be read. Please try again.');
    } else if (picked.size > _maxCvBytes) {
      setState(() => _error = 'Your CV must be 5 MB or smaller.');
    } else {
      setState(() {
        _file = picked;
        _error = null;
      });
    }
  }

  Future<void> _continue() async {
    final file = _file;
    if (file == null) {
      setState(() => _error = 'Choose a CV before continuing.');
      return;
    }
    try {
      // TODO: pass _coverLetterController.text along once the provider
      // supports storing it with the application.
      await ref.read(dashboardProvider.notifier).uploadCv(file);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Upload failed. Check the endpoint and try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading =
        ref.watch(dashboardProvider.select((state) => state.isUploading));

    final desktop = isDesktop(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final stackButtons = screenWidth < _stackedButtonsBreakpoint;
    final viewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    final charCount = _coverLetterController.text.length;

    final horizontalPadding = desktop ? 28.0 : 20.0;
    final verticalPadding = desktop ? 28.0 : 20.0;

    return Dialog(
      insetPadding: EdgeInsets.all(desktop ? 40 : 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: desktop ? 560 : 480,
          // Never exceed the viewport minus the keyboard, so the dialog
          // scrolls internally instead of overflowing off-screen.
          maxHeight: MediaQuery.sizeOf(context).height - viewInsetBottom - 40,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: verticalPadding,
            // Extra bottom padding when the keyboard is open so the
            // Continue button isn't flush against it.
            bottom: verticalPadding + viewInsetBottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Upload Documents',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: BrandColors.navy,
                            ),
                          ),
                          if (widget.jobTitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.jobTitle!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: BrandColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: isUploading
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Resume / CV label
                const Text(
                  'Resume / CV *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy,
                  ),
                ),
                const SizedBox(height: 8),

                // Drop zone
                InkWell(
                  onTap: isUploading ? null : _pickFile,
                  borderRadius: BorderRadius.circular(10),
                  child: DottedBorderBox(
                    isSelected: _file != null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: desktop ? 32 : 24,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _file == null
                                ? Icons.cloud_upload_outlined
                                : Icons.description_outlined,
                            color: _file == null
                                ? BrandColors.muted
                                : BrandColors.orange,
                            size: 32,
                          ),
                          const SizedBox(height: 14),
                          if (_file == null) ...[
                            const Text(
                              'Drag and drop your Resume/CV here',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: BrandColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                    fontSize: 13, color: BrandColors.muted),
                                children: [
                                  TextSpan(text: 'or '),
                                  TextSpan(
                                    text: 'browse files',
                                    style: TextStyle(
                                      color: BrandColors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Text(
                              _file!.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: BrandColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_file!.size / 1024).ceil()} KB selected · Tap to replace',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: BrandColors.muted),
                            ),
                          ],
                          const SizedBox(height: 8),
                          const Text(
                            'Supported formats: PDF, DOCX, DOC. Max size: 5MB.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11, color: BrandColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),

                // Cover letter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cover Letter (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy,
                      ),
                    ),
                    Text(
                      '$charCount / $_maxCoverLetterChars chars',
                      style: const TextStyle(
                          fontSize: 11, color: BrandColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _coverLetterController,
                  maxLength: _maxCoverLetterChars,
                  maxLines: 5,
                  enabled: !isUploading,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  decoration: InputDecoration(
                    hintText:
                        'Paste your cover letter here or write a brief introduction...',
                    hintStyle:
                        const TextStyle(color: BrandColors.muted, fontSize: 13),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: BrandColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: BrandColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: BrandColors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: BrandColors.border),
                const SizedBox(height: 20),

                // Footer actions
                _FooterActions(
                  stacked: stackButtons,
                  isUploading: isUploading,
                  onBack: () => Navigator.of(context).pop(),
                  onContinue: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.stacked,
    required this.isUploading,
    required this.onBack,
    required this.onContinue,
  });

  final bool stacked;
  final bool isUploading;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final backButton = OutlinedButton.icon(
      onPressed: isUploading ? null : onBack,
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandColors.orange,
        side: const BorderSide(color: BrandColors.orange),
      ),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('Back'),
    );

    final continueButton = FilledButton.icon(
      onPressed: isUploading ? null : onContinue,
      style: FilledButton.styleFrom(backgroundColor: BrandColors.orange),
      icon: isUploading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.arrow_forward, size: 16),
      label: Text(isUploading ? 'Uploading...' : 'Continue to Review'),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          continueButton,
          const SizedBox(height: 12),
          backButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: backButton),
        const SizedBox(width: 12),
        Expanded(child: continueButton),
      ],
    );
  }
}

/// Simple dashed-border container to match the drag-and-drop zone styling.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox(
      {super.key, required this.child, this.isSelected = false});

  final Widget child;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: isSelected ? BrandColors.orange : BrandColors.border,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;
  static const _dashWidth = 6.0;
  static const _dashSpace = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
