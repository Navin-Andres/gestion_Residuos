import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  String _roleFilter = 'Todos';
  final List<String> _roleOptions = ['Todos', 'Administrador', 'Empresa'];

  Future<void> _deleteUser(BuildContext context, String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de eliminar al usuario con email $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes estar autenticado para eliminar usuarios.')),
          );
          return;
        }

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final role = userDoc.data()?['role'] as String? ?? '';
        if (role != 'administrador') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solo los administradores pueden eliminar usuarios.')),
          );
          return;
        }

        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento del usuario eliminado de Firestore.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar usuario: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/admin');
          },
        ),
        title: const Text('Usuarios Registrados', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, correo o ID',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _roleOptions.map((role) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(role),
                      selected: _roleFilter == role,
                      selectedColor: Colors.green[200],
                      onSelected: (selected) {
                        setState(() {
                          _roleFilter = role;
                        });
                      },
                      labelStyle: TextStyle(
                        color: _roleFilter == role ? Colors.green[900] : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar usuarios: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No hay usuarios registrados.'));
                  }

                  final users = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final role = (data['role'] as String? ?? '').toLowerCase();
                    if (_roleFilter == 'Administrador' && role != 'administrador') return false;
                    if (_roleFilter == 'Empresa' && role != 'empresa') return false;
                    if (_roleFilter == 'Todos' && role != 'administrador' && role != 'empresa') return false;
                    if (_searchText.isEmpty) return true;
                    final displayName = (data['displayName'] as String? ?? '').toLowerCase();
                    final email = (data['email'] as String? ?? '').toLowerCase();
                    final idNumber = (data['idNumber'] as String? ?? '').toLowerCase();
                    return displayName.contains(_searchText) ||
                        email.contains(_searchText) ||
                        idNumber.contains(_searchText);
                  }).toList();

                  if (users.isEmpty) {
                    return const Center(child: Text('No se encontraron usuarios con ese filtro.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userData = users[index].data() as Map<String, dynamic>;
                      final userId = users[index].id;
                      final displayName = userData['displayName'] as String? ?? 'Sin nombre';
                      final email = userData['email'] as String? ?? 'Sin correo';
                      final idNumber = userData['idNumber'] as String? ?? 'Sin identificación';
                      final role = userData['role'] as String? ?? 'Sin rol';

                      Color badgeColor = Colors.grey;
                      IconData badgeIcon = Icons.person;
                      if (role.toLowerCase() == 'administrador') {
                        badgeColor = Colors.green[700]!;
                        badgeIcon = Icons.verified_user;
                      } else if (role.toLowerCase() == 'empresa') {
                        badgeColor = Colors.blue[700]!;
                        badgeIcon = Icons.business_center;
                      }

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.grey[50],
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: badgeColor,
                            radius: 24,
                            child: Icon(badgeIcon, color: Colors.white, size: 24),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role[0].toUpperCase() + role.substring(1),
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Correo: $email',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  'ID: $idNumber',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.green),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/edit_user',
                                    arguments: {'userId': userId, 'userData': userData},
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteUser(context, userId, email),
                              ),
                            ],
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Usuario seleccionado: $displayName')),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create_user');
        },
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Usuario',
      ),
    );
  }
}