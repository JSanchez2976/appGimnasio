import 'ajustes_repositorio.dart';

/// Proyección inicial simple desde el superávit sugerido por la calculadora.
/// Se muestra como orientación; no modela adaptaciones metabólicas individuales.
String? estimarTiempoObjetivoPeso({
  required PerfilCalculadora? perfil,
  required int? objetivoCalorias,
  required double? pesoObjetivoKg,
  required double? pesoActualKg,
}) {
  if (perfil == null ||
      perfil.meta != MetaCalculadora.ganar ||
      objetivoCalorias == null ||
      pesoObjetivoKg == null) {
    return null;
  }

  final pesoActual = pesoActualKg ?? perfil.pesoKg;
  if (pesoObjetivoKg <= pesoActual) return 'Objetivo alcanzado';

  final base = 10 * pesoActual + 6.25 * perfil.alturaCm - 5 * perfil.edad;
  final gastoReposo = base + (perfil.sexo == 'hombre' ? 5 : -161);
  final mantenimiento = gastoReposo * perfil.actividad.factor;
  final superavit = objetivoCalorias - mantenimiento;
  if (superavit <= 0) return 'Sin superávit sobre el mantenimiento estimado';

  // Conversión simplificada para una orientación inicial, no una predicción.
  final dias = ((pesoObjetivoKg - pesoActual) * 7700 / superavit).ceil();
  if (dias < 14) return 'Aproximadamente $dias días';
  final semanas = (dias / 7).round();
  if (semanas < 10) return 'Aproximadamente $semanas semanas';
  final meses = (dias / 30.44).round();
  return 'Aproximadamente $meses meses';
}
