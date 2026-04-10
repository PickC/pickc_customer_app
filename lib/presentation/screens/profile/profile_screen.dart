import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../widgets/pickc_button.dart';
import '../widgets/pickc_text_field.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final ls = ref.read(localStorageProvider);
    _nameCtrl.text = ls.getName() ?? '';
    _emailCtrl.text = ls.getEmail() ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = ref.read(localStorageProvider).getMobileNo() ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.backgroundDark,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit,
                color: AppColors.accentYellow),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            const CircleAvatar(
              backgroundColor: AppColors.appBlue,
              radius: 48,
              child: Icon(Icons.person, color: AppColors.textLight, size: 56),
            ),
            const SizedBox(height: 24),

            // Mobile (read-only)
            PickcTextField(
              controller: TextEditingController(text: mobile),
              label: 'Mobile Number',
              hint: 'Mobile',
              enabled: false,
            ),
            const SizedBox(height: 16),

            // Name
            PickcTextField(
              controller: _nameCtrl,
              label: 'Full Name',
              hint: 'Enter name',
              enabled: _isEditing,
            ),
            const SizedBox(height: 16),

            // Email
            PickcTextField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'Enter email',
              keyboardType: TextInputType.emailAddress,
              enabled: _isEditing,
            ),
            const SizedBox(height: 32),

            if (_isEditing)
              PickcButton(
                label: 'SAVE CHANGES',
                onPressed: () async {
                  // TODO: Call updateUserData API
                  final ls = ref.read(localStorageProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  await ls.setName(_nameCtrl.text.trim());
                  await ls.setEmail(_emailCtrl.text.trim());
                  if (mounted) {
                    setState(() => _isEditing = false);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Profile updated')),
                    );
                  }
                },
              ),

            const SizedBox(height: 16),
            PickcButton(
              label: 'CHANGE PASSWORD',
              onPressed: () => context.push(RouteNames.changePassword),
            ),
          ],
        ),
      ),
    );
  }
}
