import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/drawer/base_drawer.dart';
import 'package:logistics_app/screens/users/driver/driver_new_offers.dart';
import 'package:logistics_app/screens/users/driver/upcoming_trips.dart';
import 'package:logistics_app/screens/users/driver/past_trips.dart';
import 'package:logistics_app/screens/users/driver/driver_notifications.dart';

class DriverDrawer extends StatelessWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentRoute = ModalRoute.of(context)?.settings.name;

    final menuItems = [
      DrawerMenuItem(
        icon: Icons.dashboard,
        title: loc.dashboard,
        onTap: () {
          if (currentRoute != '/driverDashboard') {
            Navigator.pushReplacementNamed(context, '/driverDashboard');
          } else {
            Navigator.pop(context);
          }
        },
        isSelected: currentRoute == '/driverDashboard',
      ),
      DrawerMenuItem(
        icon: Icons.local_offer,
        title: loc.newOffers,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverNewOffersScreen()),
        ),
        isSelected: currentRoute == '/driverNewOffers',
      ),
      DrawerMenuItem(
        icon: Icons.directions_bus,
        title: loc.upcomingTrips,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UpcomingTripsScreen()),
        ),
        isSelected: currentRoute == '/driverUpcomingTrips',
      ),
      DrawerMenuItem(
        icon: Icons.history,
        title: loc.pastTrips,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PastTripsScreen()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.person,
        title: loc.profile,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.profileComingSoon)),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.notifications,
        title: loc.notifications,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverNotificationsScreen()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.settings,
        title: loc.settings,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.settingsComingSoon)),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.help_outline,
        title: loc.supportHelp,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.supportComingSoon)),
        ),
      ),
    ];

    return BaseDrawer(
      role: 'driver',
      roleLabel: loc.driver,
      menuItems: menuItems,
      headerColor1: const Color(0xFF006A6A),  // Deep Teal
      headerColor2: const Color(0xFF008B8B),  // Lighter Teal Shade
    );
  }
}


