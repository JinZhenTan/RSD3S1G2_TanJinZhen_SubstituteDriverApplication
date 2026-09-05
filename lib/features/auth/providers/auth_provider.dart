import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase_config.dart';
import '../../../models/user_role.dart';

class AuthProvider extends ChangeNotifier {
  Session? _session;
  bool isLoading = false;
  String? errorMessage;

  AuthProvider() {
    _session = supabase.auth.currentSession;
    supabase.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      notifyListeners();
    });
  }

  Session? get session => _session;
  bool get isSignedIn => _session != null;

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': userRoleToName(UserRole.user),
        },
      );

      final user = response.user;
      if (user != null) {
        try {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'name': name,
            'role': userRoleToName(UserRole.user),
          });
        } catch (e) {
          print('profiles upsert error: $e');
        }
      }
      return true;
    } on AuthException catch (e) {
      errorMessage = _friendlyError(e);
      return false;
    } catch (e) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(AuthException e) {
    switch (e.code) {
      case 'over_email_send_rate_limit':
        return 'Too many sign-up emails sent in a short time (Supabase\'s '
            'free-tier mailer has a very low limit). In Supabase, turn off '
            'Authentication -> Sign In / Providers -> Email -> "Confirm '
            'email" for testing, then try again - this also removes the '
            'need to send an email at all.';
      case 'user_already_exists':
      case 'email_exists':
        return 'That email is already registered. Try logging in instead.';
      case 'email_address_invalid':
        return 'Supabase rejected that email address as invalid. Double-check '
            'it for typos - if it looks correct, try a mainstream address '
            '(Gmail/Outlook/etc.) to rule out a Supabase-side domain '
            'restriction.';
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'signup_disabled':
        return 'Sign-ups are currently turned off for this project.';
      default:
        return e.message;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      errorMessage = _friendlyError(e);
      return false;
    } catch (e) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
