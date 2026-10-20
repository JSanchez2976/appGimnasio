import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'registro_repositorio.dart' show idDia;

class NotaRegistro {
  final DateTime fecha;
  final String texto;
  const NotaRegistro(this.fecha, this.texto);
}

class NotasRepositorio {
  NotasRepositorio._();
  static final NotasRepositorio instancia = NotasRepositorio._();

  CollectionReference<Map<String, dynamic>> _coleccion() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notas');
  }

  Stream<List<NotaRegistro>> registros() {
    return _coleccion()
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              final m = doc.data();
              return NotaRegistro(
                (m['fecha'] as Timestamp).toDate(),
                (m['texto'] as String?) ?? '',
              );
            })
            .where((n) => n.texto.isNotEmpty)
            .toList());
  }

  Future<void> guardar(DateTime dia, String texto) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return _coleccion()
        .doc(idDia(d))
        .set({'fecha': Timestamp.fromDate(d), 'texto': texto});
  }

  Future<void> borrar(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return _coleccion().doc(idDia(d)).delete();
  }
}