/// Native (Android/iOS/desktop) stub. File export is only exposed from the
/// admin dashboard, which does not run on the Android build targets in this
/// project (driver + patient only) — see `file_download_service.dart`.
void downloadBytes({
  required List<int> bytes,
  required String filename,
  String mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
}) {
  throw UnsupportedError(
      'File export is only available on the web build of the admin dashboard.');
}
