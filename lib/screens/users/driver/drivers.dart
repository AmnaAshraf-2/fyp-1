import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logistics_app/screens/users/driver/driver_new_offers.dart';
import 'package:logistics_app/screens/users/driver/upcoming_trips.dart';
import 'package:logistics_app/screens/users/driver/driver_notifications.dart';
import 'package:logistics_app/screens/users/driver/driver_live_trip.dart';
import 'package:logistics_app/drawer/driver_drawer.dart';
import 'package:logistics_app/screens/users/driver/driver_registration.dart';
import 'package:logistics_app/screens/users/driver/vehicle_info_page.dart';
import 'package:logistics_app/services/location_permission_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> with SingleTickerProviderStateMixin {
  bool _isCheckingRegistration = true;
  String _fullName = "";
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
    _populateUserData();
    _requestLocationPermission();

    // Simple fade-in animation for header
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  /// Request location permission when driver logs in
  Future<void> _requestLocationPermission() async {
    // Wait a bit for the screen to be fully built
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      final permissionService = LocationPermissionService();
      await permissionService.requestLocationPermission(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _populateUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await FirebaseDatabase.instance.ref("users/${user.uid}").get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          _fullName = data['name'] ?? data['full_name'] ?? "";
        });
      }
    }
    // If name is still empty, it will be set in build method
  }

  Future<void> _checkRegistrationStatus() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });
    return;
  }

  try {
    final userSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').get();

    if (!userSnapshot.exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }

    final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
    final driverDetails = userData['driverDetails'];
    final vehicleInfo = userData['vehicleInfo'];
    final isProfileComplete = userData['isProfileComplete'] ?? false;

    // Check if both registration steps are complete
    if (driverDetails == null || vehicleInfo == null || !isProfileComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (driverDetails == null || !isProfileComplete) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverRegistration()),
          );
        } else {
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
      });
      return;
    }

    setState(() {
      _isCheckingRegistration = false;
    });
  } catch (e) {
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

    final t = AppLocalizations.of(context)!;
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': t.newOffers,
        'route': null,
        'icon': Icons.local_offer,
        'color': Colors.blue,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverNewOffersScreen(),
            ),
          );
        },
      },
      {
        'title': t.upcomingTrips,
        'route': null,
        'icon': Icons.schedule,
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UpcomingTripsScreen(),
            ),
          );
        },
      },
      {
        'title': t.liveTrip,
        'route': null,
        'icon': Icons.directions_car,
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverLiveTripScreen(),
            ),
          );
        },
      },
    ];

    return Scaffold(
      drawer: const DriverDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header with curved design
            Stack(
              children: [
                ClipPath(
                  clipper: HeaderClipper(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.35,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF004d4d), Color(0xFF007373)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white, size: 30),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: IconButton(
                    icon: const Icon(Icons.notifications,
                        color: Colors.white, size: 30),
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
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const Center(
                        child: Text(
                          'LAARI',
                          style: TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          '${t.welcome}, ${_fullName.isEmpty ? t.guestDriver : _fullName}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black38,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Bottom List Dashboard
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ListView.builder(
                  itemCount: dashboardItems.length,
                  itemBuilder: (context, index) {
                    final item = dashboardItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GestureDetector(
                        onTap: item['onTap'],
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.4),
                                    Colors.white.withOpacity(0.1)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: item['color'].withOpacity(0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: item['color'].withOpacity(0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: item['color'].withOpacity(0.15),
                                    ),
                                    child: Icon(
                                      item['icon'],
                                      size: 32,
                                      color: item['color'],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Text(
                                      item['title'],
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 20,
                                    color: item['color'],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// Custom clipper for curved header
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Placeholder Pages
class UpcomingTripsPage extends StatelessWidget {
  const UpcomingTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.upcomingTrips)));
  }
}

class PastTripsPage extends StatelessWidget {
  const PastTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.pastTrips)));
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(appBar: AppBar(title: Text(t.profile)));
  }
}


