class CustomerModel {
  final String? mobile;
  final String? name;
  final String? email;
  final String? authToken;
  final String? refreshToken;
  final String? deviceId;

  const CustomerModel({
    this.mobile,
    this.name,
    this.email,
    this.authToken,
    this.refreshToken,
    this.deviceId,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      // Login response: userId = mobile number
      mobile: (json['userId'] ?? json['mobileNo'] ?? json['mobile'])?.toString(),
      name: json['name']?.toString(),
      // Registration uses emailID
      email: (json['emailID'] ?? json['email'])?.toString(),
      // Login response: accessToken
      authToken: (json['accessToken'] ?? json['authToken'])?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      deviceId: (json['deviceID'] ?? json['deviceId'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mobile': mobile,
        'name': name,
        'email': email,
        'authToken': authToken,
      };

  CustomerModel copyWith({
    String? mobile,
    String? name,
    String? email,
    String? authToken,
    String? refreshToken,
    String? deviceId,
  }) {
    return CustomerModel(
      mobile: mobile ?? this.mobile,
      name: name ?? this.name,
      email: email ?? this.email,
      authToken: authToken ?? this.authToken,
      refreshToken: refreshToken ?? this.refreshToken,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
