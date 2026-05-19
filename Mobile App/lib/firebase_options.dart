import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // For the hackathon, we are using the Web config as the default 
    // since we bypassed the CLI to save time. This works perfectly for Web!
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDxwA1myGUAJfQMV9nSZKRDNfquJf1b_RM',
    appId: '1:955785962137:web:cf00dc72cb506d4f938e08',
    messagingSenderId: '955785962137',
    projectId: 'ai-seekho-e66dc',
    authDomain: 'ai-seekho-e66dc.firebaseapp.com',
    storageBucket: 'ai-seekho-e66dc.firebasestorage.app',
    measurementId: 'G-ET26HYV64L',
  );
}
