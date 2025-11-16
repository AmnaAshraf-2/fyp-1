import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/driver/driver_registration.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_details.dart';
import 'package:logistics_app/splash/welcome.dart';

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
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref('users/$uid');

      // Get existing user data to preserve name and phone
      final existingData = await ref.get();
      Map<String, dynamic> existingUserData = {};
      if (existingData.exists) {
        existingUserData = Map<String, dynamic>.from(existingData.value as Map);
      }

      // Update user info while preserving existing data
      await ref.update({
        "uid": uid,
        "email": user.email ?? "",
        "phone": existingUserData['phone'] ?? user.phoneNumber ?? "",
        "name": existingUserData['name'] ?? "",
        "role": role,
        "createdAt": ServerValue.timestamp,
        "isProfileComplete": role == "driver" ? false : true,
      });
    }

    // Navigate based on selected role
    if (role == "customer") {
      // Customer goes to welcome screen, then to customer dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else if (role == "driver") {
      // Driver goes to driver registration screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverRegistration()),
      );
    } else if (role == "enterprise") {
      // Enterprise goes to enterprise registration screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterpriseDetailsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/p.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), // Higher opacity than login (0.5 vs 0.4)
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Choose Your Role",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    color: Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        children: [
                          _buildRoleTile(AppLocalizations.of(context)!.customer, 'customer', Icons.person),
                          const Divider(height: 30, color: Color(0xFF004d4d)),
                          _buildRoleTile(AppLocalizations.of(context)!.driver, 'driver', Icons.drive_eta),
                          const Divider(height: 30, color: Color(0xFF004d4d)),
                          _buildRoleTile(AppLocalizations.of(context)!.enterprise, 'enterprise', Icons.business),
                        ],
                      ),
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

  Widget _buildRoleTile(String text, String role, IconData icon) {
    return ListTile(
      title: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          color: const Color(0xFF004d4d),
        ),
      ),
      leading: Icon(
        icon,
        color: const Color(0xFF004d4d),
        size: 24,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: const Color(0xFF004d4d),
        size: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      onTap: () => _saveRoleAndNavigate(role),
    );
  }
}
