import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poultry_pal_plus_app/screens/login_screen.dart';
import 'package:poultry_pal_plus_app/screens/home_screen.dart';
import '../service/poultry_pal_service.dart';

class SplashScreen extends StatefulWidget {
    const SplashScreen({super.key});

    @override
    _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _animation;
    final PoultryPalService _service = PoultryPalService();// ✅ Your login service

    @override
    void initState() {
        super.initState();
        _controller = AnimationController(
            duration: const Duration(seconds: 3),
            vsync: this,
        );
        _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

        _controller.addStatusListener((status) {
                if (status == AnimationStatus.completed) {
                    _checkLoginStatus();
                }
            });

        _controller.forward();
    }

    Future<void> _checkLoginStatus() async {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('saved_email');
        final password = prefs.getString('saved_password');
        final remember = prefs.getBool('remember_me') ?? false;

        if (remember && email != null && password != null) {
            try {
                await _service.login(email, password);

                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
            } catch (e) {
                // Login failed → go to Login
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
            }
        } else {
            // No saved credentials → go to Login
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: AppColors.surfaceLight,
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                                return Transform.translate(
                                    offset: Offset(0, _animation.value * 50),
                                    child: Image.asset(
                                        'assets/icon.png',
                                        width: 192,
                                        height: 192,
                                    ),
                                );
                            },
                        ),
                        const SizedBox(height: 5),
                        Text(
                            'Poultry Pal Plus',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: AppColors.adaptivePrimary(context),
                                shadows: [
                                    Shadow(
                                        color: Colors.black.withOpacity(1),
                                        offset: const Offset(1, 1),
                                        blurRadius: 5,
                                    ),
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    @override
    void dispose() {
        _controller.dispose();
        super.dispose();
    }
}
