import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/drivers.dart';
import 'package:logistics_app/screens/users/enterprise.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  Future<void> _saveRoleAndNavigate(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role);

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance.ref().child('users/${user.uid}').update({
        'role': role,
      });
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _getScreenForRole(role)),
    );
  }

  Widget _getScreenForRole(String role) {
    switch (role) {
      case 'customer':
        return const CustomerDashboard();
      case 'driver':
        return const DriversScreen();
      case 'enterprise':
        return const EnterpriseScreen();
      default:
        return const RoleScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: Stack(
        children: [
          // Background circles
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.orange.shade100.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Logistics Guru",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppLocalizations.of(context)!.chooseRole,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildRoleButton(
                      AppLocalizations.of(context)!.customer, 'customer'),
                  const SizedBox(height: 20),
                  _buildRoleButton(
                      AppLocalizations.of(context)!.driver, 'driver'),
                  const SizedBox(height: 20),
                  _buildRoleButton(
                      AppLocalizations.of(context)!.enterprise, 'enterprise'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String text, String role) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        onPressed: () => _saveRoleAndNavigate(role),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
