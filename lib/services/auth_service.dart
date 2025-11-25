import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';


const String _webVapidKey = 'BHFTD6Lg55Lje2u4UTW5TmAZrK7CJzoRDi1IL3a9ZUE6bHDAKWLIaI5xQbjgqrBVVVNeaG0fSfnaQP04v2HYcy4';

class AuthUser {
  final String uid;
  final String? email;
  final String? role;
  AuthUser({required this.uid, this.email, this.role});
  AuthUser copyWith({String? role}) => AuthUser(uid: uid, email: email, role: role);
}

class AuthService {

  Future<void> _updateFcmToken() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final msg = FirebaseMessaging.instance;
      await msg.requestPermission();
      final token = await msg.getToken(vapidKey: _webVapidKey);
      if (token != null) {
        await _db.collection('users').doc(uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
      msg.onTokenRefresh.listen((t) => _db.collection('users').doc(uid)
          .set({'fcmToken': t}, SetOptions(merge: true)));
    } catch (_) {
      // Puedes registrar en logs si quieres
    }
  }

  AuthService._();
  static final AuthService instance = AuthService._();

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Combina el estado de auth con el doc de rol en Firestore
  late final Stream<AuthUser?> userStream =
      _auth.authStateChanges().switchMap(_mapToAuthUser);

  Future<void> registerWithEmail({required String email, required String password}) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _ensureUserDoc();
    await _updateFcmToken();
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _ensureUserDoc();
    await _updateFcmToken();
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> setRole(String role) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  Future<void> _ensureUserDoc() async {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);
    if (!(await ref.get()).exists) {
      await ref.set({
        'email': email,
        'role': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<AuthUser?> _mapToAuthUser(fb.User? fbUser) async* {
    if (fbUser == null) {
      yield null;
      return;
    }
    final base = AuthUser(uid: fbUser.uid, email: fbUser.email);
    final ref = _db.collection('users').doc(fbUser.uid);
    yield* ref.snapshots().map((snap) {
      final data = snap.data();
      final role = data?['role'] as String?;
      return base.copyWith(role: role);
    });
  }

  // 🔹 Funcionalidades agregadas
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  fb.User? get currentFbUser => _auth.currentUser;

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }
}

// switchMap sin RxDart
extension _SwitchMap<T> on Stream<T> {
  Stream<S> switchMap<S>(Stream<S> Function(T) mapper) async* {
    StreamSubscription<S>? inner;
    final controller = StreamController<S>();
    final outer = listen((event) async {
      await inner?.cancel();
      inner = mapper(event).listen(controller.add, onError: controller.addError);
    }, onError: controller.addError, onDone: () async {
      await inner?.cancel();
      await controller.close();
    });
    yield* controller.stream;
    await outer.cancel();
  }
}