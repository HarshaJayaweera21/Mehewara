import 'package:flutter/foundation.dart';

class ApiConstants {
  /// Base API URL resolving appropriately across Web, Android Emulator, and iOS
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5194/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5194/api';
    } else {
      return 'http://localhost:5194/api';
    }
  }

  // Endpoints
  static const String login = '/auth/login';
  static const String crewProfile = '/crew/profile';
  static const String crewStatus = '/crew/status';
  static const String crewWorkOrders = '/crew/work-orders';
  static const String crews = '/crews';
  static const String crewAvailability = '/crews/availability';
}
