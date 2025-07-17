import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'video_player_screen.dart';
import 'image_viewer_screen.dart';
import 'content_upload_screen.dart';

class EducationalContentScreen extends StatefulWidget {
  const EducationalContentScreen({Key? key}) : super(key: key);

  @override
  _EducationalContentScreenState createState() => _EducationalContentScreenState();
}

class _EducationalContentScreenState extends State<EducationalContentScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool? _isAdmin;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        setState(() {
          _isAdmin = userDoc.data()?['role'] == 'administrador';
        });
      } catch (e) {
        print('Error checking admin role: $e');
        setState(() {
          _isAdmin = false;
        });
      }
    }
  }

  Future<void> _deleteContent(BuildContext context, DocumentSnapshot doc) async {
    if (_isAdmin != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo administradores pueden borrar contenido.')));
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar este contenido?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await doc.reference.delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contenido eliminado exitosamente.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _editContent(BuildContext context, DocumentSnapshot doc) async {
    if (_isAdmin != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo administradores pueden editar contenido.')));
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final type = doc.reference.parent.id;
    final TextEditingController titleController = TextEditingController(text: data['title'] ?? '');
    final TextEditingController descriptionController = TextEditingController(text: data['description'] ?? '');
    final TextEditingController urlController = TextEditingController(text: data[type == 'educational_content_videos' ? 'videoUrl' : 'imageUrl'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Contenido'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              if (type == 'educational_content_videos')
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL del Video'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                await doc.reference.update({
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  if (type == 'educational_content_videos') 'videoUrl': urlController.text.trim(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contenido actualizado.')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _viewContent(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = doc.reference.parent.id;
    if (type == 'educational_content_videos') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoUrl: data['videoUrl'])),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ImageViewerScreen(imageUrl: data['imageUrl'])),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes estar autenticado para ver el contenido.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contenido Educativo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por título o descripción...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0)),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFD4E4D2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('educational_content_videos')
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, videoSnapshot) {
              if (videoSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('educational_content_images')
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, imageSnapshot) {
                  if (imageSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (videoSnapshot.hasError || imageSnapshot.hasError) {
                    return Center(child: Text('Error al cargar contenido: ${videoSnapshot.error ?? imageSnapshot.error}'));
                  }

                  final allDocs = [
                    ...?videoSnapshot.data?.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _searchQuery.isEmpty ||
                          (data['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                          (data['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                    }),
                    ...?imageSnapshot.data?.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _searchQuery.isEmpty ||
                          (data['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                          (data['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                    }),
                  ];

                  return ListView.builder(
                    itemCount: allDocs.length,
                    itemBuilder: (context, index) {
                      final doc = allDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = doc.reference.parent.id;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () => _viewContent(context, doc),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  type == 'educational_content_images'
                                      ? Image.network(data['imageUrl'], width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.image, size: 80);
                                        })
                                      : const Icon(Icons.video_library, size: 80, color: Colors.blue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['title'] ?? 'Sin título', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        Text('${data['description'] ?? 'Sin descripción'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  if (user.uid == data['uploadedBy'] || _isAdmin == true)
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'delete') await _deleteContent(context, doc);
                                        if (value == 'edit') await _editContent(context, doc);
                                        if (value == 'view') _viewContent(context, doc);
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                        const PopupMenuItem(value: 'delete', child: Text('Borrar')),
                                        const PopupMenuItem(value: 'view', child: Text('Ver')),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FloatingActionButton.extended(
              heroTag: 'image_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContentUploadScreen(type: 'image')),
                );
              },
              backgroundColor: Colors.green[700],
              icon: const Icon(Icons.image, color: Colors.white),
              label: const Text('Imágenes', style: TextStyle(color: Colors.white)),
            ),
          ),
          FloatingActionButton.extended(
            heroTag: 'video_fab',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContentUploadScreen(type: 'video')),
              );
            },
            backgroundColor: Colors.green[700],
            icon: const Icon(Icons.video_library, color: Colors.white),
            label: const Text('Videos', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}