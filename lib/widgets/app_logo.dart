import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Placeholder logo — replace inner content once the real logo asset is added.
/// Usage: AppLogo(size: 80)
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.local_hospital_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

/// Compact horizontal logo + wordmark for app bars and headers.
class AppLogoHorizontal extends StatelessWidget {
  final double iconSize;
  const AppLogoHorizontal({super.key, this.iconSize = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.local_hospital_rounded, color: Colors.white, size: iconSize * 0.6),
        ),
        const SizedBox(width: 8),
        const Text(
          'ERAMS',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
