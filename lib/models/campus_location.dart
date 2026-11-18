import 'system_config.dart';

class CampusLocation {
  final String id;
  final String name;
  final String category; // 'pickup' or 'dropoff'
  final String buildingCode;
  final bool isActive;

  const CampusLocation({
    required this.id,
    required this.name,
    required this.category,
    this.buildingCode = '',
    this.isActive = true,
  });

  factory CampusLocation.fromJson(Map<String, dynamic> json) {
    return CampusLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'pickup',
      buildingCode: json['building_code']?.toString() ?? '',
      isActive: json['is_active'] != false,
    );
  }

  // ==========================================
  // OFFICIAL CANTEEN PICKUP LOCATIONS (EXACTLY 3)
  // ==========================================
  static const String canteenMain = 'Main Canteen';
  static const String canteenHighSchool = 'Highschool Canteen';
  static const String canteenMini = 'Mini Canteen';

  static const List<String> officialCanteens = [
    canteenMain,
    canteenHighSchool,
    canteenMini,
  ];

  static const List<CampusLocation> defaultPickups = [
    CampusLocation(
      id: 'pk-main',
      name: canteenMain,
      category: 'pickup',
      buildingCode: 'MC',
    ),
    CampusLocation(
      id: 'pk-hs',
      name: canteenHighSchool,
      category: 'pickup',
      buildingCode: 'HSC',
    ),
    CampusLocation(
      id: 'pk-mini',
      name: canteenMini,
      category: 'pickup',
      buildingCode: 'MINI',
    ),
  ];

  // ==========================================
  // OFFICIAL DELIVERY DESTINATIONS (EXACTLY 11)
  // ==========================================
  static const List<String> officialDestinations = [
    'Backgate Annex',
    'GLE',
    'G-LECROOM',
    'NGE',
    'Allied',
    'SAL',
    'ACAD',
    'RTL',
    'Physics Lab',
    'Gymnasium',
    'Covered Courts',
  ];

  static const List<CampusLocation> defaultDropoffs = [
    CampusLocation(
      id: 'do-1',
      name: 'Backgate Annex',
      category: 'dropoff',
      buildingCode: 'BGA',
    ),
    CampusLocation(
      id: 'do-2',
      name: 'GLE',
      category: 'dropoff',
      buildingCode: 'GLE',
    ),
    CampusLocation(
      id: 'do-3',
      name: 'G-LECROOM',
      category: 'dropoff',
      buildingCode: 'G-LECROOM',
    ),
    CampusLocation(
      id: 'do-4',
      name: 'NGE',
      category: 'dropoff',
      buildingCode: 'NGE',
    ),
    CampusLocation(
      id: 'do-5',
      name: 'Allied',
      category: 'dropoff',
      buildingCode: 'ALLIED',
    ),
    CampusLocation(
      id: 'do-6',
      name: 'SAL',
      category: 'dropoff',
      buildingCode: 'SAL',
    ),
    CampusLocation(
      id: 'do-7',
      name: 'ACAD',
      category: 'dropoff',
      buildingCode: 'ACAD',
    ),
    CampusLocation(
      id: 'do-8',
      name: 'RTL',
      category: 'dropoff',
      buildingCode: 'RTL',
    ),
    CampusLocation(
      id: 'do-9',
      name: 'Physics Lab',
      category: 'dropoff',
      buildingCode: 'G-PHYSLAB',
    ),
    CampusLocation(
      id: 'do-10',
      name: 'Gymnasium',
      category: 'dropoff',
      buildingCode: 'GYM',
    ),
    CampusLocation(
      id: 'do-11',
      name: 'Covered Courts',
      category: 'dropoff',
      buildingCode: 'COURTS',
    ),
  ];

  // ==========================================
  // OFFICIAL CAMPUS DISTANCE DATASET (IN METERS)
  // 11 Destinations x 3 Canteens = 33 Combinations
  // ==========================================
  static const Map<String, Map<String, double>> campusDistances = {
    'Backgate Annex': {
      'Mini Canteen': 240.53,
      'Main Canteen': 141.30,
      'Highschool Canteen': 61.66,
    },
    'GLE': {
      'Mini Canteen': 164.55,
      'Main Canteen': 104.26,
      'Highschool Canteen': 187.23,
    },
    'G-LECROOM': {
      'Mini Canteen': 129.87,
      'Main Canteen': 94.43,
      'Highschool Canteen': 109.98,
    },
    'NGE': {
      'Mini Canteen': 98.15,
      'Main Canteen': 206.28,
      'Highschool Canteen': 267.64,
    },
    'Allied': {
      'Mini Canteen': 50.19,
      'Main Canteen': 183.27,
      'Highschool Canteen': 198.63,
    },
    'SAL': {
      'Mini Canteen': 160.91,
      'Main Canteen': 96.03,
      'Highschool Canteen': 79.73,
    },
    'ACAD': {
      'Mini Canteen': 194.27,
      'Main Canteen': 68.04,
      'Highschool Canteen': 150.93,
    },
    'RTL': {
      'Mini Canteen': 69.61,
      'Main Canteen': 153.93,
      'Highschool Canteen': 200.92,
    },
    'Physics Lab': {
      'Mini Canteen': 126.04,
      'Main Canteen': 88.39,
      'Highschool Canteen': 125.51,
    },
    'Gymnasium': {
      'Mini Canteen': 239.23,
      'Main Canteen': 110.17,
      'Highschool Canteen': 38.37,
    },
    'Covered Courts': {
      'Mini Canteen': 190.01,
      'Main Canteen': 38.26,
      'Highschool Canteen': 46.48,
    },
  };

  /// Normalizes destination building name, matching exact names or legacy aliases.
  static String? canonicalDestination(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (campusDistances.containsKey(trimmed)) return trimmed;

    final lower = trimmed.toLowerCase();
    if (lower.contains('backgate')) return 'Backgate Annex';
    if (lower.contains('g-lecroom') ||
        lower.contains('glecroom') ||
        lower.contains('gle classroom')) {
      return 'G-LECROOM';
    }
    if (lower.contains('gle')) return 'GLE';
    if (lower.contains('nge')) return 'NGE';
    if (lower.contains('allied')) return 'Allied';
    if (lower.contains('sal') || lower.contains('simplicio')) return 'SAL';
    if (lower.contains('acad') ||
        lower.contains('academic') ||
        lower.contains('engineering')) {
      return 'ACAD';
    }
    if (lower.contains('rtl') || lower.contains('rodolfo')) return 'RTL';
    if (lower.contains('phys') || lower.contains('g-physlab')) return 'Physics Lab';
    if (lower.contains('gym') || lower.contains('gymnasium')) return 'Gymnasium';
    if (lower.contains('covered') || lower.contains('court')) return 'Covered Courts';
    return null;
  }

  /// Normalizes canteen name, matching official canteens or legacy aliases.
  static String? canonicalCanteen(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed == canteenMini ||
        trimmed == canteenMain ||
        trimmed == canteenHighSchool) {
      return trimmed;
    }

    final lower = trimmed.toLowerCase();
    if (lower.contains('mini')) return canteenMini;
    if (lower.contains('high') ||
        lower.contains('hs') ||
        lower.contains('elementary')) {
      return canteenHighSchool;
    }
    if (lower.contains('main') || lower.contains('college')) return canteenMain;
    return null;
  }

  /// Retrieves the official distance measurement in meters using BOTH the selected
  /// canteen and destination building.
  /// Returns null if either location is unrecognized.
  static double? getDistanceMeters(String? canteen, String? destination) {
    final dest = canonicalDestination(destination);
    final cant = canonicalCanteen(canteen);
    if (dest == null || cant == null) return null;
    return campusDistances[dest]?[cant];
  }

  /// Formats distance into a human-readable string with "m" suffix.
  static String formatDistance(double? meters) {
    if (meters == null) return '';
    return '${meters.toStringAsFixed(2)} m';
  }

  /// Calculates the delivery fee for a specific canteen and destination.
  /// If the combination does not exist, returns null (so callers can display an error
  /// and block checkout instead of silently charging a default fee).
  ///
  /// Approved Option A Tiering:
  /// - 0 to 100 meters: ₱20.00
  /// - Over 100 to 200 meters: ₱25.00
  /// - Over 200 meters: ₱30.00
  ///
  /// Exact boundaries (unrounded distance values):
  /// - 100.00 m -> ₱20.00
  /// - 100.01 m -> ₱25.00
  /// - 200.00 m -> ₱25.00
  /// - 200.01 m -> ₱30.00
  static double? calculateDeliveryFee({
    required String canteen,
    required String destination,
    SystemConfig? config,
    double? baseFee,
  }) {
    final distance = getDistanceMeters(canteen, destination);
    if (distance == null) return null;
    return calculateFeeForDistance(distance, config: config, baseFee: baseFee);
  }

  /// Calculates the delivery fee for a specific measured distance in meters.
  static double calculateFeeForDistance(
    double distance, {
    SystemConfig? config,
    double? baseFee,
  }) {
    final shortMax = config?.deliveryDistanceShortMax ?? 100.0;
    final mediumMax = config?.deliveryDistanceMediumMax ?? 200.0;

    final shortFee = config?.deliveryFeeShort ?? (baseFee ?? 20.0);
    final mediumFee =
        config?.deliveryFeeMedium ?? (baseFee != null ? (baseFee + 5.0) : 25.0);
    final longFee =
        config?.deliveryFeeLong ?? (baseFee != null ? (baseFee + 10.0) : 30.0);

    if (distance <= shortMax) {
      return shortFee;
    } else if (distance <= mediumMax) {
      return mediumFee;
    } else {
      return longFee;
    }
  }
}
