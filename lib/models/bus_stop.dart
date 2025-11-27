class BusStop {
  final int id;
  final String name;
  final double lat;
  final double lng;
  final List<String> lines;

  BusStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.lines,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as int,
      name: json['name'] as String,
      lat: json['lat'] as double,
      lng: json['lng'] as double,
      lines: List<String>.from(json['lines'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'lines': lines,
    };
  }
}
