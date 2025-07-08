import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _notifyFullContainers = true;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Usuario', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[100]!, Colors.green[50]!],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                          backgroundColor: Colors.grey,
                          child: user?.photoURL == null
                              ? const Icon(Icons.person, size: 50, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userData?['displayName'] ?? user?.displayName ?? 'Usuario',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Correo: ${_userData?['email'] ?? user?.email ?? 'No disponible'}',
                                style: TextStyle(fontSize: 14, color: Colors.green[800]),
                              ),
                              Text(
                                'Cédula: ${_userData?['idNumber'] ?? 'No disponible'}',
                                style: TextStyle(fontSize: 14, color: Colors.green[800]),
                              ),
                              Text(
                                'Teléfono: ${_userData?['phone'] ?? 'No disponible'}',
                                style: TextStyle(fontSize: 14, color: Colors.green[800]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Notificaciones',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SwitchListTile(
                          title: const Text('Notificar contenedores llenos'),
                          value: _notifyFullContainers,
                          onChanged: (value) => setState(() => _notifyFullContainers = value),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Acciones',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ListTile(
                          leading: const Icon(Icons.edit, color: Colors.green),
                          title: const Text('Editar Perfil'),
                          onTap: () => Navigator.pushNamed(context, '/profile_setup'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Cerrar Sesión'),
                          onTap: _signOut,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}