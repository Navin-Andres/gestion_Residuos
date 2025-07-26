import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  Future<Map<String, dynamic>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'role': '', 'name': 'Administrador', 'email': ''};
    }
    try {
      print('Fetching data for user: ${user.uid}'); // Log para depuración
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) {
        return {
          'role': '',
          'name': user.displayName ?? 'Administrador',
          'email': user.email ?? '',
        };
      }
      final data = userDoc.data() as Map<String, dynamic>?;
      return {
        'role': data?['role']?.toString() ?? '',
        'name': data?['displayName']?.toString() ?? user.displayName ?? 'Administrador',
        'email': data?['email']?.toString() ?? user.email ?? '',
      };
    } catch (e) {
      print('Error fetching user data: $e');
      return {
        'role': '',
        'name': user.displayName ?? 'Administrador',
        'email': user.email ?? '',
      };
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Panel de Control',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: const Color(0xFF0D3B66),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: isDesktop
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: () => _signOut(context),
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text('Cerrar Sesión'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Colors.white70),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ]
                : null,
          ),
          drawer: isDesktop ? null : _buildDrawer(context),
          body: Row(
            children: [
              if (isDesktop)
                Container(
                  width: 280,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D3B66), Color(0xFF1E4066)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: _buildDrawerContent(context),
                ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEFF3F8), Color(0xFFFFFFFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: _buildMainContent(context, isDesktop),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: _buildDrawerContent(context),
    );
  }

  Widget _buildDrawerContent(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
        }
        final userData = snapshot.data ?? {'role': '', 'name': 'Administrador', 'email': ''};
        final userRole = userData['role'] ?? '';
        final userName = userData['name'] ?? 'Administrador';
        final userEmail = userData['email'] ?? '';
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D3B66), Color(0xFF1E4066)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30, // Reducido para evitar overflow
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Icon(Icons.person, size: 36, color: const Color(0xFF0D3B66)),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        userEmail.isNotEmpty ? userEmail : 'Gestión de Residuos',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.person,
                title: 'Perfil de Empresa',
                onTap: () => Navigator.pop(context),
              ),
              if (userRole == 'administrador')
                _buildDrawerItem(
                  context,
                  icon: Icons.group,
                  title: 'Lista de Usuarios',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/users_list');
                  },
                ),
              if (userRole == 'administrador')
                _buildDrawerItem(
                  context,
                  icon: Icons.school,
                  title: 'Secciones Educativas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/educational_content');
                  },
                ),
              _buildDrawerItem(
                context,
                icon: Icons.logout,
                title: 'Cerrar Sesión',
                onTap: () => _signOut(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ListTile(
          leading: Icon(icon, color: Colors.white, size: 28),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: onTap,
          hoverColor: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDesktop) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
        }
        final userRole = snapshot.data?['role'] ?? '';
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1200 ? 4 : constraints.maxWidth > 800 ? 3 : 2;
            return SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 40 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: isDesktop ? 32 : 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D3B66),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: isDesktop ? 1.3 : 1.2,
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridButton(BuildContext context, {required IconData icon, required String label, required String route}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    size: 48,
                    color: const Color(0xFF00A884),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF0D3B66),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}