import 'dart:async';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/notas_repositorio.dart';
import '../datos/ajustes_repositorio.dart';
import '../datos/providers.dart';
import '../datos/registro_repositorio.dart';
import '../datos/servicio_recordatorios.dart';

class RegistroPantalla extends ConsumerStatefulWidget {
  const RegistroPantalla({super.key});

  @override
  ConsumerState<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends ConsumerState<RegistroPantalla> {
  final _repo = RegistroRepositorio.instancia;
  final _notasRepo = NotasRepositorio.instancia;

  StreamSubscription<List<PesoRegistro>>? _subPesos;
  StreamSubscription<List<CaloriasRegistro>>? _subCalorias;
  List<PesoRegistro> _pesos = const [];
  List<CaloriasRegistro> _calorias = const [];
  bool _pesosCargados = false;
  bool _caloriasCargadas = false;
  bool _notasCargadas = false;
  bool _pesoEditado = false;
  double? _pesoIntroducidoKg;
  UnidadPeso _unidadPeso = UnidadPeso.kg;

  DateTime _dia = DateTime.now();
  final _pesoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
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
    _subPesos = _repo.pesos().listen((lista) {
      setState(() {
        _pesos = lista;
        if (_pesoEditado) {
          final escrito = double.tryParse(
            _pesoCtrl.text.trim().replaceAll(',', '.'),
          );
          final guardado = _pesoDelDia();
          final introducidoKg =
              _pesoIntroducidoKg ??
              (escrito == null ? null : _unidadPeso.aKg(escrito));
          if ((_pesoCtrl.text.trim().isEmpty && guardado == null) ||
              (escrito != null &&
                  guardado != null &&
                  introducidoKg == guardado.kg)) {
            _pesoEditado = false;
            _pesoIntroducidoKg = guardado?.kg;
          }
        }
        // Primera carga: rellena el día actual si aún no has escrito nada.
        if (!_pesosCargados) {
          _pesosCargados = true;
          if (_pesoCtrl.text.isEmpty) _rellenarPeso();
        }
      });
    }, onError: (Object _) => _avisar('No se pudieron cargar los pesos.'));
    _subCalorias = _repo.calorias().listen((lista) {
      setState(() {
        _calorias = lista;
        if (!_caloriasCargadas) {
          _caloriasCargadas = true;
          if (_calCtrl.values.every((c) => c.text.isEmpty)) {
            _rellenarCalorias();
          }
        }
      });
    }, onError: (Object _) => _avisar('No se pudieron cargar las calorías.'));
    ref.listenManual<AsyncValue<List<NotaRegistro>>>(notasProvider, (
      anterior,
      nuevo,
    ) {
      if (_notasCargadas || !nuevo.hasValue) return;
      _notasCargadas = true;
      if (_notaCtrl.text.isEmpty) _rellenarNota();
    }, fireImmediately: true);
    ref.listenManual<AsyncValue<PreferenciasApp>>(preferenciasAppProvider, (
      anterior,
      nuevo,
    ) {
      final unidad = nuevo.value?.unidadPeso ?? UnidadPeso.kg;
      if (unidad == _unidadPeso) return;
      final escrito = double.tryParse(
        _pesoCtrl.text.trim().replaceAll(',', '.'),
      );
      final kg = _pesoEditado
          ? (_pesoIntroducidoKg ??
                (escrito == null ? null : _unidadPeso.aKg(escrito)))
          : (_pesoDelDia()?.kg);
      _unidadPeso = unidad;
      _pesoCtrl.text = kg == null ? '' : _kgATexto(_unidadPeso.desdeKg(kg));
      if (mounted) setState(() {});
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _subPesos?.cancel();
    _subCalorias?.cancel();
    _pesoCtrl.dispose();
    _notaCtrl.dispose();
    for (final c in _calCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<NotaRegistro> get _notas =>
      ref.read(notasProvider).value ?? const <NotaRegistro>[];

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

  NotaRegistro? _notaDelDia(List<NotaRegistro> lista) {
    final id = idDia(_dia);
    for (final n in lista) {
      if (idDia(n.fecha) == id) return n;
    }
    return null;
  }

  String _kgATexto(double kg) {
    if (_unidadPeso == UnidadPeso.lb) {
      final redondeado = double.parse(kg.toStringAsFixed(1));
      return redondeado == redondeado.roundToDouble()
          ? redondeado.toStringAsFixed(0)
          : redondeado.toStringAsFixed(1);
    }
    return kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();
  }

  void _rellenarPeso() {
    final p = _pesoDelDia();
    _pesoCtrl.text = p == null ? '' : _kgATexto(_unidadPeso.desdeKg(p.kg));
    _pesoEditado = false;
    _pesoIntroducidoKg = p?.kg;
  }

  void _rellenarCalorias() {
    final c = _caloriasDelDia();
    for (final f in Franja.values) {
      final v = c?.porFranja[f] ?? 0;
      _calCtrl[f]!.text = v > 0 ? '$v' : '';
    }
  }

  void _rellenarNota() {
    _notaCtrl.text = _notaDelDia(_notas)?.texto ?? '';
  }

  /// Cambia de día y muestra en los campos lo que ya estaba guardado.
  void _irADia(DateTime dia) {
    setState(() {
      _dia = dia;
      _rellenarPeso();
      _rellenarCalorias();
      _rellenarNota();
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
    final pesoIntroducido = double.tryParse(textoPeso);
    final previoPeso = _pesoDelDia();
    final introducidoKg = _pesoEditado
        ? (_pesoIntroducidoKg ??
              (pesoIntroducido == null
                  ? null
                  : _unidadPeso.aKg(pesoIntroducido)))
        : null;
    final mismoPeso =
        previoPeso != null &&
        (introducidoKg == previoPeso.kg ||
            (!_pesoEditado &&
                pesoIntroducido == _unidadPeso.desdeKg(previoPeso.kg)));
    final kg = !_pesoEditado || mismoPeso || pesoIntroducido == null
        ? null
        : introducidoKg;
    if (_pesoEditado &&
        textoPeso.isNotEmpty &&
        !mismoPeso &&
        (kg == null || !kg.isFinite || kg <= 0 || kg > 500)) {
      _avisar('El peso no es válido.');
      return;
    }

    final previoCal = _caloriasDelDia();

    final porFranja = <Franja, int?>{};
    for (final f in Franja.values) {
      final texto = _calCtrl[f]!.text.trim();
      final n = int.tryParse(texto);
      if (texto.isNotEmpty && (n == null || n > 10000)) {
        _avisar('Las calorías de cada franja deben estar entre 0 y 10000.');
        return;
      }
      if (texto.isNotEmpty && n != null) {
        porFranja[f] = n;
      } else if ((previoCal?.porFranja[f] ?? 0) > 0) {
        porFranja[f] = null; // campo vaciado: se borra el valor guardado
      }
    }
    final borrarPeso = _pesoEditado && textoPeso.isEmpty && previoPeso != null;

    final textoNota = _notaCtrl.text.trim();
    final notaPrevia = _notaDelDia(_notas);
    final guardarNota =
        textoNota.isNotEmpty && textoNota != (notaPrevia?.texto ?? '');
    final borrarNota = textoNota.isEmpty && notaPrevia != null;

    if (kg == null &&
        !borrarPeso &&
        porFranja.isEmpty &&
        !guardarNota &&
        !borrarNota) {
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
    if (guardarNota) {
      _notasRepo.guardar(_dia, textoNota).catchError((Object _) {
        _avisar('No se pudo guardar la nota.');
      });
    } else if (borrarNota) {
      _notasRepo.borrar(_dia).catchError((Object _) {
        _avisar('No se pudo borrar la nota.');
      });
    }

    if (idDia(_dia) == idDia(DateTime.now())) {
      final quedaPeso = kg != null || (previoPeso != null && !borrarPeso);
      var totalKcal = 0;
      for (final franja in Franja.values) {
        totalKcal += porFranja.containsKey(franja)
            ? (porFranja[franja] ?? 0)
            : (previoCal?.porFranja[franja] ?? 0);
      }
      unawaited(
        ServicioRecordatorios.instancia
            .actualizarDespuesDeRegistro(quedaPeso || totalKcal > 0)
            .catchError((Object _) {}),
      );
    }

    _avisar('Guardado');
  }

  @override
  Widget build(BuildContext context) {
    final notas = ref.watch(notasProvider).value ?? const <NotaRegistro>[];
    final hayDatos =
        _pesoDelDia() != null ||
        (_caloriasDelDia()?.total ?? 0) > 0 ||
        _notaDelDia(notas) != null;
    final caloriasRecientes = _calorias
        .where((c) => c.total > 0)
        .take(3)
        .toList();

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
          onChanged: (texto) {
            _pesoEditado = true;
            final valor = double.tryParse(texto.trim().replaceAll(',', '.'));
            _pesoIntroducidoKg = valor == null ? null : _unidadPeso.aKg(valor);
          },
          decoration: InputDecoration(
            labelText: 'Peso (${_unidadPeso.simbolo})',
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
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _nombres[f],
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        Text('Nota del día', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _notaCtrl,
          maxLines: 3,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Cena fuera, cumpleaños, malestar...',
            border: OutlineInputBorder(),
          ),
        ),
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
          for (final p in _pesos.take(3))
            ListTile(
              dense: true,
              title: Text(_formato(p.fecha)),
              trailing: Text(
                '${_kgATexto(_unidadPeso.desdeKg(p.kg))} ${_unidadPeso.simbolo}',
              ),
              onTap: () => _irADia(p.fecha),
            ),
        const SizedBox(height: 16),
        Text(
          'Últimas calorías',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
