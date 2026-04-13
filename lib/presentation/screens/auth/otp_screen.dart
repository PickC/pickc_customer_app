import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../widgets/pickc_button.dart';
import '../widgets/pickc_text_field.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String mobile;
  final bool isForForgotPassword;

  const OtpScreen({
    super.key,
    required this.mobile,
    required this.isForForgotPassword,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authNotifierProvider.notifier);

    final verified = await notifier.verifyOtp(
      mobile: widget.mobile,
      otp: _otpCtrl.text.trim(),
    );
    if (!mounted) return;

    if (!verified) {
      final err = ref.read(authNotifierProvider).error?.toString() ?? 'Invalid OTP. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.statusCancelled),
      );
      return;
    }

    if (widget.isForForgotPassword) {
      context.go(RouteNames.forgotPassword);
    } else {
      // Step 3 passed — go to registration form
      context.push(RouteNames.registrationForm, extra: {'mobile': widget.mobile});
    }
  }

  Future<void> _onResend() async {
    await ref.read(authNotifierProvider.notifier).sendOtp(mobile: widget.mobile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Enter the OTP sent to', style: AppTextStyles.bodyMedium),
              Text(
                '+91 ${widget.mobile}',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.accentYellow),
              ),
              const SizedBox(height: 32),
              PickcTextField(
                controller: _otpCtrl,
                label: 'OTP',
                hint: 'Enter 6-digit OTP',
                keyboardType: TextInputType.number,
                validator: Validators.validateOtp,
                maxLength: 6,
              ),
              const SizedBox(height: 24),
              PickcButton(
                label: 'VERIFY',
                isLoading: isLoading,
                onPressed: _onVerify,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _onResend,
                  child: Text(
                    'Resend OTP',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accentYellow),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
