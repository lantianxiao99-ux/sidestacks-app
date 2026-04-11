import 'package:flutter/services.dart';

/// Fallback for non-web platforms: copies CSV to clipboard.
Future<void> downloadCsv(String content, String filename) async {
  await Clipboard.setData(ClipboardData(text: content));
}
