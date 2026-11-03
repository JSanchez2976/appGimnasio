import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'ajustes_repositorio.dart';

class ServicioRecordatorios {
  ServicioRecordatorios._();
  static final instancia = ServicioRecordatorios._();

  static const int _idBase = 43000;
  static const int _maxRecordatorios = 10;
  final FlutterLocalNotificationsPlugin _notificaciones =
      FlutterLocalNotificationsPlugin();
  bool _inicializado = false;

  bool get disponible =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> inicializar() async {
    if (_inicializado || !disponible) return;
    tzdata.initializeTimeZones();
    final zona = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zona.identifier));
    await _notificaciones.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _inicializado = true;
  }

  Future<bool> solicitarPermiso() async {
    await inicializar();
    if (!disponible) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _notificaciones
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _notificaciones
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
  }

  Future<void> programar(
    ConfiguracionRecordatorios config, {
    required bool hayDatosHoy,
  }) async {
    await inicializar();
    if (!disponible) return;

    for (var i = 0; i < _maxRecordatorios; i++) {
      await _notificaciones.cancel(id: _idBase + i);
    }

    final horas = config.horas.toSet().toList()..sort();
    for (var i = 0; i < horas.length && i < _maxRecordatorios; i++) {
      final partes = horas[i].split(':');
      final hora = int.parse(partes[0]);
      final minuto = int.parse(partes[1]);
      final ahora = tz.TZDateTime.now(tz.local);
      var siguiente = tz.TZDateTime(
        tz.local,
        ahora.year,
        ahora.month,
        ahora.day,
        hora,
        minuto,
      );
      final posponerAlDiaSiguiente =
          config.condicion == CondicionRecordatorio.siNoHayRegistro &&
          hayDatosHoy;
      if (posponerAlDiaSiguiente || !siguiente.isAfter(ahora)) {
        siguiente = tz.TZDateTime(
          tz.local,
          ahora.year,
          ahora.month,
          ahora.day + 1,
          hora,
          minuto,
        );
      }

      await _notificaciones.zonedSchedule(
        id: _idBase + i,
        title: 'Recordatorio diario',
        body: 'Un momento para registrar tu progreso de hoy.',
        scheduledDate: siguiente,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'recordatorios_diarios',
            'Recordatorios diarios',
            channelDescription: 'Avisos diarios para registrar tu progreso.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelarTodos() async {
    if (!disponible) return;
    await inicializar();
    for (var i = 0; i < _maxRecordatorios; i++) {
      await _notificaciones.cancel(id: _idBase + i);
    }
  }

  Future<void> actualizarDespuesDeRegistro(bool hayDatosHoy) async {
    final config = await AjustesRepositorio.instancia.recordatorios().first;
    if (config.condicion != CondicionRecordatorio.siNoHayRegistro) return;
    await programar(config, hayDatosHoy: hayDatosHoy);
  }
}
