import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/marker_detail.dart';
import '../models/route_model.dart';
import '../utils/constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.baseUrl;
  static const String username = AppConstants.username;

  /// Track a single bus by the short number (e.g. "0544")
  /// 
  /// Real API: GET https://punbus.itracking.in/punbusApp/tracker/veh-track.php?username=punbus&reg_no=0544
  /// Real Response:
  /// {
  ///   "type": 1,
  ///   "veh_track": [{
  ///     "lat": 30.6915, "lng": 76.7117, "speed": "13",
  ///     "reg_no": "PB65AT0544", "last_upt": "18/10/2026 07:13:48",
  ///     "depo_name": "CHD", "next_stop": "No Information",
  ///     "angle": "99", "veh_type": "ORD",
  ///     "route_name": "CHD-KHANNA-HIGH COURT-SIRHIND (12:05)",
  ///     "next_dist": 0, "current_location": "68, NH5, ..."
  ///   }]
  /// }
  /// 
  /// When bus not found: {"type": 0, "msg": "No Record Found"}
  Future<MarkerDetail?> trackBus(String regNo) async {
    final cleanRegNo = regNo.trim();
    if (cleanRegNo.isEmpty) return null;

    try {
      final url = '${baseUrl}veh-track.php?username=$username&reg_no=$cleanRegNo';
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);

        if (data is Map<String, dynamic>) {
          // type == 0 means "No Record Found"
          if (data['type'] == 0) {
            return null;
          }

          // type == 1 means success, data is in "veh_track" array
          if (data['type'] == 1 && data['veh_track'] != null) {
            final vehTrack = data['veh_track'];
            if (vehTrack is List && vehTrack.isNotEmpty) {
              return MarkerDetail.fromJson(vehTrack[0] as Map<String, dynamic>);
            }
          }

          // Also check buses_marker_list as a fallback in case API changes
          if (data['buses_marker_list'] != null) {
            final busList = data['buses_marker_list'];
            if (busList is List && busList.isNotEmpty) {
              return MarkerDetail.fromJson(busList[0] as Map<String, dynamic>);
            }
          }
        }
      }
    } catch (e) {
      // Log for debugging but don't crash
      print('Error tracking bus $cleanRegNo: $e');
    }

    return null; // Bus not found or offline
  }

  /// Track multiple buses at once in parallel - NO CAPTCHA
  Future<List<MarkerDetail>> trackMultipleBuses(List<String> busNumbers) async {
    final numbers = <String>[];
    final seen = <String>{};
    for (final busNumber in busNumbers) {
      final cleanNumber = busNumber.trim();
      if (cleanNumber.isNotEmpty && seen.add(cleanNumber)) {
        numbers.add(cleanNumber);
      }
    }

    if (numbers.isEmpty) return [];

    // Sending every request at the same time can overwhelm the tracking API,
    // causing otherwise valid buses to time out. Keep a small parallel pool so
    // the search stays responsive without overloading the server.
    const maxConcurrentRequests = 4;
    final results = List<MarkerDetail?>.filled(numbers.length, null);
    var nextIndex = 0;

    Future<void> searchNextBus() async {
      while (nextIndex < numbers.length) {
        final index = nextIndex++;
        results[index] = await trackBus(numbers[index]);
      }
    }

    await Future.wait(
      List.generate(
        numbers.length < maxConcurrentRequests
            ? numbers.length
            : maxConcurrentRequests,
        (_) => searchNextBus(),
      ),
    );

    // Filter out nulls (buses not found) and buses without valid GPS
    return results
        .whereType<MarkerDetail>()
        .where((bus) => bus.hasValidLocation)
        .toList();
  }

  /// Fetch nearby buses around a location or source stop ID
  Future<List<MarkerDetail>> getNearbyBuses({String? sourceId, double? lat, double? lng}) async {
    try {
      final String url;
      if (lat != null && lng != null) {
        url = '${baseUrl}nearby_buses.php?username=$username&lat=$lat&lng=$lng';
      } else {
        final src = sourceId ?? '1';
        url = '${baseUrl}nearby_buses.php?username=$username&source_id=$src';
      }
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          // Check veh_track first (primary format)
          if (data['veh_track'] != null && data['veh_track'] is List) {
            return (data['veh_track'] as List)
                .map((item) => MarkerDetail.fromJson(item as Map<String, dynamic>))
                .where((bus) => bus.hasValidLocation)
                .toList();
          }
          // Fallback to buses_marker_list
          if (data['buses_marker_list'] != null && data['buses_marker_list'] is List) {
            return (data['buses_marker_list'] as List)
                .map((item) => MarkerDetail.fromJson(item as Map<String, dynamic>))
                .where((bus) => bus.hasValidLocation)
                .toList();
          }
        }
      }
    } catch (e) {
      print('Error fetching nearby buses: $e');
    }
    return [];
  }

  /// Fetch ETA routes for a source stop
  Future<List<RouteItem>> getEtaRoutes(String srcId) async {
    try {
      final url = '${baseUrl}eta.php?username=$username&src_id=$srcId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['route_list'] != null && data['route_list'] is List) {
          return (data['route_list'] as List).map((r) => RouteItem.fromJson(r)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetch ETD routes for a destination stop
  Future<List<RouteItem>> getEtdRoutes(String destId) async {
    try {
      final url = '${baseUrl}stops_etd_dest.php?username=$username&dest_id=$destId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['route_list'] != null && data['route_list'] is List) {
          return (data['route_list'] as List).map((r) => RouteItem.fromJson(r)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetch vehicle types
  Future<List<String>> getVehicleTypes() async {
    try {
      final url = '${baseUrl}veh_type_list.php?username=$username';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['veh_type'] != null && data['veh_type'] is List) {
          return (data['veh_type'] as List).map((v) => (v['name'] ?? '').toString()).toList();
        }
      }
    } catch (_) {}
    return ['AC3X2', 'AC2X2', 'MERC', 'INTG', 'KMS', 'ORD', 'VOLVO', 'MIDI'];
  }
}
