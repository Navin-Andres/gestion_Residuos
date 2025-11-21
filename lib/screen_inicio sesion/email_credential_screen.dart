import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailCredentialsScreen extends StatefulWidget {
  final Map<String, String> profileData;

  const EmailCredentialsScreen({super.key, required this.profileData});

  @override
  _EmailCredentialsScreenState createState() => _EmailCredentialsScreenState();
}

class _EmailCredentialsScreenState extends State<EmailCredentialsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _registerWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Crear usuario en Firebase Authentication
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = userCredential.user!;
        print('Usuario registrado con email: UID=${user.uid}, Email=${user.email}');

        // Guardar datos del perfil en Firestore
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDocRef.set({
          'displayName': widget.profileData['displayName'],
          'phone': widget.profileData['phone'],
          'idNumber': widget.profileData['idNumber'],
          'role': 'usuario',
          'email': user.email,
          'photoURL': user.photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
          'location': {
            'city': widget.profileData['city'],
            'neighborhood': widget.profileData['neighborhood'],
          },
          'preferences': {
            'notificationsEnabled': true,
            'language': 'es',
          },
        }, SetOptions(merge: true));

        print('Perfil guardado para UID=${user.uid}: ${{
          'displayName': widget.profileData['displayName'],
          'phone': widget.profileData['phone'],
          'idNumber': widget.profileData['idNumber'],
          'location': {
            'city': widget.profileData['city'],
            'neighborhood': widget.profileData['neighborhood'],
          },
          'preferences': {'notificationsEnabled': true, 'language': 'es'},
        }}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registro exitoso'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error al registrar: $e';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        print('Error al registrar: $e');
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hintText,
    bool obscureText = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.green.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
          prefixIcon: Icon(icon, color: Colors.green.shade700),
          suffixIcon: controller.text.isNotEmpty
              ? Icon(Icons.check_circle, color: Colors.green.shade700, size: 20)
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
        ),
        keyboardType: keyboardType,
        validator: validator,
        enabled: !_isLoading,
        obscureText: obscureText,
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credenciales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade100, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: Colors.white.withOpacity(0.95),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth > 600 ? 500 : double.infinity,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/arbol.png',
                                height: 80,
                                width: 80,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.eco,
                                  size: 80,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Ecovalle',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'Crea tu cuenta',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Correo Electrónico',
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingrese su correo electrónico';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Ingrese un correo válido';
                                  }
                                  return null;
                                },
                                hintText: 'Ej. ejemplo@correo.com',
                              ),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Contraseña',
                                icon: Icons.lock,
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingrese una contraseña';
                                  }
                                  if (value.length < 6) {
                                    return 'La contraseña debe tener al menos 6 caracteres';
                                  }
                                  return null;
                                },
                                hintText: 'Mínimo 6 caracteres',
                              ),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirmar Contraseña',
                                icon: Icons.lock_outline,
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirme su contraseña';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }
                                  return null;
                                },
                                hintText: 'Repita su contraseña',
                              ),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _registerWithEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Registrar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}