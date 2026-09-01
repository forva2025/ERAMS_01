import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../services/admin_excel_export_service.dart';
import '../../services/admin_service.dart';
import '../../services/file_download_service.dart';
import '../../models/ambulance.dart';
import '../../models/hospital.dart';
import '../../models/incident.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../state/admin_provider.dart';
import '../../state/dispatcher_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/error_state.dart';
import '../../widgets/incident_routes_layer.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/profile_edit_sheet.dart';
import '../../widgets/status_badge.dart';
import '../dispatcher/location_picker.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
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
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.map_outlined), text: 'Live Map'),
              Tab(icon: Icon(Icons.airport_shuttle), text: 'Fleet'),
              Tab(icon: Icon(Icons.local_hospital), text: 'Hospitals'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.personal_injury_outlined), text: 'Patients'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Analytics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LiveMapTab(),
            _FleetTab(),
            _HospitalsTab(),
            _UsersTab(),
            _PatientsTab(),
            _AnalyticsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Live Map Tab ──────────────────────────────────────────────────────────────

class _LiveMapTab extends ConsumerStatefulWidget {
  const _LiveMapTab();

  @override
  ConsumerState<_LiveMapTab> createState() => _LiveMapTabState();
}

class _LiveMapTabState extends ConsumerState<_LiveMapTab> {
  final _mapController = MapController();
  Incident? _selectedIncident;

  @override
  void dispose() {
    super.dispose();
  }

  void _flyTo(double lat, double lng, {double zoom = 15}) {
    _mapController.move(LatLng(lat, lng), zoom);
  }

  @override
  Widget build(BuildContext context) {
    final ambulancesAsync = ref.watch(ambulancesNotifierProvider);
    final incidentsAsync = ref.watch(incidentsNotifierProvider);
    final hospitalsAsync = ref.watch(adminHospitalsProvider);

    // Show full-screen error if ALL three fail (no map to show at all)
    if (ambulancesAsync.hasError &&
        incidentsAsync.hasError &&
        hospitalsAsync.hasError) {
      return ErrorRetryView(
        error: ambulancesAsync.error!,
        onRetry: () {
          ref.invalidate(ambulancesNotifierProvider);
          ref.invalidate(incidentsNotifierProvider);
          ref.invalidate(adminHospitalsProvider);
        },
      );
    }

    final ambulances = ambulancesAsync.valueOrNull ?? [];
    final incidents = incidentsAsync.valueOrNull ?? [];
    final hospitals = hospitalsAsync.valueOrNull ?? [];

    final activeIncidents =
        incidents.where((i) => i.status.isActive).toList();

    final isLoading =
        ambulancesAsync.isLoading || incidentsAsync.isLoading;

    final ambulancesOnMap =
        ambulances.where((a) => a.latitude != null && a.longitude != null).length;
    final incidentsOnMap =
        activeIncidents.where((i) => i.latitude != null && i.longitude != null).length;

    return Column(
      children: [
        // ── Status bar ──────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                const Text('Loading live data…',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ] else ...[
                const Icon(Icons.circle, size: 10, color: Color(0xFF4CAF50)),
                const SizedBox(width: 6),
                Text(
                  'LIVE  •  '
                  '$ambulancesOnMap ambulance${ambulancesOnMap == 1 ? '' : 's'} on map  •  '
                  '$incidentsOnMap active incident${incidentsOnMap == 1 ? '' : 's'}  •  '
                  '${hospitals.length} hospital${hospitals.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (ambulancesOnMap == 0 && ambulances.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Tooltip(
                    message:
                        'Ambulances are registered but have no GPS location yet. '
                        'Location appears once a driver shares their position.',
                    child: Icon(Icons.info_outline,
                        size: 14, color: AppColors.textHint),
                  ),
                ],
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ref.invalidate(ambulancesNotifierProvider);
                  ref.invalidate(incidentsNotifierProvider);
                  ref.invalidate(adminHospitalsProvider);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Map body ────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        final map = Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(0.3476, 32.5825),
                initialZoom: 11,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.erams.erams',
                ),
                // Highlighted shortest route from each accepted ambulance to
                // its patient (drawn under the markers).
                IncidentRoutesLayer(
                  incidents: activeIncidents,
                  ambulances: ambulances,
                ),
                MarkerLayer(markers: _hospitalMarkers(hospitals)),
                MarkerLayer(markers: _ambulanceMarkers(ambulances)),
                MarkerLayer(
                  markers: _incidentMarkers(activeIncidents, (i) {
                    setState(() => _selectedIncident = i);
                    if (i.latitude != null && i.longitude != null) {
                      _flyTo(i.latitude!, i.longitude!);
                    }
                  }),
                ),
              ],
            ),
            // Legend
            Positioned(
              top: 12,
              right: 12,
              child: _AdminMapLegend(),
            ),
            // Live badge (top-left)
            Positioned(
              top: 12,
              left: 12,
              child: _LiveBadge(
                ambulanceCount: ambulancesOnMap,
                incidentCount: incidentsOnMap,
                isLoading: isLoading,
              ),
            ),
            // Selected incident detail card
            if (_selectedIncident != null)
              Positioned(
                bottom: 20,
                left: 12,
                right: isWide ? null : 12,
                child: _IncidentDetailCard(
                  incident: _selectedIncident!,
                  ambulances: ambulances,
                  hospitals: hospitals,
                  onClose: () =>
                      setState(() => _selectedIncident = null),
                ),
              ),
            // OSM attribution
            const Positioned(
              bottom: 4,
              right: 8,
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ],
        );

        if (!isWide) return map;

        return Row(
          children: [
            SizedBox(
              width: 320,
              child: _ActiveEventsFeed(
                incidents: activeIncidents,
                ambulances: ambulances,
                hospitals: hospitals,
                onTap: (i) {
                  setState(() => _selectedIncident = i);
                  if (i.latitude != null && i.longitude != null) {
                    _flyTo(i.latitude!, i.longitude!);
                  }
                },
                selectedId: _selectedIncident?.id,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: map),
          ],
        );
      },
          ),
        ),
      ],
    );
  }

  List<Marker> _hospitalMarkers(List<Hospital> hospitals) {
    return hospitals
        .where((h) => h.latitude != null && h.longitude != null)
        .map((h) => Marker(
              point: LatLng(h.latitude!, h.longitude!),
              width: 44,
              height: 44,
              child: Tooltip(
                message: h.name,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.local_hospital,
                      color: Colors.white, size: 20),
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _ambulanceMarkers(List<Ambulance> ambulances) {
    return ambulances
        .where((a) => a.latitude != null && a.longitude != null)
        .map((a) => Marker(
              point: LatLng(a.latitude!, a.longitude!),
              width: 44,
              height: 44,
              child: Tooltip(
                message: '${a.plateNumber} · ${a.status.label}',
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.forStatus(a.status.dbValue),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.airport_shuttle,
                      color: Colors.white, size: 20),
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _incidentMarkers(
      List<Incident> incidents, ValueChanged<Incident> onTap) {
    return incidents
        .where((i) => i.latitude != null && i.longitude != null)
        .map((i) => Marker(
              point: LatLng(i.latitude!, i.longitude!),
              width: 36,
              height: 44,
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Tooltip(
                  message: i.natureOfEmergency.isEmpty
                      ? 'Incident'
                      : i.natureOfEmergency,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 6),
                          ],
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 17),
                      ),
                      Container(width: 2, height: 10, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ))
        .toList();
  }
}

// ── Live badge (top-left overlay) ────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final int ambulanceCount;
  final int incidentCount;
  final bool isLoading;

  const _LiveBadge({
    required this.ambulanceCount,
    required this.incidentCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4CAF50),
                  letterSpacing: 1)),
          const SizedBox(width: 10),
          const Icon(Icons.airport_shuttle, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text('$ambulanceCount',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('$incidentCount',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ── Map legend ───────────────────────────────────────────────────────────────

class _AdminMapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendRow(
              color: AppColors.primary,
              icon: Icons.warning_amber_rounded,
              label: 'Incident'),
          SizedBox(height: 6),
          _LegendRow(
              color: AppColors.secondary,
              icon: Icons.local_hospital,
              label: 'Hospital'),
          SizedBox(height: 6),
          _LegendRow(
              color: AppColors.statusAvailable,
              icon: Icons.airport_shuttle,
              label: 'Available'),
          SizedBox(height: 6),
          _LegendRow(
              color: AppColors.statusDispatched,
              icon: Icons.airport_shuttle,
              label: 'Dispatched'),
          SizedBox(height: 6),
          _LegendRow(
              color: AppColors.statusEnRoute,
              icon: Icons.airport_shuttle,
              label: 'En Route'),
          SizedBox(height: 6),
          _LegendRow(
              color: AppColors.statusArrived,
              icon: Icons.airport_shuttle,
              label: 'Arrived'),
          SizedBox(height: 6),
          _LegendRow(
              color: AppColors.statusEnRoute,
              icon: Icons.route,
              label: 'Route to patient'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _LegendRow({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5)),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Selected incident detail card (bottom overlay) ───────────────────────────

class _IncidentDetailCard extends StatelessWidget {
  final Incident incident;
  final List<Ambulance> ambulances;
  final List<Hospital> hospitals;
  final VoidCallback onClose;

  const _IncidentDetailCard({
    required this.incident,
    required this.ambulances,
    required this.hospitals,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final ambulance = ambulances
        .where((a) => a.id == incident.assignedAmbulanceId)
        .firstOrNull;
    final hospital = hospitals
        .where((h) => h.id == incident.assignedHospitalId)
        .firstOrNull;
    final age = _timeAgo(incident.createdAt);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.natureOfEmergency.isEmpty
                          ? 'Emergency'
                          : incident.natureOfEmergency,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(age,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatusBadge(status: incident.status.dbValue),
          const SizedBox(height: 8),
          if (incident.locationDescription.isNotEmpty) ...[
            _CardRow(
                icon: Icons.place_outlined,
                text: incident.locationDescription),
            const SizedBox(height: 4),
          ],
          _CardRow(
              icon: Icons.person_outline,
              text: incident.reporterName.isEmpty
                  ? 'Unknown reporter'
                  : incident.reporterName),
          if (incident.reporterPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            _CardRow(icon: Icons.phone_outlined, text: incident.reporterPhone),
          ],
          if (ambulance != null) ...[
            const SizedBox(height: 4),
            _CardRow(
                icon: Icons.airport_shuttle,
                iconColor: AppColors.forStatus(ambulance.status.dbValue),
                text:
                    '${ambulance.plateNumber} · ${ambulance.status.label}'),
          ],
          if (hospital != null) ...[
            const SizedBox(height: 4),
            _CardRow(
                icon: Icons.local_hospital,
                iconColor: AppColors.secondary,
                text: hospital.name),
          ],
          if (incident.dispatchedAt != null) ...[
            const SizedBox(height: 4),
            _CardRow(
                icon: Icons.send_outlined,
                text:
                    'Dispatched ${_timeAgo(incident.dispatchedAt!)}'),
          ],
        ],
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

class _CardRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String text;

  const _CardRow({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 14,
            color: iconColor ?? AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

// ── Active events feed (left sidebar on wide screens) ────────────────────────

class _ActiveEventsFeed extends StatelessWidget {
  final List<Incident> incidents;
  final List<Ambulance> ambulances;
  final List<Hospital> hospitals;
  final ValueChanged<Incident> onTap;
  final String? selectedId;

  const _ActiveEventsFeed({
    required this.incidents,
    required this.ambulances,
    required this.hospitals,
    required this.onTap,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Active Events (${incidents.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: incidents.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 40, color: AppColors.statusAvailable),
                        SizedBox(height: 8),
                        Text(
                          'No active incidents',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: incidents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final incident = incidents[i];
                    final ambulance = ambulances
                        .where(
                            (a) => a.id == incident.assignedAmbulanceId)
                        .firstOrNull;
                    final hospital = hospitals
                        .where(
                            (h) => h.id == incident.assignedHospitalId)
                        .firstOrNull;
                    final isSelected = selectedId == incident.id;

                    return GestureDetector(
                      onTap: () => onTap(incident),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.07)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.divider,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    incident.natureOfEmergency.isEmpty
                                        ? 'Emergency'
                                        : incident.natureOfEmergency,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                StatusBadge(
                                    status: incident.status.dbValue),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _CardRow(
                              icon: Icons.access_time,
                              text: _timeAgo(incident.createdAt),
                            ),
                            if (incident.locationDescription
                                .isNotEmpty) ...[
                              const SizedBox(height: 3),
                              _CardRow(
                                icon: Icons.place_outlined,
                                text: incident.locationDescription,
                              ),
                            ],
                            if (ambulance != null) ...[
                              const SizedBox(height: 3),
                              _CardRow(
                                icon: Icons.airport_shuttle,
                                iconColor: AppColors.forStatus(
                                    ambulance.status.dbValue),
                                text:
                                    '${ambulance.plateNumber} · ${ambulance.status.label}',
                              ),
                            ] else if (incident.status.isActive) ...[
                              const SizedBox(height: 3),
                              const _CardRow(
                                icon: Icons.airport_shuttle,
                                iconColor: AppColors.textHint,
                                text: 'No ambulance assigned',
                              ),
                            ],
                            if (hospital != null) ...[
                              const SizedBox(height: 3),
                              _CardRow(
                                icon: Icons.local_hospital,
                                iconColor: AppColors.secondary,
                                text: hospital.name,
                              ),
                            ],
                            if (incident.dispatchedAt != null) ...[
                              const SizedBox(height: 3),
                              _CardRow(
                                icon: Icons.send_outlined,
                                text:
                                    'Dispatched ${_timeAgo(incident.dispatchedAt!)}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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

// ── Fleet Tab ────────────────────────────────────────────────────────────────

class _FleetTab extends ConsumerWidget {
  const _FleetTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleetAsync = ref.watch(fleetNotifierProvider);
    final hospitalsAsync = ref.watch(adminHospitalsProvider);
    final profilesAsync = ref.watch(profilesNotifierProvider);

    return fleetAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
          error: e, onRetry: () => ref.invalidate(fleetNotifierProvider)),
      data: (ambulances) {
        final hospitals = hospitalsAsync.valueOrNull ?? [];
        final drivers = (profilesAsync.valueOrNull ?? [])
            .where((p) => p.role == UserRole.driver)
            .toList();

        return Column(
          children: [
            _SectionHeader(
              title: '${ambulances.length} Ambulance${ambulances.length == 1 ? '' : 's'}',
              action: FilledButton.icon(
                onPressed: () => _showAmbulanceForm(
                  context,
                  ref,
                  hospitals: hospitals,
                  drivers: drivers,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Ambulance'),
              ),
            ),
            Expanded(
              child: ambulances.isEmpty
                  ? const _EmptyState(
                      icon: Icons.airport_shuttle,
                      message: 'No ambulances yet.\nTap "Add Ambulance" to register one.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ambulances.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _AmbulanceCard(
                        ambulance: ambulances[i],
                        hospitals: hospitals,
                        drivers: drivers,
                        onEdit: () => _showAmbulanceForm(
                          context,
                          ref,
                          existing: ambulances[i],
                          hospitals: hospitals,
                          drivers: drivers,
                        ),
                        onDelete: () =>
                            _confirmDeleteAmbulance(context, ref, ambulances[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAmbulanceForm(
    BuildContext context,
    WidgetRef ref, {
    Ambulance? existing,
    required List<Hospital> hospitals,
    required List<Profile> drivers,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _AmbulanceFormDialog(
        existing: existing,
        hospitals: hospitals,
        drivers: drivers,
        onSave: (plate, driverId, hospitalId, clearDriver, clearHospital,
            serviceType, baseFare, pricePerKm, equipmentNotes) async {
          final notifier = ref.read(fleetNotifierProvider.notifier);
          if (existing == null) {
            await notifier.createAmbulance(
              plateNumber: plate,
              driverId: driverId,
              hospitalId: hospitalId,
              serviceType: serviceType,
              baseFare: baseFare,
              pricePerKm: pricePerKm,
              equipmentNotes: equipmentNotes,
            );
          } else {
            await notifier.updateAmbulance(
              existing.id,
              plateNumber: plate,
              driverId: driverId,
              hospitalId: hospitalId,
              clearDriver: clearDriver,
              clearHospital: clearHospital,
              serviceType: serviceType,
              baseFare: baseFare,
              pricePerKm: pricePerKm,
              equipmentNotes: equipmentNotes,
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteAmbulance(
      BuildContext context, WidgetRef ref, Ambulance ambulance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Ambulance?'),
        content: Text(
          'This will permanently remove ${ambulance.plateNumber}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(fleetNotifierProvider.notifier).deleteAmbulance(ambulance.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _AmbulanceCard extends StatelessWidget {
  final Ambulance ambulance;
  final List<Hospital> hospitals;
  final List<Profile> drivers;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AmbulanceCard({
    required this.ambulance,
    required this.hospitals,
    required this.drivers,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hospital = hospitals.where((h) => h.id == ambulance.hospitalId)
        .firstOrNull;
    final driver = drivers.where((d) => d.id == ambulance.driverId)
        .firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.forStatus(ambulance.status.dbValue)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.airport_shuttle,
                color: AppColors.forStatus(ambulance.status.dbValue),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ambulance.plateNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusBadge(status: ambulance.status.dbValue),
                      _ServiceTypeBadge(serviceType: ambulance.serviceType),
                      if (driver != null)
                        _InfoChip(
                            icon: Icons.person, label: driver.fullName),
                      if (hospital != null)
                        _InfoChip(
                            icon: Icons.local_hospital, label: hospital.name),
                    ],
                  ),
                  if (ambulance.baseFare > 0 || ambulance.pricePerKm > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'UGX ${ambulance.baseFare.toStringAsFixed(0)} base'
                      ' + ${ambulance.pricePerKm.toStringAsFixed(0)}/km'
                      '${ambulance.ratingCount > 0 ? '  ★ ${ambulance.rating.toStringAsFixed(1)} (${ambulance.ratingCount})' : ''}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete',
              color: AppColors.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbulanceFormDialog extends StatefulWidget {
  final Ambulance? existing;
  final List<Hospital> hospitals;
  final List<Profile> drivers;
  final Future<void> Function(
    String plate,
    String? driverId,
    String? hospitalId,
    bool clearDriver,
    bool clearHospital,
    String serviceType,
    double baseFare,
    double pricePerKm,
    String equipmentNotes,
  ) onSave;

  const _AmbulanceFormDialog({
    this.existing,
    required this.hospitals,
    required this.drivers,
    required this.onSave,
  });

  @override
  State<_AmbulanceFormDialog> createState() => _AmbulanceFormDialogState();
}

class _AmbulanceFormDialogState extends State<_AmbulanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateCtrl;
  late final TextEditingController _baseFareCtrl;
  late final TextEditingController _pricePerKmCtrl;
  late final TextEditingController _equipmentCtrl;
  String? _driverId;
  String? _hospitalId;
  String _serviceType = 'BLS';
  bool _saving = false;
  String? _error;

  static const _serviceTypes = ['BLS', 'ALS', 'ICU', 'Neonatal', 'Bariatric'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _plateCtrl = TextEditingController(text: e?.plateNumber ?? '');
    _baseFareCtrl = TextEditingController(
        text: e != null && e.baseFare > 0 ? e.baseFare.toStringAsFixed(0) : '');
    _pricePerKmCtrl = TextEditingController(
        text: e != null && e.pricePerKm > 0
            ? e.pricePerKm.toStringAsFixed(0)
            : '');
    _equipmentCtrl =
        TextEditingController(text: e?.equipmentNotes ?? '');
    _driverId = e?.driverId;
    _hospitalId = e?.hospitalId;
    _serviceType = e?.serviceType.dbValue ?? 'BLS';
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _baseFareCtrl.dispose();
    _pricePerKmCtrl.dispose();
    _equipmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final origDriverId = widget.existing?.driverId;
      final origHospitalId = widget.existing?.hospitalId;
      await widget.onSave(
        _plateCtrl.text.trim().toUpperCase(),
        _driverId,
        _hospitalId,
        origDriverId != null && _driverId == null,
        origHospitalId != null && _hospitalId == null,
        _serviceType,
        double.tryParse(_baseFareCtrl.text.trim()) ?? 0,
        double.tryParse(_pricePerKmCtrl.text.trim()) ?? 0,
        _equipmentCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Ambulance' : 'Add Ambulance'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _plateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plate Number *',
                    hintText: 'e.g. UAB 123X',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _serviceType,
                  decoration:
                      const InputDecoration(labelText: 'Service Type *'),
                  items: _serviceTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _serviceType = v ?? 'BLS'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _baseFareCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Base Fare (UGX)',
                          hintText: '50000',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pricePerKmCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Per Km (UGX)',
                          hintText: '3000',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _driverId,
                  decoration:
                      const InputDecoration(labelText: 'Assigned Driver'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— None —')),
                    ...widget.drivers.map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.fullName),
                        )),
                  ],
                  onChanged: (v) => setState(() => _driverId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _hospitalId,
                  decoration:
                      const InputDecoration(labelText: 'Home Hospital'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— None —')),
                    ...widget.hospitals.map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(h.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _hospitalId = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _equipmentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Equipment Notes',
                    hintText: 'Oxygen, AED, stretcher…',
                  ),
                  maxLines: 2,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ── Hospitals Tab ─────────────────────────────────────────────────────────────

class _HospitalsTab extends ConsumerWidget {
  const _HospitalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(adminHospitalsProvider);

    return hospitalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
          error: e, onRetry: () => ref.invalidate(adminHospitalsProvider)),
      data: (hospitals) {
        return Column(
          children: [
            _SectionHeader(
              title:
                  '${hospitals.length} Hospital${hospitals.length == 1 ? '' : 's'}',
              action: FilledButton.icon(
                onPressed: () => _showHospitalForm(context, ref),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Hospital'),
              ),
            ),
            Expanded(
              child: hospitals.isEmpty
                  ? const _EmptyState(
                      icon: Icons.local_hospital,
                      message:
                          'No hospitals yet.\nTap "Add Hospital" to register one.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: hospitals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _HospitalCard(
                        hospital: hospitals[i],
                        onEdit: () => _showHospitalForm(context, ref,
                            existing: hospitals[i]),
                        onDelete: () =>
                            _confirmDeleteHospital(context, ref, hospitals[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showHospitalForm(BuildContext context, WidgetRef ref,
      {Hospital? existing}) {
    showDialog<void>(
      context: context,
      builder: (_) => _HospitalFormDialog(
        existing: existing,
        onSave: (name, address, phone, lat, lng) {
          final notifier = ref.read(adminHospitalsProvider.notifier);
          if (existing == null) {
            return notifier.createHospital(
              name: name,
              address: address,
              contactPhone: phone,
              latitude: lat,
              longitude: lng,
            );
          }
          return notifier.updateHospital(
            existing.id,
            name: name,
            address: address,
            contactPhone: phone,
            latitude: lat,
            longitude: lng,
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteHospital(
      BuildContext context, WidgetRef ref, Hospital hospital) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Hospital?'),
        content: Text(
          'This will permanently remove ${hospital.name}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(adminHospitalsProvider.notifier).deleteHospital(hospital.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HospitalCard({
    required this.hospital,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_hospital,
                  color: AppColors.secondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospital.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (hospital.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      hospital.address,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  if (hospital.contactPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      hospital.contactPhone,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete',
              color: AppColors.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalFormDialog extends StatefulWidget {
  final Hospital? existing;
  final Future<void> Function(
    String name,
    String address,
    String phone,
    double? lat,
    double? lng,
  ) onSave;

  const _HospitalFormDialog({this.existing, required this.onSave});

  @override
  State<_HospitalFormDialog> createState() => _HospitalFormDialogState();
}

class _HospitalFormDialogState extends State<_HospitalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  double? _lat;
  double? _lng;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
    _phoneCtrl =
        TextEditingController(text: widget.existing?.contactPhone ?? '');
    _lat = widget.existing?.latitude;
    _lng = widget.existing?.longitude;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await pickLocation(
      context,
      initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
    );
    if (picked != null) {
      setState(() {
        _lat = picked.latitude;
        _lng = picked.longitude;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _nameCtrl.text.trim(),
        _addressCtrl.text.trim(),
        _phoneCtrl.text.trim(),
        _lat,
        _lng,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Hospital' : 'Add Hospital'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Hospital Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Contact Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.place_outlined, size: 18),
                label: Text(
                  _lat != null && _lng != null
                      ? 'Location set (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})'
                      : 'Pick Location on Map',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ── Users Tab ────────────────────────────────────────────────────────────────

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesNotifierProvider);
    final hospitalsAsync = ref.watch(adminHospitalsProvider);

    return profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
          error: e, onRetry: () => ref.invalidate(profilesNotifierProvider)),
      data: (profiles) {
        final hospitals = hospitalsAsync.valueOrNull ?? [];
        return Column(
          children: [
            _SectionHeader(
              title: '${profiles.length} User${profiles.length == 1 ? '' : 's'}',
              action: FilledButton.icon(
                onPressed: () => _showUserForm(context, ref, hospitals: hospitals),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add User'),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _UserCard(
                  profile: profiles[i],
                  hospitals: hospitals,
                  onChangeRole: (role) async {
                    await ref
                        .read(profilesNotifierProvider.notifier)
                        .updateRole(profiles[i].id, role);
                  },
                  onChangeHospital: (hid) async {
                    await ref
                        .read(profilesNotifierProvider.notifier)
                        .updateHospital(profiles[i].id, hid);
                  },
                  onEdit: () => _showEditDetailsForm(context, ref, profiles[i]),
                  onResetPassword: () =>
                      _confirmAndResetPassword(context, ref, profiles[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUserForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Hospital> hospitals,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _UserCreateDialog(
        hospitals: hospitals,
        onCreate: (email, fullName, role, hospitalId, phone) {
          return ref.read(profilesNotifierProvider.notifier).createUser(
                email: email,
                fullName: fullName,
                role: role,
                hospitalId: hospitalId,
                phone: phone,
              );
        },
      ),
    );
  }

  void _showEditDetailsForm(
      BuildContext context, WidgetRef ref, Profile profile) {
    showDialog<void>(
      context: context,
      builder: (_) => _UserEditDetailsDialog(
        profile: profile,
        onSave: (fullName, phone) => ref
            .read(profilesNotifierProvider.notifier)
            .updateDetails(profile.id, fullName: fullName, phone: phone),
      ),
    );
  }

  Future<void> _confirmAndResetPassword(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password?'),
        content: Text(
          'This will generate a new temporary password for '
          '${profile.fullName.isEmpty ? profile.email : profile.fullName}. '
          'Their current password will stop working immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final tempPassword = await ref
          .read(profilesNotifierProvider.notifier)
          .resetPassword(profile.id);
      if (context.mounted) {
        _showTempPasswordDialog(context, tempPassword);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

void _showTempPasswordDialog(BuildContext context, String tempPassword) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Temporary Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share this password with the user. They will be required to '
            'set their own password the next time they sign in.',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    tempPassword,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: tempPassword)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class _UserCard extends StatefulWidget {
  final Profile profile;
  final List<Hospital> hospitals;
  final Future<void> Function(String role) onChangeRole;
  final Future<void> Function(String? hospitalId) onChangeHospital;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;

  const _UserCard({
    required this.profile,
    required this.hospitals,
    required this.onChangeRole,
    required this.onChangeHospital,
    required this.onEdit,
    required this.onResetPassword,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _saving = false;

  Future<void> _pickRole(BuildContext context) async {
    final roles = ['dispatcher', 'driver', 'hospital', 'admin'];
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Change role for\n${widget.profile.fullName}',
            style: const TextStyle(fontSize: 15)),
        children: roles
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        if (r == widget.profile.role.name)
                          const Icon(Icons.check,
                              size: 16, color: AppColors.primary)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(UserRole.fromString(r).label),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == widget.profile.role.name) return;
    setState(() => _saving = true);
    try {
      await widget.onChangeRole(picked);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (widget.profile.role) {
      UserRole.admin => AppColors.primary,
      UserRole.dispatcher => AppColors.secondary,
      UserRole.driver => AppColors.statusEnRoute,
      UserRole.hospital => AppColors.statusArrived,
      UserRole.patient => AppColors.textSecondary,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                widget.profile.fullName.isNotEmpty
                    ? widget.profile.fullName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: roleColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.profile.email.isNotEmpty
                        ? widget.profile.email
                        : widget.profile.phone,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : GestureDetector(
                    onTap: () => _pickRole(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: roleColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.profile.role.label,
                            style: TextStyle(
                                color: roleColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down,
                              color: roleColor, size: 16),
                        ],
                      ),
                    ),
                  ),
            PopupMenuButton<String>(
              tooltip: 'More actions',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  widget.onEdit();
                } else if (value == 'reset') {
                  widget.onResetPassword();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit Details'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    leading: Icon(Icons.key_outlined),
                    title: Text('Reset Password'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create user dialog ───────────────────────────────────────────────────────

class _UserCreateDialog extends StatefulWidget {
  final List<Hospital> hospitals;
  final Future<String> Function(
    String email,
    String fullName,
    String role,
    String? hospitalId,
    String phone,
  ) onCreate;

  const _UserCreateDialog({required this.hospitals, required this.onCreate});

  @override
  State<_UserCreateDialog> createState() => _UserCreateDialogState();
}

class _UserCreateDialogState extends State<_UserCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _role = 'dispatcher';
  String? _hospitalId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tempPassword = await widget.onCreate(
        _emailCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _role,
        _role == 'hospital' ? _hospitalId : null,
        _phoneCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        _showTempPasswordDialog(context, tempPassword);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add User'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role *'),
                items: ['dispatcher', 'driver', 'hospital', 'admin']
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(UserRole.fromString(r).label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              if (_role == 'hospital') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _hospitalId,
                  decoration: const InputDecoration(labelText: 'Hospital'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— None —')),
                    ...widget.hospitals.map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(h.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _hospitalId = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ── Edit user details dialog ─────────────────────────────────────────────────

class _UserEditDetailsDialog extends StatefulWidget {
  final Profile profile;
  final Future<void> Function(String fullName, String phone) onSave;

  const _UserEditDetailsDialog({required this.profile, required this.onSave});

  @override
  State<_UserEditDetailsDialog> createState() =>
      _UserEditDetailsDialogState();
}

class _UserEditDetailsDialogState extends State<_UserEditDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.fullName);
    _phoneCtrl = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_nameCtrl.text.trim(), _phoneCtrl.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.profile.email.isNotEmpty) ...[
                Text(widget.profile.email,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Patients Tab ─────────────────────────────────────────────

class _PatientsTab extends ConsumerStatefulWidget {
  const _PatientsTab();

  @override
  ConsumerState<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends ConsumerState<_PatientsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(patientRecordsProvider);

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        error: e,
        onRetry: () => ref.invalidate(patientRecordsProvider),
      ),
      data: (records) {
        final filtered = _query.isEmpty
            ? records
            : records.where((r) {
                final q = _query.toLowerCase();
                return r.patientName.toLowerCase().contains(q) ||
                    r.patientPhone.toLowerCase().contains(q) ||
                    r.natureOfEmergency.toLowerCase().contains(q) ||
                    (r.ambulancePlate?.toLowerCase().contains(q) ?? false) ||
                    (r.hospitalName?.toLowerCase().contains(q) ?? false) ||
                    r.locationDescription.toLowerCase().contains(q);
              }).toList();

        return Column(
          children: [
            _SectionHeader(
              title: '${records.length} Patient Record${records.length == 1 ? '' : 's'}',
              action: IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.invalidate(patientRecordsProvider),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, emergency type, ambulance…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 12),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      icon: Icons.personal_injury_outlined,
                      message: _query.isEmpty
                          ? 'No patient records yet.\nRecords appear here once incidents are logged.'
                          : 'No records match "$_query".',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(patientRecordsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _PatientRecordCard(record: filtered[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PatientRecordCard extends StatelessWidget {
  final PatientRecord record;

  const _PatientRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.forStatus(record.status);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: patient name + status badge ──────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.personal_injury_outlined,
                    size: 18,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.patientName.isNotEmpty
                            ? record.patientName
                            : 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (record.patientPhone.isNotEmpty)
                        Text(
                          record.patientPhone,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                PriorityBadge(priority: record.priority),
                const SizedBox(width: 6),
                StatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 10),
            // ── Row 2: emergency type ────────────────────────────
            _DetailRow(
              icon: Icons.emergency,
              iconColor: AppColors.error,
              label: record.natureOfEmergency.isNotEmpty
                  ? record.natureOfEmergency
                  : 'Not specified',
            ),
            if (record.locationDescription.isNotEmpty) ...[
              const SizedBox(height: 4),
              _DetailRow(
                icon: Icons.place_outlined,
                label: record.locationDescription,
              ),
            ],
            const SizedBox(height: 8),
            // ── Row 3: ambulance → hospital ──────────────────────
            Row(
              children: [
                Expanded(
                  child: _DetailRow(
                    icon: Icons.airport_shuttle,
                    iconColor: record.ambulancePlate != null
                        ? AppColors.statusEnRoute
                        : AppColors.textHint,
                    label: record.ambulancePlate ?? 'No ambulance assigned',
                    faint: record.ambulancePlate == null,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetailRow(
                    icon: Icons.local_hospital,
                    iconColor: record.hospitalName != null
                        ? AppColors.secondary
                        : AppColors.textHint,
                    label: record.hospitalName ?? 'No hospital assigned',
                    faint: record.hospitalName == null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Row 4: timestamps + response time ───────────────
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _InfoChip(
                  icon: Icons.access_time,
                  label: _formatDate(record.createdAt),
                ),
                if (record.responseTime != null)
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: 'Response: ${record.responseTime}',
                  ),
                if (record.completedAt != null)
                  _InfoChip(
                    icon: Icons.check_circle_outline,
                    label: 'Completed ${_formatDate(record.completedAt!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool faint;

  const _DetailRow({
    required this.icon,
    this.iconColor,
    required this.label,
    this.faint = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = faint ? AppColors.textHint : AppColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor ?? color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}

// ── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
          error: e, onRetry: () => ref.invalidate(analyticsProvider)),
      data: (a) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(analyticsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI row 1: Total Incidents, Avg Response
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Total Incidents',
                    value: '${a.totalIncidents}',
                    icon: Icons.assignment,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'Avg Response',
                    value: a.avgResponseFormatted,
                    icon: Icons.timer_outlined,
                    color: AppColors.statusDispatched,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // KPI row 2: Calls Today, Completion Rate
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Calls Today',
                    value: '${a.callsToday}',
                    icon: Icons.today_outlined,
                    color: AppColors.statusCompleted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'Completion Rate',
                    value: a.completionRateFormatted,
                    icon: Icons.check_circle_outline,
                    color: AppColors.statusAvailable,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Export actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showCsvDialog(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download CSV'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _downloadExcel(context, a),
                  icon: const Icon(Icons.grid_on_outlined, size: 18),
                  label: const Text('Download Excel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showDhis2Dialog(context),
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: const Text('Export to DHIS2'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Fleet utilisation donut
            _ChartCard(
              title: 'Fleet Utilisation',
              child: _DonutChart(a.fleetStatusCounts),
            ),
            const SizedBox(height: 16),
            // Incidents by status
            _ChartCard(
              title: 'Incidents by Status',
              child: a.countByStatus.isEmpty
                  ? const _EmptyState(
                      icon: Icons.bar_chart,
                      message: 'No incident data yet.',
                    )
                  : _BarChart(
                      data: a.countByStatus,
                      colorFor: AppColors.forStatus,
                    ),
            ),
            const SizedBox(height: 16),
            // Incidents by hospital
            _ChartCard(
              title: 'Incidents by Hospital',
              child: a.countByHospital.isEmpty
                  ? const _EmptyState(
                      icon: Icons.local_hospital,
                      message: 'No hospital data yet.',
                    )
                  : _BarChart(
                      data: a.countByHospital,
                      colorFor: (_) => AppColors.secondary,
                    ),
            ),
            const SizedBox(height: 16),
            // Calls by emergency type
            _ChartCard(
              title: 'Calls by Emergency Type',
              child: a.countByEmergencyType.isEmpty
                  ? const _EmptyState(
                      icon: Icons.medical_services_outlined,
                      message: 'No emergency type data yet.',
                    )
                  : _BarChart(
                      data: a.countByEmergencyType,
                      colorFor: (_) => AppColors.statusEnRoute,
                    ),
            ),
            const SizedBox(height: 16),
            // Response time (last 10 calls)
            _ChartCard(
              title: 'Response Time — Last 10 Calls (min)',
              child: _ResponseTimeChart(a.recentResponseTimes),
            ),
            const SizedBox(height: 16),
            // Status breakdown table
            if (a.countByStatus.isNotEmpty) ...[
              _ChartCard(
                title: 'Status Breakdown',
                child: Column(
                  children: a.countByStatus.entries.map((e) {
                    final pct = a.totalIncidents > 0
                        ? e.value / a.totalIncidents
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          StatusBadge(status: e.key),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: AppColors.divider,
                                color: AppColors.forStatus(e.key),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${e.value}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showCsvDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _CsvDialog(),
  );
}

void _showDhis2Dialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _Dhis2ExportDialog(),
  );
}

Future<void> _downloadExcel(BuildContext context, AdminAnalytics a) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing report…')));
  try {
    // Fetch fresh records (not the cached provider) so the export always
    // reflects the latest data, same convention as the CSV dialog.
    final records = await AdminService().fetchAllPatientRecords();
    final bytes = AdminExcelExportService()
        .buildWorkbookBytes(analytics: a, records: records);
    final date = DateTime.now().toIso8601String().split('T').first;
    downloadBytes(bytes: bytes, filename: 'erams_report_$date.xlsx');
    messenger.showSnackBar(
      const SnackBar(content: Text('Excel report downloaded')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Simple horizontal bar chart using only Flutter primitives (no fl_chart dep).
class _BarChart extends StatelessWidget {
  final Map<String, int> data;
  final Color Function(String key) colorFor;

  const _BarChart({required this.data, required this.colorFor});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Column(
      children: data.entries.map((e) {
        final frac = e.value / maxVal;
        final color = colorFor(e.key);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  e.key,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 18,
                    backgroundColor: AppColors.divider,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '${e.value}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Fleet utilisation donut (fl_chart PieChart) ───────────────────────────────

class _DonutChart extends StatelessWidget {
  final Map<String, int> counts;

  const _DonutChart(this.counts);

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) {
      return const _EmptyState(
          icon: Icons.donut_large, message: 'No fleet data yet.');
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return const _EmptyState(
          icon: Icons.donut_large, message: 'No fleet data yet.');
    }

    final sections = counts.entries.map((e) {
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: AppColors.forStatus(e.key),
        title: '',
        radius: 42,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: counts.entries.map((e) {
            final pct = (e.value / total * 100).round();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.forStatus(e.key),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${e.key} $pct% (${e.value})',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Response time bar chart (last 10 calls) ───────────────────────────────────

class _ResponseTimeChart extends StatelessWidget {
  final List<({String label, double minutes})> data;

  const _ResponseTimeChart(this.data);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyState(
          icon: Icons.timer, message: 'No response time data yet.');
    }
    final maxMin = data.fold(0.0, (m, e) => e.minutes > m ? e.minutes : m);
    if (maxMin == 0) return const SizedBox.shrink();

    return Column(
      children: data.map((e) {
        final frac = e.minutes / maxMin;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  e.label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 18,
                    backgroundColor: AppColors.divider,
                    color: AppColors.statusDispatched,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: Text(
                  '${e.minutes.toStringAsFixed(1)}m',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── CSV export dialog ─────────────────────────────────────────────────────────

class _CsvDialog extends StatefulWidget {
  const _CsvDialog();

  @override
  State<_CsvDialog> createState() => _CsvDialogState();
}

class _CsvDialogState extends State<_CsvDialog> {
  List<PatientRecord>? _records;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final records = await AdminService().fetchAllPatientRecords();
      if (mounted) setState(() => _records = records);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String _csv() {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Patient,Phone,Emergency,Location,Status,Ambulance,Hospital,'
        'Created,Dispatched,Arrived,Completed,Response Time');
    for (final r in _records!) {
      buf.writeln([
        _cell(r.incidentId),
        _cell(r.patientName),
        _cell(r.patientPhone),
        _cell(r.natureOfEmergency),
        _cell(r.locationDescription),
        _cell(r.status),
        _cell(r.ambulancePlate ?? ''),
        _cell(r.hospitalName ?? ''),
        r.createdAt.toIso8601String(),
        r.dispatchedAt?.toIso8601String() ?? '',
        r.arrivedAt?.toIso8601String() ?? '',
        r.completedAt?.toIso8601String() ?? '',
        r.responseTime ?? '',
      ].join(','));
    }
    return buf.toString();
  }

  static String _cell(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final csv = _records != null ? _csv() : null;
    return AlertDialog(
      title: const Text('Download Report'),
      content: SizedBox(
        width: 560,
        height: 320,
        child: _error != null
            ? Center(child: Text('Error: $_error'))
            : _records == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_records!.length} records ready — copy CSV below:',
                        style:
                            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.divider),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              csv!,
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (csv != null)
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('CSV copied to clipboard — paste into Excel or Sheets')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy to Clipboard'),
          ),
      ],
    );
  }
}

// ── DHIS2 export dialog ───────────────────────────────────────────────────────

class _Dhis2ExportDialog extends StatefulWidget {
  const _Dhis2ExportDialog();

  @override
  State<_Dhis2ExportDialog> createState() => _Dhis2ExportDialogState();
}

class _Dhis2ExportDialogState extends State<_Dhis2ExportDialog> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _orgUnitCtrl = TextEditingController();
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _orgUnitCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _export() async {
    if (_serverCtrl.text.trim().isEmpty ||
        _userCtrl.text.trim().isEmpty ||
        _orgUnitCtrl.text.trim().isEmpty) {
      setState(() => _result = 'Error: Server URL, username, and org unit are required.');
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final res = await AdminService().exportToDhis2(
        startDate: _fmtDate(_from),
        endDate: _fmtDate(_to),
        dhis2Url: _serverCtrl.text.trim(),
        dhis2Username: _userCtrl.text.trim(),
        dhis2Password: _passCtrl.text,
        orgUnit: _orgUnitCtrl.text.trim(),
      );
      final status = res['status'] as String? ?? res['httpStatus'] as String? ?? 'OK';
      if (mounted) setState(() { _loading = false; _result = 'Success: $status'; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _result = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export to DHIS2'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DatePickerRow(
                label: 'From',
                date: _from,
                onChanged: (d) => setState(() => _from = d),
              ),
              const SizedBox(height: 8),
              _DatePickerRow(
                label: 'To',
                date: _to,
                onChanged: (d) => setState(() => _to = d),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _serverCtrl,
                decoration: const InputDecoration(
                  labelText: 'DHIS2 Server URL',
                  hintText: 'https://play.dhis2.org/40.3.0',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _orgUnitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Org Unit UID',
                  hintText: 'DiszpKrYNg8',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 12),
                Text(
                  _result!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _result!.startsWith('Error')
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _loading ? null : _export,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerRow({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) onChanged(picked);
            },
            child: Text(fmt),
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textSecondary)),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _ServiceTypeBadge extends StatelessWidget {
  final ServiceType serviceType;
  const _ServiceTypeBadge({required this.serviceType});

  static Color _color(ServiceType t) => switch (t) {
    ServiceType.bls       => const Color(0xFF2196F3),
    ServiceType.als       => const Color(0xFFFF9800),
    ServiceType.icu       => const Color(0xFFF44336),
    ServiceType.neonatal  => const Color(0xFFE91E63),
    ServiceType.bariatric => const Color(0xFF9C27B0),
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(serviceType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        serviceType.shortLabel,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

