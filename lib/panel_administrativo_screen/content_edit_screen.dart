import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';

class ContentEditScreen extends StatefulWidget {
  final String type; // 'image' o 'video'
  final String documentId; // ID del documento a editar
  final String currentUrl; // URL actual del archivo
  final String currentTitle; // Título actual
  final String currentDescription; // Descripción actual

  const ContentEditScreen({
    Key? key,
    required this.type,
    required this.documentId,
    required this.currentUrl,
    required this.currentTitle,
    required this.currentDescription,
  }) : super(key: key);

  @override
  _ContentEditScreenState createState() => _ContentEditScreenState();
}

class _ContentEditScreenState extends State<ContentEditScreen> with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _imageFile;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  Uint8List? _thumbnailBytes;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.currentTitle;
    _descriptionController.text = widget.currentDescription;
    _selectedFileName = widget.currentUrl.split('/').last.split('?').first;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    if (widget.type == 'video') {
      _generateVideoThumbnail(null, url: widget.currentUrl);
    }
    _animationController.forward();
  }

  Future<void> _pickFile() async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: widget.type == 'image' ? ['jpg', 'png', 'jpeg'] : ['mp4', 'mov'],
        );
        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _selectedFileName = result.files.first.name;
            _selectedFileBytes = result.files.first.bytes;
            _imageFile = null;
            _thumbnailBytes = null;
          });
          if (widget.type == 'video' && _selectedFileBytes != null) {
            _generateVideoThumbnail(_selectedFileBytes!);
          }
        } else {
          _showSnackBar('No se seleccionó archivo válido.');
        }
      } else {
        if (widget.type == 'image') {
          final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            setState(() {
              _imageFile = File(pickedFile.path);
              _selectedFileName = pickedFile.name;
              _selectedFileBytes = null;
              _thumbnailBytes = null;
            });
          } else {
            _showSnackBar('No se seleccionó imagen.');
          }
        } else {
          final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
          if (pickedFile != null) {
            setState(() {
              _imageFile = File(pickedFile.path);
              _selectedFileName = pickedFile.name;
              _selectedFileBytes = null;
              _thumbnailBytes = null;
            });
            _generateVideoThumbnail(null, filePath: pickedFile.path);
          } else {
            _showSnackBar('No se seleccionó video.');
          }
        }
      }
    } catch (e) {
      _showSnackBar('Error al seleccionar archivo: $e');
    }
  }

  Future<void> _generateVideoThumbnail(Uint8List? bytes, {String? filePath, String? url}) async {
    if (widget.type != 'video') return;
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: url ?? filePath ?? '',
        imageFormat: ImageFormat.PNG,
        maxWidth: 120,
        quality: 25,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        print('Timeout al generar thumbnail para previsualización');
        return null;
      });
      if (thumbnail != null) {
        setState(() {
          _thumbnailBytes = thumbnail;
        });
      }
    } catch (e) {
      print('Error al generar thumbnail para previsualización: $e');
    }
  }

  Future<void> _updateContent() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Usuario no autenticado.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Por favor, ingresa un título.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? downloadUrl = widget.currentUrl;
      if (_imageFile != null || _selectedFileBytes != null) {
        // Eliminar el archivo anterior
        try {
          await _storage.refFromURL(widget.currentUrl).delete();
          print('Archivo anterior eliminado: ${widget.currentUrl}');
        } catch (e) {
          print('Error al eliminar archivo anterior: $e');
        }

        // Subir nuevo archivo
        String filePath = widget.type == 'image'
            ? 'educational_content_images/${DateTime.now().millisecondsSinceEpoch}_${_selectedFileName}'
            : 'educational_content_videos/${DateTime.now().millisecondsSinceEpoch}_${_selectedFileName}';
        UploadTask uploadTask;
        if (kIsWeb) {
          uploadTask = _storage.ref(filePath).putData(_selectedFileBytes!);
        } else {
          uploadTask = _storage.ref(filePath).putFile(_imageFile!);
        }

        print('Iniciando subida a $filePath');
        final snapshot = await uploadTask.whenComplete(() {});
        downloadUrl = await snapshot.ref.getDownloadURL();
        print('URL de descarga obtenida: $downloadUrl');
      }

      final firestoreSubCollection = widget.type == 'image' ? 'image' : 'video';
      final docRef = _firestore
          .collection('educational_content')
          .doc(firestoreSubCollection)
          .collection('items')
          .doc(widget.documentId);

      await docRef.update({
        'titulo': _titleController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'url': downloadUrl,
        'updatedAt': Timestamp.now(),
      });
      print('Documento actualizado en Firestore con ID: ${widget.documentId}');

      _showSnackBar('Contenido actualizado exitosamente.', isSuccess: true);
      setState(() {
        _imageFile = null;
        _selectedFileBytes = null;
        _selectedFileName = null;
        _thumbnailBytes = null;
        _isLoading = false;
      });
      _animationController.forward(from: 0.0);
      Navigator.pop(context); // Regresar tras actualizar
    } catch (e) {
      print('Error al actualizar contenido: $e');
      _showSnackBar('Error al actualizar contenido: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isSuccess
            ? Colors.green.shade600
            : isError
                ? Colors.red.shade600
                : Colors.grey.shade800,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    if (_imageFile == null && _selectedFileBytes == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.type == 'image'
            ? CachedNetworkImage(
                imageUrl: widget.currentUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    image: const DecorationImage(
                      image: AssetImage('assets/images/image_placeholder.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                  ),
                ),
              )
            : _thumbnailBytes != null
                ? Stack(
                    children: [
                      Image.memory(
                        _thumbnailBytes!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      image: const DecorationImage(
                        image: AssetImage('assets/images/video_placeholder.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  ),
      );
    }

    if (widget.type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: kIsWeb
            ? Image.memory(
                _selectedFileBytes!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    image: const DecorationImage(
                      image: AssetImage('assets/images/image_placeholder.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                  ),
                ),
              )
            : Image.file(
                _imageFile!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    image: const DecorationImage(
                      image: AssetImage('assets/images/image_placeholder.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                  ),
                ),
              ),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _thumbnailBytes != null
            ? Stack(
                children: [
                  Image.memory(
                    _thumbnailBytes!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/video_placeholder.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.type == 'image' ? 'Editar Imagen' : 'Editar Video',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ingresa un título para el contenido',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade600),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Describe el contenido',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade600),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildFilePreview(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _pickFile,
                            icon: Icon(
                              widget.type == 'image' ? Icons.image : Icons.videocam,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Seleccionar ${widget.type == 'image' ? 'Imagen' : 'Video'}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Archivo seleccionado: $_selectedFileName',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          )
                        : ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                              CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updateContent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: Text(
                                'Actualizar ${widget.type == 'image' ? 'Imagen' : 'Video'}',
                                style: const TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }
}