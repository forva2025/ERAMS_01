// Kept in sync with lib/core/config/firebase_options.dart's `web` block —
// required by firebase_messaging for background/terminated web push.
// Regenerate both together via `flutterfire configure` (see that file's
// header comment) rather than editing just one.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAu7-KWiBnCSnnVOKc9rzgIkaU_kvIDqLw',
  authDomain: 'erams-98eb2.firebaseapp.com',
  projectId: 'erams-98eb2',
  storageBucket: 'erams-98eb2.firebasestorage.app',
  messagingSenderId: '840423219815',
  appId: '1:840423219815:web:d5c4dbab9887ef5009aac2',
});

firebase.messaging();
