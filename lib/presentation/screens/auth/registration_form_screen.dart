import 'package:device_info_plus/device_info_plus.dart';
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

class RegistrationFormScreen extends ConsumerStatefulWidget {
  final String mobile;

  const RegistrationFormScreen({super.key, required this.mobile});

  @override
  ConsumerState<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends ConsumerState<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<String> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      return android.id; // Android ID — unique per device
    } catch (_) {
      return 'unknown-device';
    }
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppColors.statusCancelled,
        ),
      );
      return;
    }

    final deviceId = await _getDeviceId();
    final notifier = ref.read(authNotifierProvider.notifier);

    final success = await notifier.registerCustomer(
      mobile: widget.mobile,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      deviceId: deviceId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please login.')),
      );
      context.go(RouteNames.login);
    } else {
      final err = ref.read(authNotifierProvider).error?.toString() ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.statusCancelled),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Complete Registration'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile: +91 ${widget.mobile}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                    ),
                    const SizedBox(height: 24),
                    PickcTextField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    PickcTextField(
                      controller: _emailCtrl,
                      label: 'Email (optional)',
                      hint: 'Enter email address',
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    PickcTextField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      hint: 'Create a password (max 15 chars)',
                      obscureText: _obscurePassword,
                      validator: Validators.validatePassword,
                      maxLength: 15,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PickcTextField(
                      controller: _confirmCtrl,
                      label: 'Confirm Password',
                      hint: 'Re-enter your password',
                      obscureText: _obscureConfirm,
                      validator: Validators.validatePassword,
                      maxLength: 15,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PickcButton(
              label: 'CREATE ACCOUNT',
              isLoading: isLoading,
              onPressed: _onRegister,
            ),
          ),
        ],
      ),
    );
  }
}
