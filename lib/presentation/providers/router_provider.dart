import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/demo_mode.dart';
import '../../core/constants/route_names.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/otp_screen.dart';
import '../screens/auth/registration_form_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/booking/booking_history_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/payment/cash_payment_screen.dart';
import '../screens/payment/online_payment_screen.dart';
import '../screens/payment/payment_status_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/rating/driver_rating_screen.dart';
import '../screens/invoice/invoice_screen.dart';
import '../screens/support/query_screen.dart';
import '../screens/utility/help_webview_screen.dart';
import '../screens/utility/about_screen.dart';
import '../screens/utility/emergency_screen.dart';
import '../screens/utility/terms_screen.dart';
import '../screens/utility/rate_card_screen.dart';
import '../screens/utility/referral_screen.dart';
import '../screens/utility/zoom_image_screen.dart';
import '../screens/booking/trip_info_screen.dart';
import '../screens/payment/razorpay_payment_screen.dart';
import '../screens/tracking/driver_tracking_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    redirect: (context, state) async {
      if (kDemoMode) return null; // bypass auth guard in demo mode
      final token = await secureStorage.getAuthToken();
      final isLoggedIn = token != null && token.isNotEmpty;
      final isAuthRoute = state.matchedLocation == RouteNames.login ||
          state.matchedLocation == RouteNames.signup ||
          state.matchedLocation == RouteNames.splash ||
          state.matchedLocation == RouteNames.otp ||
          state.matchedLocation == RouteNames.registrationForm ||
          state.matchedLocation == RouteNames.forgotPassword;

      if (!isLoggedIn && !isAuthRoute) return RouteNames.login;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpScreen(
            mobile: extra?['mobile'] ?? '',
            isForForgotPassword: extra?['isForForgotPassword'] ?? false,
          );
        },
      ),
      GoRoute(
        path: RouteNames.registrationForm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RegistrationFormScreen(mobile: extra?['mobile'] ?? '');
        },
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.bookingHistory,
        builder: (context, state) => const BookingHistoryScreen(),
      ),
      GoRoute(
        path: RouteNames.payment,
        builder: (context, state) => const PaymentScreen(),
      ),
      GoRoute(
        path: RouteNames.cashPayment,
        builder: (context, state) => const CashPaymentScreen(),
      ),
      GoRoute(
        path: RouteNames.onlinePayment,
        builder: (context, state) => const OnlinePaymentScreen(),
      ),
      GoRoute(
        path: RouteNames.paymentStatus,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PaymentStatusScreen(
            isSuccess: extra?['isSuccess'] ?? false,
            paymentId: extra?['paymentId'],
            amount: extra?['amount'],
            bookingNo: extra?['bookingNo'],
            errorMessage: extra?['errorMessage'],
          );
        },
      ),
      GoRoute(
        path: RouteNames.razorpayPayment,
        builder: (context, state) {
          final extra = (state.extra as Map<String, dynamic>?) ?? {};
          return RazorpayPaymentScreen(paymentData: extra);
        },
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.driverRating,
        builder: (context, state) => const DriverRatingScreen(),
      ),
      GoRoute(
        path: RouteNames.invoice,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return InvoiceScreen(bookingNo: extra?['bookingNo'] ?? '');
        },
      ),
      GoRoute(
        path: RouteNames.query,
        builder: (context, state) => const QueryScreen(),
      ),
      GoRoute(
        path: RouteNames.helpWebview,
        builder: (context, state) => const HelpWebviewScreen(),
      ),
      GoRoute(
        path: RouteNames.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: RouteNames.emergency,
        builder: (context, state) => const EmergencyScreen(),
      ),
      GoRoute(
        path: RouteNames.terms,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: RouteNames.rateCard,
        builder: (context, state) => const RateCardScreen(),
      ),
      GoRoute(
        path: RouteNames.referral,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: RouteNames.zoomImage,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ZoomImageScreen(imageUrl: extra?['imageUrl'] ?? '');
        },
      ),
      GoRoute(
        path: RouteNames.tripInfo,
        builder: (context, state) {
          final extra = (state.extra as Map<String, dynamic>?) ?? {};
          return TripInfoScreen(tripData: extra);
        },
      ),
      GoRoute(
        path: RouteNames.driverTracking,
        builder: (context, state) {
          final extra = (state.extra as Map<String, dynamic>?) ?? {};
          final pickup = extra['pickupLatLng'] as LatLng? ??
              const LatLng(17.4486, 78.3908);
          final drop = extra['dropLatLng'] as LatLng? ??
              const LatLng(17.4486, 78.3908);
          return DriverTrackingScreen(
            tripId: extra['tripId'] as String? ?? '',
            pickupLatLng: pickup,
            dropLatLng: drop,
          );
        },
      ),
    ],
  );
});
