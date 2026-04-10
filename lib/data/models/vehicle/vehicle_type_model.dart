class VehicleTypeModel {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int? groupId;

  const VehicleTypeModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.groupId,
  });

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      groupId: (json['groupId'] as num?)?.toInt(),
    );
  }
}
