import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../models/incident.dart';
import '../../services/incident_service.dart';
import '../../widgets/status_badge.dart';

/// Shown when auto-dispatch fails ("no ambulance available").
/// Lists all ambulances so the dispatcher can manually assign one.
class ManualDispatchDialog extends StatefulWidget {
  final Incident incident;
  final List<Ambulance> ambulances;

  const ManualDispatchDialog({
    super.key,
    required this.incident,
    required this.ambulances,
  });

  @override
  State<ManualDispatchDialog> createState() => _ManualDispatchDialogState();
}

class _ManualDispatchDialogState extends State<ManualDispatchDialog> {
  String? _assigningId;
  String? _errorMessage;

  Future<void> _assign(Ambulance ambulance) async {
    setState(() {
      _assigningId = ambulance.id;
      _errorMessage = null;
    });

    try {
      await IncidentService().dispatchIncidentManual(
        widget.incident.id,
        ambulance.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DispatchException catch (e) {
      setState(() {
        _assigningId = null;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _assigningId = null;
        _errorMessage = 'Assignment failed: ${e.toString()}';
      });
    }
  }

  double? _distanceKm(Ambulance a) {
    if (a.latitude == null ||
        a.longitude == null ||
        widget.incident.latitude == null ||
        widget.incident.longitude == null) {
      return null;
    }
    const distance = Distance();
    final metres = distance.as(
      LengthUnit.Meter,
      LatLng(a.latitude!, a.longitude!),
      LatLng(widget.incident.latitude!, widget.incident.longitude!),
    );
    return metres / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.ambulances]
      ..sort((a, b) {
        final da = _distanceKm(a);
        final db = _distanceKm(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.statusDispatched,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Available Ambulance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manually assign any unit below',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Incident summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.errorSurface,
              child: Text(
                '${widget.incident.natureOfEmergency}  ·  '
                '${widget.incident.locationDescription}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.errorSurface,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            // Ambulance list
            Flexible(
              child: sorted.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No ambulances in the system.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final amb = sorted[i];
                        final dist = _distanceKm(amb);
                        final isAssigning = _assigningId == amb.id;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.forStatus(amb.status.dbValue)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.airport_shuttle,
                              color: AppColors.forStatus(amb.status.dbValue),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            amb.plateNumber,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Row(
                            children: [
                              StatusBadge(status: amb.status.dbValue),
                              if (dist != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${dist.toStringAsFixed(1)} km away',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                          trailing: SizedBox(
                            width: 88,
                            child: FilledButton(
                              onPressed: isAssigning || _assigningId != null
                                  ? null
                                  : () => _assign(amb),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                backgroundColor:
                                    AppColors.forStatus(amb.status.dbValue),
                              ),
                              child: isAssigning
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Assign',
                                      style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton(
                onPressed: _assigningId != null
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40)),
                child: const Text('Cancel — Do Not Dispatch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the manual dispatch dialog. Returns true if an ambulance was
/// successfully assigned, false if the user cancelled.
Future<bool> showManualDispatchDialog(
  BuildContext context, {
  required Incident incident,
  required List<Ambulance> ambulances,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ManualDispatchDialog(
      incident: incident,
      ambulances: ambulances,
    ),
  );
  return result ?? false;
}
