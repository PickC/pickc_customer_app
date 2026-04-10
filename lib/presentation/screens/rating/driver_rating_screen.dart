import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';
import '../../providers/providers.dart';
import '../widgets/pickc_button.dart';

class DriverRatingScreen extends ConsumerStatefulWidget {
  const DriverRatingScreen({super.key});

  @override
  ConsumerState<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends ConsumerState<DriverRatingScreen> {
  double _rating = 0;
  final Set<String> _selectedFeedback = {};
  bool _isLoading = false;

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final localStorage = ref.read(localStorageProvider);
      final dio = ref.read(dioClientProvider).dio;
      await dio.post(ApiConstants.userRatingDriver, data: {
        'driverId': localStorage.getDriverId(),
        'bookingNo': localStorage.getBookingNo(),
        'rating': _rating,
        'feedback': _selectedFeedback.toList(),
      });
    } catch (_) {
      // Non-fatal — proceed to home regardless
    }
    if (mounted) {
      setState(() => _isLoading = false);
      ref.read(homeNotifierProvider.notifier).resetAfterPayment();
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Rate Your Driver'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const CircleAvatar(
              backgroundColor: AppColors.appBlue,
              radius: 48,
              child: Icon(Icons.person, color: AppColors.textLight, size: 56),
            ),
            const SizedBox(height: 16),
            Text('How was your experience?', style: AppTextStyles.titleLarge),
            const SizedBox(height: 24),

            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: AppColors.accentYellow,
              ),
              unratedColor: AppColors.ratingNormal,
              onRatingUpdate: (r) => setState(() => _rating = r),
            ),

            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Feedback (optional)', style: AppTextStyles.titleMedium),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.driverFeedbackOptions.map((f) {
                final isSelected = _selectedFeedback.contains(f);
                return FilterChip(
                  label: Text(f, style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? AppColors.backgroundDark : AppColors.textLight,
                  )),
                  selected: isSelected,
                  selectedColor: AppColors.accentYellow,
                  backgroundColor: AppColors.backgroundDark,
                  side: BorderSide(
                    color: isSelected ? AppColors.accentYellow : AppColors.textHint,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedFeedback.add(f);
                      } else {
                        _selectedFeedback.remove(f);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            PickcButton(
              label: 'SUBMIT RATING',
              isLoading: _isLoading,
              onPressed: _submitRating,
            ),
          ],
        ),
      ),
    );
  }
}
