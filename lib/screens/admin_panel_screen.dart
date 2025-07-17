import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  Future<Map<String, dynamic>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'role': '', 'name': ''};
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data() as Map<String, dynamic>?;
      print('User document data: $data'); // Depuración
      return {
        'role': data != null && data['role'] is String ? data['role'] : '',
        'name': data != null && data['displayName'] is String ? data['displayName'] : 'Administrador Desconocido',
      };
    } catch (e) {
      print('Error fetching user data: $e');
      return {'role': '', 'name': 'Administrador Desconocido'};
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrativo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final userData = snapshot.data ?? {'role': '', 'name': 'Administrador Desconocido'};
            final userRole = userData['role'] ?? '';
            final userName = userData['name'] ?? 'Administrador Desconocido';
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.business, size: 50, color: Colors.green[700]),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gestión de Residuos',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.green),
                  title: const Text('Perfil de Empresa'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                if (userRole == 'administrador')
                  ListTile(
                    leading: const Icon(Icons.group, color: Colors.green),
                    title: const Text('Lista de Usuarios'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/users_list');
                    },
                  ),
                if (userRole == 'administrador')
                  ListTile(
                    leading: const Icon(Icons.school, color: Colors.green),
                    title: const Text('Secciones Educativas'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/educational_content');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.green),
                  title: const Text('Cerrar Sesión'),
                  onTap: () async {
                    await _signOut(context);
                  },
                ),
              ],
            );
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[100]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final userRole = snapshot.data?['role'] ?? '';
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildGridButton(
                    context,
                    icon: Icons.admin_panel_settings,
                    label: 'Vista de Reportes',
                    route: '/reportes',
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.delete,
                    label: 'Estado de Contenedores',
                    route: '/contenedores',
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.map,
                    label: 'Rutas',
                    route: '/rutas',
                  ),
                  _buildGridButton(
                    context,
                    icon: Icons.add_location_alt,
                    label: 'Agregar Contenedor',
                    route: '/agregarContenedor',
                  ),
                  if (userRole == 'administrador')
                    _buildGridButton(
                      context,
                      icon: Icons.school,
                      label: 'Secciones Educativas',
                      route: '/educational_content',
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGridButton(BuildContext context, {required IconData icon, required String label, required String route}) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.green[700]),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}