import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/registro_repositorio.dart';
import '../graficas/agregacion.dart';
import '../graficas/grafica_barras.dart';

class GraficasPantalla extends StatefulWidget {
  const GraficasPantalla({super.key});

  @override
  State<GraficasPantalla> createState() => _GraficasPantallaState();
}

class _GraficasPantallaState extends State<GraficasPantalla> {
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
      builder: (_) => _DialogoObjetivos(actual: _objetivos),
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

  Widget _tarjeta({
    required String titulo,
    required String subtitulo,
    required String? objetivo,
    required Widget grafica,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitulo, style: Theme.of(context).textTheme.bodySmall),
            if (objetivo != null)
              Text(
                'Objetivo: $objetivo (línea naranja)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            grafica,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final barrasPeso = barrasDePeso(_periodo, _inicio, _pesos);
    final barrasCal = barrasDeCalorias(_periodo, _inicio, _calorias);
    final esAnio = _periodo == Periodo.anio;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<Periodo>(
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
        _tarjeta(
          titulo: 'Peso (kg)',
          subtitulo: esAnio ? 'Media de cada mes' : 'Peso de cada día',
          objetivo:
              _objetivos.pesoKg == null ? null : '${_objetivos.pesoKg} kg',
          grafica: GraficaBarras(
            barras: barrasPeso,
            color: esquema.primary,
            empiezaEnCero: false,
            objetivo: _objetivos.pesoKg,
          ),
        ),
        const SizedBox(height: 8),
        _tarjeta(
          titulo: 'Calorías (kcal)',
          subtitulo: esAnio ? 'Media diaria de cada mes' : 'Total de cada día',
          objetivo:
              _objetivos.calorias == null ? null : '${_objetivos.calorias} kcal',
          grafica: GraficaBarras(
            barras: barrasCal,
            color: esquema.tertiary,
            empiezaEnCero: true,
            objetivo: _objetivos.calorias?.toDouble(),
          ),
        ),
      ],
    );
  }
}

class _DialogoObjetivos extends StatefulWidget {
  const _DialogoObjetivos({required this.actual});

  final Objetivos actual;

  @override
  State<_DialogoObjetivos> createState() => _DialogoObjetivosState();
}

class _DialogoObjetivosState extends State<_DialogoObjetivos> {
  late final TextEditingController _peso =
      TextEditingController(text: widget.actual.pesoKg?.toString() ?? '');
  late final TextEditingController _cal =
      TextEditingController(text: widget.actual.calorias?.toString() ?? '');
  String? _error;

  @override
  void dispose() {
    _peso.dispose();
    _cal.dispose();
    super.dispose();
  }

  void _guardar() {
    final textoPeso = _peso.text.trim().replaceAll(',', '.');
    final kg = textoPeso.isEmpty ? null : double.tryParse(textoPeso);
    if (textoPeso.isNotEmpty && (kg == null || kg < 20 || kg > 500)) {
      setState(() => _error = 'El peso objetivo no es válido.');
      return;
    }
    final textoCal = _cal.text.trim();
    final kcal = textoCal.isEmpty ? null : int.tryParse(textoCal);
    if (textoCal.isNotEmpty && (kcal == null || kcal < 500 || kcal > 10000)) {
      setState(() => _error = 'Las calorías objetivo no son válidas.');
      return;
    }
    Navigator.pop(context, Objetivos(pesoKg: kg, calorias: kcal));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tus objetivos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _peso,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Peso objetivo (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cal,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Calorías objetivo (kcal al día)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Déjalo vacío para quitar un objetivo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}