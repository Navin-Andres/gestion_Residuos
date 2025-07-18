import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  int _selectedIndex = 0;

  Future<void> _loginWithEmail() async {
    if (_selectedIndex != 1) {
      setState(() {
        _errorMessage = 'El inicio de sesión con correo solo está disponible para administradores o empresas.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user!;
      print('Inicio de sesión con email: UID=${user.uid}, Email=${user.email}');

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      print('Intentando leer documento: users/${user.uid} en ${DateTime.now()}');
      DocumentSnapshot userDoc;
      try {
        userDoc = await userDocRef.get();
        print('Documento leído: exists=${userDoc.exists}, data=${userDoc.data()}');
      } catch (e) {
        print('Error al leer documento de usuario: $e en ${DateTime.now()}');
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'read-error',
          message: 'No se pudo leer el documento del usuario: $e',
        );
      }

      String role;
      if (!userDoc.exists) {
        role = 'empresa';
        print('Creando documento para usuario: UID=${user.uid}, Rol=$role');
        try {
          await userDocRef.set({
            'email': user.email,
            'displayName': user.displayName ?? user.email?.split('@')[0],
            'photoURL': user.photoURL,
            'role': role,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
            'preferences': {
              'notificationsEnabled': true,
              'language': 'es',
              'interests': ['reciclaje'],
            },
          });
          print('Usuario creado en Firestore: UID=${user.uid}, Rol=$role');
        } catch (e) {
          print('Error al crear documento de usuario: $e en ${DateTime.now()}');
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'write-error',
            message: 'No se pudo crear el documento del usuario: $e',
          );
        }
      } else {
        final data = userDoc.data() as Map<String, dynamic>?;
        role = data != null && data['role'] is String ? data['role'] : 'usuario';
        print('Rol desde Firestore: $role');
        // Actualizar lastLogin
        await userDocRef.update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print('lastLogin actualizado para UID=${user.uid} en ${DateTime.now()}');
      }

      if (role == 'administrador' || role == 'empresa') {
        print('Navegando a AdminPanelScreen');
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        setState(() {
          _errorMessage = 'No tienes permisos de administrador o empresa.';
        });
        print('Error: Rol no permitido para AdminPanelScreen: $role');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _mapFirebaseAuthError(e.code);
      });
      print('Error de autenticación: ${e.code}, ${e.message}');
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Error en Firestore: ${e.code}';
      });
      print('Error en Firestore: ${e.code}, ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
      print('Error inesperado: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_selectedIndex == 1) {
      setState(() {
        _errorMessage = 'Inicio de sesión con Google solo está disponible para usuarios.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _errorMessage = 'Inicio de sesión con Google cancelado.';
          _isLoading = false;
        });
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      UserCredential userCredential;
      if (currentUser != null && currentUser.isAnonymous) {
        userCredential = await currentUser.linkWithCredential(credential);
        print('Cuenta anónima vinculada con Google: ${userCredential.user!.uid}');
      } else {
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user!;
      print('Inicio de sesión con Google: UID=${user.uid}, Email=${user.email}, Nombre=${user.displayName}');

      await user.updateDisplayName(user.displayName ?? user.email?.split('@')[0]);
      await user.updatePhotoURL(user.photoURL);

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      print('Intentando leer documento: users/${user.uid} en ${DateTime.now()}');
      final userDoc = await userDocRef.get();
      print('Documento leído: exists=${userDoc.exists}, data=${userDoc.data()}');
      String role;

      if (!userDoc.exists) {
        role = 'usuario';
        print('Creando documento para usuario: UID=${user.uid}, Rol=$role');
        await userDocRef.set({
          'email': user.email,
          'displayName': user.displayName ?? user.email?.split('@')[0],
          'photoURL': user.photoURL,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'preferences': {
            'notificationsEnabled': true,
            'language': 'es',
            'interests': ['reciclaje'],
          },
        });
        print('Usuario creado en Firestore: ${user.uid}, Rol: $role');
      } else {
        final data = userDoc.data() as Map<String, dynamic>?;
        role = data != null && data['role'] is String ? data['role'] : 'usuario';
        print('Rol de usuario existente: $role');
        // Actualizar lastLogin
        await userDocRef.update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print('lastLogin actualizado para UID=${user.uid} en ${DateTime.now()}');
      }

      print('Navegando a HomeScreen o ProfileSetupScreen');
      if (!userDoc.exists && role == 'usuario') {
        Navigator.pushReplacementNamed(context, '/profile_setup');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al iniciar sesión con Google: $e';
      });
      print('Error en inicio de sesión con Google: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No se encontró un usuario con ese correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'La cuenta ha sido deshabilitada.';
      default:
        return 'Error de autenticación: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.eco, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gestión de Residuos',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 36),
                ToggleButtons(
                  isSelected: [_selectedIndex == 0, _selectedIndex == 1],
                  onPressed: (index) {
                    setState(() {
                      _selectedIndex = index;
                      _errorMessage = null;
                      _emailController.clear();
                      _passwordController.clear();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: Colors.white,
                  fillColor: Colors.green.shade900,
                  color: Colors.green.shade900,
                  constraints: const BoxConstraints(minHeight: 40, minWidth: 140),
                  children: const [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person),
                        SizedBox(width: 8),
                        Text('Usuario'),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business),
                        SizedBox(width: 8),
                        Text('Administrador/Empresa'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (_selectedIndex == 1) ...[
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: const Icon(Icons.business, color: Colors.green),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock, color: Colors.green),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            obscureText: true,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ],
                        if (_selectedIndex == 0) ...[
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _loginWithGoogle,
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png',
                              height: 24,
                              width: 24,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                            ),
                            label: Text(
                              'Iniciar sesión con Google',
                              style: TextStyle(fontSize: 16, color: Colors.green.shade900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 4,
                            ),
                          ),
                        ],
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}