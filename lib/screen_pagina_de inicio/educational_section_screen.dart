import 'package:flutter/material.dart';

class EducationalSectionScreen extends StatelessWidget {
  final List<Map<String, String>> tutorials = [
    {'title': 'Cómo reciclar', 'description': 'Aprende a separar tus residuos', 'url': 'https://www.youtube.com/watch?v=example'},
    {'title': 'Compostaje en casa', 'description': 'Convierte tus residuos orgánicos', 'url': 'https://www.youtube.com/watch?v=example2'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sección Educativa')),
      body: ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: tutorials.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              leading: Icon(Icons.play_circle_fill, color: Colors.green, size: 40),
              title: Text(tutorials[index]['title']!),
              subtitle: Text(tutorials[index]['description']!),
              onTap: () {
                // Navegar a pantalla de video
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Abriendo: ${tutorials[index]['title']}')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}