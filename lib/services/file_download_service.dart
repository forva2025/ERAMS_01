// Conditional export: web → real browser download, native → unsupported.
// The admin dashboard (the only caller of this service) is a web-only
// surface in practice — driver/patient are the Android targets — so the
// native branch just documents that rather than implementing a real save.
export 'file_download_io.dart'
    if (dart.library.html) 'file_download_web.dart';
