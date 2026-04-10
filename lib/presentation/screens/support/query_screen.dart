import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/providers.dart';
import '../widgets/pickc_button.dart';
import '../widgets/pickc_text_field.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class QueryScreen extends ConsumerStatefulWidget {
  const QueryScreen({super.key});

  @override
  ConsumerState<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends ConsumerState<QueryScreen> {
  final _queryCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitQuery() async {
    if (_queryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your query')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final dio = ref.read(dioClientProvider).dio;
    final mobile = ref.read(localStorageProvider).getMobileNo() ?? '';

    // TODO: POST master/customer/sendMessageToPickC
    try {
      await dio.post(ApiConstants.sendQuery, data: {
        'mobile': mobile,
        'message': _queryCtrl.text.trim(),
      });
      if (mounted) {
        _queryCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your query has been sent to Pick-C support.')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to send query'),
            backgroundColor: AppColors.statusCancelled,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Send Query'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Have a question or concern?', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Send us a message and our support team will get back to you.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: 24),
            PickcTextField(
              controller: _queryCtrl,
              label: 'Your Query',
              hint: 'Type your message here...',
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            PickcButton(
              label: 'SEND QUERY',
              isLoading: _isLoading,
              onPressed: _submitQuery,
            ),
          ],
        ),
      ),
    );
  }
}
