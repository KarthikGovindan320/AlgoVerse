// File generated manually from Firebase project configuration.
// Project: algoverse-492311

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyASJ2r05Qexx47UDjfG-Bhp6JvRR0qvL_s',
    appId: '1:329967449801:android:25e180aad4935d079cbf18',
    messagingSenderId: '329967449801',
    projectId: 'algoverse-492311',
    storageBucket: 'algoverse-492311.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyASJ2r05Qexx47UDjfG-Bhp6JvRR0qvL_s',
    appId: '1:329967449801:ios:25e180aad4935d079cbf18',
    messagingSenderId: '329967449801',
    projectId: 'algoverse-492311',
    storageBucket: 'algoverse-492311.firebasestorage.app',
    iosBundleId: 'com.karthik.algoverse',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyASJ2r05Qexx47UDjfG-Bhp6JvRR0qvL_s',
    appId: '1:329967449801:web:25e180aad4935d079cbf18',
    messagingSenderId: '329967449801',
    projectId: 'algoverse-492311',
    authDomain: 'algoverse-492311.firebaseapp.com',
    storageBucket: 'algoverse-492311.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyASJ2r05Qexx47UDjfG-Bhp6JvRR0qvL_s',
    appId: '1:329967449801:ios:25e180aad4935d079cbf18',
    messagingSenderId: '329967449801',
    projectId: 'algoverse-492311',
    storageBucket: 'algoverse-492311.firebasestorage.app',
    iosBundleId: 'com.karthik.algoverse',
  );
}
