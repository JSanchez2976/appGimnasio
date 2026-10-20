import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Objetivos {
  final double? pesoKg;
  final int? calorias;
  const Objetivos({this.pesoKg, this.calorias});
}

class AjustesRepositorio {
  AjustesRepositorio._();
  static final AjustesRepositorio instancia = AjustesRepositorio._();

  DocumentReference<Map<String, dynamic>> _doc() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('ajustes')
        .doc('objetivos');
  }

  Stream<Objetivos> objetivos() {
    return _doc().snapshots().map((snap) {
      final m = snap.data();
      if (m == null) return const Objetivos();
      return Objetivos(
        pesoKg: (m['pesoKg'] as num?)?.toDouble(),
        calorias: (m['calorias'] as num?)?.toInt(),
      );
    });
  }

  /// Un valor null borra ese objetivo.
  Future<void> guardarObjetivos(Objetivos o) {
    return _doc().set({
      'pesoKg': o.pesoKg ?? FieldValue.delete(),
      'calorias': o.calorias ?? FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}