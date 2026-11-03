import 'dart:async';

import 'package:flutter/material.dart';

import '../datos/ajustes_repositorio.dart';
import '../datos/registro_repositorio.dart';
import '../datos/servicio_recordatorios.dart';
import 'ajustes_pantalla.dart';
import 'agua_pantalla.dart';
import 'calculadora_pantalla.dart';
import 'graficas_pantalla.dart';
import 'medidas_pantalla.dart';
import 'perfil_pantalla.dart';
import 'registro_pantalla.dart';

class InicioPantalla extends StatefulWidget {
  const InicioPantalla({super.key});

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restaurarRecordatorios());
  }

  Future<void> _restaurarRecordatorios() async {
    try {
      final config = await AjustesRepositorio.instancia.recordatorios().first;
      final hayDatos = await RegistroRepositorio.instancia
          .hayDatosRegistrados(DateTime.now());
      await ServicioRecordatorios.instancia.programar(
        config,
        hayDatosHoy: hayDatos,
      );
    } catch (_) {
      // Si no hay datos guardados todavía, la app sigue funcionando sin avisos.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/branding/calorie_graph.png',
                width: 30,
                height: 30,
                semanticLabel: 'Logo de CalorieGraph',
              ),
            ),
            const SizedBox(width: 10),
            const Text('CalorieGraph'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PerfilPantalla()),
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AjustesPantalla()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _pestana,
        children: const [
          RegistroPantalla(),
          GraficasPantalla(),
          AguaPantalla(),
          MedidasPantalla(),
          CalculadoraPantalla(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Registro'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Gráficas'),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            label: 'Agua',
          ),
          NavigationDestination(icon: Icon(Icons.straighten), label: 'Medidas'),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            label: 'Calculadora',
          ),
        ],
      ),
    );
  }
}
