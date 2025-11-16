import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/drawer/base_drawer.dart';
import 'package:logistics_app/screens/users/driver/driver_new_offers.dart';
import 'package:logistics_app/screens/users/driver/upcoming_trips.dart';
import 'package:logistics_app/screens/users/driver/driver_notifications.dart';

class DriverDrawer extends StatelessWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final menuItems = [
      DrawerMenuItem(
        icon: Icons.dashboard,
        title: 'Dashboard',
        onTap: () => Navigator.pushReplacementNamed(context, '/driverDashboard'),
        isSelected: true,
      ),
      DrawerMenuItem(
        icon: Icons.local_offer,
        title: 'New Offers',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverNewOffersScreen()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.directions_bus,
        title: 'Upcoming Trips',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UpcomingTripsScreen()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.history,
        title: 'Past Trips',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PastTripsPage()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.person,
        title: loc.profile,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile - Coming Soon')),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.notifications,
        title: 'Notifications',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverNotificationsScreen()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.settings,
        title: loc.settings,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings - Coming Soon')),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.help_outline,
        title: loc.supportHelp,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support - Coming Soon')),
        ),
      ),
    ];

    return BaseDrawer(
      role: 'driver',
      roleLabel: loc.driver,
      menuItems: menuItems,
      headerColor1: Colors.blue,
      headerColor2: Colors.blue.shade700,
    );
  }
}

// Placeholder for PastTripsPage
class PastTripsPage extends StatelessWidget {
  const PastTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Past Trips", style: TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: const Center(child: Text("Past Trips - Coming Soon", style: TextStyle(color: Color(0xFF004d4d)))),
    );
  }
}

