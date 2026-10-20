import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'graficas_pantalla.dart';
import 'registro_pantalla.dart';

class InicioPantalla extends StatefulWidget {
  const InicioPantalla({super.key});

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peso y Calorías'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _pestana,
        children: const [RegistroPantalla(), GraficasPantalla()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Registro'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Gráficas'),
        ],
      ),
    );
  }
}