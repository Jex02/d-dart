class SystemConfig {
  final int preClassBufferMinutes;
  final int dailyDeliveryLimit;
  final int requestExpirationMinutes;
  final double standardDeliveryFee;
  final double deliveryFeeShort;
  final double deliveryFeeMedium;
  final double deliveryFeeLong;
  final double deliveryDistanceShortMax;
  final double deliveryDistanceMediumMax;

  const SystemConfig({
    this.preClassBufferMinutes = 15,
    this.dailyDeliveryLimit = 5,
    this.requestExpirationMinutes = 30,
    this.standardDeliveryFee = 20.0,
    this.deliveryFeeShort = 20.0,
    this.deliveryFeeMedium = 25.0,
    this.deliveryFeeLong = 30.0,
    this.deliveryDistanceShortMax = 100.0,
    this.deliveryDistanceMediumMax = 200.0,
  });

  factory SystemConfig.fromConfigRows(List<Map<String, dynamic>> rows) {
    final map = <String, String>{};
    for (final row in rows) {
      final key = row['config_key']?.toString();
      final val = row['config_value']?.toString();
      if (key != null && val != null) {
        map[key] = val;
      }
    }

    final parsedStandard =
        double.tryParse(map['standard_delivery_fee'] ?? '') ?? 20.0;
    final parsedShort = double.tryParse(map['delivery_fee_short'] ?? '');
    final shortFee =
        (parsedShort != null && parsedShort >= 0) ? parsedShort : parsedStandard;

    final parsedMedium = double.tryParse(map['delivery_fee_medium'] ?? '');
    final mediumFee =
        (parsedMedium != null && parsedMedium >= 0) ? parsedMedium : (shortFee + 5.0);

    final parsedLong = double.tryParse(map['delivery_fee_long'] ?? '');
    final longFee =
        (parsedLong != null && parsedLong >= 0) ? parsedLong : (shortFee + 10.0);

    final parsedShortMax =
        double.tryParse(map['delivery_distance_short_max'] ?? '');
    final shortMax =
        (parsedShortMax != null && parsedShortMax > 0) ? parsedShortMax : 100.0;

    final parsedMediumMax =
        double.tryParse(map['delivery_distance_medium_max'] ?? '');
    final mediumMax =
        (parsedMediumMax != null && parsedMediumMax > shortMax)
            ? parsedMediumMax
            : 200.0;

    return SystemConfig(
      preClassBufferMinutes:
          int.tryParse(map['pre_class_buffer_minutes'] ?? '') ?? 15,
      dailyDeliveryLimit:
          int.tryParse(map['daily_delivery_limit'] ?? '') ?? 5,
      requestExpirationMinutes:
          int.tryParse(map['request_expiration_minutes'] ?? '') ?? 30,
      standardDeliveryFee: parsedStandard,
      deliveryFeeShort: shortFee,
      deliveryFeeMedium: mediumFee,
      deliveryFeeLong: longFee,
      deliveryDistanceShortMax: shortMax,
      deliveryDistanceMediumMax: mediumMax,
    );
  }
}
