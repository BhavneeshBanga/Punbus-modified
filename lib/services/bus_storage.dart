import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class BusStorage {
  static final BusStorage _instance = BusStorage._internal();
  factory BusStorage() => _instance;
  BusStorage._internal();

  /// Retrieve list of all saved bus numbers
  Future<List<String>> getBuses() async {
    final prefs = await SharedPreferences.getInstance();
    final buses = prefs.getStringList(AppConstants.savedBusesKey);
    if (buses == null || buses.isEmpty) {
      // Default initial sample buses if first run
      final initialBuses = ['2401', '1234', '5555', '8080'];
      await prefs.setStringList(AppConstants.savedBusesKey, initialBuses);
      return initialBuses;
    }
    return buses;
  }

  /// Add a bus number if not already present
  Future<bool> addBus(String busNumber) async {
    final cleanNumber = busNumber.trim();
    if (cleanNumber.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final currentList = prefs.getStringList(AppConstants.savedBusesKey) ?? [];

    if (!currentList.contains(cleanNumber)) {
      currentList.add(cleanNumber);
      return await prefs.setStringList(AppConstants.savedBusesKey, currentList);
    }
    return false; // Already exists
  }

  /// Remove a bus number from saved list
  Future<bool> removeBus(String busNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final currentList = prefs.getStringList(AppConstants.savedBusesKey) ?? [];

    if (currentList.contains(busNumber)) {
      currentList.remove(busNumber);
      return await prefs.setStringList(AppConstants.savedBusesKey, currentList);
    }
    return false;
  }

  /// Clear all saved bus numbers
  Future<bool> clearBuses() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(AppConstants.savedBusesKey);
  }
}
