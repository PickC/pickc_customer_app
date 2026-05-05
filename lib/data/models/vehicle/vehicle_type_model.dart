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
    // Support both new API (id/name) and old API (LookupID/LookupId/lookupID variants)
    final id = (json['id'] as num?)?.toInt()
        ?? (json['lookupID'] as num?)?.toInt()   // old API uppercase ID
        ?? (json['LookupID'] as num?)?.toInt()
        ?? (json['LookupId'] as num?)?.toInt()
        ?? (json['lookupId'] as num?)?.toInt()
        ?? 0;
    final name = json['name']?.toString()
        ?? json['LookupCode']?.toString()
        ?? json['lookupCode']?.toString()
        ?? '';
    final description = json['description']?.toString()
        ?? json['LookupDescription']?.toString()
        ?? json['lookupDescription']?.toString();
    return VehicleTypeModel(
      id: id,
      name: name,
      description: description,
      imageUrl: json['imageUrl']?.toString() ?? json['Image']?.toString(),
      groupId: (json['groupId'] as num?)?.toInt(),
    );
  }
}
