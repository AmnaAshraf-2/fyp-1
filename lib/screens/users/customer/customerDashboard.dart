import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../drawer/drawer.dart';

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
        'icon': Icons.add_box_outlined,
        'route': '/newBookings',
        'color': Colors.blue,
      },
      {
        'title': loc.liveTrip,
        'icon': Icons.directions_car,
        'route': '/liveTrip',
        'color': Colors.green,
      },
      {
        'title': loc.upcomingBookings,
        'icon': Icons.schedule,
        'route': '/upcomingBookings',
        'color': Colors.orange,
      },
      {
        'title': loc.pastBookings,
        'icon': Icons.history,
        'route': '/pastBookings',
        'color': Colors.purple,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        title: Text(
          loc.dashboardTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: AppDrawer(userName: _fullName, profileImageUrl: _profileImage),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "${'Welcome'}, 👋",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Dashboard Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                itemCount: dashboardItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final item = dashboardItems[index];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, item['route']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            item['color'].withOpacity(0.8),
                            item['color'].withOpacity(0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: item['color'].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: Icon(
                              item['icon'],
                              size: 32,
                              color: item['color'],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
