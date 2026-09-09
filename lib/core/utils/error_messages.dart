/// Turns a raw Dart/Supabase exception into a short, non-technical message
/// safe to show directly to an end user (dispatcher, driver, hospital staff,
/// patient — none of whom should ever see `ClientException with
/// SocketException: Failed host lookup: ...` on screen).
///
/// This is a best-effort classification based on the exception's string
/// form (Supabase/Dart don't give us a stable error-code type across every
/// failure path here), so it errs toward the two buckets that actually
/// change what the user should do: "check your connection" vs. "something
/// went wrong, try again."
String friendlyErrorMessage(Object error) {
  final s = error.toString();

  final looksOffline = s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('ClientException') ||
      s.contains('TimeoutException') ||
      s.contains('HandshakeException') ||
      s.contains('Connection failed') ||
      s.contains('Connection reset') ||
      s.contains('Network is unreachable');
  if (looksOffline) {
    return "Can't reach the ERAMS server. Check your internet connection "
        'and try again.';
  }

  final looksAuth = s.contains('row-level security') ||
      s.contains('permission denied') ||
      s.contains('JWT') ||
      s.contains('PGRST301') ||
      s.contains('401');
  if (looksAuth) {
    return "You don't have permission to view this. Try signing out and "
        'back in.';
  }

  return 'Something went wrong loading this. Please try again.';
}
