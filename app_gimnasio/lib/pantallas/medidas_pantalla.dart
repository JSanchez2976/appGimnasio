import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/medidas_repositorio.dart';
import '../datos/providers.dart';
import '../datos/registro_repositorio.dart' show idDia;
import '../graficas/agregacion.dart';
import '../graficas/grafica_barras.dart';
import '../widgets/selector_periodo.dart';
import '../widgets/tarjeta_grafica.dart';

class MedidasPantalla extends ConsumerStatefulWidget {
  const MedidasPantalla({super.key});

  @override
  ConsumerState<MedidasPantalla> createState() => _MedidasPantallaState();
}

class _MedidasPantallaState extends ConsumerState<MedidasPantalla> {
  final _repo = MedidasRepositorio.instancia;

  DateTime _dia = DateTime.now();
  final Map<Medida, TextEditingController> _ctrl = {
    for (final m in Medida.values) m: TextEditingController(),
  };
  final Set<Medida> _editadas = {};
  bool _cargado = false;
  UnidadLongitud _unidadLongitud = UnidadLongitud.cm;

  Medida _medida = Medida.cintura;
  Periodo _periodo = Periodo.mes;
  late DateTime _inicio = inicioPeriodo(Periodo.mes, DateTime.now());

  @override
  void initState() {
    super.initState();
    // Primera carga: rellena el día actual si aún no has escrito nada.
    ref.listenManual<AsyncValue<List<MedidasRegistro>>>(medidasProvider, (
      anterior,
      nuevo,
    ) {
      if (_cargado || !nuevo.hasValue) return;
      _cargado = true;
      if (_ctrl.values.every((c) => c.text.isEmpty)) {
        _rellenar(nuevo.value ?? const <MedidasRegistro>[]);
      }
    }, fireImmediately: true);
    ref.listenManual<AsyncValue<PreferenciasApp>>(preferenciasAppProvider, (
      anterior,
      nuevo,
    ) {
      final unidad = nuevo.value?.unidadLongitud ?? UnidadLongitud.cm;
      if (unidad == _unidadLongitud) return;
      final unidadAnterior = _unidadLongitud;
      _unidadLongitud = unidad;
      for (final medida in Medida.values) {
        if (medida == Medida.grasa) continue;
        final texto = _ctrl[medida]!.text.trim().replaceAll(',', '.');
        final valor = double.tryParse(texto);
        if (valor != null) {
          _ctrl[medida]!.text = _numero(
            unidad.desdeCm(unidadAnterior.aCm(valor)),
          );
        }
      }
      if (mounted) setState(() {});
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  MedidasRegistro? _registroDelDia(List<MedidasRegistro> lista) {
    final id = idDia(_dia);
    for (final r in lista) {
      if (idDia(r.fecha) == id) return r;
    }
    return null;
  }

  String _numero(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Muestra en los campos lo que ya estaba guardado en el día elegido.
  void _rellenar(List<MedidasRegistro> lista) {
    final registro = _registroDelDia(lista);
    _editadas.clear();
    for (final m in Medida.values) {
      final v = registro?.valores[m];
      final mostrado = v == null || m == Medida.grasa
          ? v
          : _unidadLongitud.desdeCm(v);
      _ctrl[m]!.text = mostrado == null ? '' : _numero(mostrado);
    }
  }

  void _irADia(DateTime dia, List<MedidasRegistro> lista) {
    setState(() {
      _dia = dia;
      _rellenar(lista);
    });
  }

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
    if (elegido == null) return;
    final lista = ref.read(medidasProvider).value ?? const <MedidasRegistro>[];
    _irADia(elegido, lista);
  }

  void _guardar() {
    FocusScope.of(context).unfocus();
    final lista = ref.read(medidasProvider).value ?? const <MedidasRegistro>[];
    final previo = _registroDelDia(lista);

    final cambios = <Medida, double?>{};
    for (final m in Medida.values) {
      if (!_editadas.contains(m)) continue;
      final texto = _ctrl[m]!.text.trim().replaceAll(',', '.');
      if (texto.isEmpty) {
        // Campo vaciado: se borra el valor que hubiera guardado.
        if (previo?.valores[m] != null) cambios[m] = null;
        continue;
      }
      final introducido = double.tryParse(texto);
      final v = introducido == null
          ? null
          : (m == Medida.grasa
                ? introducido
                : _unidadLongitud.aCm(introducido));
      final limite = m == Medida.grasa ? 90.0 : 300.0;
      if (v == null || !v.isFinite || v <= 0 || v > limite) {
        _avisar('${m.etiqueta}: el valor no es válido.');
        return;
      }
      cambios[m] = v;
    }

    if (cambios.isEmpty) {
      _avisar('No hay nada que guardar.');
      return;
    }

    _repo.guardar(_dia, cambios).catchError((Object _) {
      _avisar('No se pudieron guardar las medidas.');
    });
    _avisar('Guardado');
  }

  @override
  Widget build(BuildContext context) {
    final registros = ref.watch(medidasProvider);
    final lista = registros.value ?? const <MedidasRegistro>[];
    final previo = _registroDelDia(lista);
    final hayDatos = previo != null && previo.valores.isNotEmpty;
    final esquema = Theme.of(context).colorScheme;
    final m = _medida;

    final barras = barrasDeSerie(
      _periodo,
      _inicio,
      <MapEntry<DateTime, double>>[
        for (final r in lista)
          if (r.valores[m] != null)
            MapEntry(
              r.fecha,
              m == Medida.grasa
                  ? r.valores[m]!
                  : _unidadLongitud.desdeCm(r.valores[m]!),
            ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _elegirDia,
          icon: const Icon(Icons.calendar_today),
          label: Text('Día: ${_formato(_dia)}'),
        ),
        if (hayDatos)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Este día ya tiene medidas guardadas. Puedes editarlas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (registros.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No se pudieron cargar los datos: ${registros.error}',
              style: TextStyle(color: esquema.error),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Medidas del día', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final medida in Medida.values) ...[
                  TextField(
                    controller: _ctrl[medida],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _editadas.add(medida),
                    decoration: InputDecoration(
                      labelText: medida.etiqueta,
                      suffixText: medida == Medida.grasa
                          ? medida.unidad
                          : _unidadLongitud.simbolo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _guardar,
                    child: const Text('Guardar medidas'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('Evolución', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final medida in Medida.values)
              ChoiceChip(
                label: Text(medida.etiqueta),
                selected: _medida == medida,
                onSelected: (_) => setState(() => _medida = medida),
              ),
          ],
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
          titulo:
              '${m.etiqueta} (${m == Medida.grasa ? m.unidad : _unidadLongitud.simbolo})',
          subtitulo: _periodo == Periodo.anio
              ? 'Media de cada mes'
              : 'Medida de cada día',
          grafica: GraficaBarras(
            barras: barras,
            color: esquema.secondary,
            empiezaEnCero: false,
          ),
        ),
      ],
    );
  }
}
