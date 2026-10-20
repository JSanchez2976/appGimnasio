import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/registro_repositorio.dart';

class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key});

  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  final _repo = RegistroRepositorio.instancia;

  StreamSubscription<List<PesoRegistro>>? _subPesos;
  StreamSubscription<List<CaloriasRegistro>>? _subCalorias;
  List<PesoRegistro> _pesos = const [];
  List<CaloriasRegistro> _calorias = const [];
  bool _pesosCargados = false;
  bool _caloriasCargadas = false;

  DateTime _dia = DateTime.now();
  final _pesoCtrl = TextEditingController();
  final Map<Franja, TextEditingController> _calCtrl = {
    for (final f in Franja.values) f: TextEditingController(),
  };

  static const _nombres = {
    Franja.desayuno: 'Desayuno',
    Franja.comida: 'Comida',
    Franja.cena: 'Cena',
    Franja.snacks: 'Snacks',
  };

  @override
  void initState() {
    super.initState();
    _subPesos = _repo.pesos().listen(
      (lista) {
        setState(() {
          _pesos = lista;
          // Primera carga: rellena el día actual si aún no has escrito nada.
          if (!_pesosCargados) {
            _pesosCargados = true;
            if (_pesoCtrl.text.isEmpty) _rellenarPeso();
          }
        });
      },
      onError: (Object _) => _avisar('No se pudieron cargar los pesos.'),
    );
    _subCalorias = _repo.calorias().listen(
      (lista) {
        setState(() {
          _calorias = lista;
          if (!_caloriasCargadas) {
            _caloriasCargadas = true;
            if (_calCtrl.values.every((c) => c.text.isEmpty)) {
              _rellenarCalorias();
            }
          }
        });
      },
      onError: (Object _) => _avisar('No se pudieron cargar las calorías.'),
    );
  }

  @override
  void dispose() {
    _subPesos?.cancel();
    _subCalorias?.cancel();
    _pesoCtrl.dispose();
    for (final c in _calCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  PesoRegistro? _pesoDelDia() {
    final id = idDia(_dia);
    for (final p in _pesos) {
      if (idDia(p.fecha) == id) return p;
    }
    return null;
  }

  CaloriasRegistro? _caloriasDelDia() {
    final id = idDia(_dia);
    for (final c in _calorias) {
      if (idDia(c.fecha) == id) return c;
    }
    return null;
  }

  String _kgATexto(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();

  void _rellenarPeso() {
    final p = _pesoDelDia();
    _pesoCtrl.text = p == null ? '' : _kgATexto(p.kg);
  }

  void _rellenarCalorias() {
    final c = _caloriasDelDia();
    for (final f in Franja.values) {
      final v = c?.porFranja[f] ?? 0;
      _calCtrl[f]!.text = v > 0 ? '$v' : '';
    }
  }

  /// Cambia de día y muestra en los campos lo que ya estaba guardado.
  void _irADia(DateTime dia) {
    setState(() {
      _dia = dia;
      _rellenarPeso();
      _rellenarCalorias();
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
    if (elegido != null) _irADia(elegido);
  }

  void _guardar() {
    FocusScope.of(context).unfocus();

    final textoPeso = _pesoCtrl.text.trim().replaceAll(',', '.');
    final kg = double.tryParse(textoPeso);
    if (textoPeso.isNotEmpty && (kg == null || kg <= 0 || kg > 500)) {
      _avisar('El peso no es válido.');
      return;
    }

    final previoPeso = _pesoDelDia();
    final previoCal = _caloriasDelDia();

    final porFranja = <Franja, int?>{};
    for (final f in Franja.values) {
      final n = int.tryParse(_calCtrl[f]!.text.trim());
      if (n != null) {
        porFranja[f] = n;
      } else if ((previoCal?.porFranja[f] ?? 0) > 0) {
        porFranja[f] = null; // campo vaciado: se borra el valor guardado
      }
    }
    final borrarPeso = textoPeso.isEmpty && previoPeso != null;

    if (kg == null && !borrarPeso && porFranja.isEmpty) {
      _avisar('No hay nada que guardar.');
      return;
    }

    // No esperamos al servidor: Firestore guarda en el móvil al instante
    // y sincroniza cuando hay conexión.
    if (kg != null) {
      _repo.guardarPeso(_dia, kg).catchError((Object _) {
        _avisar('No se pudo guardar el peso.');
      });
    } else if (borrarPeso) {
      _repo.borrarPeso(_dia).catchError((Object _) {
        _avisar('No se pudo borrar el peso.');
      });
    }
    if (porFranja.isNotEmpty) {
      _repo.guardarCalorias(_dia, porFranja).catchError((Object _) {
        _avisar('No se pudieron guardar las calorías.');
      });
    }

    _avisar('Guardado');
  }

  @override
  Widget build(BuildContext context) {
    final hayDatos = _pesoDelDia() != null ||
        (_caloriasDelDia()?.total ?? 0) > 0;
    final caloriasRecientes =
        _calorias.where((c) => c.total > 0).take(7).toList();

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
              'Este día ya tiene datos guardados. Puedes editarlos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _pesoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso (kg)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Calorías (kcal)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final f in Franja.values) ...[
          TextField(
            controller: _calCtrl[f],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _nombres[f],
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        const SizedBox(height: 32),
        Text('Últimos pesos', style: Theme.of(context).textTheme.titleMedium),
        if (_pesos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aún no hay pesos registrados.'),
          )
        else
          for (final p in _pesos.take(7))
            ListTile(
              dense: true,
              title: Text(_formato(p.fecha)),
              trailing: Text('${_kgATexto(p.kg)} kg'),
              onTap: () => _irADia(p.fecha),
            ),
        const SizedBox(height: 16),
        Text('Últimas calorías',
            style: Theme.of(context).textTheme.titleMedium),
        if (caloriasRecientes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aún no hay calorías registradas.'),
          )
        else
          for (final c in caloriasRecientes)
            ListTile(
              dense: true,
              title: Text(_formato(c.fecha)),
              subtitle: Text(
                Franja.values
                    .map((f) => '${_nombres[f]}: ${c.porFranja[f]}')
                    .join(' · '),
              ),
              trailing: Text('${c.total} kcal'),
              onTap: () => _irADia(c.fecha),
            ),
      ],
    );
  }
}