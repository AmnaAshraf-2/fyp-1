import 'package:flutter/material.dart';
import 'package:logistics_app/screens/users/driver/driver_new_offers.dart';
import 'package:logistics_app/screens/users/driver/upcoming_trips.dart';
import 'package:logistics_app/screens/users/driver/driver_notifications.dart';
import 'package:logistics_app/drawer/driver_drawer.dart';
import 'package:logistics_app/screens/users/driver/driver_registration.dart';
import 'package:logistics_app/screens/users/driver/vehicle_info_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  bool _isCheckingRegistration = true;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
  }

  Future<void> _checkRegistrationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get();

      if (!userSnapshot.exists) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      final driverDetails = userData['driverDetails'];
      final vehicleInfo = userData['vehicleInfo'];
      final isProfileComplete = userData['isProfileComplete'] ?? false;

      // Check if both registration steps are complete
      if (driverDetails == null || vehicleInfo == null || !isProfileComplete) {
        // Redirect to appropriate registration step
        if (driverDetails == null || !isProfileComplete) {
          // Step 1 not complete
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverRegistration()),
          );
        } else {
          // Step 1 complete but Step 2 not complete
          final cnic = (driverDetails as Map)['cnic']?.toString() ?? '';
          final license = (driverDetails as Map)['licenseNumber']?.toString() ?? '';
          final phone = userData['phone']?.toString() ?? '';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VehicleInfoPage(
                cnic: cnic,
                license: license,
                phone: phone,
              ),
            ),
          );
        }
        return;
      }

      // Registration is complete, show dashboard
      setState(() {
        _isCheckingRegistration = false;
      });
    } catch (e) {
      // On error, show dashboard (to avoid blocking users)
      setState(() {
        _isCheckingRegistration = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRegistration) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      drawer: const DriverDrawer(),
      body: Column(
        children: [
          // Top Half - Teal Background
          Expanded(
            child: Container(
              color: const Color(0xFF004d4d),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Hamburger menu button (top left)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Builder(
                        builder: (context) => Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.menu, color: Color(0xFF004d4d), size: 24),
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          ),
                        ),
                      ),
                    ),
                    // Notification button (top right)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications, color: Color(0xFF004d4d), size: 24),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DriverNotificationsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // LAARI branding in center
                    const Center(
                      child: Text(
                        "LAARI",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Half - White Background with rounded top corners
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildOptionCard(
                      context,
                      title: "New Offers",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DriverNewOffersScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      context,
                      title: "Upcoming Trips",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UpcomingTripsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      context,
                      title: "Live Trip",
                      onTap: () {
                        // Navigate to live trip screen (placeholder for now)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Live Trip - Coming Soon')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF004d4d),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// Placeholder Pages
class UpcomingTripsPage extends StatelessWidget {
  const UpcomingTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Upcoming Trips")));
  }
}

class PastTripsPage extends StatelessWidget {
  const PastTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Past Trips")));
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Profile")));
  }
}


