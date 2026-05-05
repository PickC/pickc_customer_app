import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // true when there is no network — drives the persistent bottom card
  bool _noInternet = false;

  // transient API / validation error — auto-dismisses after 4 s
  String? _errorMessage;
  Timer? _errorTimer;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _mobileCtrl.text = '8074127034';
      _passwordCtrl.text = 'Pickc@1234';
    }
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _noInternet = !_hasConnection(initial));

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final online = _hasConnection(result);
      setState(() {
        _noInternet = !online;
        // Clear any lingering "no internet" API error when connection returns
        if (online && _errorMessage != null &&
            _errorMessage!.contains('internet')) {
          _errorMessage = null;
          _errorTimer?.cancel();
        }
      });
    });
  }

  bool _hasConnection(List<ConnectivityResult> result) =>
      result.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _errorTimer?.cancel();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    setState(() => _errorMessage = message);
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  Future<void> _onLogin() async {
    if (_noInternet) {
      _showError('No internet connection. Please check your network and try again.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.login(
      mobile: _mobileCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    final state = ref.read(authNotifierProvider);
    state.whenOrNull(
      data: (user) {
        if (user != null) context.go(RouteNames.home);
      },
      error: (e, _) => _showError(e.toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    // The card to show at the bottom — no-internet takes priority over API errors
    final String? bottomMessage = _noInternet
        ? 'No internet connection. Please check your Wi-Fi or mobile data.'
        : _errorMessage;
    final bool isNetworkCard = _noInternet;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Welcome Back', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Login to your Pick-C account',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 40),

                // Mobile number
                PickcTextField(
                  controller: _mobileCtrl,
                  label: 'Mobile Number',
                  hint: 'Enter 10-digit mobile number',
                  keyboardType: TextInputType.phone,
                  validator: Validators.validateMobile,
                  maxLength: 10,
                ),
                const SizedBox(height: 16),

                // Password
                PickcTextField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  hint: 'Enter password',
                  obscureText: _obscurePassword,
                  validator: Validators.validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(RouteNames.forgotPassword),
                    child: Text(
                      'Forgot Password?',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accentYellow,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Login button
                PickcButton(
                  label: 'LOGIN',
                  isLoading: isLoading,
                  onPressed: _onLogin,
                ),
                const SizedBox(height: 24),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTextStyles.bodyMedium,
                    ),
                    GestureDetector(
                      onTap: () => context.push(RouteNames.signup),
                      child: Text(
                        'Sign Up',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.accentYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Bottom notification card ───────────────────────────────
                // Shows no-internet (persistent) or API error (auto-dismiss)
                if (bottomMessage != null) ...[
                  const SizedBox(height: 24),
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isNetworkCard
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFF3A0000),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isNetworkCard
                              ? AppColors.textHint.withValues(alpha: 0.5)
                              : AppColors.statusCancelled
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isNetworkCard
                                ? Icons.wifi_off_rounded
                                : Icons.error_outline,
                            color: isNetworkCard
                                ? AppColors.textHint
                                : AppColors.statusCancelled,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bottomMessage,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isNetworkCard
                                    ? AppColors.textLight
                                    : const Color(0xFFFF6B6B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Only show close button for API errors;
                          // network card dismisses automatically when back online
                          if (!isNetworkCard)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _errorMessage = null),
                              child: const Icon(Icons.close,
                                  color: AppColors.statusCancelled, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
