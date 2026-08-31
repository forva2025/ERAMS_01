import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web implementation: builds an in-memory Blob and triggers a browser
/// download via a throwaway anchor click — the standard Flutter-web
/// file-download idiom, since there is no filesystem to write to directly.
void downloadBytes({
  required List<int> bytes,
  required String filename,
  String mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
}) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
