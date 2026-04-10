class InvoiceModel {
  final String? bookingNo;
  final String? customerName;
  final String? driverName;
  final String? vehicleType;
  final String? vehicleNumber;
  final String? fromAddress;
  final String? toAddress;
  final String? startTime;
  final String? endTime;
  final String? totalAmount;
  final String? paymentType;
  final String? date;

  const InvoiceModel({
    this.bookingNo,
    this.customerName,
    this.driverName,
    this.vehicleType,
    this.vehicleNumber,
    this.fromAddress,
    this.toAddress,
    this.startTime,
    this.endTime,
    this.totalAmount,
    this.paymentType,
    this.date,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      bookingNo: json['bookingNo']?.toString(),
      customerName: json['customerName']?.toString(),
      driverName: json['driverName']?.toString(),
      vehicleType: json['vehicleType']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      fromAddress: json['fromAddress']?.toString(),
      toAddress: json['toAddress']?.toString(),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      totalAmount: json['totalAmount']?.toString(),
      paymentType: json['paymentType']?.toString(),
      date: json['date']?.toString(),
    );
  }
}
