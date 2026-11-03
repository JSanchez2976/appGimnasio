import 'package:flutter/material.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/registro_repositorio.dart';
import '../datos/servicio_recordatorios.dart';

class RecordatoriosPantalla extends StatefulWidget {
  const RecordatoriosPantalla({super.key});

  @override
  State<RecordatoriosPantalla> createState() => _RecordatoriosPantallaState();
}

class _RecordatoriosPantallaState extends State<RecordatoriosPantalla> {
  final _ajustes = AjustesRepositorio.instancia;
  final _servicio = ServicioRecordatorios.instancia;
  final List<String> _horas = [];
  CondicionRecordatorio _condicion = CondicionRecordatorio.siempre;
  bool _cargado = false;
  bool _guardando = false;

  Future<void> _anadirHora() async {
    if (_horas.length >= 10) {
      _aviso('Puedes añadir hasta 10 horarios.');
      return;
    }
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (elegida == null || !mounted) return;
    final hora =
        '${elegida.hour.toString().padLeft(2, '0')}:'
        '${elegida.minute.toString().padLeft(2, '0')}';
    if (_horas.contains(hora)) {
      _aviso('Ya tienes un recordatorio a esa hora.');
      return;
    }
    setState(() {
      _horas.add(hora);
      _horas.sort();
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final config = ConfiguracionRecordatorios(
        horas: List.of(_horas),
        condicion: _condicion,
      );
      if (config.horas.isNotEmpty) {
        final permiso = await _servicio.solicitarPermiso();
        await _ajustes.guardarRecordatorios(config);
        final hayDatosHoy = await RegistroRepositorio.instancia
            .hayDatosRegistrados(DateTime.now());
        await _servicio.programar(config, hayDatosHoy: hayDatosHoy);
        if (!mounted) return;
        _aviso(
          permiso
              ? 'Recordatorios guardados.'
              : 'Horarios guardados. Activa las notificaciones en los ajustes del dispositivo.',
        );
      } else {
        await _ajustes.guardarRecordatorios(config);
        await _servicio.cancelarTodos();
        if (!mounted) return;
        _aviso('Recordatorios desactivados.');
      }
    } catch (_) {
      if (mounted) _aviso('No se pudieron guardar los recordatorios.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  String _etiquetaHora(String hora) {
    final partes = hora.split(':').map(int.parse).toList();
    return TimeOfDay(hour: partes[0], minute: partes[1]).format(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicio.disponible) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recordatorios')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Los recordatorios están disponibles en Android e iOS.'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios')),
      body: StreamBuilder<ConfiguracionRecordatorios>(
        stream: _ajustes.recordatorios(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los recordatorios.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_cargado) {
            _horas
              ..clear()
              ..addAll(snapshot.data!.horas);
            _condicion = snapshot.data!.condicion;
            _cargado = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Elige a qué horas quieres recibir avisos. Se repetirán cada día hasta que los quites.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                        child: Text(
                          'Cuándo avisar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      RadioListTile<CondicionRecordatorio>(
                        contentPadding: EdgeInsets.zero,
                        value: CondicionRecordatorio.siNoHayRegistro,
                        groupValue: _condicion,
                        onChanged: _guardando
                            ? null
                            : (value) => setState(
                                () => _condicion = value ?? _condicion,
                              ),
                        title: const Text('Solo si aún no he registrado hoy'),
                        subtitle: const Text(
                          'Al guardar peso o calorías, se omiten los avisos restantes de ese día.',
                        ),
                      ),
                      RadioListTile<CondicionRecordatorio>(
                        contentPadding: EdgeInsets.zero,
                        value: CondicionRecordatorio.siempre,
                        groupValue: _condicion,
                        onChanged: _guardando
                            ? null
                            : (value) => setState(
                                () => _condicion = value ?? _condicion,
                              ),
                        title: const Text('Siempre, aunque ya haya registrado'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Horas', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_horas.isEmpty)
                        const Text('Todavía no has añadido ningún horario.'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final hora in _horas)
                            InputChip(
                              label: Text(_etiquetaHora(hora)),
                              onDeleted: _guardando
                                  ? null
                                  : () => setState(() => _horas.remove(hora)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _guardando ? null : _anadirHora,
                          icon: const Icon(Icons.add_alarm),
                          label: const Text('Añadir hora'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar recordatorios'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
