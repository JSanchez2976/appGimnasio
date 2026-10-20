import '../datos/registro_repositorio.dart';

enum Periodo { semana, mes, anio }

class Barra {
  final String etiqueta;
  final double? valor;
  const Barra(this.etiqueta, this.valor);
}

const _mesesLargos = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];
const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Primer día del periodo que contiene [fecha] (la semana empieza en lunes).
DateTime inicioPeriodo(Periodo p, DateTime fecha) {
  switch (p) {
    case Periodo.semana:
      return DateTime(fecha.year, fecha.month, fecha.day - (fecha.weekday - 1));
    case Periodo.mes:
      return DateTime(fecha.year, fecha.month, 1);
    case Periodo.anio:
      return DateTime(fecha.year, 1, 1);
  }
}

DateTime desplazar(Periodo p, DateTime inicio, int pasos) {
  switch (p) {
    case Periodo.semana:
      return DateTime(inicio.year, inicio.month, inicio.day + 7 * pasos);
    case Periodo.mes:
      return DateTime(inicio.year, inicio.month + pasos, 1);
    case Periodo.anio:
      return DateTime(inicio.year + pasos, 1, 1);
  }
}

int numeroBarras(Periodo p, DateTime inicio) {
  switch (p) {
    case Periodo.semana:
      return 7;
    case Periodo.mes:
      return DateTime(inicio.year, inicio.month + 1, 0).day;
    case Periodo.anio:
      return 12;
  }
}

String tituloPeriodo(Periodo p, DateTime inicio) {
  switch (p) {
    case Periodo.semana:
      final fin = DateTime(inicio.year, inicio.month, inicio.day + 6);
      return '${inicio.day} ${_mesesCortos[inicio.month - 1]} – '
          '${fin.day} ${_mesesCortos[fin.month - 1]} ${fin.year}';
    case Periodo.mes:
      return '${_mesesLargos[inicio.month - 1]} ${inicio.year}';
    case Periodo.anio:
      return '${inicio.year}';
  }
}

int? _indice(Periodo p, DateTime inicio, DateTime fecha, int n) {
  switch (p) {
    case Periodo.semana:
    case Periodo.mes:
      final dias = DateTime.utc(fecha.year, fecha.month, fecha.day)
          .difference(DateTime.utc(inicio.year, inicio.month, inicio.day))
          .inDays;
      return (dias >= 0 && dias < n) ? dias : null;
    case Periodo.anio:
      return fecha.year == inicio.year ? fecha.month - 1 : null;
  }
}

String _etiqueta(Periodo p, int i) {
  switch (p) {
    case Periodo.semana:
      return const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][i];
    case Periodo.mes:
      final d = i + 1;
      return (d == 1 || d % 5 == 0) ? '$d' : '';
    case Periodo.anio:
      return const [
        'E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
      ][i];
  }
}

List<Barra> _agrupar(
  Periodo p,
  DateTime inicio,
  Iterable<MapEntry<DateTime, double>> datos,
) {
  final n = numeroBarras(p, inicio);
  final sumas = List<double>.filled(n, 0);
  final cuentas = List<int>.filled(n, 0);
  for (final d in datos) {
    final i = _indice(p, inicio, d.key, n);
    if (i == null) continue;
    sumas[i] += d.value;
    cuentas[i]++;
  }
  return List.generate(
    n,
    (i) => Barra(_etiqueta(p, i), cuentas[i] == 0 ? null : sumas[i] / cuentas[i]),
  );
}

/// Semana y mes: peso de cada día. Año: media de cada mes.
List<Barra> barrasDePeso(
    Periodo p, DateTime inicio, List<PesoRegistro> datos) {
  return _agrupar(p, inicio, datos.map((r) => MapEntry(r.fecha, r.kg)));
}

/// Semana y mes: total de cada día. Año: media diaria de cada mes.
List<Barra> barrasDeCalorias(
    Periodo p, DateTime inicio, List<CaloriasRegistro> datos) {
  return _agrupar(
    p,
    inicio,
    datos
        .where((r) => r.total > 0)
        .map((r) => MapEntry(r.fecha, r.total.toDouble())),
  );
}