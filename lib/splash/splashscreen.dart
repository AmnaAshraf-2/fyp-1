import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logistics_app/global/global.dart';
import 'package:logistics_app/screens/login.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    startTimer();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000), // 1 second for animation
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0), // Start in center
      end: Offset(0, -0.3), // Move up to match login screen position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0, // Start fully visible
      end: 1.0, // Stay visible throughout
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Start animation after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  startTimer() {
    Timer(Duration(seconds: 4), () async {
      // 4 seconds total duration (3 seconds static + 1 second animation)
      await _checkUserStatusAndNavigate();
    });
  }

  Future<void> _checkUserStatusAndNavigate() async {
    try {
      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      // If there's an error, go to login screen as fallback
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/p.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3), // Dark overlay for better text visibility
          ),
          child: Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                   
                    Text(
                      "LAARI",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "CALCULATE EVERY LOAD",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
