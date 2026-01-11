import 'package:flutter/material.dart';
import 'dart:async';
import 'bottom_nav_controller.dart';
import 'authentication/landing_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  double _logoOpacity = 0.0;
  double _taglineOpacity = 0.0;
  Offset _taglineOffset = const Offset(0, 0.5); // starts below

  @override
  void initState() {
    super.initState();

    // Logo fade-in
    Timer(const Duration(milliseconds: 200), () {
      setState(() {
        _logoOpacity = 1.0;
      });
    });

    // Tagline slide and fade
    Timer(const Duration(milliseconds: 1000), () {
      setState(() {
        _taglineOpacity = 1.0;
        _taglineOffset = const Offset(0, 0);
      });
    });

    // Navigate after splash
    Timer(const Duration(seconds: 5), () {
      final user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const BottomNavController(initialIndex: 0),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LandingPageScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ build is separate
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: _logoOpacity,
              duration: const Duration(seconds: 2),
              child: Image.asset(
                'assets/images/panen_app_logo.jpg',
                width: 250,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSlide(
              offset: _taglineOffset,
              duration: const Duration(seconds: 1),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _taglineOpacity,
                duration: const Duration(seconds: 1),
                child: const Text(
                  'Grow your idea.Harvest the future.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFF58C1D1)),
          ],
        ),
      ),
    );
  }
}
