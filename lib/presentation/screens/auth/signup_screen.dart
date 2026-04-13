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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;
    final mobile = _mobileCtrl.text.trim();
    final notifier = ref.read(authNotifierProvider.notifier);

    // Step 1 — check if mobile is already registered
    final isNew = await notifier.checkNewNumber(mobile: mobile);
    if (!mounted) return;
    if (!isNew) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile already registered. Please login.'),
          backgroundColor: AppColors.statusCancelled,
        ),
      );
      return;
    }

    // Step 2 — send OTP
    final sent = await notifier.sendOtp(mobile: mobile);
    if (!mounted) return;
    if (!sent) {
      final err = ref.read(authNotifierProvider).error?.toString() ?? 'Failed to send OTP';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.statusCancelled),
      );
      return;
    }

    context.push(RouteNames.otp, extra: {
      'mobile': mobile,
      'isForForgotPassword': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your mobile number', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Text(
                'We\'ll send an OTP to verify your number.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: 32),
              PickcTextField(
                controller: _mobileCtrl,
                label: 'Mobile Number',
                hint: 'Enter 10-digit mobile number',
                keyboardType: TextInputType.phone,
                validator: Validators.validateMobile,
                maxLength: 10,
              ),
              const SizedBox(height: 32),
              PickcButton(
                label: 'SEND OTP',
                isLoading: isLoading,
                onPressed: _onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
