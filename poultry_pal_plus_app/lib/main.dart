import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/screens/splash_screen.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poultry Pal Plus',
      theme: ThemeData(
        fontFamily: 'Roboto',

        primaryColor: Colors.brown[900], // Primary color
        primaryColorLight: Colors.brown[50], // Light variant
        primaryColorDark: Colors.brown[900], // Dark variant
        scaffoldBackgroundColor: Colors.white, // Background color
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Colors.brown[900],
          secondary: Colors.green, // Secondary color
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
