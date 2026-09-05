// ignore_for_file: non_constant_identifier_names, constant_identifier_names
class WeatherWarning {
  final String issued;
  final String title_en;
  final String? valid_from;
  final String? valid_to;
  final String heading_en;
  final String text_en;
  final String instruction_en;

  const WeatherWarning({
    required this.issued,
    required this.title_en,
    required this.valid_from,
    required this.valid_to,
    required this.heading_en,
    required this.text_en,
    required this.instruction_en,
  });

  factory WeatherWarning.fromJson(Map<String, dynamic> json) {
    final issue = (json['warning_issue'] as Map?) ?? const {};
    return WeatherWarning(
      issued: (issue['issued'] ?? '') as String,
      title_en: (issue['title_en'] ?? '') as String,
      valid_from: json['valid_from'] as String?,
      valid_to: json['valid_to'] as String?,
      heading_en: (json['heading_en'] ?? '') as String,
      text_en: (json['text_en'] ?? '') as String,
      instruction_en: (json['instruction_en'] ?? '') as String,
    );
  }

  String get blob =>
      '$title_en $heading_en $text_en $instruction_en'.toLowerCase();

  bool get isActive {
    final to = DateTime.tryParse(valid_to ?? '');
    if (to == null) return true;
    return DateTime.now().isBefore(to.add(const Duration(hours: 6)));
  }
}
