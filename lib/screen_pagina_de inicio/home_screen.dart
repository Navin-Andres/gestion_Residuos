import 'dart:async';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'package:firebase_prueba2/screen_pagina_de%20inicio/chatbot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/image_viewer_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/video_player_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/content_upload_screen.dart';
import 'package:stream_transform/stream_transform.dart' as stream_transform;


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedIndex = 0;
  List<String> _adminUserIds = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Map<String, Uint8List> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchUserData();
    _fetchAdminUserIds();
    _animationController.forward();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          if (userDoc.exists) {
            _userData = userDoc.data();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontraron datos de usuario.')),
            );
          }
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error al cargar datos de usuario: $e');
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos de usuario: $e')),
        );
      });
    }
  }

  Future<void> _fetchAdminUserIds() async {
    try {
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'administrador')
          .get();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _adminUserIds = adminQuery.docs.map((doc) => doc.id).toList();
          print('UserIds de administradores encontrados: $_adminUserIds');
          if (_adminUserIds.isEmpty) {
            print('Advertencia: No se encontraron administradores en la colección "users".');
          }
        });
      });
    } catch (e) {
      print('Error al obtener userIds de administradores: $e');
    }
  }

  Future<String> _getUserRole(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data()?['role'] ?? 'sin rol';
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  void _onNavBarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushNamed(context, '/map');
        break;
      case 2:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  Drawer _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final userRole = _userData?['role'] ?? 'usuario';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade400],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  backgroundColor: Colors.grey.shade300,
                  child: user?.photoURL == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  _userData?['displayName'] ?? user?.displayName ?? 'Usuario',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? 'No disponible',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.green),
            title: const Text('Inicio'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.green),
            title: const Text('Mapa de Contenedores'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/map');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: const Text('Perfil de Usuario'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.school, color: Colors.green),
            title: const Text('Educación y Consejos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/educational_content');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inbox, color: Colors.green),
            title: const Text('Bandeja de Entrada'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/inbox');
            },
          ),
          if (userRole == 'usuario')
            ListTile(
              leading: const Icon(Icons.report, color: Colors.green),
              title: const Text('Crear Queja'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/complaint');
              },
            ),
          if (userRole == 'empresa' || userRole == 'autoridad')
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.green),
              title: const Text('Reportes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/reports');
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
void _viewContent(BuildContext context, DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final isVideo = data['tipo'] == 'video';
  final url = data['url'] ?? '';
  final documentId = doc.id; // <-- Agrega esto
  print('Intentando visualizar contenido: $url, esVideo: $isVideo');
  if (isVideo) {
    if (url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: url,
            documentId: documentId, // <-- Pasa el documentId
          ),
        ),
      );
    } else {
      print('Error: URL de video vacía o inválida');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de video no válida.')),
      );
    }
  } else {
    if (url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            imageUrl: url,
            documentId: documentId, // <-- Pasa el documentId
          ),
        ),
      );
    } else {
      print('Error: URL de imagen vacía o inválida');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de imagen no válida.')),
      );
    }
  }
}
  

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(1.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 110,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: Colors.green.shade700),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(String videoUrl, {double width = 160, double height = 120}) {
    if (videoUrl.isEmpty) {
      print('Error: URL de video vacía');
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
            size: 40,
          ),
        ),
      );
    }

    if (_thumbnailCache.containsKey(videoUrl)) {
      print('Thumbnail cargado desde caché para: $videoUrl');
      return Stack(
        children: [
          Image.memory(
            _thumbnailCache[videoUrl]!,
            height: height,
            width: width,
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
                  size: 40,
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
        maxWidth: 160,
        quality: 30,
      ).timeout(
        const Duration(seconds: 10),
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
              Image.memory(
                snapshot.data!,
                height: height,
                width: width,
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
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        print('No se pudo generar thumbnail para: $videoUrl');
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
              size: 40,
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentCard(DocumentSnapshot doc, {bool isVideo = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['titulo'] ?? 'Sin título';
    final url = data['url'] ?? 'https://via.placeholder.com/160x120';

    return GestureDetector(
      onTap: () => _viewContent(context, doc),
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: isVideo
                    ? _buildVideoThumbnail(url)
                    : CachedNetworkImage(
                        imageUrl: url,
                        height: 120,
                        width: 160,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 120,
                          width: 160,
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator(color: Colors.green)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 120,
                          width: 160,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Gestión de Residuos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _fetchUserData,
                color: Colors.green,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20.0),
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
                            Text(
                              'Bienvenido a Ecovalle',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tu herramienta para gestionar contenedores, reportar problemas y aprender sobre reciclaje.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              context,
                              icon: Icons.report,
                              label: 'Reportar Queja',
                              onTap: () => Navigator.pushNamed(context, '/complaint'),
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.map,
                              label: 'Ver Mapa',
                              onTap: () => Navigator.pushNamed(context, '/map'),
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.school,
                              label: 'Educación',
                              onTap: () => Navigator.pushNamed(context, '/educational_content'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          'Imágenes Educativas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      StreamBuilder<List<DocumentSnapshot>>(
                        stream: FirebaseFirestore.instance
                            .collection('educational_content')
                            .doc('image')
                            .collection('items')
                            .orderBy('createdAt', descending: true)
                            .snapshots()
                            .map((snapshot) => snapshot.docs),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.green));
                          }
                          if (snapshot.hasError) {
                            print('Error en imágenes educativas: ${snapshot.error}');
                            return Center(
                              child: Text(
                                'Error al cargar imágenes: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          final docs = snapshot.data?.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final userId = data['userId'] as String?;
                            return userId != null && _adminUserIds.contains(userId);
                          }).toList() ?? [];
                          print('Imágenes recibidas: ${docs.length}');
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hay imágenes educativas disponibles.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: docs.length,
                              itemBuilder: (context, index) => _buildContentCard(docs[index], isVideo: false),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          'Videos Educativos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      StreamBuilder<List<DocumentSnapshot>>(
                        stream: FirebaseFirestore.instance
                            .collection('educational_content')
                            .doc('video')
                            .collection('items')
                            .orderBy('createdAt', descending: true)
                            .snapshots()
                            .map((snapshot) => snapshot.docs),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.green));
                          }
                          if (snapshot.hasError) {
                            print('Error en videos educativos: ${snapshot.error}');
                            return Center(
                              child: Text(
                                'Error al cargar videos: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          final docs = snapshot.data?.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final userId = data['userId'] as String?;
                            return userId != null && _adminUserIds.contains(userId);
                          }).toList() ?? [];
                          print('Videos recibidos: ${docs.length}');
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hay videos educativos disponibles.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: docs.length,
                              itemBuilder: (context, index) => _buildContentCard(docs[index], isVideo: true),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavBarItemTapped,
        indicatorColor: Colors.green.shade200,
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home, color: Colors.green),
            selectedIcon: Icon(Icons.home_filled, color: Colors.green),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.map, color: Colors.green),
            selectedIcon: Icon(Icons.map_outlined, color: Colors.green),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person, color: Colors.green),
            selectedIcon: Icon(Icons.person, color: Colors.green),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<String>(
  future: FirebaseAuth.instance.currentUser != null
      ? _getUserRole(FirebaseAuth.instance.currentUser!.uid)
      : Future.value('sin rol'),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox.shrink();
    }
    if (snapshot.data != 'administrador') {
      // MODIFICACIÓN AQUÍ: Si no es administrador, muestra el botón de Ecobot
      return FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatbotScreen()),
          );
        },
        label: const Text('Pregúntale a Ecobot', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.chat, color: Colors.white),
        backgroundColor: Colors.blue.shade600, // Un color diferente para el chatbot
        tooltip: 'Pregúntale a Ecobot',
      );
    }
    // El resto del código para el administrador se mantiene
    return PopupMenuButton<String>(
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
    );
  },
),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _thumbnailCache.clear();
    super.dispose();
  }
}