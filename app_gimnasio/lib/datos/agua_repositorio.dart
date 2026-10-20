import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'registro_repositorio.dart' show idDia;

class AguaRegistro {
  final DateTime fecha;
  final int ml;
  const AguaRegistro(this.fecha, this.ml);
}

class AguaRepositorio {
  AguaRepositorio._();
  static final AguaRepositorio instancia = AguaRepositorio._();

  DocumentReference<Map<String, dynamic>> _usuario() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _registros() =>
      _usuario().collection('agua');

  DocumentReference<Map<String, dynamic>> _docObjetivo() =>
      _usuario().collection('ajustes').doc('agua');

  Stream<List<AguaRegistro>> registros() {
    return _registros()
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final m = doc.data();
              return AguaRegistro(
                (m['fecha'] as Timestamp).toDate(),
                (m['ml'] as num).toInt(),
              );
            }).toList());
  }

  Future<void> guardar(DateTime dia, int ml) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return _registros()
        .doc(idDia(d))
        .set({'fecha': Timestamp.fromDate(d), 'ml': ml});
  }

  Future<void> borrar(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return _registros().doc(idDia(d)).delete();
  }

  Stream<int?> objetivo() {
    return _docObjetivo()
        .snapshots()
        .map((snap) => (snap.data()?['ml'] as num?)?.toInt());
  }

  /// Null quita el objetivo.
  Future<void> guardarObjetivo(int? ml) {
    return _docObjetivo()
        .set({'ml': ml ?? FieldValue.delete()}, SetOptions(merge: true));
  }
}