import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../datos/ajustes_repositorio.dart';

// Porcentajes del objetivo de calorías (provisionales, se pueden retocar).
const double avisoPorcentaje = 0.10;
const double limitePorcentaje = 0.20;

/// Diálogo para editar objetivos y márgenes. Devuelve el [Objetivos] nuevo
/// con Navigator.pop, o null si se cancela.
class DialogoObjetivos extends StatefulWidget {
  const DialogoObjetivos({
    super.key,
    required this.actual,
    required this.unidadPeso,
  });

  final Objetivos actual;
  final UnidadPeso unidadPeso;

  @override
  State<DialogoObjetivos> createState() => _DialogoObjetivosState();
}

class _DialogoObjetivosState extends State<DialogoObjetivos> {
  late final TextEditingController _peso = TextEditingController(
    text: widget.actual.pesoKg == null
        ? ''
        : _formato(widget.unidadPeso.desdeKg(widget.actual.pesoKg!)),
  );
  late final TextEditingController _cal = TextEditingController(
    text: widget.actual.calorias?.toString() ?? '',
  );
  late final TextEditingController _bajo = TextEditingController(
    text: widget.actual.calorias == null
        ? ''
        : '${widget.actual.margenBajoEfectivo}',
  );
  late final TextEditingController _alto = TextEditingController(
    text: widget.actual.calorias == null
        ? ''
        : '${widget.actual.margenAltoEfectivo}',
  );

  String? _error;
  String? _aviso;
  bool _avisoMostrado = false;
  bool _pesoEditado = false;

  String _formato(double valor) {
    if (widget.unidadPeso == UnidadPeso.lb) {
      final redondeado = double.parse(valor.toStringAsFixed(1));
      return redondeado == redondeado.roundToDouble()
          ? redondeado.toStringAsFixed(0)
          : redondeado.toStringAsFixed(1);
    }
    return valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : '$valor';
  }

  @override
  void dispose() {
    _peso.dispose();
    _cal.dispose();
    _bajo.dispose();
    _alto.dispose();
    super.dispose();
  }

  /// Vacío = valor por defecto. Devuelve null si el número no es válido.
  int? _leerMargen(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return Objetivos.margenPorDefecto;
    return int.tryParse(t);
  }

  /// Al tocar un margen: quita el error o el aviso que hubiera.
  void _alCambiar() {
    if (_avisoMostrado || _aviso != null || _error != null) {
      setState(() {
        _avisoMostrado = false;
        _aviso = null;
        _error = null;
      });
    }
  }

  /// Al tocar las calorías: además refresca el diálogo para habilitar
  /// o deshabilitar los campos de margen.
  void _alCambiarCalorias() {
    setState(() {
      _avisoMostrado = false;
      _aviso = null;
      _error = null;
    });
  }

  void _guardar() {
    final textoPeso = _peso.text.trim().replaceAll(',', '.');
    final pesoIntroducido = textoPeso.isEmpty
        ? null
        : double.tryParse(textoPeso);
    final kg = !_pesoEditado
        ? widget.actual.pesoKg
        : pesoIntroducido == null
        ? null
        : widget.unidadPeso.aKg(pesoIntroducido);
    if (_pesoEditado &&
        textoPeso.isNotEmpty &&
        (kg == null || !kg.isFinite || kg < 20 || kg > 500)) {
      setState(() {
        _error = 'El peso objetivo no es válido.';
        _aviso = null;
      });
      return;
    }

    final textoCal = _cal.text.trim();
    final kcal = textoCal.isEmpty ? null : int.tryParse(textoCal);
    if (textoCal.isNotEmpty && (kcal == null || kcal < 500 || kcal > 10000)) {
      setState(() {
        _error = 'Las calorías objetivo no son válidas.';
        _aviso = null;
      });
      return;
    }

    int? mBajo;
    int? mAlto;
    if (kcal != null) {
      mBajo = _leerMargen(_bajo.text);
      mAlto = _leerMargen(_alto.text);
      if (mBajo == null || mAlto == null) {
        setState(() {
          _error = 'Los márgenes no son válidos.';
          _aviso = null;
        });
        return;
      }

      final limite = (kcal * limitePorcentaje).floor();
      if (mBajo > limite || mAlto > limite) {
        setState(() {
          _error =
              'Ese margen es demasiado grande: con un objetivo de '
              '$kcal kcal el máximo es $limite kcal '
              '(el ${(limitePorcentaje * 100).round()} % de tu objetivo).';
          _aviso = null;
        });
        return;
      }

      final umbralAviso = kcal * avisoPorcentaje;
      if ((mBajo > umbralAviso || mAlto > umbralAviso) && !_avisoMostrado) {
        final porcentaje = (avisoPorcentaje * 100).round();
        setState(() {
          _error = null;
          _avisoMostrado = true;
          _aviso =
              'Ojo, con un margen tan amplio tu objetivo pierde fuerza 😅 '
              'El $porcentaje % de tu objetivo de $kcal kcal son '
              '${umbralAviso.round()} kcal, y tu margen lo supera. '
              '¿Seguro que quieres dejarlo así? Tú decides: pulsa '
              '"Guardar igualmente" o cámbialo.';
        });
        return;
      }
    }

    Navigator.pop(
      context,
      Objetivos(
        pesoKg: kg,
        calorias: kcal,
        margenBajo: mBajo,
        margenAlto: mAlto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final hayCalorias = _cal.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Tus objetivos'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _peso,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _pesoEditado = true,
              decoration: InputDecoration(
                labelText: 'Peso objetivo (${widget.unidadPeso.simbolo})',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cal,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _alCambiarCalorias(),
              decoration: const InputDecoration(
                labelText: 'Calorías objetivo (kcal al día)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Margen de calorías',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              hayCalorias
                  ? 'Cuánto puedes quedarte por debajo o pasarte y aun así '
                        'contar el día como cumplido. Vacío = '
                        '${Objetivos.margenPorDefecto}.'
                  : 'Pon primero unas calorías objetivo para poder ajustar '
                        'el margen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bajo,
                    enabled: hayCalorias,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _alCambiar(),
                    decoration: InputDecoration(
                      labelText: 'Por debajo',
                      hintText: '${Objetivos.margenPorDefecto}',
                      suffixText: 'kcal',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _alto,
                    enabled: hayCalorias,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _alCambiar(),
                    decoration: InputDecoration(
                      labelText: 'Por arriba',
                      hintText: '${Objetivos.margenPorDefecto}',
                      suffixText: 'kcal',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: esquema.error)),
            ],
            if (_aviso != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_aviso!),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Deja un objetivo vacío para quitarlo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(_avisoMostrado ? 'Guardar igualmente' : 'Guardar'),
        ),
      ],
    );
  }
}
