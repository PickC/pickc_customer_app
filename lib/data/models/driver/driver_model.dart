class DriverModel {
  final String? id;
  final String? name;
  final String? mobile;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? rating;
  final double? currentLat;
  final double? currentLng;

  const DriverModel({
    this.id,
    this.name,
    this.mobile,
    this.vehicleNumber,
    this.vehicleType,
    this.rating,
    this.currentLat,
    this.currentLng,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      mobile: json['mobile']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      vehicleType: json['vehicleType']?.toString(),
      rating: json['rating']?.toString(),
      currentLat: (json['lat'] as num?)?.toDouble(),
      currentLng: (json['lng'] as num?)?.toDouble(),
    );
  }
}
