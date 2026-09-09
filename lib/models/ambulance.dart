import '../core/utils/geo_utils.dart';

enum AmbulanceStatus {
  available,
  dispatched,
  enRoute,
  busy,
  offline;

  static AmbulanceStatus fromString(String value) => switch (value) {
    'available' => available,
    'dispatched' => dispatched,
    'en_route' => enRoute,
    'busy' => busy,
    'offline' => offline,
    _ => offline,
  };

  String get dbValue => switch (this) {
    enRoute => 'en_route',
    _ => name,
  };

  String get label => switch (this) {
    available => 'Available',
    dispatched => 'Dispatched',
    enRoute => 'En Route',
    busy => 'Busy',
    offline => 'Offline',
  };
}

/// Service tier labels matching the DB CHECK constraint on ambulances.service_type.
enum ServiceType {
  bls,
  als,
  icu,
  neonatal,
  bariatric;

  static ServiceType fromString(String value) => switch (value) {
    'ALS'       => als,
    'ICU'       => icu,
    'Neonatal'  => neonatal,
    'Bariatric' => bariatric,
    _           => bls,
  };

  String get dbValue => switch (this) {
    bls       => 'BLS',
    als       => 'ALS',
    icu       => 'ICU',
    neonatal  => 'Neonatal',
    bariatric => 'Bariatric',
  };

  String get label => switch (this) {
    bls       => 'Basic Life Support',
    als       => 'Advanced Life Support',
    icu       => 'ICU Transport',
    neonatal  => 'Neonatal',
    bariatric => 'Bariatric',
  };

  String get shortLabel => dbValue;
}

class Ambulance {
  final String id;
  final String plateNumber;
  final AmbulanceStatus status;
  final double? latitude;
  final double? longitude;
  final String? driverId;
  final String? hospitalId;
  final DateTime? lastLocationUpdate;

  // Marketplace fields (Phase 9+)
  final ServiceType serviceType;
  final double baseFare;
  final double pricePerKm;
  final double rating;
  final int ratingCount;
  final String equipmentNotes;

  const Ambulance({
    required this.id,
    required this.plateNumber,
    required this.status,
    this.latitude,
    this.longitude,
    this.driverId,
    this.hospitalId,
    this.lastLocationUpdate,
    this.serviceType = ServiceType.bls,
    this.baseFare = 0,
    this.pricePerKm = 0,
    this.rating = 0,
    this.ratingCount = 0,
    this.equipmentNotes = '',
  });

  factory Ambulance.fromJson(Map<String, dynamic> json) {
    return Ambulance(
      id: json['id'] as String,
      plateNumber: json['plate_number'] as String,
      status: AmbulanceStatus.fromString(json['status'] as String? ?? 'offline'),
      latitude: geoLat(json['current_location']),
      longitude: geoLng(json['current_location']),
      driverId: json['driver_id'] as String?,
      hospitalId: json['hospital_id'] as String?,
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'] as String)
          : null,
      serviceType: ServiceType.fromString(
          json['service_type'] as String? ?? 'BLS'),
      baseFare: (json['base_fare'] as num?)?.toDouble() ?? 0,
      pricePerKm: (json['price_per_km'] as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      equipmentNotes: json['equipment_notes'] as String? ?? '',
    );
  }

  Ambulance copyWith({AmbulanceStatus? status}) {
    return Ambulance(
      id: id,
      plateNumber: plateNumber,
      status: status ?? this.status,
      latitude: latitude,
      longitude: longitude,
      driverId: driverId,
      hospitalId: hospitalId,
      lastLocationUpdate: lastLocationUpdate,
      serviceType: serviceType,
      baseFare: baseFare,
      pricePerKm: pricePerKm,
      rating: rating,
      ratingCount: ratingCount,
      equipmentNotes: equipmentNotes,
    );
  }
}
