import 'dart:async';

import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../constants/api_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result model
// ─────────────────────────────────────────────────────────────────────────────

class RazorpayResult {
  final bool isSuccess;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final int? errorCode;

  const RazorpayResult._({
    required this.isSuccess,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
    this.errorCode,
  });

  factory RazorpayResult.success({
    required String paymentId,
    required String orderId,
    required String signature,
  }) =>
      RazorpayResult._(
        isSuccess: true,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      );

  factory RazorpayResult.failure({
    required String message,
    int? code,
  }) =>
      RazorpayResult._(
        isSuccess: false,
        errorMessage: message,
        errorCode: code,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps the Razorpay SDK so callers can await a result like a Future.
///
/// Usage:
/// ```dart
/// final svc = RazorpayService();
/// final result = await svc.openCheckout(
///   amountPaise: 27700,   // ₹277.00
///   bookingNo: 'BK001',
///   customerName: 'Raju',
///   customerMobile: '9876543210',
/// );
/// svc.dispose();
/// ```
class RazorpayService {
  late final Razorpay _razorpay;
  Completer<RazorpayResult>? _completer;

  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  // ── SDK callbacks ──────────────────────────────────────────────────────────

  void _onSuccess(PaymentSuccessResponse r) {
    _completer?.complete(RazorpayResult.success(
      paymentId: r.paymentId ?? '',
      orderId: r.orderId ?? '',
      signature: r.signature ?? '',
    ));
    _completer = null;
  }

  void _onError(PaymentFailureResponse r) {
    _completer?.complete(RazorpayResult.failure(
      message: r.message ?? 'Payment failed',
      code: r.code,
    ));
    _completer = null;
  }

  void _onWallet(ExternalWalletResponse r) {
    _completer?.complete(RazorpayResult.failure(
      message: 'External wallet: ${r.walletName}',
    ));
    _completer = null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Opens the Razorpay checkout sheet and returns the result.
  /// [amountPaise] — amount in **paise** (₹1 = 100 paise).
  Future<RazorpayResult> openCheckout({
    required int amountPaise,
    required String bookingNo,
    required String customerName,
    required String customerMobile,
    String customerEmail = '',
    String? razorpayOrderId,
  }) {
    _completer = Completer<RazorpayResult>();

    final options = <String, dynamic>{
      'key': ApiConstants.razorpayKeyId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': 'Pick-C Logistics',
      'description': 'Trip Payment — $bookingNo',
      'prefill': {
        'contact': customerMobile,
        'email': customerEmail.isNotEmpty
            ? customerEmail
            : '$customerMobile@pickc.in',
        'name': customerName,
      },
      'notes': {'booking_no': bookingNo},
      'theme': {'color': '#F8F206'},
      'retry': {'enabled': true, 'max_count': 3},
    };

    if (razorpayOrderId != null && razorpayOrderId.isNotEmpty) {
      options['order_id'] = razorpayOrderId;
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      _completer!.complete(RazorpayResult.failure(message: e.toString()));
      _completer = null;
    }

    return _completer!.future;
  }

  /// Verifies the payment signature on your backend after a successful checkout.
  /// Call this before marking the booking as paid.
  Future<bool> verifyPayment({
    required Dio dio,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    required String bookingNo,
  }) async {
    try {
      final response = await dio.post(
        ApiConstants.razorpayVerifyPayment,
        data: {
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
          'booking_no': bookingNo,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _razorpay.clear();
}
