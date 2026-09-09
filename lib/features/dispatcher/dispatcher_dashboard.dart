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
import '../../services/incident_service.dart';
import '../../services/profile_service.dart';
import '../../state/auth_provider.dart';
import '../../state/dispatcher_provider.dart';
import '../../state/message_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/chat_sheet.dart';
import '../../widgets/incident_history_list.dart';
import '../../widgets/incident_routes_layer.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/profile_edit_sheet.dart';
import '../../widgets/status_badge.dart';
import 'manual_dispatch_dialog.dart';
import 'new_incident_form.dart';

class DispatcherDashboard extends ConsumerStatefulWidget {
  const DispatcherDashboard({super.key});

  @override
  ConsumerState<DispatcherDashboard> createState() =>
      _DispatcherDashboardState();
}

class _DispatcherDashboardState extends ConsumerState<DispatcherDashboard>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
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
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final rows = await ProfileService().fetchDispatcherHistory();
      if (mounted) setState(() => _historyRows = rows);
    } catch (e) {
      if (mounted) setState(() => _historyError = e);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _flyToIncident(Incident incident) {
    if (incident.latitude != null && incident.longitude != null) {
      _mapController.move(
        LatLng(incident.latitude!, incident.longitude!),
        15,
      );
      ref.read(selectedIncidentIdProvider.notifier).state = incident.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(incidentsNotifierProvider);
    final ambulancesAsync = ref.watch(ambulancesNotifierProvider);
    final hospitalsAsync = ref.watch(hospitalsProvider);
    ref.watch(currentProfileProvider); // kept for auth guard
    final filter = ref.watch(incidentFilterProvider);

    // Filtered incident list
    final incidents = incidentsAsync.valueOrNull ?? [];
    final filtered = filter == 'all'
        ? incidents
        : incidents.where((i) => i.status.dbValue == filter).toList();

    final ambulances = ambulancesAsync.valueOrNull ?? [];
    final hospitals = hospitalsAsync.valueOrNull ?? [];

    return Scaffold(
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
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Live'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          if (isWide) {
            return Row(
              children: [
                SizedBox(
                  width: 400,
                  child: _IncidentPanel(
                    incidents: filtered,
                    allIncidents: incidents,
                    isLoading: incidentsAsync.isLoading,
                    filter: filter,
                    onFilterChanged: (f) =>
                        ref.read(incidentFilterProvider.notifier).state = f,
                    onIncidentTap: _flyToIncident,
                    onNewIncident: () => showNewIncidentForm(context),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _MapPanel(
                    mapController: _mapController,
                    incidents: incidents,
                    ambulances: ambulances,
                    hospitals: hospitals,
                    onIncidentMarkerTap: _flyToIncident,
                  ),
                ),
              ],
            );
          }

          // Narrow: tab layout
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.list_alt_outlined), text: 'Incidents'),
                    Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _IncidentPanel(
                        incidents: filtered,
                        allIncidents: incidents,
                        isLoading: incidentsAsync.isLoading,
                        filter: filter,
                        onFilterChanged: (f) =>
                            ref.read(incidentFilterProvider.notifier).state = f,
                        onIncidentTap: _flyToIncident,
                        onNewIncident: () => showNewIncidentForm(context),
                      ),
                      _MapPanel(
                        mapController: _mapController,
                        incidents: incidents,
                        ambulances: ambulances,
                        hospitals: hospitals,
                        onIncidentMarkerTap: _flyToIncident,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
          // History tab
          IncidentHistoryList(
            rows: _historyRows,
            isLoading: _historyLoading,
            error: _historyError,
            onRefresh: _loadHistory,
          ),
        ],
      ),
      // FAB only shown on narrow screens when on the Live tab
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => showNewIncidentForm(context),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_alert_outlined, color: Colors.white),
            label: const Text('New Incident',
                style: TextStyle(color: Colors.white)),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident Panel (left side / tab 1)
// ---------------------------------------------------------------------------

class _IncidentPanel extends StatelessWidget {
  final List<Incident> incidents;
  final List<Incident> allIncidents;
  final bool isLoading;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<Incident> onIncidentTap;
  final VoidCallback onNewIncident;

  const _IncidentPanel({
    required this.incidents,
    required this.allIncidents,
    required this.isLoading,
    required this.filter,
    required this.onFilterChanged,
    required this.onIncidentTap,
    required this.onNewIncident,
  });

  @override
  Widget build(BuildContext context) {
    final counts = _statusCounts(allIncidents);

    return Column(
      children: [
        // Summary stats bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _StatChip(
                label: 'Active',
                count: allIncidents.length,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Logged',
                count: counts['logged'] ?? 0,
                color: AppColors.statusCompleted,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Dispatched',
                count: counts['dispatched'] ?? 0,
                color: AppColors.statusDispatched,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onNewIncident,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Filter chips
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: 'All',
                    value: 'all',
                    current: filter,
                    onTap: onFilterChanged),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Logged',
                    value: 'logged',
                    current: filter,
                    onTap: onFilterChanged),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Dispatched',
                    value: 'dispatched',
                    current: filter,
                    onTap: onFilterChanged),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'En Route',
                    value: 'en_route',
                    current: filter,
                    onTap: onFilterChanged),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Arrived',
                    value: 'arrived',
                    current: filter,
                    onTap: onFilterChanged),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Incident list
        Expanded(
          child: isLoading && incidents.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : incidents.isEmpty
                  ? _EmptyState(filter: filter)
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: incidents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _IncidentCard(
                        incident: incidents[i],
                        onTap: () => onIncidentTap(incidents[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Map<String, int> _statusCounts(List<Incident> list) {
    final map = <String, int>{};
    for (final i in list) {
      map[i.status.dbValue] = (map[i.status.dbValue] ?? 0) + 1;
    }
    return map;
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  const _FilterChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 56,
              color: AppColors.statusAvailable.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            filter == 'all'
                ? 'No active incidents'
                : 'No ${_label(filter).toLowerCase()} incidents',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _label(String s) => switch (s) {
        'logged' => 'Logged',
        'dispatched' => 'Dispatched',
        'en_route' => 'En Route',
        'arrived' => 'Arrived',
        _ => s,
      };
}

// ---------------------------------------------------------------------------
// Incident Card
// ---------------------------------------------------------------------------

class _IncidentCard extends ConsumerStatefulWidget {
  final Incident incident;
  final VoidCallback onTap;
  const _IncidentCard({required this.incident, required this.onTap});

  @override
  ConsumerState<_IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends ConsumerState<_IncidentCard> {
  bool _dispatching = false;
  String? _dispatchError;
  bool _noAmbulanceAvailable = false;

  Future<void> _dispatchNearest() async {
    setState(() {
      _dispatching = true;
      _dispatchError = null;
      _noAmbulanceAvailable = false;
    });
    try {
      await IncidentService().dispatchIncident(widget.incident.id);
      // Realtime subscription will refresh the card automatically.
    } on DispatchException catch (e) {
      setState(() {
        _dispatching = false;
        if (e.code == 'no_ambulance_available') {
          _noAmbulanceAvailable = true;
          _dispatchError = e.message;
        } else {
          _dispatchError = e.message;
        }
      });
    } catch (e) {
      setState(() {
        _dispatching = false;
        _dispatchError = 'Dispatch failed: ${e.toString()}';
      });
    }
  }

  Future<void> _openManualDispatch() async {
    final ambulances = ref.read(ambulancesNotifierProvider).valueOrNull ?? [];
    if (!mounted) return;
    final assigned = await showManualDispatchDialog(
      context,
      incident: widget.incident,
      ambulances: ambulances,
    );
    if (assigned && mounted) {
      setState(() {
        _dispatchError = null;
        _noAmbulanceAvailable = false;
        _dispatching = false;
      });
    }
  }

  void _showDetails(BuildContext context) {
    final ambulances = ref.read(ambulancesNotifierProvider).valueOrNull ?? [];
    final hospitals = ref.read(hospitalsProvider).valueOrNull ?? [];

    String? assignedPlate;
    if (widget.incident.assignedAmbulanceId != null) {
      final found = ambulances.where((a) => a.id == widget.incident.assignedAmbulanceId);
      if (found.isNotEmpty) assignedPlate = found.first.plateNumber;
    }
    String? hospitalName;
    if (widget.incident.assignedHospitalId != null) {
      final found = hospitals.where((h) => h.id == widget.incident.assignedHospitalId);
      if (found.isNotEmpty) hospitalName = found.first.name;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.incident.natureOfEmergency.isEmpty
                        ? 'Unknown Emergency'
                        : widget.incident.natureOfEmergency,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _PriorityOverride(incident: widget.incident),
                const SizedBox(width: 6),
                StatusBadge(status: widget.incident.status.dbValue),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            _DetailRow(Icons.person_outline, 'Reporter', widget.incident.reporterName),
            if (widget.incident.reporterPhone.isNotEmpty)
              _DetailRow(Icons.phone_outlined, 'Phone', widget.incident.reporterPhone),
            if (widget.incident.locationDescription.isNotEmpty)
              _DetailRow(Icons.place_outlined, 'Location', widget.incident.locationDescription),
            if (widget.incident.patientConditionNotes.isNotEmpty)
              _DetailRow(Icons.medical_information_outlined, 'Patient Condition', widget.incident.patientConditionNotes),
            if (hospitalName != null)
              _DetailRow(Icons.local_hospital_outlined, 'Assigned Hospital', hospitalName),
            if (assignedPlate != null)
              _DetailRow(Icons.airport_shuttle_outlined, 'Ambulance', assignedPlate),
            const Divider(),
            _DetailRow(Icons.access_time, 'Logged', _formatTime(widget.incident.createdAt)),
            if (widget.incident.dispatchedAt != null)
              _DetailRow(Icons.send_outlined, 'Dispatched', _formatTime(widget.incident.dispatchedAt!)),
            if (widget.incident.arrivedAt != null)
              _DetailRow(Icons.location_on_outlined, 'Arrived', _formatTime(widget.incident.arrivedAt!)),
            if (widget.incident.completedAt != null)
              _DetailRow(Icons.check_circle_outline, 'Completed', _formatTime(widget.incident.completedAt!)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedIncidentIdProvider);
    final isSelected = selectedId == widget.incident.id;
    final ambulances = ref.watch(ambulancesNotifierProvider).valueOrNull ?? [];

    // Find assigned ambulance plate if available
    String? assignedPlate;
    if (widget.incident.assignedAmbulanceId != null) {
      final found = ambulances.where(
          (a) => a.id == widget.incident.assignedAmbulanceId);
      if (found.isNotEmpty) assignedPlate = found.first.plateNumber;
    }

    final isLogged = widget.incident.status == IncidentStatus.logged;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: status badge + time + chat + info ──
                Builder(
                  builder: (ctx) {
                    final msgs = ref.watch(
                        messagesProvider(widget.incident.id));
                    final seen = ref.watch(
                            chatSeenProvider)[widget.incident.id] ??
                        0;
                    final unread =
                        ((msgs.valueOrNull?.length ?? 0) - seen)
                            .clamp(0, 99);
                    return Row(
                      children: [
                        PriorityBadge(
                            priority: widget.incident.priority.dbValue),
                        const SizedBox(width: 6),
                        StatusBadge(
                            status: widget.incident.status.dbValue),
                        const Spacer(),
                        Text(
                          _timeAgo(widget.incident.createdAt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => showChatSheet(
                              context, widget.incident.id),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: chatIconWithBadge(unread),
                          ),
                        ),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () => _showDetails(context),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.info_outline,
                                size: 18,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                // ── Nature of emergency ──
                Text(
                  widget.incident.natureOfEmergency.isEmpty
                      ? 'Unknown Emergency'
                      : widget.incident.natureOfEmergency,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.incident.locationDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.incident.locationDescription,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                // ── Caller info ──
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      widget.incident.reporterName.isEmpty
                          ? 'Unknown caller'
                          : widget.incident.reporterName,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint),
                    ),
                    if (widget.incident.reporterPhone.isNotEmpty) ...[
                      const Text('  ·  ',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textHint)),
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(
                        widget.incident.reporterPhone,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint),
                      ),
                    ],
                  ],
                ),
                // ── Show on map hint ──
                if (widget.incident.latitude != null) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.gps_fixed, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Tap to show on map',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                // ── Assigned ambulance (dispatched and beyond) ──
                if (assignedPlate != null) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.airport_shuttle,
                          size: 14, color: AppColors.statusDispatched),
                      const SizedBox(width: 6),
                      Text(
                        'Ambulance: $assignedPlate',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statusDispatched,
                        ),
                      ),
                    ],
                  ),
                ],
                // ── Dispatch section (logged incidents only) ──
                if (isLogged) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Error banner
                  if (_dispatchError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _dispatchError!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Dispatch button row
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _dispatching ? null : _dispatchNearest,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            backgroundColor: AppColors.statusDispatched,
                          ),
                          icon: _dispatching
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_outlined, size: 14),
                          label: Text(
                            _dispatching
                                ? 'Dispatching…'
                                : 'Dispatch Nearest',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      if (_noAmbulanceAvailable) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _dispatching ? null : _openManualDispatch,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            side: const BorderSide(
                                color: AppColors.statusDispatched),
                            foregroundColor: AppColors.statusDispatched,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('Manual',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
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

// ---------------------------------------------------------------------------
// Map Panel (right side / tab 2)
// ---------------------------------------------------------------------------

class _MapPanel extends StatelessWidget {
  final MapController mapController;
  final List<Incident> incidents;
  final List<Ambulance> ambulances;
  final List<Hospital> hospitals;
  final ValueChanged<Incident> onIncidentMarkerTap;

  const _MapPanel({
    required this.mapController,
    required this.incidents,
    required this.ambulances,
    required this.hospitals,
    required this.onIncidentMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: const MapOptions(
            initialCenter: LatLng(0.3476, 32.5825),
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.erams.erams',
            ),
            // Highlighted shortest route from each accepted ambulance to its
            // patient (drawn under the markers).
            IncidentRoutesLayer(
              incidents: incidents,
              ambulances: ambulances,
            ),
            // Hospital markers
            MarkerLayer(markers: _hospitalMarkers(hospitals)),
            // Ambulance markers
            MarkerLayer(markers: _ambulanceMarkers(ambulances)),
            // Incident markers
            MarkerLayer(
                markers: _incidentMarkers(incidents, onIncidentMarkerTap)),
          ],
        ),
        // Legend
        Positioned(
          top: 12,
          right: 12,
          child: _MapLegend(),
        ),
        // OSM attribution
        Positioned(
          bottom: 4,
          right: 8,
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(
                fontSize: 10,
                color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }

  List<Marker> _hospitalMarkers(List<Hospital> hospitals) {
    return hospitals
        .where((h) => h.latitude != null && h.longitude != null)
        .map(
          (h) => Marker(
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
          ),
        )
        .toList();
  }

  List<Marker> _ambulanceMarkers(List<Ambulance> ambulances) {
    return ambulances
        .where((a) => a.latitude != null && a.longitude != null)
        .map(
          (a) => Marker(
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
          ),
        )
        .toList();
  }

  List<Marker> _incidentMarkers(
      List<Incident> incidents, ValueChanged<Incident> onTap) {
    return incidents
        .where((i) => i.latitude != null && i.longitude != null)
        .map(
          (i) => Marker(
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
                    Container(
                      width: 2,
                      height: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();
  }
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
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
          _LegendItem(color: AppColors.primary, icon: Icons.warning_amber_rounded, label: 'Incident'),
          SizedBox(height: 6),
          _LegendItem(color: AppColors.secondary, icon: Icons.local_hospital, label: 'Hospital'),
          SizedBox(height: 6),
          _LegendItem(color: AppColors.statusAvailable, icon: Icons.airport_shuttle, label: 'Available'),
          SizedBox(height: 6),
          _LegendItem(color: AppColors.statusDispatched, icon: Icons.airport_shuttle, label: 'Dispatched'),
          SizedBox(height: 6),
          _LegendItem(color: AppColors.statusEnRoute, icon: Icons.airport_shuttle, label: 'En Route'),
          SizedBox(height: 6),
          _LegendItem(color: AppColors.statusEnRoute, icon: Icons.route, label: 'Route to patient'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendItem(
      {required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// Tappable priority badge inside the incident detail bottom sheet — lets a
// dispatcher upgrade/downgrade the auto-derived priority. Patients get no
// equivalent control; only dispatcher/admin sessions render this widget.
class _PriorityOverride extends StatefulWidget {
  final Incident incident;
  const _PriorityOverride({required this.incident});

  @override
  State<_PriorityOverride> createState() => _PriorityOverrideState();
}

class _PriorityOverrideState extends State<_PriorityOverride> {
  bool _updating = false;

  Future<void> _setPriority(IncidentPriority priority) async {
    if (priority == widget.incident.priority) return;
    setState(() => _updating = true);
    try {
      await IncidentService()
          .updateIncidentPriority(widget.incident.id, priority.dbValue);
      // Realtime subscription will refresh the card automatically.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update priority: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<IncidentPriority>(
      enabled: !_updating,
      onSelected: _setPriority,
      itemBuilder: (_) => IncidentPriority.values
          .map((p) => PopupMenuItem(value: p, child: Text(p.label)))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PriorityBadge(priority: widget.incident.priority.dbValue),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// A labelled row used inside the incident detail bottom sheet.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
