import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../drawer/customer_drawer.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  String _fullName = "Guest User";
  String? _profileImage;

  @override
  void initState() {
    super.initState();
    _populateUserData(); // <-- call here
  }

  Future<void> _populateUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load name & profile image for drawer
    setState(() {
      _fullName = prefs.getString('full_name') ?? "Guest User";
      _profileImage = prefs.getString('profile_image');
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': loc.newBookings,
        'route': '/newBookings',
      },
      {
        'title': loc.liveTrip,
        'route': '/liveTrip',
      },
      {
        'title': loc.upcomingBookings,
        'route': '/upcomingBookings',
      },
    ];

    return Scaffold(
      drawer: const CustomerDrawer(),
      body: Column(
        children: [
          // Top Half - Header with LAARI
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            color: const Color(0xFF004d4d),
            child: SafeArea(
              child: Stack(
                children: [
                  // Centered LAARI text
                  Center(
                    child: const Text(
                      'LAARI',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 52,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  // Hamburger menu button
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white, size: 32),
                        iconSize: 32,
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ),
                  // Notification button
                  Positioned(
                    right: 16,
                    top: 16,
                    child: IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.white, size: 32),
                      iconSize: 32,
                      onPressed: () => Navigator.pushNamed(context, '/customerNotifications'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Half - Options with rounded top edges
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: dashboardItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, item['route']),
                        child: Text(
                          item['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF004d4d),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
