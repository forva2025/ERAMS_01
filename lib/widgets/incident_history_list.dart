import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/error_messages.dart';
import 'status_badge.dart';

/// Reusable past-incident list shown in the History tab of each role.
/// [rows] is the raw Supabase JSON from profile_service.dart history queries.
class IncidentHistoryList extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRefresh;

  const IncidentHistoryList({
    super.key,
    required this.rows,
    required this.isLoading,
    this.error,
    required this.onRefresh,
  });

  @override
  State<IncidentHistoryList> createState() => _IncidentHistoryListState();
}

class _IncidentHistoryListState extends State<IncidentHistoryList> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(friendlyErrorMessage(widget.error!),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _search.isEmpty
        ? widget.rows
        : widget.rows.where((r) {
            final nature =
                (r['nature_of_emergency'] as String? ?? '').toLowerCase();
            final loc =
                (r['location_description'] as String? ?? '').toLowerCase();
            final q = _search.toLowerCase();
            return nature.contains(q) || loc.contains(q);
          }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by emergency type or location…',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtered.length} incident${filtered.length == 1 ? '' : 's'} (last 30 days)',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history,
                          size: 56, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(
                        _search.isEmpty
                            ? 'No past incidents in the last 30 days.'
                            : 'No results for "$_search".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _HistoryCard(row: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _HistoryCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final nature = row['nature_of_emergency'] as String? ?? '—';
    final location = row['location_description'] as String? ?? '—';
    final status = row['status'] as String? ?? 'completed';
    final hospitalName =
        (row['hospitals'] as Map<String, dynamic>?)?['name'] as String?;
    final createdAt = row['created_at'] != null
        ? DateTime.parse(row['created_at'] as String).toLocal()
        : null;
    final completedAt = row['completed_at'] != null
        ? DateTime.parse(row['completed_at'] as String).toLocal()
        : null;

    Duration? responseTime;
    if (createdAt != null && completedAt != null) {
      responseTime = completedAt.difference(createdAt);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nature,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (hospitalName != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.local_hospital_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    hospitalName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (createdAt != null)
                  Expanded(
                    child: _MetaChip(
                      icon: Icons.schedule,
                      label: _formatDateTime(createdAt),
                    ),
                  ),
                if (responseTime != null)
                  _MetaChip(
                    icon: Icons.timer_outlined,
                    label: _formatDuration(responseTime),
                    color: AppColors.success,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}  $h:$m';
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    if (mins < 60) return '${mins}m response';
    return '${d.inHours}h ${mins % 60}m response';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
