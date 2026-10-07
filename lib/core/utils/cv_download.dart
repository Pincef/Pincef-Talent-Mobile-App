import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';

/// Downloads a file's bytes and hands them to the OS/browser's native save
/// flow via `file_saver` — covers web (browser downloads directly, no new
/// tab), Android/iOS (save/share sheet), and desktop uniformly, rather
/// than separate dart:html vs path_provider code paths per platform.
///
/// Requires `file_saver` in pubspec.yaml (flutter pub add file_saver).
/// NOTE: file_saver's exact save call differs across major versions —
/// this targets the v2/v3-style `saveFile` API; check yours if it
/// doesn't match.
Future<void> downloadCvFile({
  required String url,
  required String fileName,
  void Function(double progress)? onProgress,
}) async {
  // Plain Dio, not the app's authenticated instance — these are public
  // Cloudinary asset URLs, not authenticated backend endpoints, and
  // shouldn't carry the app's auth header.
  final response = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
    onReceiveProgress: (received, total) {
      if (total > 0 && onProgress != null) onProgress(received / total);
    },
  );

  final bytes = Uint8List.fromList(response.data!);
  final safeFileName =
      fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';

  await FileSaver.instance.saveFile(
    name: safeFileName,
    bytes: bytes,
    mimeType: MimeType.pdf,
  );
}
