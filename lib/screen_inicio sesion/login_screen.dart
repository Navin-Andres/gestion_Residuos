import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_login_screen.dart';
import 'profile_register_screen.dart';
import 'google_register_screen.dart';
import 'password_reset_screen.dart';

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
  bool _isLongPressing = false;

  void _onLongPressStart() {
    setState(() {
      _isLongPressing = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (_isLongPressing) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
        );
        setState(() {
          _isLongPressing = false;
        });
      }
    });
  }

  void _onLongPressEnd() {
    setState(() {
      _isLongPressing = false;
    });
  }

  Future<void> _loginWithEmailPassword() async {
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

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al iniciar sesión: $e';
      });
      print('Error en inicio de sesión con email: $e');
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

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;
      print('Inicio de sesión con Google: UID=${user.uid}, Email=${user.email}, Nombre=${user.displayName}');

      // Verificar si el usuario ya tiene un perfil en Firestore
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (mounted) {
        if (userDoc.exists) {
          // Usuario existente, navegar a /home
          print('Usuario existente encontrado: UID=${user.uid}');
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // Usuario nuevo, navegar a GoogleRegisterScreen
          print('Usuario nuevo, redirigiendo a pantalla de registro: UID=${user.uid}');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GoogleRegisterScreen()),
          );
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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/rio_gutapuri.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(12.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onLongPressStart: (_) => _onLongPressStart(),
                        onLongPressEnd: (_) => _onLongPressEnd(),
                        onLongPressCancel: () => _onLongPressEnd(),
                        child: Image.asset(
                          'assets/icons/arbol.png',
                          height: 50,
                          width: 50,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.eco,
                            size: 50,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ecovalle',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        'Gestión de Residuos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Correo Electrónico',
                          labelStyle: TextStyle(color: Colors.green.shade700, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                          ),
                          prefixIcon: Icon(Icons.email, color: Colors.green.shade700),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: TextStyle(color: Colors.green.shade700, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                          ),
                          prefixIcon: Icon(Icons.lock, color: Colors.green.shade700),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                        ),
                        obscureText: true,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const PasswordResetScreen()),
                                  );
                                },
                          child: const Text(
                            '¿Se te olvidó la contraseña?',
                            style: TextStyle(color: Colors.green, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithEmailPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(fontSize: 14, color: Colors.white),
                              ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _loginWithGoogle,
                        icon: Image.asset(
                          'assets/icons/google.png', // Cambiado de Image.network a Image.asset
                          height: 18,
                          width: 18,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                        ),
                        label: const Text(
                          'Iniciar Sesión con Google',
                          style: TextStyle(fontSize: 14, color: Colors.green),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProfileRegisterScreen()),
                                );
                              },
                        child: const Text(
                          '¿No tienes cuenta? Regístrate',
                          style: TextStyle(color: Colors.green, fontSize: 14),
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}