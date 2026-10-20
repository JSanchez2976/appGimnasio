import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum Franja { desayuno, comida, cena, snacks }

String idDia(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class PesoRegistro {
  final DateTime fecha;
  final double kg;
  PesoRegistro(this.fecha, this.kg);
}

class CaloriasRegistro {
  final DateTime fecha;
  final Map<Franja, int> porFranja;
  CaloriasRegistro(this.fecha, this.porFranja);

  int get total => porFranja.values.fold(0, (a, b) => a + b);
}

/// Único sitio de la app que habla con Firestore.
class RegistroRepositorio {
  RegistroRepositorio._();
  static final RegistroRepositorio instancia = RegistroRepositorio._();

  CollectionReference<Map<String, dynamic>> _coleccion(String nombre) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(nombre);
  }

  DateTime _soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> guardarPeso(DateTime dia, double kg) {
    final d = _soloDia(dia);
    return _coleccion('pesos')
        .doc(idDia(d))
        .set({'fecha': Timestamp.fromDate(d), 'kg': kg});
  }

  /// Guarda solo las franjas indicadas; las demás del mismo día no se tocan.
  /// Una franja con valor null se borra.
  Future<void> guardarCalorias(DateTime dia, Map<Franja, int?> porFranja) {
    final d = _soloDia(dia);
    return _coleccion('calorias').doc(idDia(d)).set({
      'fecha': Timestamp.fromDate(d),
      for (final e in porFranja.entries)
        e.key.name: e.value ?? FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> borrarPeso(DateTime dia) {
    return _coleccion('pesos').doc(idDia(_soloDia(dia))).delete();
  }

  Stream<List<PesoRegistro>> pesos() {
    return _coleccion('pesos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final m = doc.data();
            return PesoRegistro(
              (m['fecha'] as Timestamp).toDate(),
              (m['kg'] as num).toDouble(),
            );
          }).toList(),
        );
  }

  Stream<List<CaloriasRegistro>> calorias() {
    return _coleccion('calorias')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final m = doc.data();
            return CaloriasRegistro((m['fecha'] as Timestamp).toDate(), {
              for (final f in Franja.values)
                f: (m[f.name] as num?)?.toInt() ?? 0,
            });
          }).toList(),
        );
  }
}
