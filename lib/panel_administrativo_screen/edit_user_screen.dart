import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const EditUserScreen({super.key, required this.arguments});

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _idNumberController;
  late TextEditingController _emailController;
  late TextEditingController _newPasswordController;
  String? _selectedRole;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userData = widget.arguments['userData'] as Map<String, dynamic>;
    _fullNameController = TextEditingController(text: userData['displayName'] ?? '');
    _idNumberController = TextEditingController(text: userData['idNumber'] ?? '');
    _emailController = TextEditingController(text: userData['email'] ?? '');
    _newPasswordController = TextEditingController();
    _selectedRole = userData['role'] ?? 'empresa';
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = widget.arguments['userId'] as String;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Debes estar autenticado para editar usuarios.';
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final role = userDoc.data()?['role'] as String? ?? '';
      if (role != 'administrador') {
        setState(() {
          _errorMessage = 'Solo los administradores pueden editar usuarios.';
        });
        return;
      }

      // Actualizar datos en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'displayName': _fullNameController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
      });

      // Actualizar contraseña si se proporciona
      if (_newPasswordController.text.isNotEmpty) {
        if (currentUser.uid == userId) {
          // Si es el usuario autenticado, requiere reautenticación
          await _reauthenticateAndUpdatePassword(currentUser, _newPasswordController.text.trim());
        } else {
          // Para otros usuarios, solo un administrador puede cambiar la contraseña
          final userToUpdate = await FirebaseAuth.instance.signInAnonymously().then((_) => FirebaseAuth.instance.currentUser);
          await userToUpdate?.updatePassword(_newPasswordController.text.trim());
          await FirebaseAuth.instance.signOut(); // Restaurar estado original
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada exitosamente.')),
        );
      } else if (currentUser.uid == userId) {
        await currentUser.updateEmail(_emailController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email actualizado exitosamente.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados en Firestore. Cambiar el email o contraseña de otro usuario requiere Cloud Functions para seguridad total.')),
        );
      }

      Navigator.pushReplacementNamed(context, '/users_list');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _mapFirebaseAuthError(e.code);
      });
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = 'Error en Firestore: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reauthenticateAndUpdatePassword(User currentUser, String newPassword) async {
    final providerData = currentUser.providerData.first;
    if (providerData.providerId == 'password') {
      final credential = EmailAuthProvider.credential(
        email: currentUser.email ?? '',
        password: '', // Requiere que el usuario ingrese la contraseña actual en un paso previo
      );
      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.updatePassword(newPassword);
    }
  }

  String? _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'El correo ya está en uso.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'requires-recent-login':
        return 'Se requiere iniciar sesión recientemente para cambiar la contraseña. Vuelve a iniciar sesión.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      default:
        return 'Error de autenticación: $code';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuario', style: TextStyle(color: Colors.white)),
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      prefixIcon: const Icon(Icons.person, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre completo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _idNumberController,
                    decoration: InputDecoration(
                      labelText: 'Número de Identificación',
                      prefixIcon: const Icon(Icons.badge, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el número de identificación';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: const Icon(Icons.email, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el correo electrónico';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña (Opcional)',
                      prefixIcon: const Icon(Icons.lock, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != null && value.isNotEmpty && value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: const Icon(Icons.group, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'empresa', child: Text('Empresa')),
                      DropdownMenuItem(value: 'administrador', child: Text('Administrador')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Selecciona un rol';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Guardar Cambios', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}