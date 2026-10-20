import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'registro_repositorio.dart' show idDia;

enum Medida {
  cintura('Cintura', 'cm'),
  pecho('Pecho', 'cm'),
  brazo('Brazo', 'cm'),
  muslo('Muslo', 'cm'),
  grasa('Grasa corporal', '%');

  const Medida(this.etiqueta, this.unidad);

  final String etiqueta;
  final String unidad;
}

class MedidasRegistro {
  final DateTime fecha;

  /// Solo contiene las medidas que se anotaron ese día.
  final Map<Medida, double> valores;
  const MedidasRegistro(this.fecha, this.valores);
}

class MedidasRepositorio {
  MedidasRepositorio._();
  static final MedidasRepositorio instancia = MedidasRepositorio._();

  CollectionReference<Map<String, dynamic>> _coleccion() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medidas');
  }

  /// Guarda solo las medidas indicadas; las demás del mismo día no se tocan.
  /// Una medida con valor null se borra.
  Future<void> guardar(DateTime dia, Map<Medida, double?> valores) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return _coleccion().doc(idDia(d)).set({
      'fecha': Timestamp.fromDate(d),
      for (final e in valores.entries)
        e.key.name: e.value ?? FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Stream<List<MedidasRegistro>> registros() {
    return _coleccion()
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final m = doc.data();
              final valores = <Medida, double>{};
              for (final medida in Medida.values) {
                final v = (m[medida.name] as num?)?.toDouble();
                if (v != null) valores[medida] = v;
              }
              return MedidasRegistro(
                (m['fecha'] as Timestamp).toDate(),
                valores,
              );
            }).toList());
  }
}