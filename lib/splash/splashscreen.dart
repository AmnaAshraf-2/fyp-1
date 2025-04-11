import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logistics_app/global/global.dart';
import 'package:logistics_app/screens/login.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  startTimer() {
    Timer(Duration(seconds: 3), () async {
      if (firebaseAuth.currentUser != null) {
        // User is logged in; navigate to main screen (replace with actual screen)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  login()), // Replace with your home screen if needed
        );
      } else {
        // User is not logged in; navigate to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => login()),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "logistics",
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
