import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewerScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ver Imagen', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
      ),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 2,
          errorBuilder: (context, error, stackTrace) => const Center(child: Text('Error al cargar la imagen')),
        ),
      ),
    );
  }
}