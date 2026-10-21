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
  final String depoName;
  final String currentLocation;
  final double nextDist;

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
    this.depoName = '',
    this.currentLocation = '',
    this.nextDist = 0.0,
  });

  /// Parse from the REAL veh-track.php API response format:
  /// {
  ///   "lat": 30.6915,
  ///   "lng": 76.7117,
  ///   "speed": "13",
  ///   "reg_no": "PB65AT0544",
  ///   "last_upt": "18/10/2026 07:13:48",
  ///   "depo_name": "CHD",
  ///   "next_stop": "No Information",
  ///   "angle": "99",
  ///   "veh_type": "ORD",
  ///   "route_name": "CHD-KHANNA-HIGH COURT-SIRHIND (12:05)",
  ///   "next_dist": 0,
  ///   "current_location": "68, NH5, Sector 77, ..."
  /// }
  factory MarkerDetail.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    String parseString(dynamic value) {
      if (value == null) return '';
      return value.toString().trim();
    }

    // Real API uses "lat" and "lng" (NOT "latitude"/"longitude")
    final lat = parseDouble(json['lat'] ?? json['latitude']);
    final lng = parseDouble(json['lng'] ?? json['longitude'] ?? json['long']);
    // Real API returns speed as string like "13"
    final spd = parseDouble(json['speed']);
    // Real API uses "angle" for bearing
    final brg = parseDouble(json['angle'] ?? json['bearing'] ?? json['heading']);

    return MarkerDetail(
      busId: parseString(json['bus_id'] ?? json['veh_id'] ?? json['id'] ?? ''),
      // Real API: "reg_no" is "PB65AT0544" format
      regNo: parseString(json['reg_no'] ?? json['veh_no'] ?? json['number'] ?? json['bus_no']),
      routeName: parseString(json['route_name'] ?? json['route'] ?? json['name'] ?? ''),
      routeId: parseString(json['route_id'] ?? ''),
      latitude: lat,
      longitude: lng,
      speed: spd,
      bearing: brg,
      arvlTm: parseString(json['arvl_tm'] ?? json['arrival_time'] ?? json['eta'] ?? ''),
      sTime: parseString(json['s_time'] ?? json['schedule_time'] ?? json['etd'] ?? ''),
      number: parseString(json['number'] ?? json['bus_number'] ?? ''),
      details: parseString(json['details'] ?? json['description'] ?? ''),
      mobile: parseString(json['mobile'] ?? json['driver_mobile'] ?? json['conductor_mobile'] ?? ''),
      // Real API: "next_stop" with value "No Information" when unavailable
      stopName: parseString(json['next_stop'] ?? json['stop_name'] ?? json['current_stop'] ?? ''),
      // Real API: "last_upt" (not "last_updated")
      lastUpdated: parseString(json['last_upt'] ?? json['last_updated'] ?? json['update_time'] ?? json['gps_time'] ?? json['date_time'] ?? ''),
      // Real API: "veh_type" like "ORD", "AC3X2", etc.
      vehType: parseString(json['veh_type'] ?? json['bus_type'] ?? ''),
      // Real API: "depo_name" like "CHD"
      depoName: parseString(json['depo_name'] ?? json['depot'] ?? ''),
      // Real API: "current_location" full address string
      currentLocation: parseString(json['current_location'] ?? json['location'] ?? ''),
      // Real API: "next_dist" as number
      nextDist: parseDouble(json['next_dist']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      'reg_no': regNo,
      'route_name': routeName,
      'route_id': routeId,
      'lat': latitude,
      'lng': longitude,
      'speed': speed,
      'angle': bearing,
      'arvl_tm': arvlTm,
      's_time': sTime,
      'number': number,
      'details': details,
      'mobile': mobile,
      'next_stop': stopName,
      'last_upt': lastUpdated,
      'veh_type': vehType,
      'depo_name': depoName,
      'current_location': currentLocation,
      'next_dist': nextDist,
    };
  }

  bool get hasValidLocation => latitude != 0.0 && longitude != 0.0;
  bool get isMoving => speed > 2.0;

  /// Extract the short bus number from reg_no like "PB65AT0544" -> "0544"
  String get shortBusNumber {
    if (regNo.length >= 4) {
      // Try to extract last 4 digits
      final match = RegExp(r'(\d{4})$').firstMatch(regNo);
      if (match != null) return match.group(1)!;
    }
    return regNo;
  }

  String get displayTitle {
    if (regNo.isNotEmpty) return 'Bus $regNo';
    if (number.isNotEmpty) return 'Bus #$number';
    return 'PunBus $busId';
  }

  String get speedFormatted => '${speed.toStringAsFixed(0)} km/h';

  /// Format the next stop - hide if "No Information"
  String get nextStopFormatted {
    if (stopName.isEmpty || stopName.toLowerCase() == 'no information') {
      return '';
    }
    return stopName;
  }
}
