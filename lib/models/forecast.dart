// ignore_for_file: non_constant_identifier_names, constant_identifier_names
class Forecast {
  final String location_id;
  final String location_name;
  final String date;
  final String morning_forecast;
  final String afternoon_forecast;
  final String night_forecast;
  final String summary_forecast;
  final String summary_when;
  final int min_temp;
  final int max_temp;

  const Forecast({
    required this.location_id,
    required this.location_name,
    required this.date,
    required this.morning_forecast,
    required this.afternoon_forecast,
    required this.night_forecast,
    required this.summary_forecast,
    required this.summary_when,
    required this.min_temp,
    required this.max_temp,
  });

  factory Forecast.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'location': {
          'location_id': String location_id,
          'location_name': String location_name,
        },
        'date': String date,
        'morning_forecast': String morning_forecast,
        'afternoon_forecast': String afternoon_forecast,
        'night_forecast': String night_forecast,
        'summary_forecast': String summary_forecast,
        'summary_when': String summary_when,
        'min_temp': int min_temp,
        'max_temp': int max_temp,
      } =>
        Forecast(
          location_id: location_id,
          location_name: location_name,
          date: date,
          morning_forecast: morning_forecast,
          afternoon_forecast: afternoon_forecast,
          night_forecast: night_forecast,
          summary_forecast: summary_forecast,
          summary_when: summary_when,
          min_temp: min_temp,
          max_temp: max_temp,
        ),
      _ => throw const FormatException('Failed to load forecast.'),
    };
  }
}
