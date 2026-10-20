import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/agua_repositorio.dart';
import '../datos/providers.dart';
import '../datos/registro_repositorio.dart' show idDia;
import '../graficas/agregacion.dart';
import '../graficas/grafica_barras.dart';
import '../widgets/selector_periodo.dart';
import '../widgets/tarjeta_grafica.dart';

class AguaPantalla extends ConsumerStatefulWidget {
  const AguaPantalla({super.key});

  @override
  ConsumerState<AguaPantalla> createState() => _AguaPantallaState();
}

class _AguaPantallaState extends ConsumerState<AguaPantalla> {
  final _repo = AguaRepositorio.instancia;

  DateTime _dia = DateTime.now();
  Periodo _periodo = Periodo.semana;
  late DateTime _inicio = inicioPeriodo(Periodo.semana, DateTime.now());

  String _formato(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirDia() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (elegido != null) setState(() => _dia = elegido);
  }

  int _mlDelDia(List<AguaRegistro> lista) {
    final id = idDia(_dia);
    for (final r in lista) {
      if (idDia(r.fecha) == id) return r.ml;
    }
    return 0;
  }

  void _sumar(List<AguaRegistro> lista, int delta) {
    final nuevo = (_mlDelDia(lista) + delta).clamp(0, 20000).toInt();
    final operacion =
        nuevo == 0 ? _repo.borrar(_dia) : _repo.guardar(_dia, nuevo);
    operacion.catchError((Object _) {
      _avisar('No se pudo guardar el agua.');
    });
  }

  Future<void> _editarObjetivo(int? actual) async {
    final ml = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoAgua(actual: actual),
    );
    if (ml == null) return;
    try {
      await _repo.guardarObjetivo(ml == 0 ? null : ml);
    } catch (_) {
      _avisar('No se pudo guardar el objetivo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final registros = ref.watch(aguaProvider);
    final objetivo = ref.watch(aguaObjetivoProvider).value;
    final lista = registros.value ?? const <AguaRegistro>[];
    final ml = _mlDelDia(lista);

    final barras = barrasDeSerie(
      _periodo,
      _inicio,
      lista.map((r) => MapEntry(r.fecha, r.ml.toDouble())),
    );

    final progreso = objetivo == null
        ? null
        : (ml / objetivo).clamp(0.0, 1.0).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _elegirDia,
                icon: const Icon(Icons.calendar_today),
                label: Text('Día: ${_formato(_dia)}'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _editarObjetivo(objetivo),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Objetivo'),
            ),
          ],
        ),
        if (registros.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No se pudieron cargar los datos: ${registros.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$ml ml',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (objetivo != null) ...[
                  Text(
                    ml >= objetivo
                        ? 'Objetivo de $objetivo ml cumplido 💧'
                        : 'de $objetivo ml (te faltan ${objetivo - ml} ml)',
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progreso, minHeight: 8),
                ] else
                  Text(
                    'Pon un objetivo de agua para ver tu progreso.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: ml == 0 ? null : () => _sumar(lista, -250),
                      child: const Text('-250'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _sumar(lista, 250),
                      child: const Text('+250 (vaso)'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _sumar(lista, 500),
                      child: const Text('+500'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _sumar(lista, 1000),
                      child: const Text('+1000'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SelectorPeriodo(
          periodo: _periodo,
          inicio: _inicio,
          alCambiarPeriodo: (p) => setState(() {
            _periodo = p;
            _inicio = inicioPeriodo(p, DateTime.now());
          }),
          alMover: (pasos) =>
              setState(() => _inicio = desplazar(_periodo, _inicio, pasos)),
        ),
        const SizedBox(height: 8),
        TarjetaGrafica(
          titulo: 'Agua (ml)',
          subtitulo: _periodo == Periodo.anio
              ? 'Media diaria de cada mes'
              : 'Total de cada día',
          objetivo:
              objetivo == null ? null : 'Objetivo: $objetivo ml (línea naranja)',
          grafica: GraficaBarras(
            barras: barras,
            color: Colors.lightBlue,
            empiezaEnCero: true,
            objetivo: objetivo?.toDouble(),
          ),
        ),
      ],
    );
  }
}

class _DialogoAgua extends StatefulWidget {
  const _DialogoAgua({this.actual});

  final int? actual;

  @override
  State<_DialogoAgua> createState() => _DialogoAguaState();
}

class _DialogoAguaState extends State<_DialogoAgua> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.actual?.toString() ?? '');
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) {
      Navigator.pop(context, 0); // 0 = quitar el objetivo
      return;
    }
    final n = int.tryParse(t);
    if (n == null || n < 500 || n > 10000) {
      setState(() => _error = 'Pon un valor entre 500 y 10000 ml.');
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Objetivo de agua'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Agua al día',
              suffixText: 'ml',
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
            'Déjalo vacío para quitar el objetivo.',
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