import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'agregacion.dart';

class GraficaBarras extends StatelessWidget {
  const GraficaBarras({
    super.key,
    required this.barras,
    required this.color,
    required this.empiezaEnCero,
    this.objetivo,
  });

  final List<Barra> barras;
  final Color color;

  /// Calorías: true. Peso: false (el eje se ajusta a los datos).
  final bool empiezaEnCero;
  final double? objetivo;

  static double _intervalo(double rango) {
    final bruto = rango / 4;
    for (final p in const [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0]) {
      if (p >= bruto) return p;
    }
    return 1000.0;
  }

  @override
  Widget build(BuildContext context) {
    final valores = barras.map((b) => b.valor).whereType<double>().toList();
    final todos = <double>[...valores, if (objetivo != null) objetivo!];

    double minY;
    double maxY;
    if (empiezaEnCero) {
      minY = 0.0;
      final techo = todos.isEmpty ? 0.0 : todos.reduce(math.max);
      maxY = techo <= 0 ? 100.0 : (techo * 1.15 / 100).ceil() * 100.0;
    } else if (todos.isEmpty) {
      minY = 0.0;
      maxY = 100.0;
    } else {
      minY = math.max(0.0, (todos.reduce(math.min) - 2).floorToDouble());
      maxY = (todos.reduce(math.max) + 2).ceilToDouble();
    }
    final intervalo = _intervalo(maxY - minY);

    final ancho = barras.length <= 7 ? 22.0 : (barras.length <= 12 ? 16.0 : 6.0);
    final estiloEje = Theme.of(context).textTheme.bodySmall;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: minY,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: intervalo,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: intervalo,
                getTitlesWidget: (value, meta) =>
                    Text(value.toStringAsFixed(0), style: estiloEje),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= barras.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(barras[i].etiqueta, style: estiloEje),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (objetivo != null)
                HorizontalLine(
                  y: objetivo!,
                  color: Colors.orange,
                  strokeWidth: 2,
                  dashArray: [6, 4],
                ),
            ],
          ),
          barGroups: [
            for (var i = 0; i < barras.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    fromY: minY,
                    toY: barras[i].valor ?? minY,
                    width: ancho,
                    color: color,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}