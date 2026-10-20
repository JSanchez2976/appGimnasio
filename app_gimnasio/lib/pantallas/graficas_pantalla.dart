import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/notas_repositorio.dart';
import '../datos/providers.dart';
import '../datos/registro_repositorio.dart';
import '../graficas/agregacion.dart';
import '../graficas/grafica_barras.dart';
import '../widgets/dialogo_objetivos.dart';
import '../widgets/notas_tarjeta.dart';
import '../widgets/resumen_tarjeta.dart';
import '../widgets/tarjeta_grafica.dart';

class GraficasPantalla extends ConsumerStatefulWidget {
  const GraficasPantalla({super.key});

  @override
  ConsumerState<GraficasPantalla> createState() => _GraficasPantallaState();
}

class _GraficasPantallaState extends ConsumerState<GraficasPantalla> {
  final _registros = RegistroRepositorio.instancia;
  final _ajustes = AjustesRepositorio.instancia;
  final List<StreamSubscription<dynamic>> _subs = [];

  List<PesoRegistro> _pesos = const [];
  List<CaloriasRegistro> _calorias = const [];
  Objetivos _objetivos = const Objetivos();
  Object? _error;

  Periodo _periodo = Periodo.semana;
  late DateTime _inicio = inicioPeriodo(Periodo.semana, DateTime.now());

  @override
  void initState() {
    super.initState();
    _subs.add(_registros.pesos().listen(
          (l) => setState(() => _pesos = l),
          onError: (Object e) => setState(() => _error = e),
        ));
    _subs.add(_registros.calorias().listen(
          (l) => setState(() => _calorias = l),
          onError: (Object e) => setState(() => _error = e),
        ));
    _subs.add(_ajustes.objetivos().listen(
          (o) => setState(() => _objetivos = o),
          onError: (Object e) => setState(() => _error = e),
        ));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _cambiarPeriodo(Periodo p) {
    setState(() {
      _periodo = p;
      _inicio = inicioPeriodo(p, DateTime.now());
    });
  }

  void _mover(int pasos) {
    setState(() => _inicio = desplazar(_periodo, _inicio, pasos));
  }

  bool get _puedeAvanzar =>
      !desplazar(_periodo, _inicio, 1).isAfter(DateTime.now());

  Future<void> _editarObjetivos() async {
    final nuevo = await showDialog<Objetivos>(
      context: context,
      builder: (_) => DialogoObjetivos(actual: _objetivos),
    );
    if (nuevo == null) return;
    try {
      await _ajustes.guardarObjetivos(nuevo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar los objetivos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final notas = ref.watch(notasProvider).value ?? const <NotaRegistro>[];
    final fechasNota = notas.map((n) => n.fecha);

    final barrasPeso = conMarcasDeNotas(
      _periodo,
      _inicio,
      barrasDePeso(_periodo, _inicio, _pesos),
      fechasNota,
    );
    final barrasCal = conMarcasDeNotas(
      _periodo,
      _inicio,
      barrasDeCalorias(_periodo, _inicio, _calorias),
      fechasNota,
    );
    final esAnio = _periodo == Periodo.anio;

    final kcal = _objetivos.calorias;
    final mBajo = kcal == null ? null : _objetivos.margenBajoEfectivo;
    final mAlto = kcal == null ? null : _objetivos.margenAltoEfectivo;

    final resumen = resumenDe(
      periodo: _periodo,
      inicio: _inicio,
      pesos: _pesos,
      calorias: _calorias,
      objetivoCalorias: kcal,
      margenBajo: _objetivos.margenBajoEfectivo,
      margenAlto: _objetivos.margenAltoEfectivo,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<Periodo>(
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          segments: const [
            ButtonSegment(value: Periodo.semana, label: Text('Semana')),
            ButtonSegment(value: Periodo.mes, label: Text('Mes')),
            ButtonSegment(value: Periodo.anio, label: Text('Año')),
          ],
          selected: {_periodo},
          onSelectionChanged: (s) => _cambiarPeriodo(s.first),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _mover(-1),
            ),
            Expanded(
              child: Text(
                tituloPeriodo(_periodo, _inicio),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: _puedeAvanzar ? () => _mover(1) : null,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _editarObjetivos,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Objetivos'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No se pudieron cargar los datos: $_error',
              style: TextStyle(color: esquema.error),
            ),
          ),
        ResumenTarjeta(
          periodo: _periodo,
          inicio: _inicio,
          resumen: resumen,
          hayObjetivoCalorias: kcal != null,
        ),
        const SizedBox(height: 8),
        TarjetaGrafica(
          titulo: 'Peso (kg)',
          subtitulo: esAnio ? 'Media de cada mes' : 'Peso de cada día',
          objetivo: _objetivos.pesoKg == null
              ? null
              : 'Objetivo: ${_objetivos.pesoKg} kg (línea naranja)',
          grafica: GraficaBarras(
            barras: barrasPeso,
            color: esquema.primary,
            empiezaEnCero: false,
            objetivo: _objetivos.pesoKg,
          ),
        ),
        const SizedBox(height: 8),
        TarjetaGrafica(
          titulo: 'Calorías (kcal)',
          subtitulo: esAnio ? 'Media diaria de cada mes' : 'Total de cada día',
          objetivo: kcal == null
              ? null
              : 'Objetivo: $kcal kcal (línea naranja) · '
                  'rango ${kcal - mBajo!} a ${kcal + mAlto!} kcal',
          grafica: GraficaBarras(
            barras: barrasCal,
            color: esquema.tertiary,
            empiezaEnCero: true,
            objetivo: kcal?.toDouble(),
            margenBajo: mBajo?.toDouble(),
            margenAlto: mAlto?.toDouble(),
          ),
          pie: kcal == null ? null : const LeyendaRango(),
        ),
        const SizedBox(height: 8),
        NotasTarjeta(periodo: _periodo, inicio: _inicio, notas: notas),
      ],
    );
  }
}