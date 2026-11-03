import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/providers.dart';
import '../datos/registro_repositorio.dart';
import 'recordatorios_pantalla.dart';

class PerfilPantalla extends ConsumerWidget {
  const PerfilPantalla({super.key});

  Future<void> _editarNombre(BuildContext context, String valorActual) async {
    var nombrePropuesto = valorActual;
    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextFormField(
          initialValue: valorActual,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          onChanged: (texto) => nombrePropuesto = texto.trim(),
          onFieldSubmitted: (texto) =>
              Navigator.of(dialogContext).pop(texto.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(nombrePropuesto.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nombre == null || !context.mounted) return;
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para tu perfil.')),
      );
      return;
    }
    try {
      await AjustesRepositorio.instancia.guardarNombrePerfil(nombre);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el nombre.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = FirebaseAuth.instance.currentUser;
    final preferencias =
        ref.watch(preferenciasAppProvider).value ?? const PreferenciasApp();

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            StreamBuilder<String?>(
              stream: AjustesRepositorio.instancia.nombrePerfil(),
              builder: (context, nombreSnapshot) {
                final nombre = nombreSnapshot.data ?? usuario?.displayName;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      nombre == null || nombre.isEmpty ? 'Mi perfil' : nombre,
                    ),
                    subtitle: Text(usuario?.email ?? 'Cuenta'),
                    trailing: IconButton(
                      tooltip: 'Editar nombre',
                      onPressed: () => _editarNombre(context, nombre ?? ''),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Mis datos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            StreamBuilder<PerfilCalculadora?>(
              stream: AjustesRepositorio.instancia.perfilCalculadora(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _MensajePerfil(
                    texto: 'No se pudieron cargar tus datos.',
                  );
                }
                final perfil = snapshot.data;
                if (perfil == null) {
                  return const _MensajePerfil(
                    texto: 'Aún no has guardado tus datos. Puedes hacerlo desde la Calculadora.',
                  );
                }
                return Card(
                  child: Column(
                    children: [
                      _DatoPerfil(
                        etiqueta: 'Edad',
                        valor: '${perfil.edad} años',
                      ),
                      _DatoPerfil(
                        etiqueta: 'Altura',
                        valor:
                            '${_formato(preferencias.unidadLongitud.desdeCm(perfil.alturaCm))} ${preferencias.unidadLongitud.simbolo}',
                      ),
                      _DatoPerfil(
                        etiqueta: 'Peso actual',
                        valor:
                            '${_formato(preferencias.unidadPeso.desdeKg(perfil.pesoKg))} ${preferencias.unidadPeso.simbolo}',
                      ),
                      _DatoPerfil(
                        etiqueta: 'Actividad',
                        valor: perfil.actividad.etiqueta,
                      ),
                      _DatoPerfil(
                        etiqueta: 'Meta',
                        valor: switch (perfil.meta) {
                          MetaCalculadora.perder => 'Perder peso',
                          MetaCalculadora.mantener => 'Mantener peso',
                          MetaCalculadora.ganar => 'Ganar peso',
                        },
                        ultimo: true,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Recordatorios'),
                subtitle: const Text('Elige horas y cuándo quieres que avisemos.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecordatoriosPantalla(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<PesoRegistro>>(
              stream: RegistroRepositorio.instancia.pesos(),
              builder: (context, pesosSnapshot) =>
                  StreamBuilder<List<CaloriasRegistro>>(
                    stream: RegistroRepositorio.instancia.calorias(),
                    builder: (context, caloriasSnapshot) =>
                        StreamBuilder<Objetivos>(
                          stream: AjustesRepositorio.instancia.objetivos(),
                          builder: (context, objetivosSnapshot) {
                            if (pesosSnapshot.hasError ||
                                caloriasSnapshot.hasError ||
                                objetivosSnapshot.hasError) {
                              return const _MensajePerfil(
                                texto: 'No se pudieron cargar tus logros.',
                              );
                            }
                            if (!pesosSnapshot.hasData ||
                                !caloriasSnapshot.hasData ||
                                !objetivosSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final registrosCalorias = caloriasSnapshot.data!;
                            final diasActivos = <String>{
                              for (final peso in pesosSnapshot.data!)
                                idDia(peso.fecha),
                              for (final registro in registrosCalorias)
                                idDia(registro.fecha),
                            };
                            final objetivoKcal =
                                objetivosSnapshot.data!.calorias;
                            final diasEnObjetivoKcal = objetivoKcal == null
                                ? null
                                : registrosCalorias.where((registro) {
                                    final total = registro.total;
                                    return total > 0 &&
                                        total >=
                                            objetivoKcal -
                                                objetivosSnapshot
                                                    .data!
                                                    .margenBajoEfectivo &&
                                        total <=
                                            objetivoKcal +
                                                objetivosSnapshot
                                                    .data!
                                                    .margenAltoEfectivo;
                                  }).map((registro) => idDia(registro.fecha)).toSet();
                            final rachaRegistro =
                                _calcularRacha(diasActivos, DateTime.now());
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Rachas',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                _TarjetaRacha(
                                  titulo: 'Racha de registro',
                                  icono: Icons.local_fire_department_outlined,
                                  racha: rachaRegistro,
                                ),
                                const SizedBox(height: 8),
                                if (diasEnObjetivoKcal == null)
                                  const _MensajePerfil(
                                    texto:
                                        'Guarda un objetivo diario de kcal para activar la racha de kcal.',
                                  )
                                else
                                  _TarjetaRacha(
                                    titulo: 'Racha de kcal',
                                    icono: Icons.bolt_outlined,
                                    racha: _calcularRacha(
                                      diasEnObjetivoKcal,
                                      DateTime.now(),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                Text(
                                  'Logros',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                _LogroRangos(
                                  titulo: 'Constancia',
                                  dias: diasActivos.length,
                                ),
                                const SizedBox(height: 10),
                                if (diasEnObjetivoKcal == null)
                                  const _MensajePerfil(
                                    texto: 'Guarda un objetivo diario de kcal para empezar el logro de constancia con las calorías.',
                                  )
                                else
                                  _LogroRangos(
                                    titulo: 'Constancia con kcal',
                                    dias: diasEnObjetivoKcal.length,
                                  ),
                              ],
                            );
                          },
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formato(double valor) =>
      valor.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}

class _DatoPerfil extends StatelessWidget {
  const _DatoPerfil({
    required this.etiqueta,
    required this.valor,
    this.ultimo = false,
  });

  final String etiqueta;
  final String valor;
  final bool ultimo;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(title: Text(etiqueta), trailing: Text(valor)),
      if (!ultimo) const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );
}

class _MensajePerfil extends StatelessWidget {
  const _MensajePerfil({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(texto)),
  );
}

class _DatosRacha {
  const _DatosRacha(this.actual, this.mejor);
  final int actual;
  final int mejor;
}

_DatosRacha _calcularRacha(Set<String> dias, DateTime hoyLocal) {
  DateTime fecha(String clave) {
    final partes = clave.split('-').map(int.parse).toList();
    return DateTime.utc(partes[0], partes[1], partes[2]);
  }

  final ordenados = dias.toList()..sort();
  var mejor = 0;
  var rachaTemporal = 0;
  DateTime? anterior;
  for (final clave in ordenados) {
    final dia = fecha(clave);
    rachaTemporal = anterior != null && dia.difference(anterior).inDays == 1
        ? rachaTemporal + 1
        : 1;
    if (rachaTemporal > mejor) mejor = rachaTemporal;
    anterior = dia;
  }

  var cursor = DateTime.utc(hoyLocal.year, hoyLocal.month, hoyLocal.day);
  if (!dias.contains(idDia(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var actual = 0;
  while (dias.contains(idDia(cursor))) {
    actual++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return _DatosRacha(actual, mejor);
}

class _TarjetaRacha extends StatelessWidget {
  const _TarjetaRacha({
    required this.titulo,
    required this.icono,
    required this.racha,
  });

  final String titulo;
  final IconData icono;
  final _DatosRacha racha;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icono, color: Theme.of(context).colorScheme.primary),
      title: Text(titulo),
      subtitle: Text('Mejor racha: ${racha.mejor} ${racha.mejor == 1 ? 'día' : 'días'}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${racha.actual}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(racha.actual == 1 ? 'día seguido' : 'días seguidos'),
        ],
      ),
    ),
  );
}

enum _RangoConstancia {
  bronce('Bronce', 3, Color(0xFFB87333), Icons.workspace_premium_outlined),
  plata('Plata', 7, Color(0xFF9AA7B3), Icons.workspace_premium_outlined),
  oro('Oro', 14, Color(0xFFD4A017), Icons.workspace_premium),
  esmeralda('Esmeralda', 30, Color(0xFF078A68), Icons.diamond_outlined),
  diamante('Diamante', 60, Color(0xFF2A9DCE), Icons.diamond);

  const _RangoConstancia(
    this.nombre,
    this.diasNecesarios,
    this.color,
    this.icono,
  );
  final String nombre;
  final int diasNecesarios;
  final Color color;
  final IconData icono;
}

class _LogroRangos extends StatelessWidget {
  const _LogroRangos({required this.titulo, required this.dias});
  final String titulo;
  final int dias;

  @override
  Widget build(BuildContext context) {
    final rangos = _RangoConstancia.values;
    final rangoConseguido = rangos.lastIndexWhere(
      (rango) => dias >= rango.diasNecesarios,
    );
    final siguienteIndice = (rangoConseguido + 1)
        .clamp(0, rangos.length - 1)
        .toInt();
    final siguiente = rangos[siguienteIndice];
    final progreso = rangoConseguido == rangos.length - 1
        ? 1.0
        : (dias / siguiente.diasNecesarios).clamp(0.0, 1.0).toDouble();
    final nombreActual = rangoConseguido >= 0
        ? rangos[rangoConseguido].nombre
        : 'Sin rango';
    final color = rangoConseguido >= 0
        ? rangos[rangoConseguido].color
        : siguiente.color;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: rangoConseguido >= 0 ? 0.2 : 0.1),
              colorScheme.surfaceContainerHighest,
            ],
          ),
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    rangoConseguido >= 0
                        ? rangos[rangoConseguido].icono
                        : siguiente.icono,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        rangoConseguido >= 0
                            ? 'Rango $nombreActual'
                            : 'Rango ${siguiente.nombre}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (rangoConseguido == rangos.length - 1)
                  Icon(Icons.check_circle, color: color),
              ],
            ),
            const SizedBox(height: 16),
            Text('$dias ${dias == 1 ? 'día' : 'días'} conseguidos'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rangoConseguido == rangos.length - 1
                  ? 'Has alcanzado el rango máximo.'
                  : 'Siguiente rango: ${siguiente.nombre} · ${dias.clamp(0, siguiente.diasNecesarios)}/${siguiente.diasNecesarios} días',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
