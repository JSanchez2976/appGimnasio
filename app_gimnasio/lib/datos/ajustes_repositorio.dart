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

enum TemaApp {
  sistema('Sistema'),
  claro('Claro'),
  oscuro('Oscuro');

  const TemaApp(this.etiqueta);
  final String etiqueta;
}

enum UnidadPeso {
  kg('kg'),
  lb('lb');

  const UnidadPeso(this.simbolo);
  final String simbolo;

  double desdeKg(double valor) => this == kg ? valor : valor * 2.2046226218;
  double aKg(double valor) => this == kg ? valor : valor / 2.2046226218;
}

enum UnidadLongitud {
  cm('cm'),
  pulgadas('in');

  const UnidadLongitud(this.simbolo);
  final String simbolo;

  double desdeCm(double valor) => this == cm ? valor : valor / 2.54;
  double aCm(double valor) => this == cm ? valor : valor * 2.54;
}

class PreferenciasApp {
  final TemaApp tema;
  final UnidadPeso unidadPeso;
  final UnidadLongitud unidadLongitud;

  const PreferenciasApp({
    this.tema = TemaApp.sistema,
    this.unidadPeso = UnidadPeso.kg,
    this.unidadLongitud = UnidadLongitud.cm,
  });

  PreferenciasApp copyWith({
    TemaApp? tema,
    UnidadPeso? unidadPeso,
    UnidadLongitud? unidadLongitud,
  }) => PreferenciasApp(
    tema: tema ?? this.tema,
    unidadPeso: unidadPeso ?? this.unidadPeso,
    unidadLongitud: unidadLongitud ?? this.unidadLongitud,
  );
}

enum ActividadCalculadora {
  sedentaria('Sedentaria', 1.2),
  ligera('Ligera (1-3 días/semana)', 1.375),
  moderada('Moderada (3-5 días/semana)', 1.55),
  alta('Alta (6-7 días/semana)', 1.725),
  muyAlta('Muy alta (trabajo físico o entrenamiento intenso)', 1.9);

  const ActividadCalculadora(this.etiqueta, this.factor);
  final String etiqueta;
  final double factor;
}

enum MetaCalculadora { perder, mantener, ganar }

class PerfilCalculadora {
  final int edad;
  final String sexo;
  final double alturaCm;
  final double pesoKg;
  final ActividadCalculadora actividad;
  final MetaCalculadora meta;
  final DateTime? actualizadoEn;

  const PerfilCalculadora({
    required this.edad,
    required this.sexo,
    required this.alturaCm,
    required this.pesoKg,
    required this.actividad,
    required this.meta,
    this.actualizadoEn,
  });
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

  Stream<PreferenciasApp> preferenciasApp() {
    return _doc().snapshots().map((snap) {
      final preferencias = snap.data()?['preferencias'];
      if (preferencias is! Map<String, dynamic>) {
        return const PreferenciasApp();
      }
      return PreferenciasApp(
        tema: TemaApp.values.firstWhere(
          (v) => v.name == preferencias['tema'],
          orElse: () => TemaApp.sistema,
        ),
        unidadPeso: UnidadPeso.values.firstWhere(
          (v) => v.name == preferencias['unidadPeso'],
          orElse: () => UnidadPeso.kg,
        ),
        unidadLongitud: UnidadLongitud.values.firstWhere(
          (v) => v.name == preferencias['unidadLongitud'],
          orElse: () => UnidadLongitud.cm,
        ),
      );
    });
  }

  Future<void> guardarPreferenciasApp(PreferenciasApp preferencias) {
    return _doc().set({
      'preferencias': {
        'tema': preferencias.tema.name,
        'unidadPeso': preferencias.unidadPeso.name,
        'unidadLongitud': preferencias.unidadLongitud.name,
      },
    }, SetOptions(merge: true));
  }

  Future<void> guardarTemaApp(TemaApp tema) => _doc().set({
    'preferencias': {'tema': tema.name},
  }, SetOptions(merge: true));

  Future<void> guardarUnidadPeso(UnidadPeso unidad) => _doc().set({
    'preferencias': {'unidadPeso': unidad.name},
  }, SetOptions(merge: true));

  Future<void> guardarUnidadLongitud(UnidadLongitud unidad) => _doc().set({
    'preferencias': {'unidadLongitud': unidad.name},
  }, SetOptions(merge: true));

  Stream<String?> nombrePerfil() {
    return _doc().snapshots().map((snap) {
      final nombre = snap.data()?['perfilNombre'];
      return nombre is String && nombre.trim().isNotEmpty ? nombre.trim() : null;
    });
  }

  Future<void> guardarNombrePerfil(String nombre) {
    return _doc().set({'perfilNombre': nombre.trim()}, SetOptions(merge: true));
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

  Stream<PerfilCalculadora?> perfilCalculadora() {
    return _doc().snapshots().map((snap) {
      final m = snap.data()?['calculadora'];
      if (m is! Map<String, dynamic>) return null;
      return PerfilCalculadora(
        edad: (m['edad'] as num).toInt(),
        sexo: m['sexo'] as String,
        alturaCm: (m['alturaCm'] as num).toDouble(),
        pesoKg: (m['pesoKg'] as num).toDouble(),
        actividad: ActividadCalculadora.values.firstWhere(
          (a) => a.name == m['actividad'],
          orElse: () => ActividadCalculadora.sedentaria,
        ),
        meta: MetaCalculadora.values.firstWhere(
          (g) => g.name == m['meta'],
          orElse: () => MetaCalculadora.mantener,
        ),
        actualizadoEn: m['actualizadoEn'] is Timestamp
            ? (m['actualizadoEn'] as Timestamp).toDate()
            : null,
      );
    });
  }

  Future<void> guardarPerfilCalculadora(PerfilCalculadora perfil) {
    return _doc().set({
      'calculadora': {
        'edad': perfil.edad,
        'sexo': perfil.sexo,
        'alturaCm': perfil.alturaCm,
        'pesoKg': perfil.pesoKg,
        'actividad': perfil.actividad.name,
        'meta': perfil.meta.name,
        'actualizadoEn': Timestamp.now(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> guardarObjetivoCalorias(int calorias) {
    return _doc().set({'calorias': calorias}, SetOptions(merge: true));
  }

  Future<void> guardarObjetivosCalculadora({
    required int calorias,
    double? pesoObjetivoKg,
  }) {
    return _doc().set({
      'calorias': calorias,
      if (pesoObjetivoKg != null) 'pesoKg': pesoObjetivoKg,
    }, SetOptions(merge: true));
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
