import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Coloured pill badge for incident or ambulance status strings.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _label(String s) => switch (s) {
        'logged'             => 'LOGGED',
        'pending_acceptance' => 'PENDING',
        'dispatched'         => 'DISPATCHED',
        'en_route'           => 'EN ROUTE',
        'arrived'            => 'ARRIVED',
        'completed'          => 'COMPLETED',
        'cancelled'          => 'CANCELLED',
        'available'          => 'AVAILABLE',
        'busy'               => 'BUSY',
        'offline'            => 'OFFLINE',
        _                    => s.toUpperCase(),
      };
}
