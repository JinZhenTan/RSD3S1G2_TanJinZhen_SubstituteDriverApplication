import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase_config.dart';
import '../../../models/user_role.dart';

// Holds the sign-in state using the Provider package. Wraps Supabase Auth
// (email / password) and mirrors its session, so the rest of the app can watch
// isSignedIn to decide whether to show the login screen or the app shell.
class AuthProvider extends ChangeNotifier {
  Session? _session;
  bool isLoading = false;
  String? errorMessage;

  AuthProvider() {
    _session = supabase.auth.currentSession;
    // Keep _session in sync whenever Supabase reports a change.
    supabase.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      notifyListeners();
    });
  }

  Session? get session => _session;
  bool get isSignedIn => _session != null;

  // Self-service sign-up always creates a passenger ('user') account - a
  // driver or service-staff account is an operator/partner account, created
  // by inserting the profiles row directly in Supabase, not offered here.
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
        // Read by the handle_new_user trigger (supabase_schema.sql) which
        // creates the profiles + notification_settings rows automatically.
        data: {
          'name': name,
          'role': userRoleToName(UserRole.user),
        },
      );

      final user = response.user;
      if (user != null) {
        // Fallback if the trigger is not installed: create the profile row
        // directly. Kept in its own try / catch so a missing table never
        // fails the sign-up itself.
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

  // Turn a raw Supabase auth error into something clearer, keyed off e.code -
  // GoTrue's stable machine-readable error_code - rather than matching on
  // e.message text, which can change wording between Supabase versions.
  // Full list: https://supabase.com/docs/guides/auth/debugging/error-codes
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
        // GoTrue rejected the address's format (or, for some Supabase
        // configurations, its domain) before even trying to create the
        // account - this is a server-side check, not this app's. Most
        // often the address itself is fine but has a typo; a mainstream
        // provider (Gmail/Outlook/etc.) reliably passes it.
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
