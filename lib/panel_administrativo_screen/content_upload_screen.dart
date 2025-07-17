import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ContentUploadScreen extends StatefulWidget {
  final String type;

  const ContentUploadScreen({Key? key, required this.type}) : super(key: key);

  @override
  _ContentUploadScreenState createState() => _ContentUploadScreenState();
}

class _ContentUploadScreenState extends State<ContentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes estar autenticado para seleccionar imágenes.')));
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('educational_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}');
        await storageRef.putFile(File(image.path));
        _imageUrl = await storageRef.getDownloadURL();
        print('Imagen seleccionada, URL: $_imageUrl');
        if (mounted) setState(() {});
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se seleccionó ninguna imagen.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')));
    }
  }

  Future<void> _uploadContent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Debes estar autenticado.')));
          return;
        }

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.data()?['role'] != 'administrador') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Solo los administradores pueden subir contenido.')));
          return;
        }

        final ref = widget.type == 'image'
            ? FirebaseFirestore.instance.collection('educational_content_images').doc()
            : FirebaseFirestore.instance.collection('educational_content_videos').doc();
        await ref.set({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'uploadedBy': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          if (widget.type == 'video') 'videoUrl': _videoUrlController.text.trim(),
          if (widget.type == 'image' && _imageUrl != null) 'imageUrl': _imageUrl!,
        });
        print('Contenido subido a: ${ref.path}');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contenido subido exitosamente.')));

        _titleController.clear();
        _descriptionController.clear();
        _videoUrlController.clear();
        if (widget.type == 'image' && mounted) setState(() => _imageUrl = null);

        // Regresar a EducationalContentScreen después de subir
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al subir contenido: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type == 'image' ? 'Subir Imagen' : 'Subir Video'}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      'Formulario de Contenido',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Ingresa un título' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Ingresa una descripción' : null,
                    ),
                    const SizedBox(height: 15),
                    if (widget.type == 'video')
                      TextFormField(
                        controller: _videoUrlController,
                        decoration: const InputDecoration(labelText: 'URL del Video', border: OutlineInputBorder()),
                        validator: (value) => value == null || value.isEmpty ? 'Ingresa la URL del video' : null,
                      ),
                    const SizedBox(height: 15),
                    if (widget.type == 'image')
                      ElevatedButton(
                        onPressed: _isLoading ? null : _pickImage,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Seleccionar Imagen', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    if (widget.type == 'image' && _imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Image.network(_imageUrl!, height: 150, width: 150, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                          return const Text('Error al cargar la imagen');
                        }),
                      ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _uploadContent,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Subir ${widget.type == 'image' ? 'Imagen' : 'Video'}', style: const TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}