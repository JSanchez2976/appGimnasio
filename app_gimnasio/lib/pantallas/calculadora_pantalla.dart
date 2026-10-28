import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/providers.dart';

class CalculadoraPantalla extends ConsumerStatefulWidget {
  const CalculadoraPantalla({super.key});

  @override
  ConsumerState<CalculadoraPantalla> createState() =>
      _CalculadoraPantallaState();
}

class _CalculadoraPantallaState extends ConsumerState<CalculadoraPantalla> {
  final _ajustes = AjustesRepositorio.instancia;
  final _edad = TextEditingController();
  final _altura = TextEditingController();
  final _peso = TextEditingController();
  final _pesoObjetivo = TextEditingController();
  StreamSubscription<PerfilCalculadora?>? _subs;
  StreamSubscription<Objetivos>? _objetivosSubs;
  String _sexo = 'mujer';
  ActividadCalculadora _actividad = ActividadCalculadora.sedentaria;
  MetaCalculadora _meta = MetaCalculadora.mantener;
  bool _guardando = false;
  bool _pesoObjetivoEditado = false;
  bool _pesoEditado = false;
  bool _alturaEditada = false;
  bool _perfilInicializado = false;
  double? _pesoPerfilKg;
  double? _alturaPerfilCm;
  double? _pesoObjetivoGuardadoKg;
  double? _pesoIntroducidoKg;
  double? _alturaIntroducidaCm;
  double? _pesoObjetivoIntroducidoKg;
  UnidadPeso _unidadPeso = UnidadPeso.kg;
  UnidadLongitud _unidadLongitud = UnidadLongitud.cm;
  DateTime? _actualizadoEn;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subs = _ajustes.perfilCalculadora().listen(
      (perfil) {
        if (!mounted || perfil == null) return;
        setState(() {
          if (!_perfilInicializado) {
            _edad.text = '${perfil.edad}';
            _alturaPerfilCm = perfil.alturaCm;
            _pesoPerfilKg = perfil.pesoKg;
            _alturaIntroducidaCm = perfil.alturaCm;
            _pesoIntroducidoKg = perfil.pesoKg;
            _altura.text = _numero(_unidadLongitud.desdeCm(perfil.alturaCm));
            _peso.text = _numero(_unidadPeso.desdeKg(perfil.pesoKg));
            _sexo = perfil.sexo;
            _actividad = perfil.actividad;
            _meta = perfil.meta;
            _perfilInicializado = true;
          }
          _actualizadoEn = perfil.actualizadoEn;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() => _error = 'No se pudieron cargar tus datos.');
        }
      },
    );
    _objetivosSubs = _ajustes.objetivos().listen((objetivos) {
      if (!mounted) return;
      _pesoObjetivoGuardadoKg = objetivos.pesoKg;
      if (!_pesoObjetivoEditado) {
        _pesoObjetivo.text = objetivos.pesoKg == null
            ? ''
            : _numero(_unidadPeso.desdeKg(objetivos.pesoKg!));
      }
    });
    ref.listenManual<AsyncValue<PreferenciasApp>>(preferenciasAppProvider, (
      anterior,
      nuevo,
    ) {
      final preferencias = nuevo.value ?? const PreferenciasApp();
      final peso = _pesoValor;
      final pesoObjetivoKg = _pesoObjetivoValor;
      final altura = _alturaValor;
      _unidadPeso = preferencias.unidadPeso;
      _unidadLongitud = preferencias.unidadLongitud;
      if (peso != null) _peso.text = _numero(_unidadPeso.desdeKg(peso));
      if (pesoObjetivoKg != null) {
        _pesoObjetivo.text = _numero(_unidadPeso.desdeKg(pesoObjetivoKg));
      }
      if (altura != null) {
        _altura.text = _numero(_unidadLongitud.desdeCm(altura));
      }
      if (mounted) setState(() {});
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _subs?.cancel();
    _objetivosSubs?.cancel();
    _edad.dispose();
    _altura.dispose();
    _peso.dispose();
    _pesoObjetivo.dispose();
    super.dispose();
  }

  String _numero(double n) {
    final redondeado = double.parse(n.toStringAsFixed(1));
    return redondeado == redondeado.roundToDouble()
        ? redondeado.toStringAsFixed(0)
        : redondeado.toStringAsFixed(1);
  }

  String _tiempoDesdeActualizacion(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    final dias = diferencia.isNegative ? 0 : diferencia.inDays;
    if (diferencia.inMinutes < 1) return 'hace menos de un minuto';
    if (diferencia.inHours < 1) {
      final minutos = diferencia.inMinutes;
      return 'hace $minutos ${minutos == 1 ? 'minuto' : 'minutos'}';
    }
    if (diferencia.inDays < 1) {
      final horas = diferencia.inHours;
      return 'hace $horas ${horas == 1 ? 'hora' : 'horas'}';
    }
    if (dias < 7) return 'hace $dias ${dias == 1 ? 'día' : 'días'}';
    if (dias < 60) {
      final semanas = dias ~/ 7;
      return 'hace $semanas ${semanas == 1 ? 'semana' : 'semanas'}';
    }
    if (dias < 365) {
      final meses = dias ~/ 30;
      return 'hace $meses ${meses == 1 ? 'mes' : 'meses'}';
    }
    final anios = dias ~/ 365;
    return 'hace $anios ${anios == 1 ? 'año' : 'años'}';
  }

  int? get _edadValor => int.tryParse(_edad.text.trim());
  double? _decimal(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  double? get _alturaValor {
    if (_alturaEditada) {
      return _alturaIntroducidaCm ??
          ((_decimal(_altura.text) == null)
              ? null
              : _unidadLongitud.aCm(_decimal(_altura.text)!));
    }
    if (!_alturaEditada && _alturaPerfilCm != null) return _alturaPerfilCm;
    final valor = _decimal(_altura.text);
    return valor == null ? null : _unidadLongitud.aCm(valor);
  }

  double? get _pesoValor {
    if (_pesoEditado) {
      return _pesoIntroducidoKg ??
          ((_decimal(_peso.text) == null)
              ? null
              : _unidadPeso.aKg(_decimal(_peso.text)!));
    }
    if (!_pesoEditado && _pesoPerfilKg != null) return _pesoPerfilKg;
    final valor = _decimal(_peso.text);
    return valor == null ? null : _unidadPeso.aKg(valor);
  }

  double? get _mantenimiento {
    final edad = _edadValor;
    final altura = _alturaValor;
    final peso = _pesoValor;
    if (edad == null ||
        edad < 19 ||
        edad > 78 ||
        altura == null ||
        !altura.isFinite ||
        altura < 100 ||
        altura > 250 ||
        peso == null ||
        !peso.isFinite ||
        peso < 30 ||
        peso > 300) {
      return null;
    }
    final base = 10 * peso + 6.25 * altura - 5 * edad;
    final gastoReposo = base + (_sexo == 'hombre' ? 5 : -161);
    return gastoReposo * _actividad.factor;
  }

  int? get _objetivoCalculado {
    final mantenimiento = _mantenimiento;
    if (mantenimiento == null) return null;
    final ajuste = switch (_meta) {
      MetaCalculadora.perder => -300,
      MetaCalculadora.mantener => 0,
      MetaCalculadora.ganar => 300,
    };
    return ((mantenimiento + ajuste) / 50).round() * 50;
  }

  String? _validar() {
    final edad = _edadValor;
    final altura = _alturaValor;
    final peso = _pesoValor;
    final pesoObjetivo = _pesoObjetivoValor;
    if (edad == null || edad < 19 || edad > 78) {
      return 'La fórmula está estudiada para adultos de 19 a 78 años.';
    }
    if (altura == null ||
        !altura.isFinite ||
        altura < 100 ||
        altura > 250) {
      return 'Revisa la altura (de 100 a 250 cm).';
    }
    if (peso == null || !peso.isFinite || peso < 30 || peso > 300) {
      return 'Revisa el peso (de 30 a 300 kg).';
    }
    if (_meta == MetaCalculadora.ganar &&
        (pesoObjetivo == null ||
            !pesoObjetivo.isFinite ||
            pesoObjetivo <= peso ||
            pesoObjetivo > 500)) {
      return 'Para ganar peso, indica un objetivo superior a tu peso actual.';
    }
    return null;
  }

  Future<void> _guardarComoObjetivo() async {
    FocusScope.of(context).unfocus();
    final error = _validar();
    final calculado = _objetivoCalculado;
    if (error != null || calculado == null) {
      setState(() => _error = error ?? 'Completa tus datos para calcular.');
      return;
    }

    final pesoKg = _pesoValor!;
    final alturaCm = _alturaValor!;
    final pesoObjetivoKg = _pesoObjetivoValor;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _ajustes.guardarPerfilCalculadora(
        PerfilCalculadora(
          edad: _edadValor!,
          sexo: _sexo,
          alturaCm: alturaCm,
          pesoKg: pesoKg,
          actividad: _actividad,
          meta: _meta,
        ),
      );
      await _ajustes.guardarObjetivosCalculadora(
        calorias: calculado,
        pesoObjetivoKg: _meta == MetaCalculadora.ganar ? pesoObjetivoKg : null,
      );
      if (!mounted) return;
      _pesoPerfilKg = pesoKg;
      _alturaPerfilCm = alturaCm;
      _pesoIntroducidoKg = pesoKg;
      _alturaIntroducidaCm = alturaCm;
      _pesoEditado = false;
      _alturaEditada = false;
      if (_meta == MetaCalculadora.ganar) {
        _pesoObjetivoGuardadoKg = pesoObjetivoKg;
        _pesoObjetivoIntroducidoKg = pesoObjetivoKg;
        _pesoObjetivoEditado = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Objetivo diario guardado: $calculado kcal.')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar el objetivo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  double? get _pesoObjetivoValor {
    if (_pesoObjetivoEditado) {
      return _pesoObjetivoIntroducidoKg ??
          ((_decimal(_pesoObjetivo.text) == null)
              ? null
              : _unidadPeso.aKg(_decimal(_pesoObjetivo.text)!));
    }
    if (!_pesoObjetivoEditado && _pesoObjetivoGuardadoKg != null) {
      return _pesoObjetivoGuardadoKg;
    }
    final valor = _decimal(_pesoObjetivo.text);
    return valor == null ? null : _unidadPeso.aKg(valor);
  }

  @override
  Widget build(BuildContext context) {
    final mantenimiento = _mantenimiento;
    final objetivo = _objetivoCalculado;
    final esquema = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Calculadora de calorías',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Una estimación orientativa a partir de tus datos y actividad.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.update),
            title: Text(
              _actualizadoEn == null
                  ? 'Aún no has guardado estos datos'
                  : 'Perfil guardado ${_tiempoDesdeActualizacion(_actualizadoEn!)}',
            ),
            subtitle: const Text(
              'Te recomendamos revisarlos cada 4 semanas, o antes si cambia '
              'tu peso o tu actividad.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _edad,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Edad',
            suffixText: 'años',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(_sexo),
          initialValue: _sexo,
          decoration: const InputDecoration(
            labelText: 'Sexo usado en la fórmula',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'mujer', child: Text('Mujer')),
            DropdownMenuItem(value: 'hombre', child: Text('Hombre')),
          ],
          onChanged: (value) => setState(() => _sexo = value ?? _sexo),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _altura,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Altura',
            suffixText: _unidadLongitud.simbolo,
            border: OutlineInputBorder(),
          ),
          onChanged: (texto) => setState(() {
            _alturaEditada = true;
            final valor = _decimal(texto);
            _alturaIntroducidaCm = valor == null
                ? null
                : _unidadLongitud.aCm(valor);
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _peso,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Peso actual',
            suffixText: _unidadPeso.simbolo,
            border: OutlineInputBorder(),
          ),
          onChanged: (texto) => setState(() {
            _pesoEditado = true;
            final valor = _decimal(texto);
            _pesoIntroducidoKg = valor == null ? null : _unidadPeso.aKg(valor);
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ActividadCalculadora>(
          key: ValueKey(_actividad),
          initialValue: _actividad,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Nivel de actividad',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final actividad in ActividadCalculadora.values)
              DropdownMenuItem(
                value: actividad,
                child: Text(actividad.etiqueta),
              ),
          ],
          onChanged: (value) =>
              setState(() => _actividad = value ?? _actividad),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MetaCalculadora>(
          key: ValueKey(_meta),
          initialValue: _meta,
          decoration: const InputDecoration(
            labelText: 'Meta',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: MetaCalculadora.perder,
              child: Text('Perder peso'),
            ),
            DropdownMenuItem(
              value: MetaCalculadora.mantener,
              child: Text('Mantener peso'),
            ),
            DropdownMenuItem(
              value: MetaCalculadora.ganar,
              child: Text('Ganar peso'),
            ),
          ],
          onChanged: (value) => setState(() => _meta = value ?? _meta),
        ),
        if (_meta == MetaCalculadora.ganar) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _pesoObjetivo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '¿A qué peso quieres llegar?',
              suffixText: _unidadPeso.simbolo,
              border: OutlineInputBorder(),
            ),
            onChanged: (texto) {
              _pesoObjetivoEditado = true;
              final valor = _decimal(texto);
              _pesoObjetivoIntroducidoKg = valor == null
                  ? null
                  : _unidadPeso.aKg(valor);
              setState(() => _error = null);
            },
          ),
        ],
        const SizedBox(height: 16),
        if (mantenimiento != null && objetivo != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimación diaria',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _fila(
                    'Mantenimiento aproximado',
                    '${mantenimiento.round()} kcal',
                  ),
                  _fila('Objetivo sugerido', '$objetivo kcal'),
                  const SizedBox(height: 4),
                  Text(switch (_meta) {
                    MetaCalculadora.perder =>
                      'El objetivo sugerido resta 300 kcal al mantenimiento.',
                    MetaCalculadora.mantener =>
                      'El objetivo sugerido coincide con el mantenimiento.',
                    MetaCalculadora.ganar =>
                      'El objetivo sugerido suma 300 kcal al mantenimiento.',
                  }, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: esquema.error)),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardarComoObjetivo,
          icon: _guardando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.flag_outlined),
          label: const Text('Guardar kcal como objetivo'),
        ),
        const SizedBox(height: 8),
        Text(
          'Es un cálculo orientativo, no un consejo médico. Tu gasto real puede variar; '
          'ajusta el objetivo según tu evolución.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _fila(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(etiqueta)),
        const SizedBox(width: 12),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
