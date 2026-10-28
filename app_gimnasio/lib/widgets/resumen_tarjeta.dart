import 'package:flutter/material.dart';

import '../datos/ajustes_repositorio.dart';
import '../graficas/agregacion.dart';

/// Dibuja el resumen del periodo. Los cálculos viven en `resumenDe`.
class ResumenTarjeta extends StatelessWidget {
  const ResumenTarjeta({
    super.key,
    required this.periodo,
    required this.inicio,
    required this.resumen,
    required this.hayObjetivoCalorias,
    required this.kcalRestantesHoy,
    required this.estimacionPeso,
    required this.unidadPeso,
  });

  final Periodo periodo;
  final DateTime inicio;
  final Resumen resumen;
  final bool hayObjetivoCalorias;
  final int? kcalRestantesHoy;
  final String? estimacionPeso;
  final UnidadPeso unidadPeso;

  String _peso(double kg) =>
      '${unidadPeso.desdeKg(kg).toStringAsFixed(1)} ${unidadPeso.simbolo}';

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(etiqueta)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = resumen;

    final titulo = switch (periodo) {
      Periodo.semana => 'Resumen de la semana',
      Periodo.mes => 'Resumen del mes',
      Periodo.anio => 'Resumen del año',
    };
    final anterior = switch (periodo) {
      Periodo.semana => 'la semana anterior',
      Periodo.mes => 'el mes anterior',
      Periodo.anio => 'el año anterior',
    };

    final n = numeroBarras(periodo, inicio);
    final dias = periodo == Periodo.anio
        ? '${r.diasRegistrados} días'
        : '${r.diasRegistrados} de $n días';

    final media = r.mediaCalorias == null
        ? 'Sin datos'
        : '${r.mediaCalorias!.round()} kcal al día';

    final String rango;
    if (!hayObjetivoCalorias) {
      rango = 'Pon un objetivo de calorías';
    } else if (r.diasConCalorias == 0) {
      rango = 'Sin datos';
    } else {
      rango = '${r.diasEnRango ?? 0} de ${r.diasConCalorias} días';
    }

    final pesoMedio = r.pesoMedio == null ? 'Sin datos' : _peso(r.pesoMedio!);

    final String variacion;
    if (r.variacionPeso == null) {
      variacion = 'Sin datos para comparar';
    } else {
      final v = r.variacionPeso!;
      if (v.abs() < 0.05) {
        variacion = '0.0 ${unidadPeso.simbolo}';
      } else {
        variacion = '${v > 0 ? '+' : ''}${_peso(v.abs())}';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            Text(
              tituloPeriodo(periodo, inicio),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _fila('Días registrados', dias),
            _fila('Media de calorías', media),
            if (periodo == Periodo.semana)
              _fila(
                'Kcal restantes',
                kcalRestantesHoy == null ? 'Sin objetivo' : '$kcalRestantesHoy',
              ),
            if (periodo == Periodo.semana && estimacionPeso != null)
              _fila('Tiempo hasta el peso objetivo', estimacionPeso!),
            if (periodo == Periodo.semana && estimacionPeso != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Estimación simplificada: el gasto real puede variar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            _fila('Días dentro del rango', rango),
            _fila('Peso medio', pesoMedio),
            _fila('Peso respecto a $anterior', variacion),
          ],
        ),
      ),
    );
  }
}
