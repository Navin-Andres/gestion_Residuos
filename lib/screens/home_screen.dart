import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String? userRole;

  final List<Map<String, dynamic>> gridItems = [
    {'title': 'Mapa de Contenedores', 'icon': Icons.map, 'route': '/map'},
    {'title': 'Reporte de Quejas', 'icon': Icons.report, 'route': '/complaint'},
    {'title': 'Sección Educativa', 'icon': Icons.school, 'route': '/educational'},
    {'title': 'Perfil de Usuario', 'icon': Icons.person, 'route': '/profile'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Usuario no autenticado en ${DateTime.now()}');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        userRole = userDoc.data()?['role'] ?? 'usuario';
        print('Rol del usuario cargado: $userRole para UID: ${user.uid} en ${DateTime.now()}');
      });
      if (userRole != 'usuario') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo los usuarios pueden acceder a esta pantalla.')),
        );
        Navigator.pushReplacementNamed(context, userRole == 'empresa' || userRole == 'autoridad' ? '/admin' : '/login');
      }
    } catch (e) {
      print('Error al obtener el rol: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar permisos. Contacta al administrador.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

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
    if (userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Evitar que el usuario regrese al AdminPanelScreen
        return false; // Desactiva el botón de retroceso físico
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Residuos', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green[700],
          automaticallyImplyLeading: false, // Elimina la flecha de retroceso del AppBar
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, color: Colors.white),
              onPressed: _isLoading ? null : _signOut,
              tooltip: 'Cerrar Sesión',
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[100]!, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: gridItems.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, gridItems[index]['route']);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(gridItems[index]['icon'], size: 50, color: Colors.green[700]),
                      const SizedBox(height: 10),
                      Text(
                        gridItems[index]['title'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}