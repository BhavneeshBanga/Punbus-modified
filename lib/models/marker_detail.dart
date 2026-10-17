class MarkerDetail {
  final String busId;
  final String regNo;
  final String routeName;
  final String routeId;
  final double latitude;
  final double longitude;
  final double speed;
  final double bearing;
  final String arvlTm;
  final String sTime;
  final String number;
  final String details;
  final String mobile;
  final String stopName;
  final String lastUpdated;
  final String vehType;

  MarkerDetail({
    required this.busId,
    required this.regNo,
    required this.routeName,
    this.routeId = '',
    required this.latitude,
    required this.longitude,
    this.speed = 0.0,
    this.bearing = 0.0,
    this.arvlTm = '',
    this.sTime = '',
    this.number = '',
    this.details = '',
    this.mobile = '',
    this.stopName = '',
    this.lastUpdated = '',
    this.vehType = '',
  });

  factory MarkerDetail.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse double
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper to safely parse string
    String parseString(dynamic value) {
      if (value == null) return '';
      return value.toString().trim();
    }

    final lat = parseDouble(json['latitude'] ?? json['lat']);
    final lng = parseDouble(json['longitude'] ?? json['lng'] ?? json['long']);
    final spd = parseDouble(json['speed']);
    final brg = parseDouble(json['bearing'] ?? json['angle'] ?? json['heading']);

    return MarkerDetail(
      busId: parseString(json['bus_id'] ?? json['veh_id'] ?? json['id']),
      regNo: parseString(json['reg_no'] ?? json['veh_no'] ?? json['number'] ?? json['bus_no']),
      routeName: parseString(json['route_name'] ?? json['route'] ?? json['name'] ?? 'PunBus Route'),
      routeId: parseString(json['route_id']),
      latitude: lat,
      longitude: lng,
      speed: spd,
      bearing: brg,
      arvlTm: parseString(json['arvl_tm'] ?? json['arrival_time'] ?? json['eta']),
      sTime: parseString(json['s_time'] ?? json['schedule_time'] ?? json['etd']),
      number: parseString(json['number'] ?? json['bus_number']),
      details: parseString(json['details'] ?? json['description']),
      mobile: parseString(json['mobile'] ?? json['driver_mobile'] ?? json['conductor_mobile']),
      stopName: parseString(json['stop_name'] ?? json['next_stop'] ?? json['current_stop']),
      lastUpdated: parseString(json['last_updated'] ?? json['update_time'] ?? json['gps_time'] ?? json['date_time']),
      vehType: parseString(json['veh_type'] ?? json['bus_type'] ?? 'Standard'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      'reg_no': regNo,
      'route_name': routeName,
      'route_id': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'bearing': bearing,
      'arvl_tm': arvlTm,
      's_time': sTime,
      'number': number,
      'details': details,
      'mobile': mobile,
      'stop_name': stopName,
      'last_updated': lastUpdated,
      'veh_type': vehType,
    };
  }

  bool get hasValidLocation => latitude != 0.0 && longitude != 0.0;
  bool get isMoving => speed > 2.0;

  String get displayTitle => regNo.isNotEmpty ? 'Bus #$regNo' : (number.isNotEmpty ? 'Bus #$number' : 'PunBus $busId');
  String get speedFormatted => '${speed.toStringAsFixed(1)} km/h';
}
