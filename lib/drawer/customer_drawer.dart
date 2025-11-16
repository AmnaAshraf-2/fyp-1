import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/drawer/base_drawer.dart';

class CustomerDrawer extends StatelessWidget {
  const CustomerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final menuItems = [
      DrawerMenuItem(
        icon: Icons.dashboard,
        title: loc.dashboard,
        onTap: () => Navigator.pushReplacementNamed(context, '/'),
        isSelected: true,
      ),
      DrawerMenuItem(
        icon: Icons.person,
        title: loc.profile,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile - Coming Soon')),
        ),
      ),
      DrawerMenuItem(
        icon: Icons.history,
        title: loc.bookingHistory,
        onTap: () => Navigator.pushNamed(context, '/pastBookings'),
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
      DrawerMenuItem(
        icon: Icons.info_outline,
        title: loc.about,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('About - Coming Soon')),
        ),
      ),
    ];

    return BaseDrawer(
      role: 'customer',
      roleLabel: loc.customer,
      menuItems: menuItems,
      headerColor1: Colors.blueAccent,
      headerColor2: Colors.blue,
    );
  }
}

