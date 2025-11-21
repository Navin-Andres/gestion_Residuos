import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_prueba2/image_validation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  _ComplaintScreenState createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _controllers = {
    'description': TextEditingController(),
    'address': TextEditingController(),
    'neighborhood': TextEditingController(),
    'recipient': TextEditingController(),
  };
  dynamic selectedImage;
  bool isLoading = false;
  String? userRole;
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
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        userRole = userDoc.data()?['role'] ?? 'usuario';
        print('Rol del usuario cargado: $userRole en ${DateTime.now()}');
      });
      if (userRole != 'usuario') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Solo los usuarios pueden registrar quejas desde esta pantalla.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error al obtener el rol: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error al cargar permisos. Contacta al administrador.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
    if (pickedFile != null) {
      try {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          if ((await isValidImageBytes(bytes)).isValid) {
            setState(() => selectedImage = bytes);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Imagen seleccionada correctamente'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            throw Exception('Imagen inválida en web');
          }
        } else {
          final file = File(pickedFile.path);
          final validation = await isValidImageFile(file);
          if (validation.isValid) {
            if (validation.format == 'heic') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Formato HEIC detectado. Se convertirá a JPEG.'),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
            setState(() => selectedImage = file);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Imagen seleccionada correctamente'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            throw Exception('Imagen inválida en móvil: ${validation.error}');
          }
        }
      } catch (e) {
        print('Error al seleccionar imagen: $e en ${DateTime.now()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _removeImage() => setState(() {
        selectedImage = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Imagen eliminada'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      });

  Future<void> _createNotification(String userId, String title, String role, Map<String, dynamic> complaintData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      String senderEmail = currentUser?.email ?? 'correo@desconocido.com';

      final notificationData = {
        'userId': userId,
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
        'role': role,
        'read': false,
        'complaintId': complaintData['complaintId'],
        'description': complaintData['description'],
        'address': complaintData['address'],
        'neighborhood': complaintData['neighborhood'],
        'recipient': complaintData['recipient'],
        'imageUrl': complaintData['imageUrl'],
        'senderEmail': senderEmail,
      };
      await FirebaseFirestore.instance.collection('notifications').add(notificationData);
      print('Notificación creada para userId: $userId, senderEmail: $senderEmail en ${DateTime.now()}');
    } catch (e) {
      print('Error al crear notificación: $e en ${DateTime.now()}');
    }
  }

  Future<void> _submitComplaint() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Usuario no autenticado');
        await user.getIdToken(true);

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        final fullName = userData['displayName'] ?? 'Sin nombre';
        final idNumber = userData['idNumber'] ?? 'No disponible';
        final phone = userData['phone'] ?? 'No disponible';

        if (fullName == 'Sin nombre' || idNumber == 'No disponible' || phone == 'No disponible') {
          Navigator.pushReplacementNamed(context, '/profile_setup');
          throw Exception('Por favor, completa tu perfil con nombre, cédula y teléfono.');
        }

        String? imageUrl;
        if (selectedImage != null) {
          imageUrl = await _uploadImage(user.uid, selectedImage);
        }

        final complaintData = {
          'userId': user.uid,
          'description': _controllers['description']!.text,
          'address': _controllers['address']!.text,
          'neighborhood': _controllers['neighborhood']!.text,
          'recipient': _controllers['recipient']!.text,
          'status': 'Pendiente',
          'timestamp': FieldValue.serverTimestamp(),
          'imageUrl': imageUrl,
          'fullName': fullName,
          'idNumber': idNumber,
          'phone': phone,
        };

        final complaintRef = await FirebaseFirestore.instance.collection('complaints').add(complaintData);
        complaintData['complaintId'] = complaintRef.id;

        await _createNotification(
          user.uid,
          'Queja Enviada',
          'usuario',
          complaintData,
        );

        final recipient = _controllers['recipient']!.text;
        final recipientDoc = await FirebaseFirestore.instance.collection('recipients').doc(recipient).get();
        if (recipientDoc.exists) {
          final recipientData = recipientDoc.data()!;
          final recipientUserId = recipientData['userId'] as String?;
          final recipientRole = recipientData['role'] as String?;
          if (recipientUserId != null && recipientRole != null && (recipientRole == 'empresa' || recipientRole == 'autoridad')) {
            await _createNotification(
              recipientUserId,
              'Nueva Queja Recibida',
              recipientRole,
              complaintData,
            );
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Queja enviada exitosamente'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        print('Error al enviar queja: $e en ${DateTime.now()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar queja: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<String?> _uploadImage(String userId, dynamic image) async {
    try {
      final imageBytes = image is File ? await image.readAsBytes() : image as Uint8List;
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) throw Exception('Fallo al decodificar imagen');
      final uploadBytes = img.encodeJpg(decodedImage, quality: 85);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('complaints/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putData(uploadBytes, SettableMetadata(contentType: 'image/jpeg'));
      await uploadTask.whenComplete(() => print('Subida completada en ${DateTime.now()}'));
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error al subir imagen: $e en ${DateTime.now()}');
      throw Exception('Error al subir imagen: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (userRole == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green.shade700),
              const SizedBox(height: 16),
              Text(
                'Cargando permisos...',
                style: TextStyle(color: Colors.green.shade700, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Queja', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                      padding: const EdgeInsets.all(16), // Reducido de 24 a 16
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth > 600 ? 500 : double.infinity,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Información de la Queja',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green), // Reducido de 20 a 18
                              ),
                              const SizedBox(height: 12), // Reducido de 16 a 12
                              _buildTextField(
                                key: 'description',
                                label: 'Descripción de la queja',
                                icon: Icons.description,
                                maxLines: 4,
                                validator: (v) => (v?.isEmpty ?? true) || (v?.length ?? 0) < 10 ? 'Mínimo 10 caracteres' : null,
                                hintText: 'Describe el problema en detalle',
                              ),
                              const SizedBox(height: 12), // Reducido de 16 a 12
                              _buildTextField(
                                key: 'address',
                                label: 'Dirección',
                                icon: Icons.location_on,
                                validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                                hintText: 'Ej. Calle 10 #5-20',
                              ),
                              const SizedBox(height: 12), // Reducido de 16 a 12
                              _buildTextField(
                                key: 'neighborhood',
                                label: 'Barrio',
                                icon: Icons.home,
                                validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                                hintText: 'Ej. Centro',
                              ),
                              const SizedBox(height: 12), // Reducido de 16 a 12
                              _buildDropdown(
                                key: 'recipient',
                                hint: 'Selecciona un destinatario',
                                items: [
                                  'Interaseo Valledupar',
                                  'Autoridad Ambiental',
                                  'Alcaldía de Valledupar',
                                ],
                                icon: Icons.person,
                                validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null,
                                hintText: 'Selecciona una entidad',
                              ),
                              const SizedBox(height: 16), // Reducido de 24 a 16
                              const Text(
                                'Agregar Imagen (Opcional)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green), // Reducido de 18 a 16
                              ),
                              const SizedBox(height: 12), // Reducido de 16 a 12
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildImageButton(
                                    icon: Icons.camera_alt,
                                    label: 'Tomar foto',
                                    onPressed: () => _pickImage(ImageSource.camera),
                                  ),
                                  _buildImageButton(
                                    icon: Icons.photo,
                                    label: 'Subir imagen',
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                  ),
                                ],
                              ),
                              if (selectedImage != null) ...[
                                const SizedBox(height: 12), // Reducido de 16 a 12
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.green.shade700, width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      kIsWeb
                                          ? Image.memory(selectedImage as Uint8List, height: 120, fit: BoxFit.cover) // Reducido de 150 a 120
                                          : Image.file(selectedImage as File, height: 120, fit: BoxFit.cover), // Reducido de 150 a 120
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: _removeImage,
                                        tooltip: 'Eliminar imagen',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16), // Reducido de 24 a 16
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _submitComplaint,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32), // Reducido de 16 a 12
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 4,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Enviar Queja',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildTextField({
    required String key,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    String? hintText,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 8), // Reducido de 16 a 8
      child: TextFormField(
        controller: _controllers[key]!,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.green.shade700),
          prefixIcon: Icon(icon, color: Colors.green.shade700),
          suffixIcon: _controllers[key]!.text.isNotEmpty
              ? Icon(Icons.check_circle, color: Colors.green.shade700, size: 20)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
        ),
        maxLines: maxLines,
        validator: validator,
        enabled: !isLoading,
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildDropdown({
    required String key,
    required String hint,
    required List<String> items,
    required IconData icon,
    String? Function(String?)? validator,
    String? hintText,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 8), // Reducido de 16 a 8
      child: DropdownButtonFormField<String>(
        value: _controllers[key]!.text.isNotEmpty ? _controllers[key]!.text : null,
        hint: Text(hint, style: TextStyle(color: Colors.green.shade700)),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 16)))).toList(),
        onChanged: isLoading ? null : (value) => setState(() => _controllers[key]!.text = value ?? ''),
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green.shade700),
          suffixIcon: _controllers[key]!.text.isNotEmpty
              ? Icon(Icons.check_circle, color: Colors.green.shade700, size: 20)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildImageButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon, size: 24, color: Colors.white),
        label: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }
}