import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/container.dart';

class ContainerMapScreen extends StatefulWidget {
  @override
  _ContainerMapScreenState createState() => _ContainerMapScreenState();
}

class _ContainerMapScreenState extends State<ContainerMapScreen> {
  List<ContainerModel> _containers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchContainers();
  }

  Future<void> _fetchContainers() async {
    try {
      print('Obteniendo contenedores de Firestore...');
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('containers').get();
      final containers = snapshot.docs
          .map((doc) => ContainerModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      print('Contenedores obtenidos: ${containers.length}');
      containers.forEach((c) {
        print('Contenedor ${c.id}: Estado=${c.status}, Lat=${c.location.latitude}, Lon=${c.location.longitude}');
      });
      setState(() {
        _containers = containers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar contenedores: $e';
        _isLoading = false;
      });
      print('Error al cargar contenedores: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Lleno':
        return Colors.red;
      case 'Vacío':
        return Colors.green;
      case 'En mantenimiento':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa de Contenedores'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchContainers,
            tooltip: 'Recargar contenedores',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.0),
                      color: Colors.grey[200],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildLegendItem('Lleno', Colors.red),
                          _buildLegendItem('Vacío', Colors.green),
                          _buildLegendItem('En mantenimiento', Colors.orange),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(10.46314, -73.25322), // Valledupar
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                            additionalOptions: {
                              'attribution': '© OpenStreetMap contributors',
                            },
                          ),
                          MarkerLayer(
                            markers: _containers.map((container) {
                              print('Añadiendo marcador para contenedor ${container.id} en (${container.location.latitude}, ${container.location.longitude})');
                              return Marker(
                                point: container.location,
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Contenedor ${container.id}'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Estado: ${container.status}'),
                                            SizedBox(height: 10),
                                            ElevatedButton(
                                              onPressed: () {
                                                _updateContainerStatus(container.id);
                                              },
                                              child: Text('Cambiar Estado'),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text('Cerrar'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Icons.location_pin,
                                    color: _getStatusColor(container.status),
                                    size: 40,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLegendItem(String status, Color color) {
    return Row(
      children: [
        Container(width: 15, height: 15, color: color),
        SizedBox(width: 5),
        Text(status),
      ],
    );
  }

  Future<void> _updateContainerStatus(String containerId) async {
    final newStatus = _containers.firstWhere((c) => c.id == containerId).status == 'Lleno'
        ? 'Vacío'
        : 'Lleno';
    try {
      await FirebaseFirestore.instance
          .collection('containers')
          .doc(containerId)
          .update({'status': newStatus});
      _fetchContainers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar estado: $e')),
      );
      print('Error al actualizar estado: $e');
    }
  }
}