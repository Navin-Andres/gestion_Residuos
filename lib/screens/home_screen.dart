import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_prueba2/screens/map_screen.dart';
import 'package:firebase_prueba2/screens/complaint_screen.dart';
import 'package:firebase_prueba2/screens/educational_section_screen.dart';
import 'package:firebase_prueba2/screens/user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> gridItems = [
    {'title': 'Mapa de Contenedores', 'icon': Icons.map, 'route': '/map'},
    {'title': 'Reporte de Quejas', 'icon': Icons.report, 'route': '/complaint'},
    {'title': 'Sección Educativa', 'icon': Icons.school, 'route': '/educational'},
    {'title': 'Perfil de Usuario', 'icon': Icons.person, 'route': '/profile'},
    {'title': 'Panel de Autoridades', 'icon': Icons.admin_panel_settings, 'route': '/authority'},
  ];

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final stopwatch = Stopwatch()..start();
      print('Iniciando cierre de sesión...');
      await FirebaseAuth.instance.signOut();
      stopwatch.stop();
      print('Cierre de sesión completado en ${stopwatch.elapsedMilliseconds} ms');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('Error al cerrar sesión: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        
        title: Text('Gestión de Residuos'),
        actions: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(Icons.logout),
            onPressed: _isLoading ? null : _signOut,
            tooltip: 'Cerrar Sesión',
          ),
        ],
        
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: gridItems.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 4,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, gridItems[index]['route']);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(gridItems[index]['icon'], size: 50, color: Colors.green),
                  SizedBox(height: 10),
                  Text(
                    gridItems[index]['title'],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}