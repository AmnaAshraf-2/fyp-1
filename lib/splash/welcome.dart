import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/main.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/driver/drivers.dart';
import 'package:logistics_app/screens/users/driver/driver_registration.dart';
import 'package:logistics_app/screens/users/driver/vehicle_info_page.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_details.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logistics_app/services/location_permission_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    // Show welcome screen for 2 seconds, then navigate
    await Future.delayed(const Duration(seconds: 2));
    await _navigateBasedOnRole();
  }

  Future<void> _navigateBasedOnRole() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    String languageCode = 'en';
    if (user != null) {
      languageCode = prefs.getString('languageCode_${user.uid}') ?? 'en';
    } else {
      languageCode = prefs.getString('languageCode') ?? 'en';
    }

    MyApp.setLocale(context, Locale(languageCode));

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final uid = user.uid;
    final userSnapshot = await FirebaseDatabase.instance.ref('users/$uid').get();

    if (!userSnapshot.exists) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
    final role = userData['role']?.toString();
    Widget screen;

    switch (role) {
      case 'customer':
        screen = const CustomerDashboard();
        break;
      case 'driver':
        // Check if driver registration is complete (both steps)
        final driverDetails = userData['driverDetails'];
        final vehicleInfo = userData['vehicleInfo'];
        final isProfileComplete = userData['isProfileComplete'] ?? false;
        
        // Driver must complete both registration steps:
        // Step 1: driverDetails (from DriverRegistration)
        // Step 2: vehicleInfo (from VehicleInfoPage)
        if (driverDetails != null && 
            vehicleInfo != null && 
            isProfileComplete == true) {
          // Request location permission for drivers (needed to show nearby customers)
          if (mounted && !kIsWeb) {
            final locationService = LocationPermissionService();
            await locationService.requestLocationPermission(context);
          }
          screen = const DriversScreen();
        } else {
          // If step 1 is complete but step 2 is not, navigate to vehicle info
          if (driverDetails != null && vehicleInfo == null) {
            // Need to get cnic and license from driverDetails for VehicleInfoPage
            final cnic = (driverDetails as Map)['cnic']?.toString() ?? '';
            final license = (driverDetails as Map)['licenseNumber']?.toString() ?? '';
            final phone = userData['phone']?.toString() ?? '';
            screen = VehicleInfoPage(
              cnic: cnic,
              license: license,
              phone: phone,
            );
          } else {
            // Step 1 not complete, go to driver registration
            screen = const DriverRegistration();
          }
        }
        break;
      case 'enterprise':
        // Check if enterprise registration is complete
        final enterpriseDetails = userData['enterpriseDetails'];
        final isProfileComplete = userData['isProfileComplete'] ?? false;
        
        if (enterpriseDetails != null && isProfileComplete == true) {
          // Request location permission for enterprises (needed to show nearby customers)
          if (mounted && !kIsWeb) {
            final locationService = LocationPermissionService();
            await locationService.requestLocationPermission(context);
          }
          screen = const EnterpriseDashboard();
        } else {
          screen = const EnterpriseDetailsScreen();
        }
        break;
      default:
        Navigator.pushReplacementNamed(context, '/login');
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    "Welcome Aboard!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "BOOK • TRACK • MANAGE",
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
    );
  }
}
