import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/servicio_recordatorios.dart';
import '../datos/providers.dart';
import '../navegacion.dart';

class AjustesPantalla extends ConsumerStatefulWidget {
  const AjustesPantalla({super.key});

  @override
  ConsumerState<AjustesPantalla> createState() => _AjustesPantallaState();
}

class _AjustesPantallaState extends ConsumerState<AjustesPantalla> {
  final _ajustes = AjustesRepositorio.instancia;
  bool _cerrandoSesion = false;

  Future<void> _guardar(Future<void> Function() guardar) async {
    try {
      await guardar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar los ajustes.')),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    setState(() => _cerrandoSesion = true);
    try {
      await ServicioRecordatorios.instancia.cancelarTodos();
      await FirebaseAuth.instance.signOut();
      appNavigatorKey.currentState?.pop();
      await Future<void>.delayed(Duration.zero);
      final contextRaiz = appNavigatorKey.currentState?.overlay?.context;
      if (contextRaiz == null) return;
      await showDialog<void>(
        context: contextRaiz,
        builder: (contextoDialogo) => AlertDialog(
          title: const Text('Sesión cerrada'),
          content: const Text('Has cerrado sesión correctamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contextoDialogo).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _cerrandoSesion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cerrar la sesión.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferencias =
        ref.watch(preferenciasAppProvider).value ?? const PreferenciasApp();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apariencia', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TemaApp>(
                    key: ValueKey(preferencias.tema),
                    initialValue: preferencias.tema,
                    decoration: const InputDecoration(
                      labelText: 'Tema',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final tema in TemaApp.values)
                        DropdownMenuItem(value: tema, child: Text(tema.etiqueta)),
                    ],
                    onChanged: (tema) {
                      if (tema != null) {
                        _guardar(() => _ajustes.guardarTemaApp(tema));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unidades', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UnidadPeso>(
                    key: ValueKey(preferencias.unidadPeso),
                    initialValue: preferencias.unidadPeso,
                    decoration: const InputDecoration(
                      labelText: 'Peso',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UnidadPeso.kg,
                        child: Text('Kilogramos (kg)'),
                      ),
                      DropdownMenuItem(
                        value: UnidadPeso.lb,
                        child: Text('Libras (lb)'),
                      ),
                    ],
                    onChanged: (unidad) {
                      if (unidad != null) {
                        _guardar(() => _ajustes.guardarUnidadPeso(unidad));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UnidadLongitud>(
                    key: ValueKey(preferencias.unidadLongitud),
                    initialValue: preferencias.unidadLongitud,
                    decoration: const InputDecoration(
                      labelText: 'Longitud y altura',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UnidadLongitud.cm,
                        child: Text('Centímetros (cm)'),
                      ),
                      DropdownMenuItem(
                        value: UnidadLongitud.pulgadas,
                        child: Text('Pulgadas (in)'),
                      ),
                    ],
                    onChanged: (unidad) {
                      if (unidad != null) {
                        _guardar(() => _ajustes.guardarUnidadLongitud(unidad));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            trailing: _cerrandoSesion
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _cerrandoSesion ? null : _cerrarSesion,
          ),
        ],
      ),
    );
  }
}
