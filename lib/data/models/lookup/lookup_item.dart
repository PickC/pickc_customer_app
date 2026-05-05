/// Generic lookup item — used for vehicle types (Open/Closed),
/// cargo types, and loading/unloading types from the API.
class LookupItem {
  final int id;
  final String code;
  final String? description;
  final String? category;

  const LookupItem({
    required this.id,
    required this.code,
    this.description,
    this.category,
  });

  factory LookupItem.fromJson(Map<String, dynamic> json) {
    // Handles both old API (lookupID / LookupId) and new API (id / name)
    final id = (json['lookupID'] as num?)?.toInt()
        ?? (json['LookupId'] as num?)?.toInt()
        ?? (json['lookupId'] as num?)?.toInt()
        ?? (json['id'] as num?)?.toInt()
        ?? 0;
    final code = json['lookupCode']?.toString()
        ?? json['LookupCode']?.toString()
        ?? json['code']?.toString()
        ?? json['name']?.toString()
        ?? '';
    final description = json['lookupDescription']?.toString()
        ?? json['LookupDescription']?.toString()
        ?? json['description']?.toString();
    final category = json['lookupCategory']?.toString()
        ?? json['LookupCategory']?.toString()
        ?? json['category']?.toString();
    return LookupItem(
        id: id, code: code, description: description, category: category);
  }
}
