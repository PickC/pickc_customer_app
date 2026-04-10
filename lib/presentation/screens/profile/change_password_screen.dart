import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../widgets/pickc_button.dart';
import '../widgets/pickc_text_field.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'),
            backgroundColor: AppColors.statusCancelled),
      );
      return;
    }

    setState(() => _isLoading = true);
    // TODO: Call changePassword API via AuthRemoteDatasource
    // final mobile = ref.read(localStorageProvider).getMobileNo() ?? '';
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              PickcTextField(
                controller: _currentPasswordCtrl,
                label: 'Current Password',
                hint: 'Enter current password',
                obscureText: true,
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 16),
              PickcTextField(
                controller: _newPasswordCtrl,
                label: 'New Password',
                hint: 'Enter new password',
                obscureText: true,
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 16),
              PickcTextField(
                controller: _confirmPasswordCtrl,
                label: 'Confirm New Password',
                hint: 'Re-enter new password',
                obscureText: true,
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 32),
              PickcButton(
                label: 'CHANGE PASSWORD',
                isLoading: _isLoading,
                onPressed: _onChangePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
