import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/main.dart';
import 'package:logistics_app/screens/language.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/drivers.dart';
import 'package:logistics_app/screens/users/enterprise.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    startTimer();
  }

  Future<void> startTimer() async {
    await Future.delayed(const Duration(seconds: 2));
    await _navigateBasedOnRole();
  }

  Future<void> _navigateBasedOnRole() async {
    final prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('languageCode') ?? 'en';

    // Apply saved language
    MyApp.setLocale(context, Locale(languageCode));

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No user is signed in, go to Language screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
      );
      return;
    }

    final uid = user.uid;
    final snapshot =
        await FirebaseDatabase.instance.ref('users/$uid/role').get();

    if (!snapshot.exists) {
      // Role not set, go to Role selection screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
      );
      return;
    }

    final role = snapshot.value.toString();
    Widget screen;

    switch (role) {
      case 'customer':
        screen = const CustomerDashboard();
        break;
      case 'driver':
        screen = const DriversScreen();
        break;
      case 'enterprise':
        screen = const EnterpriseScreen();
        break;
      default:
        screen = const LanguageSettingsScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome aboard!",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Plan, track, and manage logistics with ease.",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
