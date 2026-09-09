import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/emergency_types.dart';
import '../../core/theme/app_colors.dart';
import '../../models/hospital.dart';
import '../../services/incident_service.dart';
import '../../state/dispatcher_provider.dart';
import '../../widgets/error_state.dart';
import 'location_picker.dart';

/// Dialog form for logging a new emergency incident.
/// Call [showNewIncidentForm] to push it.
class NewIncidentForm extends ConsumerStatefulWidget {
  const NewIncidentForm({super.key});

  @override
  ConsumerState<NewIncidentForm> createState() => _NewIncidentFormState();
}

class _NewIncidentFormState extends ConsumerState<NewIncidentForm> {
  final _formKey = GlobalKey<FormState>();

  final _reporterNameCtrl = TextEditingController();
  final _reporterPhoneCtrl = TextEditingController();
  final _locationDescCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();

  LatLng? _pickedLocation;
  String? _selectedEmergencyType;
  Hospital? _selectedHospital;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reporterNameCtrl.dispose();
    _reporterPhoneCtrl.dispose();
    _locationDescCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await pickLocation(context, initial: _pickedLocation);
    if (result != null) setState(() => _pickedLocation = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedLocation == null) {
      setState(() => _errorMessage = 'Please pick the incident location on the map.');
      return;
    }
    if (_selectedHospital == null) {
      setState(() => _errorMessage = 'Please select a hospital.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await IncidentService().createIncident(
        reporterName: _reporterNameCtrl.text.trim(),
        reporterPhone: _reporterPhoneCtrl.text.trim(),
        latitude: _pickedLocation!.latitude,
        longitude: _pickedLocation!.longitude,
        locationDescription: _locationDescCtrl.text.trim(),
        natureOfEmergency: _selectedEmergencyType!,
        patientConditionNotes: _conditionCtrl.text.trim(),
        assignedHospitalId: _selectedHospital!.id,
      );
      // Realtime will push the new incident to the list automatically.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Failed to log incident: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitalsAsync = ref.watch(hospitalsProvider);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_alert_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Log New Incident',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Scrollable form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Caller Information'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reporterNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Caller Name *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reporterPhoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Caller Phone *',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader('Incident Location'),
                      const SizedBox(height: 12),
                      // Location picker button
                      InkWell(
                        onTap: _pickLocation,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _pickedLocation == null
                                  ? AppColors.divider
                                  : AppColors.primary,
                              width: _pickedLocation == null ? 1 : 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: _pickedLocation == null
                                ? Colors.white
                                : AppColors.primaryContainer,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map_outlined,
                                color: _pickedLocation == null
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _pickedLocation == null
                                      ? 'Tap to pick location on map *'
                                      : 'Lat: ${_pickedLocation!.latitude.toStringAsFixed(5)},  '
                                          'Lng: ${_pickedLocation!.longitude.toStringAsFixed(5)}',
                                  style: TextStyle(
                                    color: _pickedLocation == null
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                    fontWeight: _pickedLocation == null
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationDescCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Location Description *',
                          hintText: 'e.g. Near Banda market, opposite Shell station',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader('Emergency Details'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedEmergencyType,
                        decoration: const InputDecoration(
                          labelText: 'Nature of Emergency *',
                          prefixIcon: Icon(Icons.warning_amber_outlined),
                        ),
                        items: emergencyTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedEmergencyType = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _conditionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Patient Condition Notes',
                          hintText: 'e.g. Conscious, multiple lacerations, bleeding controlled',
                          prefixIcon: Icon(Icons.medical_information_outlined),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader('Hospital Assignment'),
                      const SizedBox(height: 12),
                      hospitalsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => InlineErrorRow(
                          error: e,
                          onRetry: () => ref.invalidate(hospitalsProvider),
                        ),
                        data: (hospitals) => DropdownButtonFormField<Hospital>(
                          initialValue: _selectedHospital,
                          decoration: const InputDecoration(
                            labelText: 'Assign to Hospital *',
                            prefixIcon: Icon(Icons.local_hospital_outlined),
                          ),
                          items: hospitals
                              .map((h) => DropdownMenuItem(
                                    value: h,
                                    child: Text(h.name),
                                  ))
                              .toList(),
                          onChanged: (h) =>
                              setState(() => _selectedHospital = h),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                      color: AppColors.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(_submitting ? 'Logging…' : 'Log Incident'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Show the new incident dialog.
Future<void> showNewIncidentForm(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const NewIncidentForm(),
  );
}
