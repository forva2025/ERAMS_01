import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand — ambulance red
  static const Color primary = Color(0xFFC62828);
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFFFDAD6);

  // Secondary — professional deep blue
  static const Color secondary = Color(0xFF1565C0);
  static const Color onSecondary = Colors.white;

  // Surfaces
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);

  // Ambulance / incident status colours — used for badges and map markers
  static const Color statusAvailable = Color(0xFF2E7D32);   // green
  static const Color statusPending = Color(0xFFF57F17);     // amber — awaiting driver acceptance
  static const Color statusDispatched = Color(0xFFE65100);  // deep orange
  static const Color statusEnRoute = Color(0xFF1565C0);     // blue
  static const Color statusArrived = Color(0xFF6A1B9A);     // purple
  static const Color statusCompleted = Color(0xFF00695C);   // teal
  static const Color statusCancelled = Color(0xFF757575);   // grey
  static const Color statusBusy = Color(0xFFC62828);        // red
  static const Color statusOffline = Color(0xFF424242);     // dark grey

  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Utility
  static const Color error = Color(0xFFB00020);
  static const Color errorSurface = Color(0xFFFFF0F0);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);

  // Incident priority colours — used for the priority badge
  static const Color priorityCritical = Color(0xFFB00020); // red
  static const Color priorityHigh = Color(0xFFE65100);     // deep orange
  static const Color priorityMedium = Color(0xFFF57F17);   // amber
  static const Color priorityLow = Color(0xFF757575);      // grey

  /// Returns the colour for a given ambulance or incident status string.
  static Color forStatus(String status) => switch (status) {
    'available'          => statusAvailable,
    'pending_acceptance' => statusPending,
    'dispatched'         => statusDispatched,
    'en_route'           => statusEnRoute,
    'arrived'            => statusArrived,
    'completed' || 'logged' => statusCompleted,
    'cancelled'          => statusCancelled,
    'busy'               => statusBusy,
    'offline'            => statusOffline,
    _                    => statusOffline,
  };

  /// Returns the colour for a given incident priority string.
  static Color forPriority(String priority) => switch (priority) {
    'critical' => priorityCritical,
    'high'     => priorityHigh,
    'low'      => priorityLow,
    _          => priorityMedium,
  };
}
