import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/marker_detail.dart';
import '../models/route_model.dart';
import '../utils/constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.baseUrl;
  static const String username = AppConstants.username;

  static final Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'PunBusTracker/1.0.0 (Dart/Flutter)',
  };

  /// Track a single bus by reg_no - NO CAPTCHA
  Future<MarkerDetail?> trackBus(String regNo) async {
    final cleanRegNo = regNo.trim();
    if (cleanRegNo.isEmpty) return null;

    // First try veh-track.php endpoint
    try {
      final vehUrl = '${baseUrl}veh-track.php?username=$username&reg_no=$cleanRegNo';
      final response = await http.get(Uri.parse(vehUrl), headers: _headers).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['type'] == 0 || (data['msg'] != null && data['msg'].toString().toLowerCase().contains('no record'))) {
            // No record on this endpoint
          } else if (data['buses_marker_list'] != null && data['buses_marker_list'] is List && (data['buses_marker_list'] as List).isNotEmpty) {
            return MarkerDetail.fromJson(data['buses_marker_list'][0]);
          } else if (data['data'] != null) {
            if (data['data'] is List && (data['data'] as List).isNotEmpty) {
              return MarkerDetail.fromJson(data['data'][0]);
            } else if (data['data'] is Map<String, dynamic>) {
              return MarkerDetail.fromJson(data['data']);
            }
          }
        }
      }
    } catch (e) {
      // Continue to fallback
    }

    // Secondary fallback: nearby_buses.php with reg_no
    try {
      final fallbackUrl = '${baseUrl}nearby_buses.php?username=$username&reg_no=$cleanRegNo';
      final response = await http.get(Uri.parse(fallbackUrl), headers: _headers).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['buses_marker_list'] != null && data['buses_marker_list'] is List && (data['buses_marker_list'] as List).isNotEmpty) {
            return MarkerDetail.fromJson(data['buses_marker_list'][0]);
          }
        }
      }
    } catch (_) {
      // Silently ignore errors
    }

    return null; // Bus not found or offline
  }

  /// Track multiple buses at once in parallel
  Future<List<MarkerDetail>> trackMultipleBuses(List<String> busNumbers) async {
    if (busNumbers.isEmpty) return [];

    final futures = busNumbers.map((no) => trackBus(no));
    final results = await Future.wait(futures);
    return results.whereType<MarkerDetail>().toList();
  }

  /// Fetch nearby buses around coordinates or source stop ID
  Future<List<MarkerDetail>> getNearbyBuses({double? lat, double? lng, String? sourceId}) async {
    try {
      final src = sourceId ?? '1';
      final url = '${baseUrl}nearby_buses.php?username=$username&source_id=$src';
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data['buses_marker_list'] != null && data['buses_marker_list'] is List) {
          final list = (data['buses_marker_list'] as List)
              .map((item) => MarkerDetail.fromJson(item as Map<String, dynamic>))
              .toList();
          return list;
        }
      }
    } catch (_) {}

    // Fallback: If nearby API endpoint is inactive, return known active bus positions or empty
    return [];
  }

  /// Fetch ETA routes for a source stop
  Future<List<RouteItem>> getEtaRoutes(String srcId) async {
    try {
      final url = '${baseUrl}eta.php?username=$username&src_id=$srcId';
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 10));
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
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 10));
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
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 6));
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
