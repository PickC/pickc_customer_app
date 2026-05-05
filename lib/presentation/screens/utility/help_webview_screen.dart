import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class HelpWebviewScreen extends StatefulWidget {
  const HelpWebviewScreen({super.key});

  @override
  State<HelpWebviewScreen> createState() => _HelpWebviewScreenState();
}

class _HelpWebviewScreenState extends State<HelpWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          // Inject responsive viewport meta tag so page scales to mobile width
          _controller.runJavaScript(
            "var meta = document.querySelector('meta[name=viewport]');"
            "if (!meta) {"
            "  meta = document.createElement('meta');"
            "  meta.name = 'viewport';"
            "  document.head.appendChild(meta);"
            "}"
            "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0';",
          );
          setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(AppConstants.helpUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Help'),
        foregroundColor: AppColors.accentYellow,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.accentYellow),
            ),
        ],
      ),
    );
  }
}
