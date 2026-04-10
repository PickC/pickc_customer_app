class ApiConstants {
  static const String baseUrl = 'https://pickcapi-atgcb7d4afccanav.centralindia-01.azurewebsites.net/api/';

  // ── Auth ────────────────────────────────────────────────────────────────────
  static const String login              = 'auth/customer/login';
  static const String logout             = 'auth/logout';
  static const String refreshToken       = 'auth/refresh';
  static const String sendOtp            = 'auth/otp/send';
  static const String verifyOtp          = 'auth/otp/verify';

  // ── Customers ───────────────────────────────────────────────────────────────
  static const String saveCustomer       = 'master/customers';
  static const String getCustomer        = 'master/customers/{mobileNo}';
  static const String updateDeviceId     = 'master/customers/device';
  static const String updatePassword     = 'master/customers/password';

  // ── Lookups ─────────────────────────────────────────────────────────────────
  static const String getVehicleGroups   = 'master/lookups/vehicle-groups';
  static const String getVehicleTypes    = 'master/lookups/vehicle-types';
  static const String getCargoTypes      = 'master/lookups/cargo-types';
  static const String getLoadingTypes    = 'master/lookups/loading-types';

  // ── Rate Cards ───────────────────────────────────────────────────────────────
  // GET master/rate-cards/{category}/{vehicleType}/{rateType}
  static const String getRateCard        = 'master/rate-cards';

  // ── Bookings ─────────────────────────────────────────────────────────────────
  static const String createBooking      = 'booking/bookings';
  static const String getBooking         = 'booking/bookings/{bookingNo}';
  static const String customerBookings   = 'booking/bookings/customer/{customerId}';
  static const String cancelBooking      = 'booking/bookings/cancel';
  static const String confirmBooking     = 'booking/bookings/confirm';        // driver confirms
  static const String reachPickup        = 'booking/bookings/{bookingNo}/reach-pickup';
  static const String reachDestination   = 'booking/bookings/{bookingNo}/reach-destination';
  static const String nearbyBookings     = 'booking/bookings/nearby';

  // ── Trips ────────────────────────────────────────────────────────────────────
  static const String createTrip         = 'trip/trips';
  static const String getTrip            = 'trip/trips/{tripId}';
  static const String endTrip            = 'trip/trips/end';
  static const String currentCustomerTrip = 'trip/trips/customer/{customerMobile}/current';
  static const String currentDriverTrip  = 'trip/trips/driver/{driverId}/current';
  static const String tripByBooking      = 'trip/trips/booking/{bookingNo}';

  // ── Trip Monitoring (real-time driver location) ───────────────────────────────
  static const String tripMonitors       = 'trip/monitors';
  static const String monitorByTrip      = 'trip/monitors/trip/{tripId}';
  static const String monitorByDriver    = 'trip/monitors/driver/{driverId}';

  // ── Billing / Invoices ────────────────────────────────────────────────────────
  static const String invoices           = 'billing/invoices';
  static const String invoiceByBooking   = 'billing/invoices/booking/{bookingNo}';
  static const String invoiceByTrip      = 'billing/invoices/trip/{tripId}';
  static const String payInvoice         = 'billing/invoices/pay';

  // ── Reports ──────────────────────────────────────────────────────────────────
  // POST api/reports/invoice/{invoiceNo}/{tripId}/email
  static const String emailInvoice       = 'reports/invoice/{invoiceNo}/{tripId}/email';

  // ── Drivers ──────────────────────────────────────────────────────────────────
  static const String getDriver          = 'master/drivers/{driverId}';

  // ── Booking history (alias) ───────────────────────────────────────────────────
  static const String bookingHistory     = 'booking/bookings/customer/{mobile}';

  // ── Billing aliases used by payment / invoice screens ────────────────────────
  // GET billing/invoices/booking/{bno}  — amount for current booking
  static const String getAmtCurrentBooking = 'billing/invoices/booking/{bno}';
  // PUT billing/invoices/pay
  static const String payByCash          = 'billing/invoices/pay';
  // GET billing/invoices/booking/{bookingNumber}
  static const String getUserInvoiceDetails = 'billing/invoices/booking/{bookingNumber}';
  // POST reports/invoice/{invoiceNo}/{tripId}/email
  static const String sendInvoiceMail    = 'reports/invoice/{invoiceNo}/{tripId}/email';

  // ── Rating (endpoint TBC — not in swagger, kept for backwards compat) ────────
  static const String userRatingDriver   = 'trip/trips/rate';

  // ── Support ──────────────────────────────────────────────────────────────────
  static const String sendQuery          = 'master/support/query';

  // ── Online payment (CCAvenue — not in new swagger, kept as placeholder) ───────
  static const String onlinePayment      = 'billing/payment/rsa-key';

  // ── Razorpay (still on old route until backend confirms new path) ────────────
  static const String razorpayVerifyPayment = 'billing/payment/razorpay/verify';
  static const String razorpayKeyId      = 'rzp_live_SaZL1IpOM6tmAR';

  // ── Google Maps ───────────────────────────────────────────────────────────────
  static const String placesAutocomplete =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String googleMapsApiKey   = 'AIzaSyAcv7D6zbckc22vXM8fK1zmzZ2gObE5RWE';

  // ── Polling interval ──────────────────────────────────────────────────────────
  static const int pollingIntervalMs = 10000;
}
