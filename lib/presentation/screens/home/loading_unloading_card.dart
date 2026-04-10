import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';

/// First card in the truck sheet — lets the customer choose whether
/// they need labour help for loading / unloading.
class LoadingUnloadingCard extends ConsumerWidget {
  const LoadingUnloadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(labourOptionProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentYellow.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: AppColors.accentYellow,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Do you need Labour?',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (selected != LabourOption.none)
                Text(
                  '+ charges apply',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accentYellow,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _OptionChip(
                label: 'None',
                icon: Icons.do_not_disturb_alt_outlined,
                isSelected: selected == LabourOption.none,
                onTap: () => ref
                    .read(labourOptionProvider.notifier)
                    .state = LabourOption.none,
              ),
              const SizedBox(width: 6),
              _OptionChip(
                label: 'Loading',
                icon: Icons.upload_outlined,
                isSelected: selected == LabourOption.loading,
                onTap: () => ref
                    .read(labourOptionProvider.notifier)
                    .state = LabourOption.loading,
              ),
              const SizedBox(width: 6),
              _OptionChip(
                label: 'Unloading',
                icon: Icons.download_outlined,
                isSelected: selected == LabourOption.unloading,
                onTap: () => ref
                    .read(labourOptionProvider.notifier)
                    .state = LabourOption.unloading,
              ),
              const SizedBox(width: 6),
              _OptionChip(
                label: 'Both',
                icon: Icons.swap_vert,
                isSelected: selected == LabourOption.both,
                onTap: () => ref
                    .read(labourOptionProvider.notifier)
                    .state = LabourOption.both,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentYellow
                : AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentYellow
                  : AppColors.textHint.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.backgroundDark
                    : AppColors.textHint,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.backgroundDark
                      : AppColors.textHint,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
