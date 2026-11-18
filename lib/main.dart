import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/supabase_constants.dart';
import 'get_started.dart';
import 'login.dart';
import 'reset_password_page.dart';
import 'services/app_router.dart';
import 'services/cart_service.dart';
import 'services/chat_read_tracker.dart';
import 'services/duty_lock_service.dart';
import 'services/remember_me_service.dart';
import 'services/supabase_service.dart';
import 'services/theme_service.dart';
import 'widgets/responsive_shell.dart';

bool _isPasswordRecoveryActive = false;

bool _isRecoveryUrl() {
  if (!kIsWeb) return false;
  final uri = Uri.base;
  return uri.fragment.contains('type=recovery') ||
      uri.queryParameters['type'] == 'recovery';
}

bool _hasAuthCallbackUrl() {
  if (!kIsWeb) return false;
  final uri = Uri.base;
  final frag = uri.fragment;
  final params = uri.queryParameters;
  return _isRecoveryUrl() ||
      frag.contains('access_token=') ||
      params.containsKey('code') ||
      frag.contains('error=') ||
      params.containsKey('error');
}

String? _extractAuthCallbackError() {
  if (!kIsWeb) return null;
  final uri = Uri.base;
  final combined = <String, String>{
    ...uri.queryParameters,
    if (uri.fragment.isNotEmpty) ...Uri.splitQueryString(uri.fragment),
  };
  final desc = combined['error_description'];
  final err = combined['error'];
  if (desc != null && desc.trim().isNotEmpty) {
    return desc.replaceAll('+', ' ').trim();
  }
  if (err != null && err.trim().isNotEmpty) {
    return err.replaceAll('_', ' ').trim();
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.instance.load();

  // Capture web URL callback state BEFORE Supabase.initialize() clears URL params.
  final launchedWithRecoveryUrl = _isRecoveryUrl();
  final hasAuthCallback = _hasAuthCallbackUrl();
  final initialCallbackError = _extractAuthCallbackError();
  if (launchedWithRecoveryUrl) {
    _isPasswordRecoveryActive = true;
  }

  try {
    await RememberMeService.clearEphemeralBeforeInit(
      supabaseUrl: SupabaseConstants.url,
      skipIfRecovery: hasAuthCallback || _isPasswordRecoveryActive,
    );
    await Supabase.initialize(
      url: SupabaseConstants.url,
      publishableKey: SupabaseConstants.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    await RememberMeService.enforceSessionOnStartup(
      skipIfRecovery: hasAuthCallback || _isPasswordRecoveryActive,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(
    DDartApp(
      launchedWithRecoveryLink: launchedWithRecoveryUrl,
      initialRecoveryError: initialCallbackError,
    ),
  );
}

class DDartApp extends StatefulWidget {
  const DDartApp({
    super.key,
    this.launchedWithRecoveryLink = false,
    this.initialRecoveryError,
  });

  final bool launchedWithRecoveryLink;
  final String? initialRecoveryError;

  @override
  State<DDartApp> createState() => _DDartAppState();
}

class _DDartAppState extends State<DDartApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          if (data.event == AuthChangeEvent.signedOut) {
            _isPasswordRecoveryActive = false;
            SupabaseService().cachedProfile = null;
            CartService.instance.clearCart();
            DutyLockService.reset();
            ChatReadTracker.instance.clear();
          } else if (data.event == AuthChangeEvent.passwordRecovery) {
            _isPasswordRecoveryActive = true;
            RememberMeService.clearEphemeralFlag();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => ResetPasswordPage(
                    initialEmail: data.session?.user.email,
                    startInUpdateMode: true,
                  ),
                ),
                (_) => false,
              );
            });
          } else if (data.event == AuthChangeEvent.userUpdated) {
            _isPasswordRecoveryActive = false;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Auth stream error: $error');
          final message = error is AuthException
              ? error.message
              : 'Password reset link is invalid or has expired. Please request a new one.';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => ResetPasswordPage(
                  initialErrorMessage: message,
                ),
              ),
              (_) => false,
            );
          });
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget initialHome;
    if (widget.launchedWithRecoveryLink) {
      initialHome = ResetPasswordPage(
        initialEmail: SupabaseService().currentUser?.email,
        startInUpdateMode: true,
      );
    } else if (widget.initialRecoveryError != null) {
      initialHome = ResetPasswordPage(
        initialErrorMessage: widget.initialRecoveryError,
      );
    } else if (SupabaseService().isAuthenticated) {
      initialHome = const _SessionBootstrapScreen();
    } else {
      initialHome = const GetStartedPage();
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'D-Dart',
          theme: DDartTheme.lightTheme,
          darkTheme: DDartTheme.darkTheme,
          themeMode: themeMode,
          home: initialHome,
        );
      },
    );
  }
}

class _SessionBootstrapScreen extends StatefulWidget {
  const _SessionBootstrapScreen();

  @override
  State<_SessionBootstrapScreen> createState() =>
      _SessionBootstrapScreenState();
}

class _SessionBootstrapScreenState extends State<_SessionBootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  Future<void> _routeUser() async {
    Widget next;
    try {
      next = await AppRouter.resolveHomeForProfile();
    } catch (e) {
      debugPrint('Session bootstrap error: $e');
      next = const LoginPage();
    }
    if (!mounted || _isPasswordRecoveryActive) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF8F1F0D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'D-DART',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ],
        ),
      ),
    );
  }
}
