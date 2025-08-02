import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleRegisterScreen extends StatefulWidget {
  const GoogleRegisterScreen({super.key});

  @override
  _GoogleRegisterScreenState createState() => _GoogleRegisterScreenState();
}

class _GoogleRegisterScreenState extends State<GoogleRegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
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

    // Prellenar nombre con datos de Google si están disponibles
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _fullNameController.text = user.displayName ?? '';
      });
    }
  }

  Future<void> _registerWithGoogle() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Iniciar sesión con Google
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() {
            _errorMessage = 'Registro con Google cancelado.';
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
        print('Usuario registrado con Google: UID=${user.uid}, Email=${user.email}, Nombre=${user.displayName}');

        // Guardar datos del perfil en Firestore
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDocRef.set({
          'displayName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'idNumber': _idNumberController.text.trim(),
          'role': 'usuario',
          'email': user.email,
          'photoURL': user.photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
          'location': {
            'city': _cityController.text.trim(),
            'neighborhood': _neighborhoodController.text.trim(),
          },
          'preferences': {
            'notificationsEnabled': true,
            'language': 'es',
          },
        }, SetOptions(merge: true));

        print('Perfil guardado para UID=${user.uid}: ${{
          'displayName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'idNumber': _idNumberController.text.trim(),
          'location': {'city': _cityController.text.trim(), 'neighborhood': _neighborhoodController.text.trim()},
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
            _errorMessage = 'Error al registrar con Google: $e';
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
        print('Error al registrar con Google: $e');
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
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro con Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                'Completa tu perfil',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Nombre Completo',
                                icon: Icons.person,
                                validator: (value) => value!.isEmpty ? 'Ingrese el nombre completo' : null,
                                hintText: 'Ej. Juan Pérez',
                              ),
                              _buildTextField(
                                controller: _idNumberController,
                                label: 'Número de Identificación',
                                icon: Icons.badge,
                                keyboardType: TextInputType.number,
                                validator: (value) => value!.isEmpty ? 'Ingrese el número de identificación' : null,
                                hintText: 'Ej. 1234567890',
                              ),
                              _buildTextField(
                                controller: _phoneController,
                                label: 'Teléfono',
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                validator: (value) => value!.isEmpty ? 'Ingrese el número de teléfono' : null,
                                hintText: 'Ej. +57 300 123 4567',
                              ),
                              _buildTextField(
                                controller: _cityController,
                                label: 'Ciudad',
                                icon: Icons.location_city,
                                validator: (value) => value!.isEmpty ? 'Ingrese la ciudad' : null,
                                hintText: 'Ej. Valledupar',
                              ),
                              _buildTextField(
                                controller: _neighborhoodController,
                                label: 'Barrio',
                                icon: Icons.map,
                                validator: (value) => value!.isEmpty ? 'Ingrese el barrio' : null,
                                hintText: 'Ej. Centro',
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
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _registerWithGoogle,
                                  icon: Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                                  ),
                                  label: const Text(
                                    'Registrar con Google',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
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
    _fullNameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}