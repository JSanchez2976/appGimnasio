import 'package:flutter/material.dart';

import '../graficas/grafica_barras.dart';

/// Tarjeta con título, subtítulo, objetivo y una gráfica dentro.
class TarjetaGrafica extends StatelessWidget {
  const TarjetaGrafica({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.grafica,
    this.objetivo,
    this.pie,
  });

  final String titulo;
  final String subtitulo;
  final String? objetivo;
  final Widget grafica;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: estilo.titleMedium),
            Text(subtitulo, style: estilo.bodySmall),
            if (objetivo != null) Text(objetivo!, style: estilo.bodySmall),
            const SizedBox(height: 16),
            grafica,
            if (pie != null) ...[const SizedBox(height: 12), pie!],
          ],
        ),
      ),
    );
  }
}

/// Leyenda de los tres colores de las barras de calorías.
class LeyendaRango extends StatelessWidget {
  const LeyendaRango({super.key});

  Widget _punto(BuildContext context, Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        _punto(context, colorDentro, 'Dentro del rango'),
        _punto(context, colorBajo, 'Por debajo'),
        _punto(context, colorAlto, 'Por encima'),
      ],
    );
  }
}