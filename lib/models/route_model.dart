class RouteItem {
  final String routeId;
  final String routeName;
  final String? srcId;
  final String? destId;
  final String? vehId;
  final String? regNo;
  final String? departureTime;
  final String? arrivalTime;

  RouteItem({
    required this.routeId,
    required this.routeName,
    this.srcId,
    this.destId,
    this.vehId,
    this.regNo,
    this.departureTime,
    this.arrivalTime,
  });

  factory RouteItem.fromJson(Map<String, dynamic> json) {
    return RouteItem(
      routeId: (json['route_id'] ?? json['id'] ?? '').toString(),
      routeName: (json['route_name'] ?? json['name'] ?? 'Route').toString(),
      srcId: json['src_id']?.toString(),
      destId: json['dest_id']?.toString(),
      vehId: json['veh_id']?.toString(),
      regNo: json['reg_no']?.toString(),
      departureTime: json['s_time']?.toString() ?? json['dept_time']?.toString(),
      arrivalTime: json['arvl_tm']?.toString(),
    );
  }
}

class StopItem {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;
  final String? arrivalTime;
  final String? departureTime;
  final int? sequence;

  StopItem({
    required this.stopId,
    required this.stopName,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.arrivalTime,
    this.departureTime,
    this.sequence,
  });

  factory StopItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return StopItem(
      stopId: (json['stop_id'] ?? json['id'] ?? json['stops_id'] ?? '').toString(),
      stopName: (json['stop_name'] ?? json['name'] ?? json['station'] ?? '').toString(),
      latitude: parseDouble(json['latitude'] ?? json['lat']),
      longitude: parseDouble(json['longitude'] ?? json['lng'] ?? json['long']),
      arrivalTime: json['arvl_tm']?.toString(),
      departureTime: json['s_time']?.toString() ?? json['dept_time']?.toString(),
      sequence: json['seq'] != null ? int.tryParse(json['seq'].toString()) : null,
    );
  }
}

class ContactDepot {
  final String name;
  final String phone;
  final String address;
  final String? email;

  ContactDepot({
    required this.name,
    required this.phone,
    required this.address,
    this.email,
  });

  factory ContactDepot.fromJson(Map<String, dynamic> json) {
    return ContactDepot(
      name: (json['name'] ?? json['depot_name'] ?? '').toString(),
      phone: (json['phone'] ?? json['contact_no'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      email: json['email']?.toString(),
    );
  }
}
