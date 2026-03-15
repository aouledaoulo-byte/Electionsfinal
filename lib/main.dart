import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() => runApp(const ElectionApp());

class ElectionApp extends StatelessWidget {
  const ElectionApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elections 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20), brightness: Brightness.light),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
