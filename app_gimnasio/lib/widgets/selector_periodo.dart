import 'package:flutter/material.dart';

import '../graficas/agregacion.dart';

class SelectorPeriodo extends StatelessWidget {
  const SelectorPeriodo({
    super.key,
    required this.periodo,
    required this.inicio,
    required this.alCambiarPeriodo,
    required this.alMover,
  });

  final Periodo periodo;
  final DateTime inicio;
  final ValueChanged<Periodo> alCambiarPeriodo;
  final ValueChanged<int> alMover;

  bool get _puedeAvanzar =>
      !desplazar(periodo, inicio, 1).isAfter(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<Periodo>(
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          segments: const [
            ButtonSegment(value: Periodo.semana, label: Text('Semana')),
            ButtonSegment(value: Periodo.mes, label: Text('Mes')),
            ButtonSegment(value: Periodo.anio, label: Text('Año')),
          ],
          selected: {periodo},
          onSelectionChanged: (s) => alCambiarPeriodo(s.first),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => alMover(-1),
            ),
            Expanded(
              child: Text(
                tituloPeriodo(periodo, inicio),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: _puedeAvanzar ? () => alMover(1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
