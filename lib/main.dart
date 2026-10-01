import 'package:flutter/material.dart';
import 'get_started.dart';

void main() {
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