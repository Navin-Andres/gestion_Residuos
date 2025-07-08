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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        if ((await isValidImageBytes(bytes)).isValid) setState(() => selectedImage = bytes);
      } else {
        final file = File(pickedFile.path);
        if ((await isValidImageFile(file)).isValid) setState(() => selectedImage = file);
      }
    }
  }

  void _removeImage() => setState(() => selectedImage = null);

  Future<void> _submitComplaint() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Usuario no autenticado');
        await user.getIdToken(true);

        String? imageUrl = selectedImage != null
            ? await _uploadImage(user.uid, selectedImage)
            : null;
        final userData = (await FirebaseFirestore.instance.collection('users').doc(user.uid).get()).data() ?? {};
        final fullName = userData['displayName'] ?? 'Sin nombre';
        final idNumber = userData['idNumber'] ?? 'No disponible';
        final phone = userData['phone'] ?? 'No disponible';

        if (['Sin nombre', 'No disponible'].contains(fullName) || ['No disponible'].contains(idNumber) || ['No disponible'].contains(phone)) {
          throw Exception('Perfil incompleto');
        }

        await FirebaseFirestore.instance.collection('complaints').add({
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
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Queja enviada exitosamente')));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().contains('Perfil incompleto')
              ? 'Por favor, completa tu perfil'
              : 'Error al enviar queja: $e')),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<String?> _uploadImage(String userId, dynamic image) async {
    final imageBytes = image is File ? await image.readAsBytes() : image as Uint8List;
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) throw Exception('Fallo al decodificar imagen');
    final uploadBytes = img.encodeJpg(decodedImage, quality: 85);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('complaints/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = storageRef.putData(uploadBytes, SettableMetadata(contentType: 'image/jpeg'));
    await uploadTask.whenComplete(() {});
    return await storageRef.getDownloadURL();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar foto'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
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
    );
  }

  Widget _buildDropdown(String key, String hint, List<String> items, {String? Function(String?)? validator}) {
    return DropdownButtonFormField<String>(
      value: _controllers[key]!.text.isNotEmpty ? _controllers[key]!.text : null,
      hint: Text(hint),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (value) => setState(() => _controllers[key]!.text = value ?? ''),
      validator: validator,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }
}