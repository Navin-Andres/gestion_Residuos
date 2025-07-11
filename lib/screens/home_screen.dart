import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedIndex = 0; // Índice para el NavigationBar (0: Inicio)

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
        print('Error al cargar datos del usuario: $e en ${DateTime.now()}');
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
      print('Error al cerrar sesión: $e en ${DateTime.now()}');
    }
  }

  void _onNavBarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        // Ya estamos en HomeScreen
        break;
      case 1:
        Navigator.pushNamed(context, '/map');
        break;
      case 2:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  Drawer _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final userRole = _userData?['role'] ?? 'usuario'; // Rol por defecto si no se encuentra

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[700]!, Colors.green[400]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  backgroundColor: Colors.grey,
                  child: user?.photoURL == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  _userData?['displayName'] ?? user?.displayName ?? 'Usuario',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? 'No disponible',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.green),
            title: const Text('Inicio'),
            selected: true,
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
              // Ya estamos en HomeScreen
            },
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.green),
            title: const Text('Mapa de Contenedores'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/map');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: const Text('Perfil de Usuario'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inbox, color: Colors.green),
            title: const Text('Bandeja de Entrada'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/inbox');
            },
          ),
          if (userRole == 'usuario')
            ListTile(
              leading: const Icon(Icons.report, color: Colors.green),
              title: const Text('Crear Queja'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/complaint');
              },
            ),
          if (userRole == 'empresa' || userRole == 'autoridad')
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.green),
              title: const Text('Reportes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/reports');
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[100]!, Colors.green[50]!],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Text(
                      'Bienvenido a Gestión de Residuos, tu herramienta para reportar problemas de recolección, consultar contenedores y gestionar tus quejas.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavBarItemTapped,
        indicatorColor: Colors.green[200],
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home, color: Colors.green),
            selectedIcon: Icon(Icons.home_filled, color: Colors.green),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.map, color: Colors.green),
            selectedIcon: Icon(Icons.map_outlined, color: Colors.green),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person, color: Colors.green),
            selectedIcon: Icon(Icons.person, color: Colors.green),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}