// PLACEHOLDER — required by firebase_messaging for background/terminated web
// push, but the values below are inert until this is kept in sync with
// lib/core/config/firebase_options.dart after running `flutterfire configure`
// (see that file's header comment for the full setup steps).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
  authDomain: 'erams-98eb2.firebaseapp.com',
  projectId: 'erams-98eb2',
  storageBucket: 'erams-98eb2.appspot.com',
  messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
  appId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
});

firebase.messaging();
