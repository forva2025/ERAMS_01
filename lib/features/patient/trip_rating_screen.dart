import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/patient_service.dart';
import '../../state/patient_provider.dart';

class TripRatingScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String ambulancePlate;
  final String driverName;

  const TripRatingScreen({
    super.key,
    required this.tripId,
    required this.ambulancePlate,
    required this.driverName,
  });

  @override
  ConsumerState<TripRatingScreen> createState() => _TripRatingScreenState();
}

class _TripRatingScreenState extends ConsumerState<TripRatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    try {
      await PatientService().submitRating(
        widget.tripId,
        _rating,
        _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (mounted) {
        ref.invalidate(patientActiveIncidentProvider);
        context.go('/patient');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit rating: $e')),
        );
        setState(() => _submitting = false);
      }
    }
  }

  void _skip() {
    ref.invalidate(patientActiveIncidentProvider);
    context.go('/patient');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.star_rate_rounded,
                size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'How was your experience?',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (widget.ambulancePlate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.driverName.isNotEmpty
                    ? '${widget.ambulancePlate} · ${widget.driverName}'
                    : widget.ambulancePlate,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 32),
            // Interactive 5-star row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final value = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = value),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      _rating >= value
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 52,
                      color: _rating >= value
                          ? Colors.amber
                          : AppColors.textHint,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Text(
              _label(_rating),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _rating > 0
                    ? Colors.amber.shade700
                    : AppColors.textHint,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Leave a comment (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    (_rating == 0 || _submitting) ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Submit Rating',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _skip,
                child: const Text('Skip',
                    style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(int rating) => switch (rating) {
        1 => 'Poor',
        2 => 'Fair',
        3 => 'Good',
        4 => 'Very Good',
        5 => 'Excellent!',
        _ => 'Tap a star to rate',
      };
}
