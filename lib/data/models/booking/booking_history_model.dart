class BookingHistoryModel {
  final String? bookingNo;
  final String? fromAddress;
  final String? toAddress;
  final String? status;
  final String? date;
  final String? vehicleType;
  final String? amount;
  final String? driverName;

  const BookingHistoryModel({
    this.bookingNo,
    this.fromAddress,
    this.toAddress,
    this.status,
    this.date,
    this.vehicleType,
    this.amount,
    this.driverName,
  });

  factory BookingHistoryModel.fromJson(Map<String, dynamic> json) {
    return BookingHistoryModel(
      bookingNo: json['bookingNo']?.toString(),
      fromAddress: json['fromAddress']?.toString(),
      toAddress: json['toAddress']?.toString(),
      status: json['status']?.toString(),
      date: json['date']?.toString(),
      vehicleType: json['vehicleType']?.toString(),
      amount: json['amount']?.toString(),
      driverName: json['driverName']?.toString(),
    );
  }
}
