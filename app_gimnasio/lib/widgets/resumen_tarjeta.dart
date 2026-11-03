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

  Widget _fila(BuildContext context, String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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

    final colores = Theme.of(context).colorScheme;
    final kcalValor = kcalRestantesHoy == null
        ? 'Sin objetivo'
        : '$kcalRestantesHoy kcal';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            Text(
              tituloPeriodo(periodo, inicio),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (periodo == Periodo.semana) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colores.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      color: colores.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kcal restantes',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: colores.onPrimaryContainer),
                          ),
                          Text(
                            'para hoy',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colores.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        kcalValor,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colores.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (estimacionPeso != null) ...[
                _fila(context, 'Tiempo hasta el peso objetivo', estimacionPeso!),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    'Estimación simplificada: el gasto real puede variar.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const Divider(height: 20),
            ],
            Text(
              'Actividad y calorías',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            _fila(context, 'Días registrados', dias),
            _fila(context, 'Media de calorías', media),
            _fila(context, 'Días dentro del rango', rango),
            const Divider(height: 20),
            Text('Peso', style: Theme.of(context).textTheme.labelLarge),
            _fila(context, 'Peso medio', pesoMedio),
            _fila(context, 'Peso respecto a $anterior', variacion),
          ],
        ),
      ),
    );
  }
}
