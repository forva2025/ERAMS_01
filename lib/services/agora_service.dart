// Conditional export: web → stub (no-op), native → full Agora implementation.
// dart.library.io is present on Android/iOS/desktop but absent on Flutter web.
export 'agora_service_stub.dart'
    if (dart.library.io) 'agora_service_native.dart';
