import 'package:flutter/material.dart';

import '../datos/notas_repositorio.dart';
import '../graficas/agregacion.dart';

class NotasTarjeta extends StatelessWidget {
  const NotasTarjeta({
    super.key,
    required this.periodo,
    required this.inicio,
    required this.notas,
  });

  final Periodo periodo;
  final DateTime inicio;
  final List<NotaRegistro> notas;

  static const _maximo = 15;

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final delPeriodo = notas
        .where((n) => estaEnPeriodo(periodo, inicio, n.fecha))
        .toList();
    if (delPeriodo.isEmpty) return const SizedBox.shrink();

    final visibles = delPeriodo.take(_maximo).toList();
    final restantes = delPeriodo.length - visibles.length;
    final estilo = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notas', style: estilo.titleMedium),
            Text(
              'Los puntos bajo el eje marcan los días con nota.',
              style: estilo.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final n in visibles)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(_fecha(n.fecha), style: estilo.labelLarge),
                title: Text(n.texto, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            if (restantes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Y $restantes más en este periodo.',
                  style: estilo.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}