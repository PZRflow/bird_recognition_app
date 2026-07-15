import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'features/home/home_screen.dart';

class BirdRecognitionApp extends StatefulWidget {
  const BirdRecognitionApp({super.key});

  // ignore: library_private_types_in_public_api
  static _BirdRecognitionAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_BirdRecognitionAppState>();

  @override
  State<BirdRecognitionApp> createState() => _BirdRecognitionAppState();
}

class _BirdRecognitionAppState extends State<BirdRecognitionApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _locale,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1A15), // Deep dark green/black
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676), // Vibrant Neon Green
          secondary: Color(0xFF1DE9B6), // Teal accent
          surface: Color(0xFF1B2A22),
          onPrimary: Colors.black,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            elevation: 8,
            shadowColor: const Color(0xFF00E676).withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
