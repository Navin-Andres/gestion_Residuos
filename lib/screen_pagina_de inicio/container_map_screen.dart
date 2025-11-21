import 'dart:convert';
import 'package:async/async.dart';
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
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final List<Prediction> _suggestions = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final places = GoogleMapsPlaces(apiKey: googleApiKey);
  LatLng? _userLocation;
  BitmapDescriptor? _containerIcon;
  ScaffoldMessengerState? _scaffoldMessenger;
  CancelableOperation? _iconOperation;
  CancelableOperation? _locationOperation;
  CancelableOperation? _searchOperation;
  CancelableOperation? _placeDetailsOperation;
  CancelableOperation? _firestoreOperation;
  CancelableOperation? _directionsOperation;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _loadUserLocation();
    _loadContainerMarkers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  Future<void> _loadCustomIcons() async {
    print('Cargando ícono personalizado en ${DateTime.now()}');
    _iconOperation = CancelableOperation.fromFuture(
      BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(64, 64)),
        'assets/icons/contenedor_verde.png',
      ).then((icon) {
        if (mounted) {
          setState(() {
            _containerIcon = icon;
          });
        }
      }).catchError((e) {
        if (mounted) {
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('Error cargando ícono: $e')),
          );
        }
      }),
    );
  }

  Future<void> _loadUserLocation() async {
    print('Cargando ubicación del usuario en ${DateTime.now()}');
    _locationOperation?.cancel();
    _locationOperation = CancelableOperation.fromFuture(
      Geolocator.isLocationServiceEnabled().then((serviceEnabled) async {
        if (!serviceEnabled) {
          if (mounted) {
            _scaffoldMessenger?.showSnackBar(
              const SnackBar(content: Text("Los servicios de ubicación están desactivados")),
            );
          }
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              _scaffoldMessenger?.showSnackBar(
                const SnackBar(content: Text("Permiso de ubicación denegado")),
              );
            }
            return;
          }
        }

        Position position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
          });
        }
      }).catchError((e) {
        if (mounted) {
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('Error obteniendo ubicación: $e')),
          );
        }
      }),
    );
  }

  void _centrarEnMiUbicacion() {
    print('Centrando en ubicación del usuario en ${DateTime.now()}');
    if (_userLocation != null && _mapController != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 16),
      );
    } else {
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text("Ubicación del usuario no disponible")),
        );
      }
    }
  }

  void _clearMap() {
    print('Limpiando mapa en ${DateTime.now()}');
    if (mounted) {
      setState(() {
        _polylines.clear();
        _markers.clear();
        _suggestions.clear();
        _searchController.clear();
      });
      _loadContainerMarkers();
    }
  }

  void _onSearchChanged(String value) async {
    if (value.isEmpty) {
      if (mounted) {
        setState(() => _suggestions.clear());
      }
      return;
    }
    print('Buscando dirección: $value en ${DateTime.now()}');
    _searchOperation?.cancel();
    _searchOperation = CancelableOperation.fromFuture(
      places.autocomplete(
        value,
        components: [Component(Component.country, "co")],
        language: 'es',
      ).then((res) {
        if (res.isOkay && mounted) {
          setState(() {
            _suggestions
              ..clear()
              ..addAll(res.predictions);
          });
        }
      }).catchError((e) {
        if (mounted) {
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('Error buscando dirección: $e')),
          );
        }
      }),
    );
  }

  Future<void> _selectSuggestion(Prediction p) async {
    print('Seleccionando sugerencia ${p.placeId} en ${DateTime.now()}');
    _placeDetailsOperation?.cancel();
    _placeDetailsOperation = CancelableOperation.fromFuture(
      places.getDetailsByPlaceId(p.placeId!).then((res) {
        if (res.isOkay && mounted) {
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
          if (_mapController != null && mounted) {
            _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
          }
        }
      }).catchError((e) {
        if (mounted) {
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('Error seleccionando dirección: $e')),
          );
        }
      }),
    );
  }

  Future<void> _loadContainerMarkers() async {
    print('Cargando marcadores de contenedores en ${DateTime.now()}');
    _firestoreOperation?.cancel();
    _firestoreOperation = CancelableOperation.fromFuture(
      FirebaseFirestore.instance.collection('contenedores').get().then((snapshot) {
        if (mounted) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final lat = data['latitud'];
            final lng = data['longitud'];
            final address = data['direccion'];
            final estado = data['estado'] ?? data['descripcion'] ?? 'Sin estado';
            if (lat != null && lng != null) {
              final pos = LatLng(lat, lng);
              _markers.add(
                Marker(
                  markerId: MarkerId(doc.id),
                  position: pos,
                  icon: _containerIcon ?? BitmapDescriptor.defaultMarker,
                  onTap: () => _showContainerInfo(pos, address ?? 'Contenedor', estado),
                ),
              );
            }
          }
          setState(() {});
        }
      }).catchError((e) {
        if (mounted) {
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('Error cargando contenedores: $e')),
          );
        }
      }),
    );
  }

  void _showContainerInfo(LatLng position, String address, String estado) {
    print('Mostrando información del contenedor en ${DateTime.now()}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Información del Contenedor'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8, // Ancho expandido
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dirección: $address', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Estado: $estado', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _mostrarRutaHastaContenedor(position);
              },
              child: const Text('Cómo llegar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarRutaHastaContenedor(LatLng destino) async {
    print('Mostrando ruta a ${destino.latitude},${destino.longitude} en ${DateTime.now()}');
    if (_userLocation == null) {
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text("Ubicación del usuario no disponible")),
        );
      }
      return;
    }

    _directionsOperation?.cancel();
    _directionsOperation = CancelableOperation.fromFuture(
      http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_userLocation!.latitude},${_userLocation!.longitude}&destination=${destino.latitude},${destino.longitude}&key=$googleApiKey',
      )).then((response) {
        if (mounted) {
          final json = jsonDecode(response.body);
          final routes = json['routes'];
          if (routes == null || routes.isEmpty) {
            _scaffoldMessenger?.showSnackBar(
              const SnackBar(content: Text("No se pudo encontrar una ruta.")),
            );
            return;
          }

          final points = routes[0]['overview_polyline']['points'];
          final List<LatLng> routeCoords = _decodePolyline(points);

          if (routeCoords.isEmpty) {
            _scaffoldMessenger?.showSnackBar(
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
          if (_mapController != null && mounted) {
            _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
              _boundsFromLatLngList(routeCoords),
              100,
            ));
          }
        }
      }).catchError((e) {
        if (mounted) {
          _scaffoldMessenger?.showSnackBar(
            SnackBar(content: Text('Error mostrando ruta: $e')),
          );
        }
      }),
    );
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
  void dispose() {
    print('Disposing ContainerMapScreen at ${DateTime.now()}');
    _iconOperation?.cancel();
    _locationOperation?.cancel();
    _searchOperation?.cancel();
    _placeDetailsOperation?.cancel();
    _firestoreOperation?.cancel();
    _directionsOperation?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    places.dispose();
    _iconOperation = null;
    _locationOperation = null;
    _searchOperation = null;
    _placeDetailsOperation = null;
    _firestoreOperation = null;
    _directionsOperation = null;
    _scaffoldMessenger = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Contenedores', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) {
              if (mounted) {
                _mapController = c;
              }
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(10.4631, -73.2532),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
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
                                if (mounted) {
                                  setState(() => _suggestions.clear());
                                }
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FloatingActionButton(
            onPressed: _centrarEnMiUbicacion,
            backgroundColor: Colors.white,
            heroTag: 'location',
            child: const Icon(Icons.my_location, color: Colors.blue),
            tooltip: 'Centrar en mi ubicación',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _clearMap,
            backgroundColor: Colors.green[700],
            heroTag: 'clear',
            child: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Limpiar mapa',
          ),
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}