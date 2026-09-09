import '../core/utils/geo_utils.dart';

class Hospital {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String contactPhone;

  const Hospital({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.contactPhone,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      latitude: geoLat(json['location']),
      longitude: geoLng(json['location']),
      contactPhone: json['contact_phone'] as String? ?? '',
    );
  }
}
