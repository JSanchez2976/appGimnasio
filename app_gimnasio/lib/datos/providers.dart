import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agua_repositorio.dart';
import 'medidas_repositorio.dart';
import 'notas_repositorio.dart';

/// Usuario con sesión iniciada, o null.
final usuarioProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Crea un provider de datos que se reinicia cuando cambia el usuario,
/// para no mostrar nunca datos de otra cuenta.
StreamProvider<T> _porUsuario<T>(Stream<T> Function() crear) {
  return StreamProvider<T>((ref) {
    final usuario = ref.watch(usuarioProvider).value;
    if (usuario == null) return Stream<T>.empty();
    return crear();
  });
}

final aguaProvider = _porUsuario(() => AguaRepositorio.instancia.registros());

final aguaObjetivoProvider = _porUsuario(
  () => AguaRepositorio.instancia.objetivo(),
);

final medidasProvider = _porUsuario(
  () => MedidasRepositorio.instancia.registros(),
);
final notasProvider = _porUsuario(() => NotasRepositorio.instancia.registros());
