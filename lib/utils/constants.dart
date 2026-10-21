import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Bus Tracker';
  static const String baseUrl = 'https://punbus.itracking.in/punbusApp/tracker/';
  static const String username = 'punbus';
  static const String grievanceUrl = 'https://connect.punjab.gov.in/service/grievance/gr1';
  static const String officialWebsite = 'http://punbusonline.com/';
  static const String tollFreeNumber = '1800 180 0516';
  static const String supportEmail = 'support@punbusonline.com';

  // Storage Keys
  static const String savedBusesKey = 'saved_punbus_numbers';
}

class AppColors {
  static const Color primary = Color(0xFFF05A22); // Punbus saffron/orange
  static const Color primaryDark = Color(0xFFC73E0E);
  static const Color primaryLight = Color(0xFFFFE0D4);
  static const Color accent = Color(0xFF1565C0);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF212121);
  static const Color textMuted = Color(0xFF757575);
  static const Color divider = Color(0xFFE0E0E0);
}
