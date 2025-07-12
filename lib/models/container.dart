import 'package:google_maps_flutter/google_maps_flutter.dart';

class ContainerModel {
  final String id;
  final String status;
  final LatLng location;
  final String? address;

  ContainerModel({
    required this.id,
    required this.status,
    required this.location,
    this.address,
  });

  factory ContainerModel.fromFirestore(Map<String, dynamic> data, String id) {
    final locationData = data['location'] as Map<String, dynamic>?;
    return ContainerModel(
      id: id,
      status: data['status'] ?? 'Desconocido',
      location: LatLng(
        (locationData?['latitude'] as num?)?.toDouble() ?? 0.0,
        (locationData?['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      address: data['address'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status': status,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      if (address != null) 'address': address,
    };
  }
}
