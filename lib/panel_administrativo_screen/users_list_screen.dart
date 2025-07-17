import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

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

        // Eliminar el documento de Firestore
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
    print('Building UsersListScreen');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios Registrados', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[100]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            print('StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
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

            final users = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                print('Rendering user at index $index');
                final userData = users[index].data() as Map<String, dynamic>;
                final userId = users[index].id;
                final displayName = userData['displayName'] as String? ?? 'Sin nombre';
                final email = userData['email'] as String? ?? 'Sin correo';
                final idNumber = userData['idNumber'] as String? ?? 'Sin identificación';
                final role = userData['role'] as String? ?? 'Sin rol';

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[700],
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Correo: $email', maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('ID: $idNumber', maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('Rol: $role', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create_user');
        },
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Usuario',
      ), // Asegurado que está dentro de Scaffold
    );
  }
}