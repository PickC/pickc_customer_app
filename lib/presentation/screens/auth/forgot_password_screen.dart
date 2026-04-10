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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _mobileCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.generateOtp(mobile: _mobileCtrl.text.trim());
    if (!mounted) return;
    context.push(RouteNames.otp, extra: {
      'mobile': _mobileCtrl.text.trim(),
      'isForForgotPassword': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Forgot Password'),
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
              Text(
                'Enter your registered mobile number. We will send you an OTP to reset your password.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
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
                onPressed: _onSendOtp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
