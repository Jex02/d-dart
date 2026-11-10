class SystemConfig {
  final int preClassBufferMinutes;
  final int dailyDeliveryLimit;
  final int requestExpirationMinutes;
  final double standardDeliveryFee;

  const SystemConfig({
    this.preClassBufferMinutes = 15,
    this.dailyDeliveryLimit = 5,
    this.requestExpirationMinutes = 30,
    this.standardDeliveryFee = 20.0,
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

    return SystemConfig(
      preClassBufferMinutes:
          int.tryParse(map['pre_class_buffer_minutes'] ?? '') ?? 15,
      dailyDeliveryLimit:
          int.tryParse(map['daily_delivery_limit'] ?? '') ?? 5,
      requestExpirationMinutes:
          int.tryParse(map['request_expiration_minutes'] ?? '') ?? 30,
      standardDeliveryFee:
          double.tryParse(map['standard_delivery_fee'] ?? '') ?? 20.0,
    );
  }
}
