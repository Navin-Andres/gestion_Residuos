import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String documentId;

  const ImageViewerScreen({Key? key, required this.imageUrl, required this.documentId}) : super(key: key);

  @override
  _ImageViewerScreenState createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _contentData;
  String? _publisherName;

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
    _fetchContentData();
    _animationController.forward();
  }

  Future<void> _fetchContentData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('educational_content')
          .doc('image')
          .collection('items')
          .doc(widget.documentId)
          .get();
      if (doc.exists) {
        setState(() {
          _contentData = doc.data();
        });
        print('Documento completo: ${doc.data()}');
        print('Descripción obtenida: ${_contentData?['descripcion']}');
        if (_contentData?['userId'] != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_contentData!['userId'])
              .get();
          setState(() {
            _publisherName = userDoc.data()?['displayName'] ?? _contentData!['userId'];
          });
        }
      } else {
        _showSnackBar('No se encontró el contenido.');
        print('Error: Documento no encontrado para ID: ${widget.documentId}');
      }
    } catch (e) {
      print('Error al obtener datos del contenido: $e');
      _showSnackBar('Error al cargar datos: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
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

  // Función para construir el texto con URLs clicables
  Widget _buildDescriptionText(String description) {
    if (description.isEmpty) {
      print('Descripción vacía');
      return const Text(
        'Sin descripción',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      );
    }

    final urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)',
      caseSensitive: false,
    );
    final matches = urlPattern.allMatches(description);
    final spans = <TextSpan>[];

    if (matches.isEmpty) {
      print('No se encontraron URLs en: "$description"');
      return Text(
        description,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      );
    }

    int lastMatchEnd = 0;
    for (var match in matches) {
      final matchStart = match.start;
      final matchEnd = match.end;
      final matchText = description.substring(matchStart, matchEnd);

      // Añadir el texto antes de la URL
      if (matchStart > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: description.substring(lastMatchEnd, matchStart),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        );
      }

      // Normalizar y codificar la URL
      final url = matchText.startsWith('www.') ? 'https://$matchText' : matchText;
      String encodedUrl;
      try {
        encodedUrl = Uri.encodeFull(url);
        print('URL detectada: $url (codificada: $encodedUrl)');
      } catch (e) {
        print('Error al codificar URL: $url ($e)');
        _showSnackBar('URL inválida: $matchText');
        spans.add(
          TextSpan(
            text: matchText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        );
        lastMatchEnd = matchEnd;
        continue;
      }

      // Añadir la URL como enlace clicable
      spans.add(
        TextSpan(
          text: matchText,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.blue,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              try {
                final uri = Uri.parse(encodedUrl);
                print('Intentando abrir URL en inAppWebView: $uri');
                await launchUrl(uri, mode: LaunchMode.inAppWebView);
                print('URL abierta exitosamente: $uri');
              } catch (e) {
                _showSnackBar('Error al abrir el enlace: $matchText ($e)');
                print('Excepción al abrir $encodedUrl: $e');
              }
            },
        ),
      );

      lastMatchEnd = matchEnd;
    }

    // Añadir el texto restante después de la última URL
    if (lastMatchEnd < description.length) {
      spans.add(
        TextSpan(
          text: description.substring(lastMatchEnd),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: spans,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Ver Imagen',
          style: TextStyle(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      image: const DecorationImage(
                        image: AssetImage('assets/images/image_placeholder.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_contentData != null) ...[
                        Text(
                          _contentData!['titulo'] ?? 'Sin título',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDescriptionText(
                          _contentData!['descripcion'] ?? 'Sin descripción',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _publisherName ?? 'Cargando...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _contentData!['createdAt'] != null
                                  ? _formatDate((_contentData!['createdAt'] as Timestamp).toDate())
                                  : 'Sin fecha',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}