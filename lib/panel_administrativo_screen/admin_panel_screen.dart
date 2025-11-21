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
      print('Fetching data for user: ${user.uid}');
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
                fontSize: 24,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: Colors.green.shade700,
            elevation: 2,
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
                          foregroundColor: Colors.green.shade700,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.green.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 2,
                          shadowColor: Colors.green.shade100,
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade700, Colors.green.shade500],
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
                      colors: [Color(0xFFECEFF1), Color(0xFFFFFFFF)],
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
          return Center(child: CircularProgressIndicator(color: Colors.green.shade700));
        }
        final userData = snapshot.data ?? {'role': '', 'name': 'Administrador', 'email': ''};
        final userRole = userData['role'] ?? '';
        final userName = userData['name'] ?? 'Administrador';
        final userEmail = userData['email'] ?? '';
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade500],
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
                      radius: 32,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Icon(Icons.person, size: 40, color: Colors.green.shade700),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          letterSpacing: 0.3,
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
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          onTap: onTap,
          hoverColor: Colors.green.shade300.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDesktop) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.green.shade700));
        }
        final userData = snapshot.data ?? {'role': '', 'name': 'Administrador', 'email': ''};
        final userRole = userData['role'] ?? '';
        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = isDesktop ? 3 : 2;
            final itemCount = isDesktop ? 5 : (userRole == 'administrador' ? 5 : 4);
            return SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - kToolbarHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: isDesktop ? 34 : 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isDesktop ? 1.2 : 1.3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(itemCount, (index) {
                        final items = [
                          {'icon': Icons.admin_panel_settings, 'label': 'Vista de Reportes', 'route': '/reportes', 'iconColor': Colors.blue[600]},
                          {'icon': Icons.delete, 'label': 'Estado de Contenedores', 'route': '/contenedores', 'iconColor': Colors.purple[600]},
                          {'icon': Icons.map, 'label': 'Rutas', 'route': '/rutas', 'iconColor': Colors.orange[600]},
                          {'icon': Icons.add_location_alt, 'label': 'Agregar Contenedor', 'route': '/agregarContenedor', 'iconColor': Colors.teal[600]},
                          if (userRole == 'administrador')
                            {'icon': Icons.school, 'label': 'Secciones Educativas', 'route': '/educational_content', 'iconColor': Colors.indigo[600]},
                        ];
                        final item = items[index];
                        return _buildGridButton(
                          context,
                          icon: item['icon'] as IconData,
                          label: item['label'] as String,
                          route: item['route'] as String,
                          iconColor: item['iconColor'] as Color,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridButton(BuildContext context, {required IconData icon, required String label, required String route, required Color iconColor}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.grey[100],
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey[200]!.withOpacity(0.3),
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
                    size: 40,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
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