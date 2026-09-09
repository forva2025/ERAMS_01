import 'dart:convert';
import 'dart:typed_data';

/// Extracts latitude from a PostgREST geography column.
/// Handles hex-encoded EWKB (PostgREST default), GeoJSON string, or GeoJSON map.
double? geoLat(dynamic raw) => _coords(raw)?[1];

/// Extracts longitude from a PostgREST geography column.
double? geoLng(dynamic raw) => _coords(raw)?[0];

List<double>? _coords(dynamic raw) {
  if (raw == null) return null;

  if (raw is Map<String, dynamic>) return _fromGeoJson(raw);

  if (raw is String) {
    if (raw.isEmpty) return null;
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return _fromGeoJson(decoded);
      } catch (_) {}
    }
    // PostgREST default: hex-encoded EWKB
    if (raw.length >= 42 && _looksLikeHex(raw)) return _parseWkbHex(raw);
  }

  return null;
}

List<double>? _fromGeoJson(Map<String, dynamic> geo) {
  final coords = geo['coordinates'];
  if (coords is! List || coords.length < 2) return null;
  return [(coords[0] as num).toDouble(), (coords[1] as num).toDouble()];
}

bool _looksLikeHex(String s) {
  for (int i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final isDigit = c >= 48 && c <= 57;
    final isUpper = c >= 65 && c <= 70;
    final isLower = c >= 97 && c <= 102;
    if (!isDigit && !isUpper && !isLower) return false;
  }
  return true;
}

/// Parses a hex-encoded WKB / EWKB Point string and returns [lng, lat].
///
/// WKB Point layout (little-endian, with SRID):
///   01            byte order (01 = LE)
///   01000020      geometry type: 0x20000001 = EWKB Point with SRID
///   E6100000      SRID = 4326
///   <8 bytes>     X (longitude) as IEEE-754 double
///   <8 bytes>     Y (latitude)  as IEEE-754 double
List<double>? _parseWkbHex(String hex) {
  try {
    final len = hex.length ~/ 2;
    final bytes = Uint8List(len);
    for (int i = 0; i < len; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    final isLE = bytes[0] == 1;
    final bd = ByteData.sublistView(bytes);

    final geomType = isLE
        ? bd.getUint32(1, Endian.little)
        : bd.getUint32(1, Endian.big);

    // Lower 16 bits encode the base type; 1 = Point
    if ((geomType & 0xFFFF) != 1) return null;

    // EWKB flag 0x20000000 means a 4-byte SRID follows the type
    final hasSrid = (geomType & 0x20000000) != 0;
    final offset = hasSrid ? 9 : 5;

    if (bytes.length < offset + 16) return null;

    final x = isLE
        ? bd.getFloat64(offset, Endian.little)
        : bd.getFloat64(offset, Endian.big);
    final y = isLE
        ? bd.getFloat64(offset + 8, Endian.little)
        : bd.getFloat64(offset + 8, Endian.big);

    return [x, y]; // [longitude, latitude]
  } catch (_) {
    return null;
  }
}
