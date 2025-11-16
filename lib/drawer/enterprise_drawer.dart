import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/drawer/base_drawer.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_vehicle_management.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_driver_management.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_new_offers.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_bookings.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_profile.dart';

class EnterpriseDrawer extends StatelessWidget {
  const EnterpriseDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final menuItems = [
      DrawerMenuItem(
        icon: Icons.dashboard,
        title: loc.enterpriseDashboard,
        onTap: () => Navigator.pushReplacementNamed(context, '/enterpriseDashboard'),
        isSelected: true,
      ),
      DrawerMenuItem(
        icon: Icons.local_offer,
        title: 'New Offers',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnterpriseNewOffersScreen()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.directions_bus,
        title: 'Bookings',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnterpriseBookingsScreen()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.local_shipping,
        title: 'Vehicle Management',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnterpriseVehicleManagement()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.people,
        title: 'Driver Management',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnterpriseDriverManagement()),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.person,
        title: loc.profile,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnterpriseProfileScreen()),
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
      role: 'enterprise',
      roleLabel: loc.enterprise,
      menuItems: menuItems,
      headerColor1: Colors.green,
      headerColor2: Colors.green.shade700,
    );
  }
}

