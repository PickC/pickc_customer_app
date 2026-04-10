import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/pickc_button.dart';

/// Combines ReferralActivity + AddFriendActivity + AboutReferralActivity
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _friendMobileCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendMobileCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Refer & Earn'),
        backgroundColor: AppColors.backgroundDark,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentYellow,
          tabs: const [
            Tab(text: 'My Referral'),
            Tab(text: 'Add Friend'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Referral tab
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.people, color: AppColors.accentYellow, size: 64),
                const SizedBox(height: 16),
                Text('Your Referral Code', style: AppTextStyles.titleLarge),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accentYellow),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TODO: Load actual referral code from API
                      Text('PICKC123', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accentYellow)),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.copy, color: AppColors.textHint),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: 'PICKC123'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Referral code copied!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Share your referral code and earn rewards when your friends book their first truck!',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Add Friend tab
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Friend's Mobile Number", style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _friendMobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Enter 10-digit mobile number',
                    hintStyle: AppTextStyles.hintText,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.textHint),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.textHint),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.accentYellow, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // TODO: Call add friend referral API
                PickcButton(label: 'SEND INVITE', onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
