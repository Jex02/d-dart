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

  static const List<CampusLocation> defaultPickups = [
    CampusLocation(id: 'pk-1', name: 'Main Canteen', category: 'pickup', buildingCode: 'MC'),
    CampusLocation(id: 'pk-2', name: 'College Canteen', category: 'pickup', buildingCode: 'CC'),
    CampusLocation(id: 'pk-3', name: 'Elementary Canteen', category: 'pickup', buildingCode: 'EC'),
    CampusLocation(id: 'pk-4', name: 'Campus Kiosks', category: 'pickup', buildingCode: 'CK'),
  ];

  static const List<CampusLocation> defaultDropoffs = [
    CampusLocation(id: 'do-1', name: 'ALLIED Building', category: 'dropoff', buildingCode: 'ALLIED'),
    CampusLocation(id: 'do-2', name: 'GLE Building', category: 'dropoff', buildingCode: 'GLE'),
    CampusLocation(id: 'do-3', name: 'Main Building', category: 'dropoff', buildingCode: 'MAIN'),
    CampusLocation(id: 'do-4', name: 'University Library', category: 'dropoff', buildingCode: 'LRAC'),
    CampusLocation(id: 'do-5', name: 'Department Offices', category: 'dropoff', buildingCode: 'DEPT'),
  ];
}
