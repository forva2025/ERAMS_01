Place `ringtone.mp3` here — a short (~3-8s), loopable ringtone played by
`IncomingCallScreen` (lib/features/calls/incoming_call_screen.dart) while a
call is ringing in the foreground.

This is separate from the Android *notification* sound used for
backgrounded/killed-app ringing, which is a native raw resource at
`android/app/src/main/res/raw/ringtone.mp3` — see
`lib/services/push_notification_service.dart`'s channel setup comment.

No source audio is bundled in this repo; supply/license one before this
feature will actually ring.
