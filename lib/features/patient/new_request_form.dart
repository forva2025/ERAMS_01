import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/emergency_types.dart';
import '../../core/theme/app_colors.dart';
import '../../state/patient_provider.dart';
import '../dispatcher/location_picker.dart';

class NewRequestFormScreen extends ConsumerStatefulWidget {
  const NewRequestFormScreen({super.key});

  @override
  ConsumerState<NewRequestFormScreen> createState() =>
      _NewRequestFormScreenState();
}

class _NewRequestFormScreenState
    extends ConsumerState<NewRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _emergencyType;
  final _notesController = TextEditingController();
  LatLng? _pickedLocation;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _changeLocation() async {
    final current = _pickedLocation ??
        ref.read(patientLocationProvider).valueOrNull;
    final picked = await pickLocation(context, initial: current);
    if (picked != null) setState(() => _pickedLocation = picked);
  }

  void _findAmbulances() {
    if (!_formKey.currentState!.validate()) return;
    final location = _pickedLocation ??
        ref.read(patientLocationProvider).valueOrNull;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not yet available. Please wait.')),
      );
      return;
    }
    context.push('/patient/pick', extra: <String, dynamic>{
      'nature_of_emergency':      _emergencyType!,
      'patient_condition_notes':  _notesController.text.trim(),
      'latitude':                 location.latitude,
      'longitude':                location.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(patientLocationProvider);
    final effectiveLocation =
        _pickedLocation ?? locationAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Ambulance')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Emergency type
            const Text(
              'NATURE OF EMERGENCY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _emergencyType,
              decoration: InputDecoration(
                hintText: 'Select emergency type',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              items: emergencyTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _emergencyType = v),
              validator: (v) =>
                  v == null ? 'Please select an emergency type' : null,
            ),
            const SizedBox(height: 24),

            // Additional notes
            const Text(
              'ADDITIONAL NOTES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Patient condition, age, any known allergies…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // Location
            const Text(
              'YOUR LOCATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: locationAsync.when(
                      loading: () => const Text('Getting your location…',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                      error: (_, __) => const Text(
                          'Location unavailable',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                      data: (_) => Text(
                        effectiveLocation != null
                            ? '${effectiveLocation.latitude.toStringAsFixed(5)}, '
                                '${effectiveLocation.longitude.toStringAsFixed(5)}'
                            : 'Detecting location…',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _changeLocation,
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Find ambulances CTA
            FilledButton.icon(
              onPressed: _findAmbulances,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.search, size: 20),
              label: const Text(
                'Find Nearby Ambulances',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
