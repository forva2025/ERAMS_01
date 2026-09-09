import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen dialog where the dispatcher taps the map to place an incident
/// marker. Returns a [LatLng] on confirm, or null if cancelled.
class LocationPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerDialog({super.key, this.initialLocation});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  // Default center: central Kampala
  static const _kampala = LatLng(0.3476, 32.5825);

  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Incident Location'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          TextButton(
            onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _picked ?? _kampala,
              initialZoom: 13,
              onTap: (_, latLng) => setState(() => _picked = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.erams.erams',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 48,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                          ),
                          CustomPaint(
                            size: const Size(2, 8),
                            painter: _LinePainter(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _picked == null
                      ? 'Tap the map to mark the incident location'
                      : 'Lat: ${_picked!.latitude.toStringAsFixed(5)}, '
                          'Lng: ${_picked!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Pushes [LocationPickerDialog] as a full-screen route and returns the
/// selected [LatLng], or null if the user cancelled.
Future<LatLng?> pickLocation(BuildContext context, {LatLng? initial}) {
  return Navigator.of(context).push<LatLng?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPickerDialog(initialLocation: initial),
    ),
  );
}
