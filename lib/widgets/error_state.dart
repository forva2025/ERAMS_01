import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/error_messages.dart';

/// Full-block error state: icon + friendly message + Retry button.
///
/// Use this in place of a raw `Text('Error: $e')` inside an
/// `AsyncValue.when(error: ...)` branch so a dropped connection or backend
/// hiccup reads as a normal, recoverable app state — not a crash dump.
class ErrorRetryView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorRetryView({
    super.key,
    required this.error,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline variant for small contexts (a form dropdown, a bottom
/// sheet field) where a full centered block would look out of place.
class InlineErrorRow extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const InlineErrorRow({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 16, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            friendlyErrorMessage(error),
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Retry'),
          ),
      ],
    );
  }
}
