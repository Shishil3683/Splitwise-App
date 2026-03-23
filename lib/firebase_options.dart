import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD_LWsIW-Jl2e7fRpeTNUP9bhIPVrEcrCw',
    authDomain: 'flutter-splitwiseweb.firebaseapp.com',
    projectId: 'flutter-splitwiseweb',
    storageBucket: 'flutter-splitwiseweb.firebasestorage.app',
    messagingSenderId: '690041459342',
    appId: '1:690041459342:web:abcd17f90607cef686efdf',
    measurementId: 'G-Z6CL1V7WGH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD_LWsIW-Jl2e7fRpeTNUP9bhIPVrEcrCw',
    appId: '1:690041459342:web:abcd17f90607cef686efdf',
    messagingSenderId: '690041459342',
    projectId: 'flutter-splitwiseweb',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your-api-key',
    appId: 'your-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
  );
}
