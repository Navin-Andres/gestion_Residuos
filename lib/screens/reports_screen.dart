import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_prueba2/image_validation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? userRole = 'loading'; // Estado inicial para indicar carga
  final Set<String> _selectedComplaints = {};
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    // Limpiar caché de imágenes problemáticas
    const problematicUrls = [
      'https://firebasestorage.googleapis.com/v0/b/gestion-de-residuos-ec0a2.firebasestorage.app/o/complaints%2F47sYzQtbGrc8hffLK2KTBwephxB3%2F1751607955674.jpg?alt=media&token=09aefdcb-fd15-44db-9b16-c23820112e18',
      'https://firebasestorage.googleapis.com/v0/b/gestion-de-residuos-ec0a2.firebasestorage.app/o/complaints%2F47sYzQtbGrc8hffLK2KTBwephxB3%2F1751635785331.jpg?alt=media&token=c438bf28-b225-4869-b09a-9241f4c8dacb',
    ];
    for (var url in problematicUrls) {
      CachedNetworkImage.evictFromCache(url);
      print("Caché limpiada para $url en ${DateTime.now()} en plataforma: ${kIsWeb ? 'web' : 'móvil'}");
    }
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        userRole = 'anonymous';
        print("Usuario no autenticado en ${DateTime.now()}");
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para acceder.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      await user.getIdToken(true); // Renovar token
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc.data()?['role'] == null) {
        setState(() {
          userRole = 'anonymous';
          print("Rol no encontrado para UID: ${user.uid} en ${DateTime.now()}");
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, completa tu perfil con un rol válido.')),
        );
      } else {
        setState(() {
          userRole = userDoc.data()?['role'] as String? ?? 'anonymous';
          print("Rol del usuario cargado: $userRole para UID: ${user.uid} en ${DateTime.now()}");
        });
      }
    } catch (e) {
      print("Error al obtener el rol: $e en ${DateTime.now()}");
      setState(() {
        userRole = 'anonymous';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los permisos. Contacta al administrador.')),
      );
    }
  }

  Future<void> _deleteSelectedComplaints() async {
    if (userRole != 'admin' && userRole != 'empresa') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo administradores o empresas pueden eliminar quejas')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar las quejas seleccionadas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final docId in _selectedComplaints) {
        final complaintDoc = await _firestore.collection('complaints').doc(docId).get();
        final imageUrl = complaintDoc.data()?['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
            print("Imagen eliminada: $imageUrl en ${DateTime.now()}");
          } catch (e) {
            print("Error al eliminar imagen: $e en ${DateTime.now()}");
          }
        }
        await _firestore.collection('complaints').doc(docId).delete();
        print("Queja eliminada: $docId en ${DateTime.now()}");
      }
      setState(() {
        _selectedComplaints.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quejas eliminadas exitosamente')),
      );
    } catch (e) {
      print("Error al eliminar quejas: $e en ${DateTime.now()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar quejas: $e')),
      );
    }
  }

  Future<void> _deleteAllComplaints() async {
    if (userRole != 'admin' && userRole != 'empresa') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo administradores o empresas pueden eliminar quejas')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación Total'),
        content: const Text('¿Estás seguro de eliminar todas las quejas? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await _firestore.collection('complaints').get();
      for (final doc in snapshot.docs) {
        final imageUrl = doc.data()['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
            print("Imagen eliminada: $imageUrl en ${DateTime.now()}");
          } catch (e) {
            print("Error al eliminar imagen: $e en ${DateTime.now()}");
          }
        }
        await doc.reference.delete();
        print("Queja eliminada: ${doc.id} en ${DateTime.now()}");
      }
      setState(() {
        _selectedComplaints.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas las quejas han sido eliminadas')),
      );
    } catch (e) {
      print("Error al eliminar todas las quejas: $e en ${DateTime.now()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar todas las quejas: $e')),
      );
    }
  }

  Future<void> _deleteComplaint(String docId, String? imageUrl) async {
    if (userRole != 'admin' && userRole != 'empresa') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo administradores o empresas pueden eliminar quejas')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar esta queja?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
          print("Imagen eliminada: $imageUrl en ${DateTime.now()}");
        } catch (e) {
          if (e.toString().contains('unauthorized')) {
            print("Error de permisos al eliminar imagen: $e en ${DateTime.now()}");
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No tienes permisos para eliminar la imagen. Contacta al administrador.')),
            );
          } else {
            print("Error al eliminar imagen: $e en ${DateTime.now()}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al eliminar imagen: $e')),
            );
          }
        }
      }
      await _firestore.collection('complaints').doc(docId).delete();
      print("Queja eliminada: $docId en ${DateTime.now()}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queja eliminada exitosamente')),
      );
    } catch (e) {
      print("Error al eliminar queja: $e en ${DateTime.now()}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar queja: $e')),
      );
    }
  }

  Future<void> _editComplaint(String docId, Map<String, dynamic> currentData) async {
    if (userRole != 'admin' && userRole != 'empresa') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo administradores o empresas pueden editar quejas')),
      );
      return;
    }

    final descriptionController = TextEditingController(text: currentData['description'] ?? '');
    final addressController = TextEditingController(text: currentData['address'] ?? '');
    final neighborhoodController = TextEditingController(text: currentData['neighborhood'] ?? '');
    final recipientController = TextEditingController(text: currentData['recipient'] ?? '');
    String? status = currentData['status'] ?? 'Pendiente';
    dynamic selectedImage;
    String? imageUrl = currentData['imageUrl'];
    bool isLoading = false;

    Future<void> pickImage(ImageSource source) async {
      final picker = ImagePicker();
      try {
        final pickedFile = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
        if (pickedFile != null) {
          if (kIsWeb) {
            final bytes = await pickedFile.readAsBytes();
            final validation = await isValidImageBytes(bytes);
            if (validation.isValid) {
              selectedImage = bytes;
            } else {
              throw Exception("Imagen inválida (web): ${validation.error}");
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
              selectedImage = file;
            } else {
              throw Exception("Imagen inválida (móvil): ${validation.error}");
            }
          }
        }
      } catch (e) {
        print("Error al seleccionar imagen: $e en ${DateTime.now()}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }

    void removeImage() {
      selectedImage = null;
      imageUrl = null;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Queja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: neighborhoodController,
                  decoration: const InputDecoration(labelText: 'Barrio', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: recipientController.text.isNotEmpty ? recipientController.text : null,
                  hint: const Text('Selecciona un destinatario'),
                  items: const [
                    DropdownMenuItem(value: 'Interaseo Valledupar', child: Text('Interaseo Valledupar')),
                    DropdownMenuItem(value: 'Autoridad Ambiental', child: Text('Autoridad Ambiental')),
                    DropdownMenuItem(value: 'Alcaldía de Valledupar', child: Text('Alcaldía de Valledupar')),
                  ],
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      if (newValue != null) {
                        recipientController.text = newValue;
                      }
                    });
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  hint: const Text('Selecciona un estado'),
                  items: const [
                    DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'En Proceso', child: Text('En Proceso')),
                    DropdownMenuItem(value: 'Resuelto', child: Text('Resuelto')),
                  ],
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      if (newValue != null) {
                        status = newValue;
                      }
                    });
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Tomar foto'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo),
                      label: const Text('Subir imagen'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                    ),
                  ],
                ),
                if (selectedImage != null || imageUrl != null) ...[
                  const SizedBox(height: 10),
                  selectedImage != null
                      ? kIsWeb
                          ? Image.memory(selectedImage as Uint8List, height: 100, fit: BoxFit.cover)
                          : Image.file(selectedImage as File, height: 100, fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: imageUrl!,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setDialogState(removeImage);
                    },
                  ),
                ],
                if (isLoading) const CircularProgressIndicator(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (descriptionController.text.isEmpty || descriptionController.text.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('La descripción debe tener al menos 10 caracteres')),
                        );
                        return;
                      }
                      if (addressController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, ingresa una dirección')),
                        );
                        return;
                      }
                      if (neighborhoodController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, ingresa un barrio')),
                        );
                        return;
                      }
                      if (recipientController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, selecciona un destinatario')),
                        );
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                      });

                      try {
                        String? newImageUrl = imageUrl;
                        if (selectedImage != null) {
                          Uint8List imageBytes;
                          String source = kIsWeb ? 'web' : 'móvil';
                          String format = 'jpeg';
                          String extension = 'jpg';
                          if (selectedImage is File) {
                            final validation = await isValidImageFile(selectedImage);
                            if (!validation.isValid) {
                              throw Exception("Archivo de imagen inválido ($source): ${validation.error}");
                            }
                            imageBytes = await selectedImage.readAsBytes();
                          } else {
                            final validation = await isValidImageBytes(selectedImage);
                            if (!validation.isValid) {
                              throw Exception("Datos de imagen inválidos ($source): ${validation.error}");
                            }
                            imageBytes = selectedImage;
                          }

                          final decodedImage = img.decodeImage(imageBytes);
                          if (decodedImage == null) {
                            throw Exception("Fallo al decodificar la imagen ($source) en ${DateTime.now()}");
                          }
                          imageBytes = img.encodeJpg(decodedImage, quality: 85);

                          if (imageUrl != null && imageUrl!.contains('firebasestorage.googleapis.com')) {
                            try {
                              final ref = _storage.refFromURL(imageUrl!);
                              await ref.delete();
                              print("Imagen antigua eliminada: $imageUrl en ${DateTime.now()}");
                            } catch (e) {
                              print("Error al eliminar imagen antigua: $e en ${DateTime.now()}");
                            }
                          }

                          final ref = _storage
                              .ref()
                              .child('complaints/${currentData['userId']}/${DateTime.now().millisecondsSinceEpoch}.$extension');
                          final uploadTask = ref.putData(imageBytes, SettableMetadata(contentType: 'image/$format'));
                          final snapshot = await uploadTask.whenComplete(() => print('Subida completada en ${DateTime.now()}'));
                          if (snapshot.state != TaskState.success) {
                            throw Exception("Fallo en la subida: ${snapshot.state} ($source) en ${DateTime.now()}");
                          }
                          newImageUrl = await ref.getDownloadURL();
                          print("Imagen subida: $newImageUrl ($source) en ${DateTime.now()}");
                        }

                        await _firestore.collection('complaints').doc(docId).update({
                          'description': descriptionController.text,
                          'address': addressController.text,
                          'neighborhood': neighborhoodController.text,
                          'recipient': recipientController.text,
                          'status': status,
                          'imageUrl': newImageUrl,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        print("Queja actualizada: $docId en ${DateTime.now()}");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Queja actualizada exitosamente')),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        print("Error al actualizar queja: $e en ${DateTime.now()}");
                        if (e.toString().contains('permission-denied') || e.toString().contains('unauthorized')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No tienes permisos para realizar esta acción.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al actualizar queja: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() {
                          isLoading = false;
                        });
                      }
                    },
              child: const Text('Guardar', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );

    descriptionController.dispose();
    addressController.dispose();
    neighborhoodController.dispose();
    recipientController.dispose();
  }

  Future<void> _createComplaint() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para crear una queja.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (userRole != 'admin' && userRole != 'empresa') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo administradores o empresas pueden crear quejas')),
      );
      return;
    }

    final descriptionController = TextEditingController();
    final addressController = TextEditingController();
    final neighborhoodController = TextEditingController();
    final recipientController = TextEditingController();
    String? status = 'Pendiente';
    dynamic selectedImage;
    bool isLoading = false;

    Future<void> pickImage(ImageSource source) async {
      final picker = ImagePicker();
      try {
        final pickedFile = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
        if (pickedFile != null) {
          if (kIsWeb) {
            final bytes = await pickedFile.readAsBytes();
            final validation = await isValidImageBytes(bytes);
            if (validation.isValid) {
              selectedImage = bytes;
            } else {
              throw Exception("Imagen inválida (web): ${validation.error}");
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
              selectedImage = file;
            } else {
              throw Exception("Imagen inválida (móvil): ${validation.error}");
            }
          }
        }
      } catch (e) {
        print("Error al seleccionar imagen: $e en ${DateTime.now()}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }

    void removeImage() {
      selectedImage = null;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Crear Nueva Queja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: neighborhoodController,
                  decoration: const InputDecoration(labelText: 'Barrio', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: recipientController.text.isNotEmpty ? recipientController.text : null,
                  hint: const Text('Selecciona un destinatario'),
                  items: const [
                    DropdownMenuItem(value: 'Interaseo Valledupar', child: Text('Interaseo Valledupar')),
                    DropdownMenuItem(value: 'Autoridad Ambiental', child: Text('Autoridad Ambiental')),
                    DropdownMenuItem(value: 'Alcaldía de Valledupar', child: Text('Alcaldía de Valledupar')),
                  ],
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      if (newValue != null) {
                        recipientController.text = newValue;
                      }
                    });
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  hint: const Text('Selecciona un estado'),
                  items: const [
                    DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'En Proceso', child: Text('En Proceso')),
                    DropdownMenuItem(value: 'Resuelto', child: Text('Resuelto')),
                  ],
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      if (newValue != null) {
                        status = newValue;
                      }
                    });
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Tomar foto'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => pickImage(ImageSource.gallery),
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
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setDialogState(removeImage);
                    },
                  ),
                ],
                if (isLoading) const CircularProgressIndicator(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (descriptionController.text.isEmpty || descriptionController.text.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('La descripción debe tener al menos 10 caracteres')),
                        );
                        return;
                      }
                      if (addressController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, ingresa una dirección')),
                        );
                        return;
                      }
                      if (neighborhoodController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, ingresa un barrio')),
                        );
                        return;
                      }
                      if (recipientController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, selecciona un destinatario')),
                        );
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                      });

                      try {
                        String? imageUrl;
                        if (selectedImage != null) {
                          Uint8List imageBytes;
                          String source = kIsWeb ? 'web' : 'móvil';
                          String format = 'jpeg';
                          String extension = 'jpg';
                          if (selectedImage is File) {
                            final validation = await isValidImageFile(selectedImage);
                            if (!validation.isValid) {
                              throw Exception("Archivo de imagen inválido ($source): ${validation.error}");
                            }
                            imageBytes = await selectedImage.readAsBytes();
                          } else {
                            final validation = await isValidImageBytes(selectedImage);
                            if (!validation.isValid) {
                              throw Exception("Datos de imagen inválidos ($source): ${validation.error}");
                            }
                            imageBytes = selectedImage;
                          }

                          final decodedImage = img.decodeImage(imageBytes);
                          if (decodedImage == null) {
                            throw Exception("Fallo al decodificar la imagen ($source) en ${DateTime.now()}");
                          }
                          imageBytes = img.encodeJpg(decodedImage, quality: 85);

                          final ref = _storage
                              .ref()
                              .child('complaints/${_auth.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.$extension');
                          final uploadTask = ref.putData(imageBytes, SettableMetadata(contentType: 'image/$format'));
                          final snapshot = await uploadTask.whenComplete(() => print('Subida completada en ${DateTime.now()}'));
                          if (snapshot.state != TaskState.success) {
                            throw Exception("Fallo en la subida: ${snapshot.state} ($source) en ${DateTime.now()}");
                          }
                          imageUrl = await ref.getDownloadURL();
                          print("Imagen subida: $imageUrl ($source) en ${DateTime.now()}");
                        }

                        final userId = _auth.currentUser!.uid;
                        final userDoc = await _firestore.collection('users').doc(userId).get();
                        final userData = userDoc.data() ?? {};
                        final fullName = userData['displayName'] ?? 'Sin nombre';
                        final idNumber = userData['idNumber'] ?? 'No disponible';
                        final phone = userData['phone'] ?? 'No disponible';

                        if (fullName == 'Sin nombre' || idNumber == 'No disponible' || phone == 'No disponible') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor, completa tu perfil con nombre, cédula y teléfono.')),
                          );
                          Navigator.pushReplacementNamed(context, '/profile_setup');
                          return;
                        }

                        await _firestore.collection('complaints').add({
                          'userId': userId,
                          'description': descriptionController.text,
                          'address': addressController.text,
                          'neighborhood': neighborhoodController.text,
                          'recipient': recipientController.text,
                          'status': status,
                          'timestamp': FieldValue.serverTimestamp(),
                          'imageUrl': imageUrl,
                          'fullName': fullName,
                          'idNumber': idNumber,
                          'phone': phone,
                        });

                        print("Queja creada en ${DateTime.now()}");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Queja creada exitosamente')),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        print("Error al crear queja: $e en ${DateTime.now()}");
                        if (e.toString().contains('permission-denied') || e.toString().contains('unauthorized')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No tienes permisos para realizar esta acción.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al crear queja: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() {
                          isLoading = false;
                        });
                      }
                    },
              child: const Text('Crear', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );

    descriptionController.dispose();
    addressController.dispose();
    neighborhoodController.dispose();
    recipientController.dispose();
  }

  Future<void> _viewDetails(String docId, Map<String, dynamic> report) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de la Queja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Nombre Completo', report['fullName'] ?? 'Sin nombre'),
              _buildDetailRow('Cédula', report['idNumber'] ?? 'No disponible'),
              _buildDetailRow('Teléfono', report['phone'] ?? 'No disponible'),
              _buildDetailRow('Descripción', report['description'] ?? 'Sin descripción'),
              _buildDetailRow('Dirección', report['address'] ?? 'Sin dirección'),
              _buildDetailRow('Barrio', report['neighborhood'] ?? 'Sin barrio'),
              const SizedBox(height: 10),
              report['imageUrl'] != null && (report['imageUrl'] as String).isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: report['imageUrl'],
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator(color: Colors.green)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(child: Icon(Icons.error, color: Colors.red)),
                        ),
                      ),
                    )
                  : Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text(
                          'No se proporcionó ninguna imagen',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      print('Usuario no autenticado, redirigiendo a /login');
      Navigator.pushReplacementNamed(context, '/login');
      return const SizedBox.shrink(); // Evitar renderizado si no hay usuario
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context, '/admin'); // Cambiado a /admin para regresar al Panel Administrativo
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vista de Reportes', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green[700],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/admin'); // Cambiado a /admin
            },
          ),
          actions: [
            if (userRole == 'admin' || userRole == 'empresa') ...[
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _createComplaint,
                tooltip: 'Crear nueva queja',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                onPressed: _selectedComplaints.isNotEmpty ? _deleteSelectedComplaints : _deleteAllComplaints,
                tooltip: _selectedComplaints.isNotEmpty ? 'Eliminar seleccionadas' : 'Eliminar todas',
              ),
            ],
            if (userRole == 'loading') // Mostrar indicador mientras carga
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[100]!, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              }
              if (snapshot.hasError) {
                print('Error en Firestore: ${snapshot.error} en ${DateTime.now()}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Error al cargar reportes.', style: TextStyle(color: Colors.red)),
                      TextButton(
                        onPressed: _fetchUserRole,
                        child: const Text('Reintentar', style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No hay reportes disponibles.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                );
              }

              final reports = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index].data() as Map<String, dynamic>;
                  final docId = reports[index].id;
                  final timestamp = report['timestamp'] as Timestamp?;
                  final formattedDate = timestamp != null
                      ? DateFormat('yyyy-MM-dd, HH:mm').format(timestamp.toDate()).replaceAll('PM', 'PM -05').replaceAll('AM', 'AM -05')
                      : 'Sin fecha';
                  final imageUrl = report['imageUrl'] as String?;
                  final fullName = report['fullName'] ?? 'Sin nombre';
                  final idNumber = report['idNumber'] ?? 'No disponible';
                  final phone = report['phone'] ?? 'No disponible';
                  final description = report['description'] ?? 'Sin descripción';
                  final address = report['address'] ?? 'Sin dirección';
                  final neighborhood = report['neighborhood'] ?? 'Sin barrio';

                  final isValidUrl = imageUrl != null &&
                      imageUrl.isNotEmpty &&
                      Uri.tryParse(imageUrl)?.hasScheme == true &&
                      imageUrl.contains('firebasestorage.googleapis.com');

                  if (isValidUrl) {
                    print('Intentando cargar imagen: $imageUrl en ${DateTime.now()} en plataforma: ${kIsWeb ? 'web' : 'móvil'}');
                  } else {
                    print('URL de imagen inválida o ausente para reporte $docId: $imageUrl en ${DateTime.now()}');
                  }

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (userRole == 'admin' || userRole == 'empresa')
                            Checkbox(
                              value: _selectedComplaints.contains(docId),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedComplaints.add(docId);
                                  } else {
                                    _selectedComplaints.remove(docId);
                                  }
                                });
                              },
                              activeColor: Colors.green[700],
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Queja #${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility, color: Colors.blue),
                                          onPressed: () => _viewDetails(docId, report),
                                          tooltip: 'Ver detalles',
                                        ),
                                        if (userRole == 'admin' || userRole == 'empresa') ...[
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () => _editComplaint(docId, report),
                                            tooltip: 'Editar queja',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteComplaint(docId, imageUrl),
                                            tooltip: 'Eliminar queja',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow('Nombre Completo', fullName),
                                _buildDetailRow('Cédula', idNumber),
                                _buildDetailRow('Teléfono', phone),
                                _buildDetailRow('Descripción', description),
                                _buildDetailRow('Dirección', address),
                                _buildDetailRow('Barrio', neighborhood),
                                const SizedBox(height: 8),
                                Text(
                                  'Fecha: $formattedDate',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                isValidUrl
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl!,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(child: CircularProgressIndicator(color: Colors.green)),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(child: Icon(Icons.error, color: Colors.red)),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Text(
                                            'No se proporcionó ninguna imagen',
                                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}