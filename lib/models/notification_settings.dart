// Model class for a row of the Supabase 'notification_settings' table
// (one row per user). These are account-level toggles so they follow the user
// across devices.
class NotificationSettings {
  final bool tripUpdates;
  final bool safetyAlerts;
  final bool carServiceUpdates;
  final bool chatMessages;
  final bool promotions;

  const NotificationSettings({
    this.tripUpdates = true,
    this.safetyAlerts = true,
    this.carServiceUpdates = true,
    this.chatMessages = true,
    this.promotions = false,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      tripUpdates: (json['trip_updates'] as bool?) ?? true,
      safetyAlerts: (json['safety_alerts'] as bool?) ?? true,
      carServiceUpdates: (json['car_service_updates'] as bool?) ?? true,
      chatMessages: (json['chat_messages'] as bool?) ?? true,
      promotions: (json['promotions'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap(String userId) {
    return {
      'user_id': userId,
      'trip_updates': tripUpdates,
      'safety_alerts': safetyAlerts,
      'car_service_updates': carServiceUpdates,
      'chat_messages': chatMessages,
      'promotions': promotions,
    };
  }

  NotificationSettings copyWith({
    bool? tripUpdates,
    bool? safetyAlerts,
    bool? carServiceUpdates,
    bool? chatMessages,
    bool? promotions,
  }) {
    return NotificationSettings(
      tripUpdates: tripUpdates ?? this.tripUpdates,
      safetyAlerts: safetyAlerts ?? this.safetyAlerts,
      carServiceUpdates: carServiceUpdates ?? this.carServiceUpdates,
      chatMessages: chatMessages ?? this.chatMessages,
      promotions: promotions ?? this.promotions,
    );
  }
}
