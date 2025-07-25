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

class _ComplaintScreenState extends State<ComplaintScreen> {
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

  @override
  void initState() {
    super.initState();
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
          const SnackBar(content: Text('Solo los usuarios pueden registrar quejas desde esta pantalla.')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error al obtener el rol: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar permisos. Contacta al administrador.')),
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
          } else {
            throw Exception('Imagen inválida en web');
          }
        } else {
          final file = File(pickedFile.path);
          final validation = await isValidImageFile(file);
          if (validation.isValid) {
            if (validation.format == 'heic') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Formato HEIC detectado. Se convertirá a JPEG.')),
              );
            }
            setState(() => selectedImage = file);
          } else {
            throw Exception('Imagen inválida en móvil: ${validation.error}');
          }
        }
      } catch (e) {
        print('Error al seleccionar imagen: $e en ${DateTime.now()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  void _removeImage() => setState(() => selectedImage = null);

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
        'senderEmail': senderEmail, // Cambiado de senderName a senderEmail
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

        // Notificación para el usuario
        await _createNotification(
          user.uid,
          'Queja Enviada',
          'usuario',
          complaintData,
        );

        // Notificación para empresa o autoridad según el recipient
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
          const SnackBar(content: Text('Queja enviada exitosamente')),
        );
        Navigator.pop(context);
      } catch (e) {
        print('Error al enviar queja: $e en ${DateTime.now()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar queja: $e')),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Queja', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[100]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField('description', 'Descripción', maxLines: 4, validator: (v) =>
                (v?.isEmpty ?? true) || (v?.length ?? 0) < 10 ? 'Mínimo 10 caracteres' : null),
            const SizedBox(height: 10),
            _buildTextField('address', 'Dirección', validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null),
            const SizedBox(height: 10),
            _buildTextField('neighborhood', 'Barrio', validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null),
            const SizedBox(height: 10),
            _buildDropdown('recipient', 'Selecciona un destinatario', [
              'Interaseo Valledupar',
              'Autoridad Ambiental',
              'Alcaldía de Valledupar',
            ], validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: isLoading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar foto'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('Subir imagen'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                ),
              ],
            ),
            if (selectedImage != null) ...[
              const SizedBox(height: 10),
              kIsWeb
                  ? Image.memory(selectedImage as Uint8List, height: 100, fit: BoxFit.cover)
                  : Image.file(selectedImage as File, height: 100, fit: BoxFit.cover),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _removeImage),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _submitComplaint,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar Queja'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String key, String label, {int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: _controllers[key]!,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      maxLines: maxLines,
      validator: validator,
      enabled: !isLoading,
    );
  }

  Widget _buildDropdown(String key, String hint, List<String> items, {String? Function(String?)? validator}) {
    return DropdownButtonFormField<String>(
      value: _controllers[key]!.text.isNotEmpty ? _controllers[key]!.text : null,
      hint: Text(hint),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: isLoading ? null : (value) => setState(() => _controllers[key]!.text = value ?? ''),
      validator: validator,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }
}