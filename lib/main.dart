import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/supabase_constants.dart';
import 'get_started.dart';
import 'services/app_router.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const DDartApp());
}

class DDartApp extends StatelessWidget {
  const DDartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'D-Dart',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: SupabaseService().isAuthenticated
          ? const _SessionBootstrapScreen()
          : const GetStartedPage(),
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
