// Model class for a row of the Supabase 'payment_methods' table.
//
// Only one row per 'type' is allowed per user (enforced by AccountProvider,
// not the database - see the unique index note in supabase_schema.sql). A
// card's full number and CVV are never stored - only the last 4 digits and
// expiry, same as a real payment provider would return to the merchant after
// tokenising the card. CVV is asked for on the form only to "authorise" the
// card in this simulated flow and is discarded immediately.
class PaymentMethod {
  final String id;
  final String userId;
  final String type; // 'card', 'ewallet' or 'cash'
  final String label;
  final bool isDefault;
  final String? last4; // type == 'card' only
  final String? expiry; // MM/YY, type == 'card' only
  final String? cardholderName; // type == 'card' only

  PaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    required this.label,
    this.isDefault = false,
    this.last4,
    this.expiry,
    this.cardholderName,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      type: (json['type'] ?? 'cash') as String,
      label: (json['label'] ?? 'Cash') as String,
      isDefault: (json['is_default'] as bool?) ?? false,
      last4: json['last4'] as String?,
      expiry: json['expiry'] as String?,
      cardholderName: json['cardholder_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'type': type,
      'label': label,
      'is_default': isDefault,
      'last4': last4,
      'expiry': expiry,
      'cardholder_name': cardholderName,
    };
  }

  PaymentMethod copyWith({
    bool? isDefault,
    String? label,
    String? last4,
    String? expiry,
    String? cardholderName,
  }) {
    return PaymentMethod(
      id: id,
      userId: userId,
      type: type,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      last4: last4 ?? this.last4,
      expiry: expiry ?? this.expiry,
      cardholderName: cardholderName ?? this.cardholderName,
    );
  }

  // Short badge text shown in the coloured card icon.
  String get badge {
    if (type == 'card') return 'CARD';
    if (type == 'ewallet') return 'TNG';
    return 'CSH';
  }
}
