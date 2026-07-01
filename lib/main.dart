import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BirdRecognitionApp());
}

class BirdRecognitionApp extends StatelessWidget {
  const BirdRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bird Recognition',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5), 
          brightness: Brightness.dark,
          primary: const Color(0xFF2E7D32), 
          secondary: const Color(0xFF81C784),
          surface: const Color(0xFF121212),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F1714), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
