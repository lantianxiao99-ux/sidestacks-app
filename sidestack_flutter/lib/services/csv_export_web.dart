// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation: triggers a browser file download.
Future<void> downloadCsv(String content, String filename) async {
  final bytes = content.codeUnits;
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
