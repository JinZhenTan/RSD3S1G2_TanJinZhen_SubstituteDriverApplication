// Model class for a row of the Supabase 'receipts' table.
// A receipt is written whenever a booking or a car service request is paid.
// The Activity & Receipts screen sums these for the monthly spend figure and
// exports them to CSV / PDF.
class Receipt {
  final String id;
  final String userId;
  final String? bookingId;
  final String? serviceRequestId;
  final double amount;
  final String description;
  final DateTime createdAt;

  Receipt({
    required this.id,
    required this.userId,
    this.bookingId,
    this.serviceRequestId,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      bookingId: json['booking_id']?.toString(),
      serviceRequestId: json['service_request_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      description: (json['description'] ?? '') as String,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'booking_id': bookingId,
      'service_request_id': serviceRequestId,
      'amount': amount,
      'description': description,
    };
  }

  // Short reference like "#A1042" derived from the row id, for display only.
  String get reference {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return '#A${digits.substring(digits.length - 4)}';
    }
    return '#A${id.substring(0, id.length < 4 ? id.length : 4).toUpperCase()}';
  }
}
