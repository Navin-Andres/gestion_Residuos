import 'package:latlong2/latlong.dart';

class ContainerModel {
  final String id;
  final String status; // Ejemplo: "Lleno", "Vacío", "En mantenimiento"
  final LatLng location;

  ContainerModel({
    required this.id,
    required this.status,
    required this.location,
  });

  factory ContainerModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ContainerModel(
      id: id,
      status: data['status'] ?? 'Desconocido',
      location: LatLng(
        data['latitude'] ?? 0.0,
        data['longitude'] ?? 0.0,
      ),
    );
  }
}