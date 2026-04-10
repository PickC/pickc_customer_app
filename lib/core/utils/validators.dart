class Validators {
  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) return 'Mobile number is required';
    if (value.length != 10) return 'Enter valid 10-digit mobile number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) return 'Enter valid Indian mobile number';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return null; // email is optional
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(value)) {
      return 'Enter valid email address';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) return 'OTP is required';
    if (value.length != 6) return 'Enter valid 6-digit OTP';
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }
}
