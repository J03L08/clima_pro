import 'package:cloud_firestore/cloud_firestore.dart';

class UsersService {
  UsersService._();
  static final UsersService instance = UsersService._();

  final _db = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> tecnicos() {
    return _db.collection('users')
      .where('role', isEqualTo: 'tecnico')
      .snapshots()
      .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }
}