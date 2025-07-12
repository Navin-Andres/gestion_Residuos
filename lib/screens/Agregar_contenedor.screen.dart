import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;

const String googleApiKey = 'AIzaSyCy3zRVuZkc4Mv6stnC7lPptX1tniXjxiw';

class AgregarContenedorScreen extends StatefulWidget {
  const AgregarContenedorScreen({super.key});
  @override
  _AgregarContenedorScreenState createState() => _AgregarContenedorScreenState();
}

class _AgregarContenedorScreenState extends State<AgregarContenedorScreen> {
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  late GoogleMapController _mapController;
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googleApiKey);
  final List<Prediction> _suggestions = [];
  final Set<Marker> _markers = {};
  LatLng _posicionInicial = const LatLng(10.4631, -73.2532);
  BitmapDescriptor? _containerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcon().then((_) {
      _loadContenedoresExistentes();
    });
  }

  Future<void> _loadCustomIcon() async {
    _containerIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(64, 64)),
      'assets/icons/contenedor_verde.png',
    );
  }

  void _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    final res = await _places.autocomplete(value, components: [Component(Component.country, "co")], language: 'es');
    if (res.isOkay) {
      setState(() {
        _suggestions
          ..clear()
          ..addAll(res.predictions);
      });
    }
  }

  Future<void> _selectSuggestion(Prediction p) async {
    final res = await _places.getDetailsByPlaceId(p.placeId!);
    if (res.isOkay) {
      final loc = res.result.geometry!.location;
      final pos = LatLng(loc.lat, loc.lng);
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'nuevo');
        _markers.add(
          Marker(
            markerId: const MarkerId('nuevo'),
            position: pos,
            icon: _containerIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: res.result.name),
          ),
        );
        _suggestions.clear();
        _direccionController.text = p.description!;
        _posicionInicial = pos;
      });
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    }
  }

  void _guardarContenedor() async {
    final direccion = _direccionController.text.trim();
    final descripcion = _descripcionController.text.trim();

    if (direccion.isNotEmpty && _markers.any((m) => m.markerId.value == 'nuevo')) {
      final marker = _markers.firstWhere((m) => m.markerId.value == 'nuevo');
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      try {
        await FirebaseFirestore.instance.collection('contenedores').add({
          'direccion': direccion,
          'descripcion': descripcion,
          'latitud': lat,
          'longitud': lng,
          'fecha_creacion': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contenedor guardado en Firestore')),
        );

        _direccionController.clear();
        _descripcionController.clear();
        setState(() {
          _markers.remove(marker);
        });
        _loadContenedoresExistentes();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una dirección')),
      );
    }
  }

  Future<void> _loadContenedoresExistentes() async {
    _markers.removeWhere((m) => m.markerId.value != 'nuevo');
    final snapshot = await FirebaseFirestore.instance.collection('contenedores').get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final lat = data['latitud'];
      final lng = data['longitud'];
      final direccion = data['direccion'];
      final descripcion = data['descripcion'];
      final docId = doc.id;

      final marker = Marker(
        markerId: MarkerId(docId),
        position: LatLng(lat, lng),
        icon: _containerIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: direccion, snippet: descripcion),
        onTap: () => _mostrarDialogoEliminarContenedor(docId, direccion),
      );

      _markers.add(marker);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _mostrarDialogoEliminarContenedor(String docId, String? direccion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar contenedor?"),
        content: Text("¿Deseas eliminar el contenedor ubicado en:\n\n$direccion?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('contenedores').doc(docId).delete();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Contenedor eliminado")),
              );
              _loadContenedoresExistentes();
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _direccionController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar/Eliminar Contenedor'),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _direccionController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    labelText: 'Buscar dirección',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _direccionController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _direccionController.clear();
                              setState(() => _suggestions.clear());
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (_suggestions.isNotEmpty)
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) {
                        final p = _suggestions[i];
                        return ListTile(
                          title: Text(p.description!),
                          onTap: () => _selectSuggestion(p),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del contenedor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _guardarContenedor,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Contenedor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(target: _posicionInicial, zoom: 13),
              markers: _markers,
              myLocationEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}
