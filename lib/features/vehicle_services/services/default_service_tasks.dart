import '../../../models/car_service_request.dart';


class _SeedTask {
  final String title;
  final String? detail;
  final double price;
  const _SeedTask(this.title, this.price, [this.detail]);
}

const Map<String, List<_SeedTask>> _byType = {
  'general': [
    _SeedTask('Engine oil & filter change', 100,
        'Fully synthetic 5W-40, up to 4 litres'),
    _SeedTask('Air filter inspection & clean', 15),
    _SeedTask('Brake inspection — front & rear', 15),
    _SeedTask('Top up fluids', 15,
        'Coolant, brake, washer and power-steering fluid'),
    _SeedTask('30-point safety check', 15),
  ],
  'oilFilter': [
    _SeedTask('Drain used engine oil', 0),
    _SeedTask('Replace oil filter', 30, 'OEM filter'),
    _SeedTask('Refill engine oil', 85, 'Semi-synthetic 5W-40, 4 litres'),
    _SeedTask('Reset service indicator', 0),
    _SeedTask('Visual under-body check', 15),
  ],
  'tyre': [
    _SeedTask('Tyre rotation — 4 wheels', 40),
    _SeedTask('Wheel balancing', 40),
    _SeedTask('Tread depth & pressure check', 0),
    _SeedTask('Wheel alignment check', 70),
  ],
  'battery': [
    _SeedTask('Battery health & voltage test', 55),
    _SeedTask('Clean terminals & check charging system', 40),
    _SeedTask('Test alternator output', 25),
  ],
  'wash': [
    _SeedTask('Exterior wash & hand dry', 30),
    _SeedTask('Interior vacuum & wipe-down', 35),
    _SeedTask('Tyre shine & glass clean', 15),
  ],
  'inspection': [
    _SeedTask('Full 50-point mechanical inspection', 100),
    _SeedTask('OBD-II diagnostic scan', 50),
    _SeedTask('Brake & suspension check', 35),
    _SeedTask('Written condition report', 15),
  ],
};

List<Map<String, dynamic>> defaultServiceTasks(
  String serviceRequestId,
  List<CarServiceType> types,
) {
  final seeds = <_SeedTask>[
    for (final type in types) ...(_byType[type.name] ?? _byType['general']!),
  ];
  return seeds
      .map((s) => {
            'service_request_id': serviceRequestId,
            'title': s.title,
            'detail': s.detail,
            'price': s.price,
            'is_extra': false,
            'approval': 'included',
          })
      .toList();
}
