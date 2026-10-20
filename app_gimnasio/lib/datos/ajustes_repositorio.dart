import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Objetivos {
  static const int margenPorDefecto = 100;

  final double? pesoKg;
  final int? calorias;

  /// Kcal que puedes quedarte por debajo / pasarte por arriba del objetivo
  /// y seguir contando como "día cumplido". Null = valor por defecto.
  final int? margenBajo;
  final int? margenAlto;

  const Objetivos({
    this.pesoKg,
    this.calorias,
    this.margenBajo,
    this.margenAlto,
  });

  int get margenBajoEfectivo => margenBajo ?? margenPorDefecto;
  int get margenAltoEfectivo => margenAlto ?? margenPorDefecto;
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
        margenBajo: (m['margenBajo'] as num?)?.toInt(),
        margenAlto: (m['margenAlto'] as num?)?.toInt(),
      );
    });
  }

  /// Un valor null borra ese ajuste.
  Future<void> guardarObjetivos(Objetivos o) {
    return _doc().set({
      'pesoKg': o.pesoKg ?? FieldValue.delete(),
      'calorias': o.calorias ?? FieldValue.delete(),
      'margenBajo': o.margenBajo ?? FieldValue.delete(),
      'margenAlto': o.margenAlto ?? FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}