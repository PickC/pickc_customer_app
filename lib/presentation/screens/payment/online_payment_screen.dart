import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/rsa_utils.dart';
import '../../providers/providers.dart';

class OnlinePaymentScreen extends ConsumerStatefulWidget {
  const OnlinePaymentScreen({super.key});

  @override
  ConsumerState<OnlinePaymentScreen> createState() =>
      _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends ConsumerState<OnlinePaymentScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  Future<void> _initPayment() async {
    final dio = ref.read(dioClientProvider).dio;
    final localStorage = ref.read(localStorageProvider);
    final mobile = await ref.read(secureStorageProvider).getMobileNo() ?? '';

    try {
      // TODO: GET master/customer/getRSAKey → returns {rsaKey, amount, bookingNo, ...}
      final response = await dio.get(ApiConstants.onlinePayment);
      final data = response.data as Map<String, dynamic>;
      final rsaKey = data['rsaKey']?.toString() ?? '';
      final amount = data['amount']?.toString() ?? '0';
      final bookingNo = localStorage.getBookingNo() ?? '';

      // Encrypt payment params using RSA/PKCS1 (matches Android RSAUtility.java)
      final encryptedData = RsaUtils.encrypt(
        'amount=$amount&bookingNo=$bookingNo&mobile=$mobile',
        rsaKey,
      );

      if (encryptedData == null) return;

      // Load CCAvenue WebView
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            // Intercept success/cancel URLs
            if (request.url.contains('success') ||
                request.url.contains('SUCCESS')) {
              context.go(RouteNames.paymentStatus, extra: {'isSuccess': true});
              return NavigationDecision.prevent;
            }
            if (request.url.contains('cancel') ||
                request.url.contains('CANCEL') ||
                request.url.contains('failure')) {
              context.go(RouteNames.paymentStatus,
                  extra: {'isSuccess': false});
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ))
        ..loadRequest(
          Uri.parse(AppConstants.ccAvenueTransUrl),
          method: LoadRequestMethod.post,
          body: 'encRequest=$encryptedData'.codeUnits
              .map((e) => e)
              .toList()
              as dynamic,
        );

      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment init failed: $e'),
            backgroundColor: AppColors.statusCancelled,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Online Payment'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            const Center(child: CircularProgressIndicator()),
          if (_isLoading && _controller != null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
