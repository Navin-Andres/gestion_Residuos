import 'package:firebase_prueba2/screens/email_credential_screen.dart';
import 'package:flutter/material.dart';
import 'google_register_screen.dart';

class ProfileRegisterScreen extends StatefulWidget {
  const ProfileRegisterScreen({super.key});

  @override
  _ProfileRegisterScreenState createState() => _ProfileRegisterScreenState();
}

class _ProfileRegisterScreenState extends State<ProfileRegisterScreen> with SingleTickerProviderStateMixin {
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
  }

  void _continueToEmail() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailCredentialsScreen(
            profileData: {
              'displayName': _fullNameController.text.trim(),
              'idNumber': _idNumberController.text.trim(),
              'phone': _phoneController.text.trim(),
              'city': _cityController.text.trim(),
              'neighborhood': _neighborhoodController.text.trim(),
            },
          ),
        ),
      );
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
        title: const Text('Registro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                'Configura tu perfil',
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
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const GoogleRegisterScreen()),
                                        );
                                      },
                                child: const Text(
                                  'O regístrate con Google',
                                  style: TextStyle(color: Colors.green, fontSize: 14),
                                ),
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
                                  onPressed: _isLoading ? null : _continueToEmail,
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
                                          'Continuar',
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
    _fullNameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}