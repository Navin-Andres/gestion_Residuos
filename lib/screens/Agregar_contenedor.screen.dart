import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

const String googleApiKey = 'AIzaSyCy3zRVuZkc4Mv6stnC7lPptX1tniXjxiw';

class AgregarContenedorScreen extends StatefulWidget {
  const AgregarContenedorScreen({super.key});
  @override
  _AgregarContenedorScreenState createState() => _AgregarContenedorScreenState();
}

class _AgregarContenedorScreenState extends State<AgregarContenedorScreen> {
  final TextEditingController _direccionController = TextEditingController();
  String? _estadoContenedor;
  GoogleMapController? _mapController;
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googleApiKey);
  final List<Prediction> _suggestions = [];
  final Set<Marker> _markers = {};
  LatLng _posicionInicial = const LatLng(10.4631, -73.2532);
  BitmapDescriptor? _containerIcon;
  final List<String> _estados = ['Bueno', 'Regular', 'Malo'];
  ScaffoldMessengerState? _scaffoldMessenger;
  CancelableOperation? _iconOperation;
  CancelableOperation? _searchOperation;
  CancelableOperation? _placeDetailsOperation;
  CancelableOperation? _firestoreOperation;

  @override
  void initState() {
    super.initState();
    _loadCustomIcon();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  Future<void> _loadCustomIcon() async {
    print('Cargando ícono personalizado en ${DateTime.now()}');
    _iconOperation = CancelableOperation.fromFuture(
      BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(64, 64)),
        'assets/icons/contenedor_verde.png',
      ).then((icon) {
        if (mounted) {
          _containerIcon = icon;
          return _loadContenedoresExistentes();
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
      _places.autocomplete(value, components: [Component(Component.country, "co")], language: 'es').then((res) {
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
      _places.getDetailsByPlaceId(p.placeId!).then((res) {
        if (res.isOkay && mounted) {
          final loc = res.result.geometry!.location;
          final pos = LatLng(loc.lat, loc.lng);
          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'nuevo');
            _markers.add(
              Marker(
                markerId: const MarkerId('nuevo'),
                position: pos,
                icon: _containerIcon ?? BitmapDescriptor.defaultMarker,
                infoWindow: InfoWindow(title: res.result.name, snippet: _estadoContenedor ?? 'Estado no seleccionado'),
              ),
            );
            _suggestions.clear();
            _direccionController.text = p.description!;
            _posicionInicial = pos;
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

  Future<void> _guardarContenedor() async {
    print('Guardando contenedor en ${DateTime.now()}');
    final direccion = _direccionController.text.trim();
    final estado = _estadoContenedor;

    if (direccion.isNotEmpty && _estadoContenedor != null && _markers.any((m) => m.markerId.value == 'nuevo')) {
      final marker = _markers.firstWhere((m) => m.markerId.value == 'nuevo');
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      _firestoreOperation?.cancel();
      _firestoreOperation = CancelableOperation.fromFuture(
        FirebaseFirestore.instance.collection('contenedores').add({
          'direccion': direccion,
          'estado': estado,
          'latitud': lat,
          'longitud': lng,
          'fecha_creacion': FieldValue.serverTimestamp(),
        }).then((_) {
          if (mounted) {
            _scaffoldMessenger?.showSnackBar(
              const SnackBar(content: Text('Contenedor guardado en Firestore')),
            );
            _direccionController.clear();
            setState(() {
              _estadoContenedor = null;
              _markers.remove(marker);
            });
            return _loadContenedoresExistentes();
          }
        }).catchError((e) {
          if (mounted) {
            _scaffoldMessenger?.showSnackBar(
              SnackBar(content: Text('Error al guardar: $e')),
            );
          }
        }),
      );
    } else {
      if (mounted) {
        _scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text('Por favor selecciona una dirección y un estado')),
        );
      }
    }
  }

  Future<void> _loadContenedoresExistentes() async {
    print('Cargando contenedores existentes en ${DateTime.now()}');
    _firestoreOperation?.cancel();
    _firestoreOperation = CancelableOperation.fromFuture(
      FirebaseFirestore.instance.collection('contenedores').get().then((snapshot) {
        if (mounted) {
          _markers.removeWhere((m) => m.markerId.value != 'nuevo');
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final lat = data['latitud'];
            final lng = data['longitud'];
            final direccion = data['direccion'];
            final estado = data['estado'] ?? data['descripcion'] ?? 'Sin estado';
            final docId = doc.id;

            final marker = Marker(
              markerId: MarkerId(docId),
              position: LatLng(lat, lng),
              icon: _containerIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(title: direccion, snippet: estado),
              onTap: () => _mostrarDialogoEliminarContenedor(docId, direccion),
            );

            _markers.add(marker);
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

  Future<void> _mostrarDialogoEliminarContenedor(String docId, String? direccion) async {
    print('Mostrando diálogo para eliminar contenedor $docId en ${DateTime.now()}');
    if (!mounted) return;
    final dialogContext = context;
    final result = await showDialog<bool>(
      context: dialogContext,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("¿Eliminar contenedor?"),
        content: Text("¿Deseas eliminar el contenedor ubicado en:\n\n$direccion?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _firestoreOperation?.cancel();
      _firestoreOperation = CancelableOperation.fromFuture(
        FirebaseFirestore.instance.collection('contenedores').doc(docId).delete().then((_) {
          if (mounted) {
            _scaffoldMessenger?.showSnackBar(
              const SnackBar(content: Text("Contenedor eliminado")),
            );
            return _loadContenedoresExistentes();
          }
        }).catchError((e) {
          if (mounted) {
            _scaffoldMessenger?.showSnackBar(
              SnackBar(content: Text('Error al eliminar: $e')),
            );
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    print('Disposing AgregarContenedorScreen at ${DateTime.now()}');
    _iconOperation?.cancel();
    _searchOperation?.cancel();
    _placeDetailsOperation?.cancel();
    _firestoreOperation?.cancel();
    _direccionController.dispose();
    _mapController?.dispose();
    _places.dispose();
    _iconOperation = null;
    _searchOperation = null;
    _placeDetailsOperation = null;
    _firestoreOperation = null;
    _scaffoldMessenger = null;
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
                              if (mounted) {
                                setState(() => _suggestions.clear());
                              }
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
                DropdownButtonFormField<String>(
                  value: _estadoContenedor,
                  decoration: InputDecoration(
                    labelText: 'Estado del contenedor',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.info, color: Colors.green),
                  ),
                  items: _estados
                      .map((estado) => DropdownMenuItem(
                            value: estado,
                            child: Text(estado),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        _estadoContenedor = value;
                      });
                    }
                  },
                  validator: (value) => value == null ? 'Selecciona un estado' : null,
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
              onMapCreated: (controller) {
                if (mounted) {
                  _mapController = controller;
                }
              },
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