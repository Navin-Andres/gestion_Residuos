import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;

const String googleApiKey = 'AIzaSyCy3zRVuZkc4Mv6stnC7lPptX1tniXjxiw';

class ContainerMapScreen extends StatefulWidget {
  const ContainerMapScreen({super.key});
  @override
  _ContainerMapScreenState createState() => _ContainerMapScreenState();
}

class _ContainerMapScreenState extends State<ContainerMapScreen> {
  late GoogleMapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  final List<Prediction> _suggestions = [];
  final Set<Marker> _markers = {};
  final places = GoogleMapsPlaces(apiKey: googleApiKey);

  @override
  void initState() {
    super.initState();
    _loadContainerMarkers();
  }

  void _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    final res = await places.autocomplete(
      value,
      components: [Component(Component.country, "co")],
      language: 'es',
    );
    if (res.isOkay) {
      setState(() {
        _suggestions
          ..clear()
          ..addAll(res.predictions);
      });
    }
  }

  Future<void> _selectSuggestion(Prediction p) async {
    final res = await places.getDetailsByPlaceId(p.placeId!);
    if (res.isOkay) {
      final loc = res.result.geometry!.location;
      final pos = LatLng(loc.lat, loc.lng);
      setState(() {
        // No limpiamos los markers, solo agregamos el nuevo temporal de búsqueda
        _markers.add(
          Marker(
            markerId: MarkerId(p.placeId!),
            position: pos,
            infoWindow: InfoWindow(title: res.result.name),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
        _suggestions.clear();
        _searchController.text = p.description!;
      });
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    }
  }

  Future<void> _loadContainerMarkers() async {
  final snapshot = await FirebaseFirestore.instance.collection('contenedores').get();
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final lat = data['lat'] ?? data['latitud'];
final lng = data['lng'] ?? data['longitud'];
final address = data['address'] ?? data['direccion'];

    if (lat != null && lng != null) {
      _markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: address ?? 'Contenedor'),
        ),
      );
    }
  }
  setState(() {}); // Actualiza el mapa
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Contenedores'),
        backgroundColor: Colors.green[700],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: const CameraPosition(
              target: LatLng(10.4631, -73.2532),
              zoom: 13,
            ),
            markers: _markers,
            myLocationEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _suggestions.clear());
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: ListView.builder(
                      itemCount: _suggestions.length,
                      shrinkWrap: true,
                      itemBuilder: (_, i) {
                        final p = _suggestions[i];
                        return ListTile(
                          title: Text(p.description!),
                          onTap: () => _selectSuggestion(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
