import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';

// ── Public API ───────────────────────────────────────────────────────────────

/// Shows the Book Later date + time selector sheet.
/// Saves the chosen [DateTime] into [scheduledDateTimeProvider].
/// Returns true if confirmed, false/null if dismissed.
Future<bool> showBookLaterSheet(BuildContext context, WidgetRef ref) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProviderScope.containerOf(context, listen: false).let(
      (container) => UncontrolledProviderScope(
        container: container,
        child: const _BookLaterSheet(),
      ),
    ),
  );
  return result == true;
}

// ── Sheet widget ─────────────────────────────────────────────────────────────

class _BookLaterSheet extends ConsumerStatefulWidget {
  const _BookLaterSheet();

  @override
  ConsumerState<_BookLaterSheet> createState() => _BookLaterSheetState();
}

class _BookLaterSheetState extends ConsumerState<_BookLaterSheet> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final _dateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  void initState() {
    super.initState();
    final existing = ref.read(scheduledDateTimeProvider);
    if (existing != null) {
      _selectedDate = existing;
      _selectedTime = TimeOfDay.fromDateTime(existing);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => _themedPicker(ctx, child),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Widget _themedPicker(BuildContext ctx, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentYellow,
          onPrimary: AppColors.backgroundDark,
          surface: Color(0xFF222000),
          onSurface: AppColors.textLight,
        ),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      child: child!,
    );
  }

  void _onConfirm() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time')),
      );
      return;
    }
    final scheduled = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (scheduled.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please schedule at least 30 minutes ahead')),
      );
      return;
    }
    ref.read(scheduledDateTimeProvider.notifier).state = scheduled;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = _selectedDate != null;
    final hasTime = _selectedTime != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title row
          Row(
            children: [
              const Icon(Icons.schedule,
                  color: AppColors.accentYellow, size: 20),
              const SizedBox(width: 8),
              Text('Schedule Booking', style: AppTextStyles.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textHint, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a date and time for your truck pickup.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 20),

          // Date selector
          _SelectorTile(
            icon: Icons.calendar_month_outlined,
            label: 'Pickup Date',
            value: hasDate ? _dateFormat.format(_selectedDate!) : null,
            placeholder: 'Select date',
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),

          // Time selector
          _SelectorTile(
            icon: Icons.access_time_outlined,
            label: 'Pickup Time',
            value: hasTime ? _selectedTime!.format(context) : null,
            placeholder: 'Select time',
            onTap: _pickTime,
          ),
          const SizedBox(height: 20),

          // Scheduled summary chip
          if (hasDate && hasTime) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accentYellow.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.accentYellow, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scheduled: ${_dateFormat.format(_selectedDate!)} at ${_selectedTime!.format(context)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.accentYellow,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CONFIRM button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (hasDate && hasTime) ? _onConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.backgroundDark,
                disabledBackgroundColor:
                    AppColors.accentYellow.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text('CONFIRM SCHEDULE',
                  style: AppTextStyles.labelButton),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selector tile ────────────────────────────────────────────────────────────

class _SelectorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? AppColors.accentYellow
                : AppColors.textHint.withValues(alpha: 0.4),
            width: hasValue ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  hasValue ? AppColors.accentYellow : AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? placeholder,
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.textLight
                          : AppColors.textHint,
                      fontSize: 15,
                      fontWeight: hasValue
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Extension helper (avoids importing dart:core extras) ─────────────────────

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
