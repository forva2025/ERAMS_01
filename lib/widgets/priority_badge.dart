import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Coloured pill badge for incident priority strings. Carries a small flag
/// icon so it isn't confused with [StatusBadge] on a crowded card.
class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forPriority(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            _label(priority),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _label(String p) => switch (p) {
        'critical' => 'CRITICAL',
        'high'     => 'HIGH',
        'medium'   => 'MEDIUM',
        'low'      => 'LOW',
        _          => p.toUpperCase(),
      };
}
