import 'package:flutter/material.dart';

/// Full booking record returned by
/// GET booking/bookings/customer/{customerId}
class BookingModel {
  final String bookingNo;
  final DateTime? bookingDate;
  final String? customerID;
  final DateTime? requiredDate;
  final String locationFrom;
  final String locationTo;
  final String? cargoDescription;
  final int? vehicleType;
  final String? vehicleTypeName;
  final String? vehicleTypeIcon;
  final int? vehicleGroup;
  final String? vehicleGroupName;
  final String? cargoType;
  final String? payLoad;
  final int loadingUnLoading;
  final String? remarks;
  final double latitude;
  final double longitude;
  final double toLatitude;
  final double toLongitude;
  final String? receiverMobileNo;
  final bool isConfirm;
  final DateTime? confirmDate;
  final String? driverID;
  final String? vehicleNo;
  final bool isCancel;
  final DateTime? cancelTime;
  final String? cancelRemarks;
  final bool isCancelByDriver;
  final DateTime? driverCancelDateTime;
  final bool isComplete;
  final DateTime? completeTime;
  final bool isReachPickUp;
  final DateTime? pickupReachDateTime;
  final bool isReachDestination;
  final DateTime? destinationReachDateTime;
  final int status;

  const BookingModel({
    required this.bookingNo,
    this.bookingDate,
    this.customerID,
    this.requiredDate,
    this.locationFrom = '',
    this.locationTo = '',
    this.cargoDescription,
    this.vehicleType,
    this.vehicleTypeName,
    this.vehicleTypeIcon,
    this.vehicleGroup,
    this.vehicleGroupName,
    this.cargoType,
    this.payLoad,
    this.loadingUnLoading = 0,
    this.remarks,
    this.latitude = 0,
    this.longitude = 0,
    this.toLatitude = 0,
    this.toLongitude = 0,
    this.receiverMobileNo,
    this.isConfirm = false,
    this.confirmDate,
    this.driverID,
    this.vehicleNo,
    this.isCancel = false,
    this.cancelTime,
    this.cancelRemarks,
    this.isCancelByDriver = false,
    this.driverCancelDateTime,
    this.isComplete = false,
    this.completeTime,
    this.isReachPickUp = false,
    this.pickupReachDateTime,
    this.isReachDestination = false,
    this.destinationReachDateTime,
    this.status = 0,
  });

  // ── Parsing helpers ─────────────────────────────────────────────────────────

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  factory BookingModel.fromJson(Map<String, dynamic> j) => BookingModel(
        bookingNo: j['bookingNo']?.toString() ?? '',
        bookingDate: _date(j['bookingDate']),
        customerID: j['customerID']?.toString(),
        requiredDate: _date(j['requiredDate']),
        locationFrom: j['locationFrom']?.toString() ?? '',
        locationTo: j['locationTo']?.toString() ?? '',
        cargoDescription: j['cargoDescription']?.toString(),
        vehicleType: (j['vehicleType'] as num?)?.toInt(),
        vehicleTypeName: j['vehicleTypeName']?.toString(),
        vehicleTypeIcon: j['vehicleTypeIcon']?.toString(),
        vehicleGroup: (j['vehicleGroup'] as num?)?.toInt(),
        vehicleGroupName: j['vehicleGroupName']?.toString(),
        cargoType: j['cargoType']?.toString(),
        payLoad: j['payLoad']?.toString(),
        loadingUnLoading: (j['loadingUnLoading'] as num?)?.toInt() ?? 0,
        remarks: j['remarks']?.toString(),
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        toLatitude: (j['toLatitude'] as num?)?.toDouble() ?? 0,
        toLongitude: (j['toLongitude'] as num?)?.toDouble() ?? 0,
        receiverMobileNo: j['receiverMobileNo']?.toString(),
        isConfirm: j['isConfirm'] as bool? ?? false,
        confirmDate: _date(j['confirmDate']),
        driverID: j['driverID']?.toString(),
        vehicleNo: j['vehicleNo']?.toString(),
        isCancel: j['isCancel'] as bool? ?? false,
        cancelTime: _date(j['cancelTime']),
        cancelRemarks: j['cancelRemarks']?.toString(),
        isCancelByDriver: j['isCancelByDriver'] as bool? ?? false,
        driverCancelDateTime: _date(j['driverCancelDateTime']),
        isComplete: j['isComplete'] as bool? ?? false,
        completeTime: _date(j['completeTime']),
        isReachPickUp: j['isReachPickUp'] as bool? ?? false,
        pickupReachDateTime: _date(j['pickupReachDateTime']),
        isReachDestination: j['isReachDestination'] as bool? ?? false,
        destinationReachDateTime: _date(j['destinationReachDateTime']),
        status: (j['status'] as num?)?.toInt() ?? 0,
      );

  // ── Status derived from boolean flags (check in priority order) ─────────────

  String get statusLabel {
    if (isCancel) return 'Cancelled';
    if (isCancelByDriver) return 'Cancelled by Driver';
    if (isComplete) return 'Completed';
    if (isReachDestination) return 'Reached Destination';
    if (isReachPickUp) return 'Picked Up';
    if (isConfirm) return 'Confirmed';
    return 'Pending';
  }

  Color get statusColor {
    if (isCancel) return const Color(0xFFE53935);       // Red
    if (isCancelByDriver) return const Color(0xFFFF6D00); // Orange
    if (isComplete) return const Color(0xFF43A047);     // Green
    if (isReachDestination) return const Color(0xFF00897B); // Teal
    if (isReachPickUp) return const Color(0xFF1E88E5);  // Blue
    if (isConfirm) return const Color(0xFF3949AB);      // Indigo
    return const Color(0xFF757575);                     // Grey
  }

  String get loadingLabel {
    switch (loadingUnLoading) {
      case 1:  return 'Loading';
      case 2:  return 'Unloading';
      case 3:  return 'Loading & Unloading';
      default: return 'Not Required';
    }
  }

  /// True when at least one coordinate pair is non-zero.
  bool get hasCoordinates =>
      !(latitude == 0 && longitude == 0 && toLatitude == 0 && toLongitude == 0);
}
