# Pick-C Flutter App — Progress & TODO

> Open this file in VS Code. Pick up from wherever the checkmark stops.

---

## Project Info

| Item | Value |
|---|---|
| Flutter project | `D:\SHARMA\PROJECT\PICKC2026\NEW_CODE\pickc_customer_app` |
| Android source | `D:\SHARMA\PROJECT\PICKC2026\OLD-CODE\Pick-C Customer App-2023-10-14` |
| Package | `com.prts.pickc_customer_app` |
| Architecture | Clean Architecture + Riverpod + go_router |

---

## ✅ DONE — Session 1 (2026-03-23)

### Foundation (Phase 1)
- [x] `pubspec.yaml` — all dependencies added
- [x] `lib/core/constants/api_constants.dart` — all 37 API endpoints as TODO placeholders
- [x] `lib/core/constants/app_constants.dart` — status strings, notification events, vehicle IDs, URLs
- [x] `lib/core/constants/storage_keys.dart` — all 30+ SharedPrefs key strings
- [x] `lib/core/constants/route_names.dart` — all 25 named routes
- [x] `lib/core/theme/` — app_colors, app_text_styles, app_theme (dark theme)
- [x] `lib/core/network/` — DioClient (with auth interceptor), NetworkInfo
- [x] `lib/core/storage/` — SecureStorage (auth token), LocalStorage (all 30+ keys)
- [x] `lib/core/errors/` — AppException, Failure hierarchy
- [x] `lib/core/notifications/` — NotificationService, NotificationHandler
- [x] `lib/core/socket/socket_service.dart` — polling stream (10s, matches Android)
- [x] `lib/core/utils/` — rsa_utils (RSA/PKCS1 = Android), validators, extensions
- [x] `lib/main.dart` + `lib/app.dart` — ProviderScope bootstrap
- [x] `lib/presentation/providers/providers.dart` — all base Riverpod providers
- [x] `lib/presentation/providers/router_provider.dart` — GoRouter + auth guard

### Auth Screens (Phase 2)
- [x] `splash_screen.dart` — dark bg + yellow 50dp bottom bar + SIGN UP / LOGIN
- [x] `login_screen.dart` — mobile + password + forgot pwd link + yellow LOGIN button
- [x] `signup_screen.dart` — 5 fields + OTP note + SIGN UP bottom button
- [x] `otp_screen.dart` — shared by signup + forgot password flow
- [x] `forgot_password_screen.dart`
- [x] `widgets/pickc_button.dart` — yellow button, loading state
- [x] `widgets/pickc_text_field.dart` — dark bg, yellow focus border, hint #afafaf

### Auth Data Layer
- [x] `data/models/auth/customer_model.dart`
- [x] `data/datasources/remote/auth_remote_datasource.dart` — all auth API calls
- [x] `data/repositories/auth_repository_impl.dart` — Either<Failure, T>
- [x] `presentation/providers/auth_provider.dart` — AuthNotifier (login, otp, logout)

### Home Screen (Phase 3)
- [x] `home_screen.dart` — Map + drawer + AnimatedSwitcher panel
- [x] `booking_form_widget.dart` — pickup/drop location entry
- [x] `truck_categories_widget.dart` — vehicle type grid
- [x] `driver_details_widget.dart` — driver info + call button + cancel
- [x] `presentation/providers/home_provider.dart` — HomeState machine + 10s polling
- [x] `presentation/providers/vehicle_provider.dart` — vehicle types list

### Models
- [x] `data/models/driver/driver_model.dart`
- [x] `data/models/vehicle/vehicle_type_model.dart`
- [x] `data/models/booking/booking_history_model.dart`
- [x] `data/models/invoice/invoice_model.dart`

### Remaining Screens (Phases 4–7)
- [x] `booking/booking_history_screen.dart` — list with status colors
- [x] `payment/payment_screen.dart` — Cash vs Online selector
- [x] `payment/cash_payment_screen.dart` — load amount + confirm POST
- [x] `payment/online_payment_screen.dart` — CCAvenue WebView + RSA encrypt
- [x] `payment/payment_status_screen.dart` — success/fail with home + invoice links
- [x] `profile/profile_screen.dart` — editable name/email
- [x] `profile/change_password_screen.dart`
- [x] `rating/driver_rating_screen.dart` — star rating + feedback chips
- [x] `invoice/invoice_screen.dart` — full invoice display + email send
- [x] `support/query_screen.dart` — message to Pick-C support
- [x] `utility/help_webview_screen.dart`
- [x] `utility/about_screen.dart`
- [x] `utility/emergency_screen.dart` — call buttons for Police/Ambulance/etc
- [x] `utility/terms_screen.dart`
- [x] `utility/rate_card_screen.dart`
- [x] `utility/referral_screen.dart` — My Referral + Add Friend tabs
- [x] `utility/zoom_image_screen.dart` — pinch-to-zoom with photo_view

---

## ✅ DONE — Session 2 (2026-03-23)

### Step 1: flutter analyze — all clean
- Fixed `ConnectivityResult` type bug (checkConnectivity returns List, not single value)
- Fixed unused imports in 6 files
- Fixed `BuildContext` across async gap in profile_screen.dart
- Fixed unused local variables in change_password_screen + driver_rating_screen
- Replaced all deprecated `.withOpacity()` → `.withValues(alpha:)` in 8 files
- Removed unnecessary import in rsa_utils.dart
- Fixed widget_test.dart (was referencing non-existent `MyApp`)

### Step 2 & 3: AndroidManifest.xml — done
- Added INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, CALL_PHONE permissions
- Added Google Maps API key placeholder (replace `YOUR_GOOGLE_MAPS_API_KEY`)

### Build fixes (Android/Kotlin environment)
- Gradle: 8.14 → 8.13 (AGP 8.11.1 requires min 8.13)
- Kotlin KGP: 2.2.20 → 2.3.10 (matches resolved kotlin-stdlib transitive dep)
- Migrated `kotlinOptions { jvmTarget }` → `kotlin { compilerOptions { jvmTarget } }` (Kotlin 2.3 breaking change)
- Added `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.0.4` dependency
- Reduced JVM heap: 8G→4G, metaspace: 4G→2G (was OOM-crashing on 15GB machine)
- Set `kotlin.incremental=false` (cross-drive C:/D: path issue with pub cache)
- Set `GRADLE_USER_HOME=D:\gradle-home` permanently via Windows registry (`setx`)
- Removed `ndkVersion` (NDK wasn't installed, pure Dart app doesn't need it)
- **Result: `flutter build apk --debug` → ✅ BUILD SUCCESSFUL**
- APK: `build\app\outputs\flutter-apk\app-debug.apk`

### Step 4: Connect real API endpoints
When you receive the endpoints MD file, update `lib/core/constants/api_constants.dart`.
Every endpoint has a `// TODO:` comment marking it.

### Step 5: Implement polling logic
In `lib/presentation/providers/home_provider.dart`, fill in the `_poll()` method:
```dart
Future<void> _poll() async {
  if (state == HomeState.idle || state == HomeState.selectingTrucks) return;
  // Call isInTrip API → if true, state = HomeState.tripActive
  // Call isReachPickupWaiting API → show notification if driver arrived
  // Call hasCustomerDuePayment → if true, state = HomeState.paymentDue
}
```

### Step 6: Test on Android emulator
```powershell
flutter run
```
Verify:
- Splash screen: dark background + yellow 50dp bar + SIGN UP / LOGIN buttons
- Login screen: dark background, yellow LOGIN button, hint color #afafaf
- All 25 screens navigate correctly from drawer

### Step 7: iOS platform
- Add Google Maps to `ios/Runner/Info.plist`
- Add location permission strings to `Info.plist`

---

## Architecture Reference

```
HomeState machine:
  idle → BookingFormWidget
  selectingTrucks → TruckCategoriesWidget
  bookingConfirmed → DriverDetailsWidget (driver en route)
  tripActive → DriverDetailsWidget (trip running)
  paymentDue → navigate to PaymentScreen

Polling: Timer.periodic 10s in HomeNotifier._poll()
Auth: Token stored in flutter_secure_storage (upgrade from Android plain SharedPrefs)
RSA: lib/core/utils/rsa_utils.dart matches Android RSAUtility.java exactly
```

## Color Reference
```
Background dark:  #181300
Background light: #ededed
Accent yellow:    #f8f206
Hint text:        #afafaf
Status confirmed: #c9bb00
Status cancelled: #ff5d51
Status completed: #80ff7c
Status pending:   #7085ff
App blue:         #0d3e69
```
