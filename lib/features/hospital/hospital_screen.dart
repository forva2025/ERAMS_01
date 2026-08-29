import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../models/hospital.dart';
import '../../models/incident.dart';
import '../../services/auth_service.dart';
import '../../services/hospital_service.dart';
import '../../services/profile_service.dart';
import '../../state/hospital_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/error_state.dart';
import '../../widgets/incident_history_list.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/profile_edit_sheet.dart';
import '../../widgets/status_badge.dart';

class HospitalScreen extends ConsumerStatefulWidget {
  const HospitalScreen({super.key});

  @override
  ConsumerState<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends ConsumerState<HospitalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _historyRows = [];
  bool _historyLoading = false;
  Object? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _historyRows.isEmpty) {
        _loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final hospitalId =
        ref.read(myHospitalProvider).valueOrNull?.id;
    if (hospitalId == null) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final rows =
          await ProfileService().fetchHospitalHistory(hospitalId);
      if (mounted) setState(() => _historyRows = rows);
    } catch (e) {
      if (mounted) setState(() => _historyError = e);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitalAsync = ref.watch(myHospitalProvider);
    final incidentsAsync = ref.watch(hospitalIncidentsProvider);
    final ambulances =
        ref.watch(hospitalAmbulancesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppLogoHorizontal(),
        actions: [
          IconButton(
            tooltip: 'My profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => showProfileSheet(context),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.local_hospital_outlined), text: 'Incoming'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Incoming tab ──────────────────────────────────────
          hospitalAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetryView(
              error: e,
              onRetry: () => ref.invalidate(myHospitalProvider),
            ),
            data: (hospital) {
              if (hospital == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No hospital is linked to your account.\n'
                      'Contact the administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HospitalHeader(
                      hospital: hospital,
                      incidentsAsync: incidentsAsync),
                  const Divider(height: 1),
                  // ── Top half: live map ──────────────────────────
                  Expanded(
                    flex: 1,
                    child: _HospitalLiveMap(
                      hospital: hospital,
                      ambulances: ambulances,
                      incidents:
                          incidentsAsync.valueOrNull ?? [],
                    ),
                  ),
                  const Divider(height: 1),
                  // ── Bottom half: incoming patient list ──────────
                  Expanded(
                    flex: 1,
                    child: incidentsAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => ErrorRetryView(
                        error: e,
                        onRetry: () =>
                            ref.invalidate(hospitalIncidentsProvider),
                      ),
                      data: (incidents) => incidents.isEmpty
                          ? _EmptyState(hospitalName: hospital.name)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: incidents.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final amb = incidents[i]
                                            .assignedAmbulanceId !=
                                        null
                                    ? ambulances
                                        .where((a) =>
                                            a.id ==
                                            incidents[i]
                                                .assignedAmbulanceId)
                                        .firstOrNull
                                    : null;
                                return _IncomingPatientCard(
                                  incident: incidents[i],
                                  hospital: hospital,
                                  ambulance: amb,
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
          // ── History tab ───────────────────────────────────────
          IncidentHistoryList(
            rows: _historyRows,
            isLoading: _historyLoading,
            error: _historyError,
            onRefresh: _loadHistory,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live map — top half of the Incoming tab
// ---------------------------------------------------------------------------

class _HospitalLiveMap extends StatefulWidget {
  final Hospital hospital;
  final List<Ambulance> ambulances;
  final List<Incident> incidents;

  const _HospitalLiveMap({
    required this.hospital,
    required this.ambulances,
    required this.incidents,
  });

  @override
  State<_HospitalLiveMap> createState() => _HospitalLiveMapState();
}

class _HospitalLiveMapState extends State<_HospitalLiveMap> {
  @override
  Widget build(BuildContext context) {
    final hosp = widget.hospital;
    final hospLat = hosp.latitude;
    final hospLng = hosp.longitude;

    // IDs of ambulances currently heading to this hospital
    final headingIds = widget.incidents
        .where((i) => i.assignedAmbulanceId != null && i.status.isActive)
        .map((i) => i.assignedAmbulanceId!)
        .toSet();

    final markers = <Marker>[];

    // Hospital pin (always centre)
    if (hospLat != null && hospLng != null) {
      markers.add(Marker(
        point: LatLng(hospLat, hospLng),
        width: 52,
        height: 52,
        child: Tooltip(
          message: hosp.name,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.4),
                    blurRadius: 12),
              ],
            ),
            child: const Icon(Icons.local_hospital,
                color: Colors.white, size: 26),
          ),
        ),
      ));
    }

    // Ambulance pins
    for (final amb in widget.ambulances) {
      final lat = amb.latitude;
      final lng = amb.longitude;
      if (lat == null || lng == null) continue;

      final isHeading = headingIds.contains(amb.id);
      final color = isHeading
          ? AppColors.primary
          : AppColors.forStatus(amb.status.dbValue);

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: isHeading ? 44 : 36,
        height: isHeading ? 44 : 36,
        child: Tooltip(
          message: isHeading
              ? '${amb.plateNumber} — heading here'
              : '${amb.plateNumber} · ${amb.status.label}',
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white, width: isHeading ? 3 : 2),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: isHeading ? 10 : 4),
              ],
            ),
            child: Icon(
              isHeading
                  ? Icons.airport_shuttle
                  : Icons.airport_shuttle_outlined,
              color: Colors.white,
              size: isHeading ? 22 : 18,
            ),
          ),
        ),
      ));
    }

    // Patient / incident pins for active incidents at this hospital
    for (final inc in widget.incidents) {
      final lat = inc.latitude;
      final lng = inc.longitude;
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 48,
        child: Tooltip(
          message: inc.locationDescription.isEmpty
              ? inc.natureOfEmergency
              : inc.locationDescription,
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.4),
                        blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle,
                    color: Colors.white, size: 18),
              ),
              Container(
                  width: 2, height: 12, color: AppColors.error),
            ],
          ),
        ),
      ));
    }

    final center = hospLat != null && hospLng != null
        ? LatLng(hospLat, hospLng)
        : const LatLng(0.3476, 32.5825);

    final headingCount = headingIds.length;
    final proximityCount =
        widget.ambulances.where((a) => !headingIds.contains(a.id) &&
            a.latitude != null).length;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.erams.erams',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Legend
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HospLegendRow(AppColors.secondary, Icons.local_hospital,
                    'This hospital'),
                SizedBox(height: 4),
                _HospLegendRow(AppColors.primary, Icons.airport_shuttle,
                    'Heading here'),
                SizedBox(height: 4),
                _HospLegendRow(AppColors.statusAvailable,
                    Icons.airport_shuttle_outlined, 'Available'),
                SizedBox(height: 4),
                _HospLegendRow(
                    AppColors.error, Icons.person_pin_circle, 'Patient'),
              ],
            ),
          ),
        ),
        // Live badge
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.statusAvailable,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  'LIVE  ·  $headingCount en route  ·  $proximityCount nearby',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
        // OSM attribution
        Positioned(
          bottom: 2,
          right: 6,
          child: Text(
            '© OpenStreetMap',
            style: TextStyle(
                fontSize: 9,
                color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

class _HospLegendRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _HospLegendRow(this.color, this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5)),
          child: Icon(icon, color: Colors.white, size: 11),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hospital header
// ---------------------------------------------------------------------------

class _HospitalHeader extends StatelessWidget {
  final Hospital hospital;
  final AsyncValue<List<Incident>> incidentsAsync;

  const _HospitalHeader(
      {required this.hospital, required this.incidentsAsync});

  @override
  Widget build(BuildContext context) {
    final count = incidentsAsync.valueOrNull?.length ?? 0;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_hospital,
                color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospital.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? 'No active incoming patients'
                      : '$count incoming patient${count == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: count == 0
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    fontWeight: count == 0
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final String hospitalName;
  const _EmptyState({required this.hospitalName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 60,
            color: AppColors.statusAvailable.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          const Text(
            'No incoming patients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New assignments for $hospitalName will appear here',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incoming patient card
// ---------------------------------------------------------------------------

class _IncomingPatientCard extends ConsumerStatefulWidget {
  final Incident incident;
  final Hospital hospital;
  final Ambulance? ambulance;

  const _IncomingPatientCard({
    required this.incident,
    required this.hospital,
    this.ambulance,
  });

  @override
  ConsumerState<_IncomingPatientCard> createState() =>
      _IncomingPatientCardState();
}

class _IncomingPatientCardState
    extends ConsumerState<_IncomingPatientCard> {
  bool _acknowledging = false;

  String _etaLabel() {
    final amb = widget.ambulance;
    if (amb?.latitude == null ||
        amb?.longitude == null ||
        widget.hospital.latitude == null ||
        widget.hospital.longitude == null) {
      return '';
    }
    const dist = Distance();
    final km = dist.as(
      LengthUnit.Kilometer,
      LatLng(amb!.latitude!, amb.longitude!),
      LatLng(widget.hospital.latitude!, widget.hospital.longitude!),
    );
    final minutes = (km / 40 * 60).ceil();
    return '~$minutes min  ·  ${km.toStringAsFixed(1)} km from hospital';
  }

  Future<void> _acknowledge() async {
    setState(() => _acknowledging = true);
    try {
      await HospitalService()
          .acknowledgeIncident(widget.incident.id);
      ref
          .read(acknowledgedIncidentsProvider.notifier)
          .markAcknowledged(widget.incident.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acknowledged = ref
        .watch(acknowledgedIncidentsProvider)
        .valueOrNull
        ?.contains(widget.incident.id) ??
        false;
    final eta = _etaLabel();

    return Card(
      margin: EdgeInsets.zero,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + time
            Row(
              children: [
                PriorityBadge(priority: widget.incident.priority.dbValue),
                const SizedBox(width: 6),
                StatusBadge(status: widget.incident.status.dbValue),
                const Spacer(),
                Text(
                  _timeAgo(widget.incident.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Nature of emergency
            Text(
              widget.incident.natureOfEmergency.isEmpty
                  ? 'Emergency'
                  : widget.incident.natureOfEmergency,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            // Location
            if (widget.incident.locationDescription.isNotEmpty)
              _InfoRow(
                Icons.place_outlined,
                widget.incident.locationDescription,
              ),
            // Caller
            _InfoRow(
              Icons.person_outline,
              widget.incident.reporterPhone.isEmpty
                  ? widget.incident.reporterName.isEmpty
                      ? 'Unknown caller'
                      : widget.incident.reporterName
                  : '${widget.incident.reporterName}  ·  ${widget.incident.reporterPhone}',
            ),
            // Ambulance + status
            if (widget.ambulance != null)
              _InfoRow(
                Icons.airport_shuttle_outlined,
                '${widget.ambulance!.plateNumber}  ·  ${widget.ambulance!.status.label}',
                color: AppColors.forStatus(
                    widget.ambulance!.status.dbValue),
              ),
            // ETA
            if (eta.isNotEmpty)
              _InfoRow(Icons.timer_outlined, eta,
                  color: AppColors.secondary),
            // Patient condition notes
            if (widget.incident.patientConditionNotes.isNotEmpty) ...[
              const Divider(height: 20),
              _InfoRow(
                Icons.medical_information_outlined,
                widget.incident.patientConditionNotes,
                highlight: true,
              ),
            ],
            const SizedBox(height: 14),
            // Acknowledge button
            SizedBox(
              width: double.infinity,
              child: acknowledged
                  ? OutlinedButton.icon(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: const BorderSide(
                            color: AppColors.statusAvailable),
                        foregroundColor: AppColors.statusAvailable,
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        'Acknowledged',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _acknowledging ? null : _acknowledge,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: AppColors.secondary,
                      ),
                      icon: _acknowledging
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                      label: const Text(
                        'Acknowledge — Ready to Receive',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final bool highlight;

  const _InfoRow(this.icon, this.text,
      {this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (highlight ? AppColors.textPrimary : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: effectiveColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: effectiveColor,
                fontWeight: highlight ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
