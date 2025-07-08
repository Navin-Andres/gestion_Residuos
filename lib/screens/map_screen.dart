import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _mapInitialized = false;

  // Ejemplo de contenedores con estado
  final List<Map<String, dynamic>> containers = [
    {
      'position': LatLng(10.47314, -73.25322),
      'status': 'Lleno',
      'id': '1',
    },
    {
      'position': LatLng(10.46314, -73.26322),
      'status': 'Vacío',
      'id': '2',
    },
    {
      'position': LatLng(10.45314, -73.24322),
      'status': 'En mantenimiento',
      'id': '3',
    },
  ];

  Set<Marker> get _markers {
    return containers.map((container) {
      Color markerColor;
      switch (container['status']) {
        case 'Lleno':
          markerColor = Colors.red;
          break;
        case 'Vacío':
          markerColor = Colors.green;
          break;
        case 'En mantenimiento':
          markerColor = Colors.orange;
          break;
        default:
          markerColor = Colors.blue;
      }
      return Marker(
        markerId: MarkerId(container['id']),
        position: container['position'],
        infoWindow: InfoWindow(
          title: 'Contenedor',
          snippet: 'Estado: ${container['status']}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          markerColor == Colors.red
              ? BitmapDescriptor.hueRed
              : markerColor == Colors.green
                  ? BitmapDescriptor.hueGreen
                  : markerColor == Colors.orange
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueAzure,
        ),
      );
    }).toSet();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 10), () {
      if (_isLoading && _errorMessage == null && mounted) {
        setState(() {
          _errorMessage = 'El mapa está tomando demasiado tiempo en cargar. Verifica tu conexión.';
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _onMapCreated(GoogleMapController controller) {
    if (mounted) {
      setState(() {
        _mapController = controller;
        _isLoading = false;
        _mapInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa de Contenedores'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(10.46314, -73.25322), // Valledupar, Colombia
              zoom: 12.0,
            ),
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            indoorViewEnabled: false,
            trafficEnabled: false,
            buildingsEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
          if (_isLoading && !_mapInitialized)
            Container(
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Cargando mapa...'),
                  ],
                ),
              ),
            ),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                        _mapInitialized = false;
                      });
                    },
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}