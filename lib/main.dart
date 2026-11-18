import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/supabase_constants.dart';
import 'get_started.dart';
import 'reset_password_page.dart';
import 'services/app_router.dart';
import 'services/chat_read_tracker.dart';
import 'services/remember_me_service.dart';
import 'services/supabase_service.dart';

bool _isRecoveryUrl() {
  if (!kIsWeb) return false;
  final uri = Uri.base;
  return uri.fragment.contains('type=recovery') ||
      uri.queryParameters['type'] == 'recovery';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
    await RememberMeService.enforceSessionOnStartup(
      skipIfRecovery: _isRecoveryUrl(),
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const DDartApp());
}

class DDartApp extends StatefulWidget {
  const DDartApp({super.key});

  @override
  State<DDartApp> createState() => _DDartAppState();
}

class _DDartAppState extends State<DDartApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;
  late final bool _launchedWithRecoveryLink;

  @override
  void initState() {
    super.initState();
    _launchedWithRecoveryLink = _isRecoveryUrl();
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedOut) {
          SupabaseService().cachedProfile = null;
          ChatReadTracker.instance.clear();
        } else if (data.event == AuthChangeEvent.passwordRecovery) {
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
        }
      });
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
    if (_launchedWithRecoveryLink) {
      initialHome = ResetPasswordPage(
        initialEmail: SupabaseService().currentUser?.email,
        startInUpdateMode: true,
      );
    } else if (SupabaseService().isAuthenticated) {
      initialHome = const _SessionBootstrapScreen();
    } else {
      initialHome = const GetStartedPage();
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'D-Dart',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: initialHome,
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
    final next = await AppRouter.resolveHomeForProfile();
    if (!mounted) return;
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
