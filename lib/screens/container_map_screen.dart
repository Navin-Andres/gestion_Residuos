import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

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
  final Set<Polyline> _polylines = {};
  final places = GoogleMapsPlaces(apiKey: googleApiKey);
  LatLng? _userLocation;
  BitmapDescriptor? _containerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _loadUserLocation();
    _loadContainerMarkers();
  }

  Future<void> _loadCustomIcons() async {
  _containerIcon = await BitmapDescriptor.fromAssetImage(
  const ImageConfiguration(size: Size(64, 64)), // más pequeño
  'assets/icons/contenedor_verde.png',
  );
}

  Future<void> _loadUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void _centrarEnMiUbicacion() {
    if (_userLocation != null && _mapController != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 16),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ubicación del usuario no disponible")),
      );
    }
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
        _markers.clear();
        _markers.add(Marker(
          markerId: MarkerId(p.placeId!),
          position: pos,
          infoWindow: InfoWindow(title: res.result.name),
        ));
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
      final lat = data['latitud'];
      final lng = data['longitud'];
      final address = data['direccion'];
      if (lat != null && lng != null) {
        final pos = LatLng(lat, lng);
        _markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: pos,
            icon: _containerIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: address ?? 'Contenedor',
              snippet: 'Cómo llegar',
              onTap: () => _mostrarRutaHastaContenedor(pos),
            ),
          ),
        );
      }
    }
    setState(() {});
  }

  Future<void> _mostrarRutaHastaContenedor(LatLng destino) async {
    if (_userLocation == null) return;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${_userLocation!.latitude},${_userLocation!.longitude}&destination=${destino.latitude},${destino.longitude}&key=$googleApiKey',
    );

    final response = await http.get(url);
    final json = jsonDecode(response.body);

    final routes = json['routes'];
    if (routes == null || routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo encontrar una ruta.")),
      );
      return;
    }

    final points = routes[0]['overview_polyline']['points'];
    final List<LatLng> routeCoords = _decodePolyline(points);

    if (routeCoords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La ruta está vacía.")),
      );
      return;
    }

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: routeCoords,
          color: Colors.blue,
          width: 5,
        ),
      );
    });

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(
      _boundsFromLatLngList(routeCoords),
      100,
    ));
  }

  List<LatLng> _decodePolyline(String poly) {
    List<LatLng> points = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude;
    double x1 = list.first.latitude;
    double y0 = list.first.longitude;
    double y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }
    return LatLngBounds(northeast: LatLng(x1, y1), southwest: LatLng(x0, y0));
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
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // usamos el FAB personalizado
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
      floatingActionButton: FloatingActionButton(
        onPressed: _centrarEnMiUbicacion,
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
