import 'package:flutter/material.dart';

import '../../../supabase_config.dart';
import '../../../models/notification_settings.dart';
import '../../../models/payment_method.dart';
import '../../../models/profile.dart';
import '../../../models/receipt.dart';
import '../../../models/vehicle.dart';

class AccountProvider extends ChangeNotifier {
  Profile? profile;
  List<Vehicle> vehicles = [];
  List<PaymentMethod> paymentMethods = [];
  List<Receipt> receipts = [];
  NotificationSettings notificationSettings = const NotificationSettings();

  bool isLoading = false;
  String? errorMessage;

  String? get _userId => supabase.auth.currentUser?.id;

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final profileRow = await supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (profileRow == null) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        profile = Profile.fromJson(profileRow);

        await refreshVehicles();
        await refreshPaymentMethods();
        await refreshReceipts();

        final settingsRow = await supabase
            .from('notification_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        notificationSettings = settingsRow == null
            ? const NotificationSettings()
            : NotificationSettings.fromJson(settingsRow);

        errorMessage = null;
        break;
      } catch (e) {
        print('AccountProvider.load attempt $attempt error: $e');
        errorMessage = 'Could not load your account. Pull to retry.';
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    isLoading = false;
    notifyListeners();
  }

  double get spentThisMonth {
    final now = DateTime.now();
    double total = 0;
    for (final r in receipts) {
      if (r.createdAt.year == now.year && r.createdAt.month == now.month) {
        total += r.amount;
      }
    }
    return total;
  }

  PaymentMethod? get defaultPaymentMethod {
    if (paymentMethods.isEmpty) return null;
    for (final m in paymentMethods) {
      if (m.isDefault) return m;
    }
    return paymentMethods.first;
  }

  Future<void> refreshPaymentMethods() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final rows = await supabase
          .from('payment_methods')
          .select()
          .eq('user_id', userId);
      paymentMethods = (rows as List)
          .map((json) => PaymentMethod.fromJson(json as Map<String, dynamic>))
          .toList();
      if (!hasType('cash')) await addPaymentMethod('cash', 'Cash');
      if (!hasType('ewallet')) {
        await addPaymentMethod('ewallet', "Touch 'n Go eWallet");
      }
      notifyListeners();
    } catch (e) {
      print('refreshPaymentMethods error: $e');
    }
  }

  Future<void> refreshReceipts() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final rows = await supabase
          .from('receipts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      receipts = (rows as List)
          .map((json) => Receipt.fromJson(json as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      print('refreshReceipts error: $e');
    }
  }

  bool hasType(String type) => paymentMethods.any((m) => m.type == type);

  Future<bool> addPaymentMethod(
    String type,
    String label, {
    String? last4,
    String? expiry,
    String? cardholderName,
  }) async {
    final userId = _userId;
    if (userId == null || hasType(type)) return false;
    try {
      final inserted = await supabase.from('payment_methods').insert({
        'user_id': userId,
        'type': type,
        'label': label,
        'is_default': paymentMethods.isEmpty,
        'last4': last4,
        'expiry': expiry,
        'cardholder_name': cardholderName,
      }).select();
      paymentMethods.add(
        PaymentMethod.fromJson(
          (inserted as List).first as Map<String, dynamic>,
        ),
      );
      notifyListeners();
      return true;
    } catch (e) {
      print('addPaymentMethod error: $e');
      return false;
    }
  }

  Future<void> updatePaymentMethod(PaymentMethod updated) async {
    try {
      await supabase.from('payment_methods').update({
        'label': updated.label,
        'last4': updated.last4,
        'expiry': updated.expiry,
        'cardholder_name': updated.cardholderName,
      }).eq('id', updated.id);
      paymentMethods = paymentMethods
          .map((m) => m.id == updated.id ? updated : m)
          .toList();
      notifyListeners();
    } catch (e) {
      print('updatePaymentMethod error: $e');
    }
  }

  Future<void> removePaymentMethod(PaymentMethod method) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await supabase.from('payment_methods').delete().eq('id', method.id);
      paymentMethods = paymentMethods.where((m) => m.id != method.id).toList();
      if (method.isDefault && paymentMethods.isNotEmpty) {
        await setDefaultPaymentMethod(paymentMethods.first);
      } else {
        notifyListeners();
      }
    } catch (e) {
      print('removePaymentMethod error: $e');
    }
  }

  Future<void> setDefaultPaymentMethod(PaymentMethod method) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await supabase
          .from('payment_methods')
          .update({'is_default': false}).eq('user_id', userId);
      await supabase
          .from('payment_methods')
          .update({'is_default': true}).eq('id', method.id);
      paymentMethods = paymentMethods
          .map((m) => m.copyWith(isDefault: m.id == method.id))
          .toList();
      notifyListeners();
    } catch (e) {
      print('setDefaultPaymentMethod error: $e');
    }
  }

  Vehicle? get defaultVehicle {
    if (vehicles.isEmpty) return null;
    for (final v in vehicles) {
      if (v.isDefault) return v;
    }
    return vehicles.first;
  }

  Future<void> refreshVehicles() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final rows = await supabase
          .from('vehicles')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      vehicles = (rows as List)
          .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      print('refreshVehicles error: $e');
    }
  }

  Future<void> addVehicle(Vehicle newVehicle) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final inserted = await supabase.from('vehicles').insert({
        ...newVehicle.toMap(),
        'is_default': vehicles.isEmpty,
      }).select();
      vehicles.add(
        Vehicle.fromJson((inserted as List).first as Map<String, dynamic>),
      );
      notifyListeners();
    } catch (e) {
      print('addVehicle error: $e');
    }
  }

  Future<void> updateVehicle(Vehicle updated) async {
    try {
      await supabase.from('vehicles').update(updated.toMap()).eq('id', updated.id);
      vehicles = vehicles.map((v) => v.id == updated.id ? updated : v).toList();
      notifyListeners();
    } catch (e) {
      print('updateVehicle error: $e');
    }
  }

  Future<void> removeVehicle(Vehicle target) async {
    try {
      await supabase.from('vehicles').delete().eq('id', target.id);
      vehicles = vehicles.where((v) => v.id != target.id).toList();
      if (target.isDefault && vehicles.isNotEmpty) {
        await setDefaultVehicle(vehicles.first);
      } else {
        notifyListeners();
      }
    } catch (e) {
      print('removeVehicle error: $e');
    }
  }

  Future<void> setDefaultVehicle(Vehicle target) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await supabase.from('vehicles').update({'is_default': false}).eq('user_id', userId);
      await supabase.from('vehicles').update({'is_default': true}).eq('id', target.id);
      vehicles =
          vehicles.map((v) => v.copyWith(isDefault: v.id == target.id)).toList();
      notifyListeners();
    } catch (e) {
      print('setDefaultVehicle error: $e');
    }
  }

  Future<void> updateProfile({required String name, String? phone}) async {
    final userId = _userId;
    final current = profile;
    if (userId == null || current == null) return;
    final trimmedName = name.trim().isEmpty ? current.name : name.trim();
    final trimmedPhone = phone?.trim();
    try {
      await supabase.from('profiles').update({
        'name': trimmedName,
        'phone': trimmedPhone,
      }).eq('id', userId);
      profile = Profile(
        id: current.id,
        name: trimmedName,
        role: current.role,
        phone: trimmedPhone,
        avatarUrl: current.avatarUrl,
        rating: current.rating,
        basicSalary: current.basicSalary,
        earningsDeductionRate: current.earningsDeductionRate,
      );
      notifyListeners();
    } catch (e) {
      print('updateProfile error: $e');
    }
  }

  Future<void> updateNotificationSettings(NotificationSettings settings) async {
    final userId = _userId;
    if (userId == null) return;
    notificationSettings = settings;
    notifyListeners();
    try {
      await supabase
          .from('notification_settings')
          .upsert(settings.toMap(userId));
    } catch (e) {
      print('updateNotificationSettings error: $e');
    }
  }

  void clear() {
    profile = null;
    vehicles = [];
    paymentMethods = [];
    receipts = [];
    notificationSettings = const NotificationSettings();
    notifyListeners();
  }
}
