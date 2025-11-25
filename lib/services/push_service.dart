import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _msg = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> initAndSaveToken() async {
    // Permisos (Web/Android)
    await _msg.requestPermission();
    final token = await _msg.getToken(vapidKey: 'BHFTD6Lg55Lje2u4UTW5TmAZrK7CJzoRDi1IL3a9ZUE6bHDAKWLIaI5xQbjgqrBVVVNeaG0fSfnaQP04v2HYcy4');
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && token != null) {
      await _db.collection('users').doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
    }

    // actualiza token cuando cambie (ej. reinstalación)
    _msg.onTokenRefresh.listen((t) async {
      final u = fb.FirebaseAuth.instance.currentUser?.uid;
      if (u != null) {
        await _db.collection('users').doc(u)
          .set({'fcmToken': t}, SetOptions(merge: true));
      }
    });
  }
}