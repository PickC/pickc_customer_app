import '../data/models/auth/customer_model.dart';
import '../data/models/booking/booking_history_model.dart';
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

  static const bookings = <BookingHistoryModel>[
    BookingHistoryModel(
      bookingNo: 'PKC-2024-001',
      fromAddress: '12, MG Road, Andheri West, Mumbai',
      toAddress: '45, Link Road, Goregaon East, Mumbai',
      status: 'Completed',
      date: '22 Mar 2024',
      vehicleType: 'Mini Truck',
      amount: '850',
      driverName: 'Raju Sharma',
    ),
    BookingHistoryModel(
      bookingNo: 'PKC-2024-002',
      fromAddress: 'Bandra Station, Bandra West, Mumbai',
      toAddress: 'Kurla Complex, Kurla East, Mumbai',
      status: 'Cancelled',
      date: '15 Mar 2024',
      vehicleType: 'Pickup Van',
      amount: '650',
      driverName: 'Suresh Kumar',
    ),
    BookingHistoryModel(
      bookingNo: 'PKC-2024-003',
      fromAddress: 'Malad West Market, Mumbai',
      toAddress: 'Thane Station Road, Thane',
      status: 'Confirmed',
      date: '10 Mar 2024',
      vehicleType: 'Tata Ace',
      amount: '1200',
      driverName: 'Manoj Patil',
    ),
    BookingHistoryModel(
      bookingNo: 'PKC-2024-004',
      fromAddress: 'Dadar TT Circle, Mumbai',
      toAddress: 'Navi Mumbai APMC, Vashi',
      status: 'Pending',
      date: '05 Mar 2024',
      vehicleType: 'Canter',
      amount: '2100',
      driverName: 'Arun Desai',
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
