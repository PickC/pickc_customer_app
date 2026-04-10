import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/demo_mode.dart';
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
    // GET master/customer/vehicleGroupList
    final dio = ref.read(dioClientProvider).dio;
    try {
      final response = await dio.get(ApiConstants.getVehicleTypes);
      final list = (response.data as List? ?? [])
          .map((e) => VehicleTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return list;
    } on DioException {
      // fall through to demo data
    }
    // Demo data — used until real API is connected
    return const [
      VehicleTypeModel(id: 1, name: 'Mini Truck', description: 'Up to 1 Ton'),
      VehicleTypeModel(id: 2, name: 'Pickup Van',  description: 'Up to 750 Kg'),
      VehicleTypeModel(id: 3, name: 'Tata Ace',    description: 'Up to 1.5 Ton'),
      VehicleTypeModel(id: 4, name: 'Canter',      description: 'Up to 3 Ton'),
      VehicleTypeModel(id: 5, name: 'Truck 407',   description: 'Up to 5 Ton'),
    ];
  }
}
