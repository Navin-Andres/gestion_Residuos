import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/content_upload_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/content_edit_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/image_viewer_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/video_player_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:async';
import 'dart:typed_data';

class EducationalContentScreen extends StatefulWidget {
  const EducationalContentScreen({Key? key}) : super(key: key);

  @override
  _EducationalContentScreenState createState() => _EducationalContentScreenState();
}

class _EducationalContentScreenState extends State<EducationalContentScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'todos';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Map<String, Uint8List> _thumbnailCache = {};
  List<String> _adminUserIds = [];
  List<DocumentSnapshot> _combinedDocs = [];
  String? _currentUserRole;
  bool _isLoading = false;
  StreamController<List<DocumentSnapshot>> _combinedStreamController = StreamController<List<DocumentSnapshot>>.broadcast();
  StreamSubscription? _combinedStreamSubscription; // Añadido: Para rastrear la suscripción

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchAdminUserIds();
    _fetchCurrentUserRole();
    _animationController.forward();
    _setupCombinedStream();
  }

  void _setupCombinedStream() {
    final videoStream = FirebaseFirestore.instance
        .collection('educational_content')
        .doc('video')
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('Error en videoStream: $error');
        }).map((snapshot) {
          print('Videos recibidos: ${snapshot.docs.length}');
          return snapshot.docs;
        });

    final imageStream = FirebaseFirestore.instance
        .collection('educational_content')
        .doc('image')
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('Error en imageStream: $error');
        }).map((snapshot) {
          print('Imágenes recibidas: ${snapshot.docs.length}');
          return snapshot.docs;
        });

    final combinedStream = StreamGroup.merge([videoStream, imageStream]);

    _combinedStreamSubscription = combinedStream.listen(
      (List<DocumentSnapshot> newDocs) {
        if (!_combinedStreamController.isClosed) {
          print('Actualizando con nuevos documentos: ${newDocs.length}');
          _updateCombinedDocs(newDocs);
        }
      },
      onError: (error) {
        if (!_combinedStreamController.isClosed) {
          print('Error en suscripción combinada: $error');
          _combinedStreamController.addError(error);
        }
      },
      onDone: () {
        print('Stream combinado cerrado');
        if (!_combinedStreamController.isClosed) {
          _combinedStreamController.close();
        }
      },
      cancelOnError: false,
    );
  }

  void _updateCombinedDocs(List<DocumentSnapshot> newDocs) {
    if (!mounted || _combinedStreamController.isClosed) return; // Evitar actualizar si el widget está disposed
    setState(() {
      _combinedDocs.removeWhere((doc) => newDocs.any((newDoc) => newDoc.id == doc.id));
      _combinedDocs.addAll(newDocs);
      _combinedDocs.sort((a, b) => (b.data() as Map<String, dynamic>)['createdAt']
          .compareTo((a.data() as Map<String, dynamic>)['createdAt']));
      print('Documentos combinados en "todos": ${_combinedDocs.length}');
      if (!_combinedStreamController.isClosed) {
        _combinedStreamController.add(_combinedDocs);
      }
    });
  }

  Future<void> _fetchAdminUserIds() async {
    try {
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'administrador')
          .get();
      setState(() {
        _adminUserIds = adminQuery.docs.map((doc) => doc.id).toList();
        print('UserIds de administradores encontrados: $_adminUserIds');
        if (_adminUserIds.isEmpty) {
          print('Advertencia: No se encontraron administradores en la colección "users".');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontraron administradores. Contacta al soporte.')),
          );
        }
      });
    } catch (e) {
      print('Error al obtener userIds de administradores: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos de administradores: $e')),
      );
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await _getUserRole(user.uid);
      setState(() {
        _currentUserRole = role;
      });
    }
  }

  Stream<List<DocumentSnapshot>> _getContentStream(String filter) {
    print('Obteniendo stream para filtro: $filter');
    if (filter == 'videos') {
      return FirebaseFirestore.instance
          .collection('educational_content')
          .doc('video')
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            print('Videos recibidos: ${snapshot.docs.length}');
            return snapshot.docs;
          });
    } else if (filter == 'imagenes') {
      return FirebaseFirestore.instance
          .collection('educational_content')
          .doc('image')
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            print('Imágenes recibidas: ${snapshot.docs.length}');
            return snapshot.docs;
          });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_combinedStreamController.isClosed) {
          _combinedStreamController.add(_combinedDocs);
          print('Forzando emisión de _combinedDocs para filtro "todos": ${_combinedDocs.length} documentos');
        }
      });
      return _combinedStreamController.stream;
    }
  }

  Widget _buildVideoThumbnail(String videoUrl, {double width = 120, double height = 80}) {
    if (videoUrl.isEmpty) {
      print('Error: URL de video vacía: $videoUrl');
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
          image: const DecorationImage(
            image: AssetImage('assets/images/video_placeholder.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.play_circle_fill,
            color: Colors.white,
            size: 36,
          ),
        ),
      );
    }

    if (_thumbnailCache.containsKey(videoUrl)) {
      print('Thumbnail cargado desde caché para: $videoUrl');
      return Stack(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: MemoryImage(_thumbnailCache[videoUrl]!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.3),
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
      );
    }

    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.PNG,
        maxWidth: width.toInt(),
        quality: 25,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Timeout al generar thumbnail para: $videoUrl');
          return null;
        },
      ).catchError((error) {
        print('Error al generar thumbnail para $videoUrl: $error');
        return null;
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Cargando thumbnail para: $videoUrl');
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          print('Thumbnail generado exitosamente para: $videoUrl');
          _thumbnailCache[videoUrl] = snapshot.data!;
          return Stack(
            children: [
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: MemoryImage(snapshot.data!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.3),
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
          );
        }
        print('No se pudo generar thumbnail para: $videoUrl, mostrando placeholder');
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
            image: const DecorationImage(
              image: AssetImage('assets/images/video_placeholder.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 36,
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteContent(String docId, String url, String type) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar este contenido? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Eliminar archivo de Firebase Storage
      await FirebaseStorage.instance.refFromURL(url).delete();
      print('Archivo eliminado de Storage: $url');

      // Eliminar documento de Firestore
      final firestoreSubCollection = type == 'image' ? 'image' : 'video';
      await FirebaseFirestore.instance
          .collection('educational_content')
          .doc(firestoreSubCollection)
          .collection('items')
          .doc(docId)
          .delete();
      print('Documento eliminado de Firestore: $docId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Contenido eliminado exitosamente.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green.shade600,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      print('Error al eliminar contenido: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar contenido: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildContentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isVideo = (data['tipo']?.toString().toLowerCase() ?? '') == 'video';
    final title = data['titulo'] ?? 'Sin título';
    final description = data['descripcion'] ?? 'Sin descripción';
    final url = data['url'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final userId = data['userId'] as String?;
    final docId = doc.id;

    print('Intentando renderizar tarjeta para: $title, URL: $url, UserId: $userId, Tipo: ${data['tipo']}');

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isLoading || url.isEmpty
            ? null
            : () {
                print('Navegando a contenido: $url, esVideo: $isVideo, docId: $docId');
                if (isVideo) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(videoUrl: url, documentId: docId),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerScreen(imageUrl: url, documentId: docId),
                    ),
                  );
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isVideo
                    ? _buildVideoThumbnail(url)
                    : CachedNetworkImage(
                        imageUrl: url,
                        width: 120,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 120,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          print('Error al cargar imagen: $url, error: $error');
                          return Container(
                            width: 120,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              image: const DecorationImage(
                                image: AssetImage('assets/images/image_placeholder.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 32,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVideo ? Colors.red.shade100 : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVideo ? Icons.videocam : Icons.image,
                                size: 16,
                                color: isVideo ? Colors.red.shade700 : Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVideo ? 'Video' : 'Imagen',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isVideo ? Colors.red.shade700 : Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_currentUserRole == 'administrador') ...[
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            enabled: !_isLoading,
                            onSelected: (value) {
                              if (value == 'view') {
                                if (isVideo) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VideoPlayerScreen(videoUrl: url, documentId: docId),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImageViewerScreen(imageUrl: url, documentId: docId),
                                    ),
                                  );
                                }
                              } else if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ContentEditScreen(
                                      type: isVideo ? 'video' : 'image',
                                      documentId: docId,
                                      currentUrl: url,
                                      currentTitle: title,
                                      currentDescription: description,
                                    ),
                                  ),
                                );
                              } else if (value == 'delete') {
                                _deleteContent(docId, url, isVideo ? 'video' : 'image');
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Ver'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red.shade600),
                                    const SizedBox(width: 8),
                                    Text('Eliminar'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(createdAt.toDate()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (userId == null || !_adminUserIds.contains(userId)) ...[
                      const SizedBox(height: 8),
                      Text(
                        'No autorizado (UserId inválido: $userId)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                    if (url.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'URL vacía',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minutos';
    } else {
      return 'Ahora mismo';
    }
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'todos', 'label': 'Todos', 'icon': Icons.grid_view},
      {'key': 'videos', 'label': 'Videos', 'icon': Icons.videocam},
      {'key': 'imagenes', 'label': 'Imágenes', 'icon': Icons.image},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                  if (_selectedFilter == 'todos' && !_combinedStreamController.isClosed) {
                    _combinedStreamController.add(_combinedDocs);
                    print('Filtro cambiado a "todos", emitiendo _combinedDocs: ${_combinedDocs.length} documentos');
                  }
                });
              },
              backgroundColor: Colors.grey.shade50,
              selectedColor: Colors.green.shade600,
              checkmarkColor: Colors.white,
              elevation: isSelected ? 4 : 1,
              pressElevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _combinedStreamSubscription?.cancel(); // Cancelar la suscripción al stream combinado
    _combinedStreamController.close();
    _searchController.dispose();
    _animationController.dispose();
    _thumbnailCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Contenido Educativo',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                        decoration: InputDecoration(
                          labelText: 'Buscar contenido educativo',
                          hintText: 'Buscar por título o descripción...',
                          prefixIcon: const Icon(Icons.search, color: Colors.green),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
                                )
                              : null,
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
                      _buildFilterChips(),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<DocumentSnapshot>>(
                    stream: _getContentStream(_selectedFilter),
                    builder: (context, snapshot) {
                      print('StreamBuilder - Estado: ${snapshot.connectionState}, Datos: ${snapshot.data?.length}, Error: ${snapshot.error}');

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        print('Error en Stream: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar contenido',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Por favor, intenta de nuevo más tarde',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data?.where((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final userId = data['userId'] as String?;
                        final matchesSearch = _searchQuery.isEmpty ||
                            (data['titulo']?.toLowerCase().contains(_searchQuery) ?? false) ||
                            (data['descripcion']?.toLowerCase().contains(_searchQuery) ?? false);
                        final isValidUrl = data['url'] != null && data['url'].isNotEmpty;
                        print('Evaluando documento: ${data['titulo'] ?? 'Sin título'}, Tipo: ${data['tipo']}, UserId: $userId, URL: ${data['url']}');
                        if (!matchesSearch) {
                          print('Documento filtrado por búsqueda: ${data['titulo'] ?? 'Sin título'}');
                        }
                        if (userId == null || !_adminUserIds.contains(userId)) {
                          print('Documento filtrado por userId: ${data['titulo'] ?? 'Sin título'}, userId: $userId');
                        }
                        if (!isValidUrl) {
                          print('Documento filtrado por URL inválida: ${data['titulo'] ?? 'Sin título'}, url: ${data['url']}');
                        }
                        return matchesSearch && isValidUrl;
                      }).toList() ?? [];

                      print('Documentos filtrados: ${docs.length}');

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off : Icons.school_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No se encontraron resultados'
                                    : 'No hay contenido válido disponible',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Intenta con diferentes términos de búsqueda'
                                    : 'Asegúrate de que el contenido tenga URLs válidas',
                                style: TextStyle(color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          print('Renderizando tarjeta en índice: $index, Título: ${docs[index]['titulo'] ?? 'Sin título'}');
                          return _buildContentCard(docs[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _currentUserRole == 'administrador'
          ? PopupMenuButton<String>(
              onSelected: (String value) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContentUploadScreen(type: value),
                  ),
                );
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'image',
                  child: Row(
                    children: [
                      Icon(Icons.image, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Subir Imagen'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'video',
                  child: Row(
                    children: [
                      Icon(Icons.videocam, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Subir Video'),
                    ],
                  ),
                ),
              ],
              child: FloatingActionButton(
                onPressed: null,
                backgroundColor: Colors.green.shade600,
                child: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Subir Contenido',
              ),
            )
          : null,
    );
  }

  Future<String> _getUserRole(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data()?['role'] ?? 'sin rol';
  }
}