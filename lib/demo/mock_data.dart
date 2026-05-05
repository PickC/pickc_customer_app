import '../data/models/auth/customer_model.dart';
import '../data/models/booking/booking_model.dart';
import '../data/models/driver/driver_model.dart';
import '../data/models/invoice/invoice_model.dart';
import '../data/models/vehicle/vehicle_type_model.dart';

/// Static mock data used when [kDemoMode] is true.
class MockData {
  MockData._();

  static const customer = CustomerModel(
    mobile: '9999999999',
    name: 'Demo User',
    email: 'demo@pickc.in',
    authToken: 'demo-token',
  );

  static const driver = DriverModel(
    id: '101',
    name: 'Raju Sharma',
    mobile: '9876543210',
    vehicleNumber: 'MH 04 AB 1234',
    vehicleType: 'Mini Truck',
    rating: '4.5',
    currentLat: 19.0760,
    currentLng: 72.8777,
  );

  static const vehicles = <VehicleTypeModel>[
    VehicleTypeModel(id: 1, name: 'Mini Truck', description: 'Up to 1 Ton'),
    VehicleTypeModel(id: 2, name: 'Pickup Van', description: 'Up to 750 Kg'),
    VehicleTypeModel(id: 3, name: 'Tata Ace', description: 'Up to 1.5 Ton'),
    VehicleTypeModel(id: 4, name: 'Canter', description: 'Up to 3 Ton'),
    VehicleTypeModel(id: 5, name: 'Truck 407', description: 'Up to 5 Ton'),
  ];

  static final bookings = <BookingModel>[
    BookingModel(
      bookingNo: 'PKC-2024-001',
      locationFrom: '12, MG Road, Andheri West, Mumbai',
      locationTo: '45, Link Road, Goregaon East, Mumbai',
      vehicleTypeName: 'Mini Truck',
      vehicleGroupName: 'Mini',
      cargoType: 'Household',
      payLoad: '500',
      isComplete: true,
      isConfirm: true,
      isReachPickUp: true,
      isReachDestination: true,
      driverID: 'DRV101',
      vehicleNo: 'MH 04 AB 1234',
    ),
    BookingModel(
      bookingNo: 'PKC-2024-002',
      locationFrom: 'Bandra Station, Bandra West, Mumbai',
      locationTo: 'Kurla Complex, Kurla East, Mumbai',
      vehicleTypeName: 'Pickup Van',
      vehicleGroupName: 'Small',
      cargoType: 'Industrial',
      payLoad: '300',
      isCancel: true,
    ),
    BookingModel(
      bookingNo: 'PKC-2024-003',
      locationFrom: 'Malad West Market, Mumbai',
      locationTo: 'Thane Station Road, Thane',
      vehicleTypeName: 'Tata Ace',
      vehicleGroupName: 'Small',
      cargoType: 'Vegetables',
      payLoad: '800',
      isConfirm: true,
      driverID: 'DRV203',
      vehicleNo: 'MH 02 CD 5678',
    ),
    BookingModel(
      bookingNo: 'PKC-2024-004',
      locationFrom: 'Dadar TT Circle, Mumbai',
      locationTo: 'Navi Mumbai APMC, Vashi',
      vehicleTypeName: 'Canter',
      vehicleGroupName: 'Medium',
      cargoType: 'Industrial',
      payLoad: '2000',
    ),
  ];

  static const invoice = InvoiceModel(
    bookingNo: 'PKC-2024-001',
    customerName: 'Demo User',
    driverName: 'Raju Sharma',
    vehicleType: 'Mini Truck',
    vehicleNumber: 'MH 04 AB 1234',
    fromAddress: '12, MG Road, Andheri West, Mumbai',
    toAddress: '45, Link Road, Goregaon East, Mumbai',
    date: '22 Mar 2024',
    startTime: '10:30 AM',
    endTime: '11:45 AM',
    paymentType: 'Cash',
    totalAmount: '850',
  );
}
