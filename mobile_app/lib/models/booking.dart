class Booking {
  final int bookingId;
  final String tractorId;
  final String memberId;
  final DateTime startDate;
  final DateTime endDate;
  final String bookingStatus;
  final String paymentStatus;
  final int paymentAmountRwf;
  
  Booking({
    required this.bookingId,
    required this.tractorId,
    required this.memberId,
    required this.startDate,
    required this.endDate,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.paymentAmountRwf,
  });
  
  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      bookingId: json['booking_id'],
      tractorId: json['tractor_id'],
      memberId: json['member_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      bookingStatus: json['booking_status'],
      paymentStatus: json['payment_status'],
      paymentAmountRwf: json['payment_amount_rwf'],
    );
  }
}