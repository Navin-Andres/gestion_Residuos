import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  String? _preferredContactMethod;
  String? _errorMessage;
  bool _isLoading = false;

  final List<String> _contactMethods = ['email', 'phone', 'push'];

  @override
  void initState() {
    super.initState();
    // Prellenar campos con datos existentes del usuario, si los hay
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            _fullNameController.text = data?['displayName'] ?? user.displayName ?? '';
            _phoneController.text = data?['phone'] ?? '';
            _idNumberController.text = data?['idNumber'] ?? '';
            _cityController.text = data?['location']?['city'] ?? '';
            _neighborhoodController.text = data?['location']?['neighborhood'] ?? '';
            _preferredContactMethod = data?['preferredContactMethod'] ?? 'email';
          });
          print('Datos prellenados para UID=${user.uid}: ${doc.data()} en ${DateTime.now()}');
        }
      }).catchError((e) {
        print('Error al prellenar datos: $e en ${DateTime.now()}');
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          setState(() {
            _errorMessage = 'No hay usuario autenticado.';
            _isLoading = false;
          });
          print('No hay usuario autenticado en ${DateTime.now()}');
          return;
        }

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
          'preferredContactMethod': _preferredContactMethod,
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
          'preferredContactMethod': _preferredContactMethod,
          'preferences': {'notificationsEnabled': true, 'language': 'es'},
        }} en ${DateTime.now()}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil guardado exitosamente')),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error al guardar perfil: $e';
            _isLoading = false;
          });
        }
        print('Error al guardar perfil: $e en ${DateTime.now()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
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
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.person, color: Colors.green),
                  ),
                  validator: (value) => value!.isEmpty ? 'Ingrese el nombre completo' : null,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _idNumberController,
                  decoration: InputDecoration(
                    labelText: 'Número de Identificación',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.badge, color: Colors.green),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Ingrese el número de identificación' : null,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.phone, color: Colors.green),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value!.isEmpty ? 'Ingrese el número de teléfono' : null,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'Ciudad',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.location_city, color: Colors.green),
                  ),
                  validator: (value) => value!.isEmpty ? 'Ingrese la ciudad' : null,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _neighborhoodController,
                  decoration: InputDecoration(
                    labelText: 'Barrio',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.map, color: Colors.green),
                  ),
                  validator: (value) => value!.isEmpty ? 'Ingrese el barrio' : null,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _preferredContactMethod,
                  decoration: InputDecoration(
                    labelText: 'Método de Contacto Preferido',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.contact_mail, color: Colors.green),
                  ),
                  items: _contactMethods
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method.capitalize()),
                          ))
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (mounted) {
                            setState(() {
                              _preferredContactMethod = value;
                            });
                          }
                        },
                  validator: (value) => value == null ? 'Seleccione un método de contacto' : null,
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
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Guardar', style: TextStyle(color: Colors.white)),
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
    _fullNameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }
}

// Extensión para capitalizar strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}