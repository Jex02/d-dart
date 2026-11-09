import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/supabase_constants.dart';
import 'get_started.dart';

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
      home: const GetStartedPage(),
    );
  }
}
