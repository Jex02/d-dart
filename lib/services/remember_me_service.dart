import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the Login "Remember me" preference cleanly across Web and Mobile:
/// - When checked: keeps the Supabase session across restarts AND pre-fills
///   the user's email after explicit sign-out.
/// - When unchecked: clears any saved email and marks the session ephemeral so
///   closing/reloading the app does not auto-sign the user back in.
class RememberMeService {
  RememberMeService._();

  static const String _keyRememberMe = 'ddart_remember_me';
  static const String _keyRememberedEmail = 'ddart_remembered_email';
  static const String _keyEphemeralSession = 'ddart_ephemeral_session';
  static const String _supabaseFlutterSessionKey = 'SUPABASE_PERSIST_SESSION_KEY';
  static bool _pendingStartupSignOut = false;

  static Future<({bool rememberMe, String email})> loadLoginDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? true;
      final email = rememberMe ? (prefs.getString(_keyRememberedEmail) ?? '') : '';
      return (rememberMe: rememberMe, email: email);
    } catch (_) {
      return (rememberMe: true, email: '');
    }
  }

  static Future<void> setPreference(bool rememberMe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, rememberMe);
      if (!rememberMe) {
        await prefs.remove(_keyRememberedEmail);
      }
    } catch (_) {}
  }

  static Future<void> saveOnLogin({
    required String email,
    required bool rememberMe,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, rememberMe);
      if (rememberMe) {
        await prefs.setString(_keyRememberedEmail, email.trim());
        await prefs.setBool(_keyEphemeralSession, false);
      } else {
        await prefs.remove(_keyRememberedEmail);
        await prefs.setBool(_keyEphemeralSession, true);
      }
    } catch (_) {}
  }

  static Future<void> clearEphemeralFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEphemeralSession, false);
    } catch (_) {}
  }

  /// Called BEFORE Supabase.initialize() so that an ephemeral ("Remember me"
  /// unchecked) session is cleared from local storage before Supabase even
  /// attempts to restore or refresh it on startup.
  static Future<bool> clearEphemeralBeforeInit({
    required String supabaseUrl,
    bool skipIfRecovery = false,
  }) async {
    if (skipIfRecovery) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasEphemeral = prefs.getBool(_keyEphemeralSession) ?? false;
      if (!wasEphemeral) return false;

      await prefs.setBool(_keyEphemeralSession, false);
      _pendingStartupSignOut = true;
      final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
      final sessionKey = 'sb-$projectRef-auth-token';
      await prefs.remove(sessionKey);
      await prefs.remove(_supabaseFlutterSessionKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called once during app startup right after Supabase.initialize().
  /// If the last login had "Remember me" unchecked, sign out any remaining
  /// Supabase session so the app returns to the login/landing flow.
  static Future<void> enforceSessionOnStartup({bool skipIfRecovery = false}) async {
    if (skipIfRecovery) {
      _pendingStartupSignOut = false;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasEphemeral =
          _pendingStartupSignOut || (prefs.getBool(_keyEphemeralSession) ?? false);
      _pendingStartupSignOut = false;
      if (wasEphemeral) {
        await prefs.setBool(_keyEphemeralSession, false);
        if (Supabase.instance.client.auth.currentSession != null) {
          await Supabase.instance.client.auth.signOut();
        }
      }
    } catch (_) {}
  }
}
