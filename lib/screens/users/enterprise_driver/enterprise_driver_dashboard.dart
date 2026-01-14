import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:logistics_app/screens/users/driver/upcoming_trips.dart';
import 'package:logistics_app/screens/users/driver/driver_notifications.dart';
import 'package:logistics_app/screens/users/driver/driver_live_trip.dart';
import 'package:logistics_app/drawer/driver_drawer.dart';
import 'package:logistics_app/screens/users/enterprise_driver/enterprise_driver_assignments.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/location_permission_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EnterpriseDriverDashboard extends StatefulWidget {
  const EnterpriseDriverDashboard({super.key});

  @override
  State<EnterpriseDriverDashboard> createState() => _EnterpriseDriverDashboardState();
}

class _EnterpriseDriverDashboardState extends State<EnterpriseDriverDashboard> with SingleTickerProviderStateMixin {
  String _fullName = "";
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int _pendingAssignmentsCount = 0;
  StreamSubscription? _assignmentsSubscription;

  @override
  void initState() {
    super.initState();
    _populateUserData();
    _requestLocationPermission();
    _loadPendingAssignmentsCount();

    // Simple fade-in animation for header
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _assignmentsSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _loadPendingAssignmentsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _assignmentsSubscription = FirebaseDatabase.instance
        .ref('enterprise_driver_assignments/${user.uid}')
        .orderByChild('status')
        .equalTo('pending')
        .onValue
        .listen((event) {
      if (mounted) {
        int count = 0;
        if (event.snapshot.exists) {
          count = event.snapshot.children.length;
        }
        setState(() {
          _pendingAssignmentsCount = count;
        });
      }
    });
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
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': '${t.newAssignments}${_pendingAssignmentsCount > 0 ? ' ($_pendingAssignmentsCount)' : ''}',
        'route': null,
        'icon': Icons.assignment,
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EnterpriseDriverAssignmentsScreen(),
            ),
          ).then((_) {
            // Reload count when returning from assignments screen
            _loadPendingAssignmentsCount();
          });
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
        'color': Colors.green,
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
                          '${t.welcome}, ${_fullName.isEmpty ? t.enterpriseDriver : _fullName}',
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t.enterpriseDriver,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
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

