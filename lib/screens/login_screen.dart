import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      print('UID: ${userCredential.user!.uid}');
      print('Email: ${userCredential.user!.email}');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      final role = userDoc.data()?['role'] ?? 'usuario';
      print('Rol desde Firestore: $role');

      if (_selectedIndex == 1) {
        if (role == 'autoridad' || role == 'empresa') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          setState(() {
            _errorMessage = 'No tienes permisos de autoridad o empresa. Contacta al administrador para actualizar tu rol.';
          });
        }
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
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

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Iniciar sesión con Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _errorMessage = 'Inicio de sesión con Google cancelado.';
          _isLoading = false;
        });
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Verificar si el usuario es anónimo y vincular si es necesario
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

      // Actualizar perfil de Firebase
      await user.updateDisplayName(user.displayName ?? user.email?.split('@')[0]);
      await user.updatePhotoURL(user.photoURL);

      // Verificar o crear usuario en Firestore
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      String role;

      if (!userDoc.exists) {
        // Nuevo usuario: crear documento en Firestore con rol basado en selección
        role = _selectedIndex == 1 ? 'empresa' : 'usuario'; // Asigna 'empresa' si es autoridad/empresa
        await userDocRef.set({
          'email': user.email,
          'displayName': user.displayName ?? user.email?.split('@')[0],
          'photoURL': user.photoURL,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('Usuario creado en Firestore: ${user.uid}, Rol: $role');
      } else {
        role = userDoc.data()?['role'] ?? 'usuario';
        print('Rol de usuario existente: $role');
      }

      // Navegación basada en rol y selección
      if (_selectedIndex == 1) {
        if (role == 'autoridad' || role == 'empresa') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          setState(() {
            _errorMessage = 'No tienes permisos de autoridad o empresa. Contacta al administrador para actualizar tu rol.';
          });
        }
      } else {
        // Solo usuarios con rol 'usuario' van a profile_setup si son nuevos
        if (!userDoc.exists && role == 'usuario') {
          Navigator.pushReplacementNamed(context, '/profile_setup');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
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
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.eco, color: Colors.green, size: 60),
                ),
                SizedBox(height: 24),
                Text(
                  'Gestión de Residuos',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 36),
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
                  fillColor: Colors.green[900],
                  color: Colors.green[900],
                  constraints: BoxConstraints(minHeight: 40, minWidth: 140),
                  children: [
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
                        Text('Autoridad/Empresa'),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(
                              _selectedIndex == 0 ? Icons.email : Icons.business,
                              color: Colors.green,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock, color: Colors.green),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          obscureText: true,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _loginWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                        ),
                        if (_selectedIndex == 0) ...[
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _loginWithGoogle,
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png',
                              height: 24,
                              width: 24,
                            ),
                            label: Text(
                              'Iniciar sesión con Google',
                              style: TextStyle(fontSize: 16, color: Colors.green[900]),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 4,
                            ),
                          ),
                        ],
                        if (_errorMessage != null)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(_errorMessage!, style: TextStyle(color: Colors.red[700])),
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