import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  _CreateUserScreenState createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedRole = 'empresa';
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Intentando crear usuario con email: ${_emailController.text}');
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user!;
      print('Usuario creado en Firebase Auth: UID=${user.uid}, Email=${user.email}');

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      print('Intentando guardar datos en Firestore: $userDocRef');
      await userDocRef.set({
        'email': user.email,
        'displayName': _fullNameController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Documento creado en Firestore: UID=${user.uid}, Rol=$_selectedRole');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario creado exitosamente')),
      );
      Navigator.pushReplacementNamed(context, '/users_list');
    } on FirebaseAuthException catch (e) {
      print('Error de autenticación detallado: ${e.code}, ${e.message}, StackTrace: ${e.stackTrace}');
      setState(() {
        _errorMessage = _mapFirebaseAuthError(e.code);
      });
    } on FirebaseException catch (e) {
      print('Error en Firestore detallado: ${e.code}, ${e.message}, StackTrace: ${e.stackTrace}');
      setState(() {
        _errorMessage = 'Error en Firestore: ${e.message}';
      });
    } catch (e, stackTrace) {
      print('Error inesperado detallado: $e, StackTrace: $stackTrace');
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'El correo ya está en uso.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      default:
        return 'Error de autenticación: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Usuario', style: TextStyle(color: Colors.white)),
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
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Repetir Contraseña',
                      prefixIcon: const Icon(Icons.lock, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Repite la contraseña';
                      }
                      if (value != _passwordController.text) {
                        return 'Las contraseñas no coinciden';
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
                    onPressed: _isLoading ? null : _createUser,
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
                        : const Text('Crear Usuario', style: TextStyle(fontSize: 16, color: Colors.white)),
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}