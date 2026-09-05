// Model class for a row of the Supabase 'vehicles' table.
// A user can register as many of their own cars as they like; isDefault
// marks the one pre-selected when booking a substitute driver or car
// service, though either flow lets the user pick a different one instead.
class Vehicle {
  final String id;
  final String userId;
  final String plateNumber;
  final String model;
  final String colour;
  final String transmission;
  final bool isDefault;

  Vehicle({
    required this.id,
    required this.userId,
    required this.plateNumber,
    required this.model,
    required this.colour,
    required this.transmission,
    this.isDefault = false,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      plateNumber: (json['plate_number'] ?? '') as String,
      model: (json['model'] ?? '') as String,
      colour: (json['colour'] ?? '') as String,
      transmission: (json['transmission'] ?? 'Automatic') as String,
      isDefault: (json['is_default'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'plate_number': plateNumber,
      'model': model,
      'colour': colour,
      'transmission': transmission,
      'is_default': isDefault,
    };
  }

  Vehicle copyWith({
    String? plateNumber,
    String? model,
    String? colour,
    String? transmission,
    bool? isDefault,
  }) {
    return Vehicle(
      id: id,
      userId: userId,
      plateNumber: plateNumber ?? this.plateNumber,
      model: model ?? this.model,
      colour: colour ?? this.colour,
      transmission: transmission ?? this.transmission,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  String get modelAndColour => '$model · $colour';
}
