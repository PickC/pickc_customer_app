import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/demo_mode.dart';
import '../../data/models/lookup/lookup_item.dart';
import '../../data/models/vehicle/vehicle_type_model.dart';
import '../../demo/mock_data.dart';
import 'providers.dart';

final vehicleTypesProvider =
    AsyncNotifierProvider<VehicleTypesNotifier, List<VehicleTypeModel>>(
        VehicleTypesNotifier.new);

class VehicleTypesNotifier extends AsyncNotifier<List<VehicleTypeModel>> {
  @override
  Future<List<VehicleTypeModel>> build() async {
    return _fetchVehicleTypes();
  }

  Future<List<VehicleTypeModel>> _fetchVehicleTypes() async {
    if (kDemoMode) return MockData.vehicles;
    final dio = ref.read(dioClientProvider).dio;

    List<VehicleTypeModel> parseList(dynamic data) =>
        (data as List? ?? [])
            .map((e) => VehicleTypeModel.fromJson(e as Map<String, dynamic>))
            .where((v) => v.id != 0 && v.name.isNotEmpty)
            .toList();

    // Endpoints to try, in priority order (most complete first)
    final endpoints = [
      ApiConstants.vehicleGroupList, // old-style: master/customer/vehicleGroupList
      ApiConstants.getVehicleGroups, // new: master/lookups/vehicle-groups
      ApiConstants.getVehicleTypes,  // new: master/lookups/vehicle-types
    ];

    for (final endpoint in endpoints) {
      try {
        final res = await dio.get(endpoint);
        final list = parseList(res.data);
        if (list.isNotEmpty) return list;
      } on DioException catch (_) {}
    }

    // Demo fallback — IDs match DB lookup table (LookupCategory = VehicleGroup)
    return const [
      VehicleTypeModel(id: 1000, name: 'Mini',   description: 'Up to 1 Ton'),
      VehicleTypeModel(id: 1001, name: 'Small',  description: 'Up to 1.5 Ton'),
      VehicleTypeModel(id: 1002, name: 'Medium', description: 'Up to 3 Ton'),
      VehicleTypeModel(id: 1003, name: 'Large',  description: 'Up to 5 Ton'),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic lookup helper
// ─────────────────────────────────────────────────────────────────────────────

List<LookupItem> _parseLookupList(dynamic data) =>
    (data as List? ?? [])
        .map((e) => LookupItem.fromJson(e as Map<String, dynamic>))
        .where((v) => v.id != 0 && v.code.isNotEmpty)
        .toList();

// ─────────────────────────────────────────────────────────────────────────────
// Cargo types  —  GET master/lookups/cargo-types
// ─────────────────────────────────────────────────────────────────────────────

final cargoTypesProvider = FutureProvider<List<LookupItem>>((ref) async {
  try {
    final dio = ref.read(dioClientProvider).dio;
    final res = await dio.get(ApiConstants.getCargoTypes);
    final list = _parseLookupList(res.data);
    if (list.isNotEmpty) return list;
  } catch (_) {}
  // Fallback — IDs will be updated once the real API confirms values
  return const [
    LookupItem(id: 1, code: 'Industrial', description: 'Industrial Goods'),
    LookupItem(id: 2, code: 'Vegetables', description: 'Vegetables & Fruits'),
    LookupItem(id: 3, code: 'Household',  description: 'Household Items'),
    LookupItem(id: 4, code: 'Fragile',    description: 'Fragile Goods'),
  ];
});

// Selected cargo type lookupID — used for validation (non-null = something selected)
final selectedCargoLookupIdProvider = StateProvider<int?>((ref) => null);

// Selected cargo type CODE (string) — this is what the API expects as "cargoType"
final selectedCargoCodeProvider = StateProvider<String?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
// Loading / unloading types  —  GET master/lookups/loading-types
// ─────────────────────────────────────────────────────────────────────────────

final loadingTypesProvider = FutureProvider<List<LookupItem>>((ref) async {
  try {
    final dio = ref.read(dioClientProvider).dio;
    final res = await dio.get(ApiConstants.getLoadingTypes);
    final list = _parseLookupList(res.data);
    if (list.isNotEmpty) return list;
  } catch (_) {}
  // Fallback — IDs match old app defaults until real API values are confirmed
  return const [
    LookupItem(id: 0, code: 'None',      description: 'No labour needed'),
    LookupItem(id: 1, code: 'Loading',   description: 'Loading help'),
    LookupItem(id: 2, code: 'Unloading', description: 'Unloading help'),
    LookupItem(id: 3, code: 'Both',      description: 'Loading & Unloading'),
  ];
});

// Selected loading type lookupID — sent in the booking payload
final selectedLoadingLookupIdProvider = StateProvider<int?>((ref) => null);
