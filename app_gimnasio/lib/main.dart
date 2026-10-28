import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'datos/ajustes_repositorio.dart';
import 'datos/providers.dart';
import 'navegacion.dart';
import 'pantallas/inicio_pantalla.dart';
import 'pantallas/login_pantalla.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ProviderScope(retry: (retryCount, error) => null, child: const MiApp()),
  );
}

class MiApp extends ConsumerWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema =
        ref.watch(preferenciasAppProvider).value?.tema ?? TemaApp.sistema;
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Peso y Calorías',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: switch (tema) {
        TemaApp.sistema => ThemeMode.system,
        TemaApp.claro => ThemeMode.light,
        TemaApp.oscuro => ThemeMode.dark,
      },
      home: const PuertaAutenticacion(),
    );
  }
}

/// Decide qué pantalla mostrar según haya o no una sesión iniciada.
class PuertaAutenticacion extends StatelessWidget {
  const PuertaAutenticacion({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const InicioPantalla();
        return const LoginPantalla();
      },
    );
  }
}
