import '../datos/registro_repositorio.dart';

enum Periodo { semana, mes, anio }

class Barra {
  final String etiqueta;
  final double? valor;

  /// Hay una nota guardada en ese día (o en ese mes, en la vista Año).
  final bool conNota;

  const Barra(this.etiqueta, this.valor, {this.conNota = false});
}

const _mesesLargos = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];
const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
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
      final dias = DateTime.utc(
        fecha.year,
        fecha.month,
        fecha.day,
      ).difference(DateTime.utc(inicio.year, inicio.month, inicio.day)).inDays;
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
        'E',
        'F',
        'M',
        'A',
        'M',
        'J',
        'J',
        'A',
        'S',
        'O',
        'N',
        'D',
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
    (i) =>
        Barra(_etiqueta(p, i), cuentas[i] == 0 ? null : sumas[i] / cuentas[i]),
  );
}

/// Semana y mes: peso de cada día. Año: media de cada mes.
List<Barra> barrasDePeso(Periodo p, DateTime inicio, List<PesoRegistro> datos) {
  return _agrupar(p, inicio, datos.map((r) => MapEntry(r.fecha, r.kg)));
}

/// Semana y mes: total de cada día. Año: media diaria de cada mes.
List<Barra> barrasDeCalorias(
  Periodo p,
  DateTime inicio,
  List<CaloriasRegistro> datos,
) {
  return _agrupar(
    p,
    inicio,
    datos
        .where((r) => r.total > 0)
        .map((r) => MapEntry(r.fecha, r.total.toDouble())),
  );
}

class Resumen {
  final int diasRegistrados;
  final int diasConCalorias;
  final double? mediaCalorias;

  /// Null si no hay objetivo de calorías.
  final int? diasEnRango;
  final double? pesoMedio;

  /// Kg de diferencia entre el peso medio del periodo y el del anterior.
  final double? variacionPeso;

  const Resumen({
    required this.diasRegistrados,
    required this.diasConCalorias,
    required this.mediaCalorias,
    required this.diasEnRango,
    required this.pesoMedio,
    required this.variacionPeso,
  });
}

bool _dentro(Periodo p, DateTime inicio, DateTime fecha) {
  final fin = desplazar(p, inicio, 1);
  return !fecha.isBefore(inicio) && fecha.isBefore(fin);
}

double? _pesoMedio(Periodo p, DateTime inicio, List<PesoRegistro> pesos) {
  var suma = 0.0;
  var n = 0;
  for (final r in pesos) {
    if (_dentro(p, inicio, r.fecha)) {
      suma += r.kg;
      n++;
    }
  }
  return n == 0 ? null : suma / n;
}

Resumen resumenDe({
  required Periodo periodo,
  required DateTime inicio,
  required List<PesoRegistro> pesos,
  required List<CaloriasRegistro> calorias,
  int? objetivoCalorias,
  int margenBajo = 100,
  int margenAlto = 100,
}) {
  final dias = <String>{};
  for (final r in pesos) {
    if (_dentro(periodo, inicio, r.fecha)) {
      dias.add(idDia(r.fecha));
    }
  }

  var sumaCal = 0;
  var diasCal = 0;
  var enRango = 0;
  for (final r in calorias) {
    if (r.total <= 0 || !_dentro(periodo, inicio, r.fecha)) continue;
    dias.add(idDia(r.fecha));
    sumaCal += r.total;
    diasCal++;
    if (objetivoCalorias != null &&
        r.total >= objetivoCalorias - margenBajo &&
        r.total <= objetivoCalorias + margenAlto) {
      enRango++;
    }
  }

  final actual = _pesoMedio(periodo, inicio, pesos);
  final previo = _pesoMedio(periodo, desplazar(periodo, inicio, -1), pesos);

  return Resumen(
    diasRegistrados: dias.length,
    diasConCalorias: diasCal,
    mediaCalorias: diasCal == 0 ? null : sumaCal / diasCal,
    diasEnRango: objetivoCalorias == null ? null : enRango,
    pesoMedio: actual,
    variacionPeso: (actual != null && previo != null) ? actual - previo : null,
  );
}

/// Para series genéricas (agua, medidas...): valor de cada día en semana y
/// mes, y media de cada mes en año.
List<Barra> barrasDeSerie(
  Periodo p,
  DateTime inicio,
  Iterable<MapEntry<DateTime, double>> datos,
) {
  return _agrupar(p, inicio, datos);
}

/// True si [fecha] cae dentro del periodo que empieza en [inicio].
bool estaEnPeriodo(Periodo p, DateTime inicio, DateTime fecha) =>
    _dentro(p, inicio, fecha);

/// Devuelve las mismas barras, marcando las que tienen alguna nota.
List<Barra> conMarcasDeNotas(
  Periodo p,
  DateTime inicio,
  List<Barra> barras,
  Iterable<DateTime> fechasConNota,
) {
  final marcadas = <int>{};
  for (final f in fechasConNota) {
    final i = _indice(p, inicio, f, barras.length);
    if (i != null) marcadas.add(i);
  }
  return [
    for (var i = 0; i < barras.length; i++)
      Barra(barras[i].etiqueta, barras[i].valor, conNota: marcadas.contains(i)),
  ];
}
