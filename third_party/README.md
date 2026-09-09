# third_party/

Vendored, patched copies of pub.dev packages that have a build-blocking bug
with no fixed upstream release available. Referenced via `dependency_overrides`
in the root `pubspec.yaml`. Prefer removing the override and going back to a
normal pub.dev dependency the moment a real fix ships upstream.

## flutter_local_notifications (vendored from 12.0.4)

`FlutterLocalNotificationsPlugin.java`'s `bigLargeIcon(null)` call is
ambiguous once compiled against Android API 31+ (Android added a second
`bigLargeIcon(Icon)` overload at API 31; the plugin was written when only
`bigLargeIcon(Bitmap)` existed, and a bare `null` literal can no longer pick
one). This is a confirmed, still-open upstream bug — reported against
multiple versions of the package (12.x, 14.1.5, 17.1.2), not anything
specific to this project's config. See:
https://github.com/MaikuB/flutter_local_notifications/issues/2438

Local fix (2 Sep 2026): explicit `(Bitmap)` cast on that one line
(`android/src/main/java/.../FlutterLocalNotificationsPlugin.java` line 925).
Everything else is untouched, unpatched pub.dev source.

To upgrade this package in the future: check whether the linked issue is
closed upstream first. If so, delete this directory, remove the
`dependency_overrides` entry, and bump the version in the main `pubspec.yaml`
normally. If not, re-vendor the newer version and reapply the same one-line
cast fix.

## vibration (vendored from 1.7.7)

Same class of problem, different plugin: `VibrationPlugin.java`'s
`registerWith(PluginRegistry.Registrar)` references the v1 Android embedding,
which the current Flutter SDK no longer ships — a compile error regardless of
whether it's ever called. It isn't: the class already implements the modern
`FlutterPlugin` interface (`onAttachedToEngine`/`onDetachedFromEngine`), and
this app uses v2 embedding exclusively (`flutterEmbedding value="2"` in
`AndroidManifest.xml`). `registerWith` was pure dead code.

Every `vibration` version from 1.8.0 onward pulls in `device_info_plus`,
which requires `ffi ^2.x` — incompatible with `agora_rtc_engine ^6.6.3`'s
`ffi ^1.1.2` requirement (same conflict class as flutter_local_notifications
above). 1.7.7 is the last version before that transitive dependency was
introduced, so there's no non-vendored version that avoids both problems at
once.

Local fix (2 Sep 2026): deleted the dead `registerWith` method entirely
(`android/src/main/java/.../VibrationPlugin.java`). No other changes.

To upgrade: same process as flutter_local_notifications above — check
upstream first, and separately re-check whether `agora_rtc_engine` has since
released a version compatible with `ffi ^2.x`, which would remove the need
to vendor this at all.
