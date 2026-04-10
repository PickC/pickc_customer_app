import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/home_provider.dart';

// ── Public API ───────────────────────────────────────────────────────────────

/// Shows the delivery receiver's mobile number bottom sheet.
/// Returns true if the user pressed OK, false/null if dismissed.
Future<bool> showReceiverMobileSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ReceiverMobileSheet(),
  );
  return result == true;
}

// ── Sheet widget ─────────────────────────────────────────────────────────────

class _ReceiverMobileSheet extends ConsumerStatefulWidget {
  const _ReceiverMobileSheet();

  @override
  ConsumerState<_ReceiverMobileSheet> createState() =>
      _ReceiverMobileSheetState();
}

class _ReceiverMobileSheetState
    extends ConsumerState<_ReceiverMobileSheet> {
  final _mobileCtrl = TextEditingController();
  bool _useOwn = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(receiverMobileProvider);
    if (existing != null) _mobileCtrl.text = existing;
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  void _toggleUseOwn(bool val) {
    setState(() => _useOwn = val);
    if (val) {
      final own = ref.read(customerMobileProvider) ?? '';
      _mobileCtrl.text = own;
    } else {
      _mobileCtrl.clear();
    }
  }

  void _onOk() {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number')),
      );
      return;
    }
    ref.read(receiverMobileProvider.notifier).state = mobile;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
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
              const Icon(Icons.person_pin_outlined,
                  color: AppColors.accentYellow, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delivery Receiver\'s Mobile',
                  style: AppTextStyles.titleLarge,
                ),
              ),
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
            'Enter the mobile number of the person receiving the delivery.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),

          // Mobile number input
          TextField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: AppTextStyles.bodyMedium,
            enabled: !_useOwn,
            decoration: InputDecoration(
              hintText: '9xxxxxxxxx',
              hintStyle: AppTextStyles.hintText,
              counterText: '',
              filled: true,
              fillColor: AppColors.backgroundDark,
              prefixIcon: const Icon(Icons.phone_android_outlined,
                  color: AppColors.textHint, size: 20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.textHint.withValues(alpha: 0.4)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.textHint.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.accentYellow, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Use registered number toggle
          GestureDetector(
            onTap: () => _toggleUseOwn(!_useOwn),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _useOwn
                    ? AppColors.accentYellow.withValues(alpha: 0.12)
                    : AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _useOwn
                      ? AppColors.accentYellow
                      : AppColors.textHint.withValues(alpha: 0.35),
                  width: _useOwn ? 1.5 : 0.8,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _useOwn
                          ? AppColors.accentYellow
                          : Colors.transparent,
                      border: Border.all(
                        color: _useOwn
                            ? AppColors.accentYellow
                            : AppColors.textHint,
                        width: 1.5,
                      ),
                    ),
                    child: _useOwn
                        ? const Icon(Icons.check,
                            size: 12, color: AppColors.backgroundDark)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Use my registered mobile number',
                    style: TextStyle(
                      color: _useOwn
                          ? AppColors.accentYellow
                          : AppColors.textLight,
                      fontSize: 13,
                      fontWeight: _useOwn
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // OK button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _onOk,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentYellow,
                foregroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text('OK', style: AppTextStyles.labelButton),
            ),
          ),
        ],
      ),
    );
  }
}
