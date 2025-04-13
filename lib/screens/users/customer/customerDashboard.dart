import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Placeholder Screens (replace with actual screens later)
class NewBookingsScreen extends StatelessWidget {
  const NewBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.newBookings)),
      body: const Center(child: Text('New Bookings Screen')),
    );
  }
}

class LiveTripScreen extends StatelessWidget {
  const LiveTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.liveTrip)),
      body: const Center(child: Text('Live Trip Screen')),
    );
  }
}

class UpcomingBookingsScreen extends StatelessWidget {
  const UpcomingBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(AppLocalizations.of(context)!.upcomingBookings)),
      body: const Center(child: Text('Upcoming Bookings Screen')),
    );
  }
}

class PastBookingsScreen extends StatelessWidget {
  const PastBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.pastBookings)),
      body: const Center(child: Text('Past Bookings Screen')),
    );
  }
}

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  void navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final List<_DashboardItem> dashboardItems = [
      _DashboardItem(
        title: loc.newBookings,
        icon: Icons.add_box_outlined,
        onTap: () => navigateTo(context, const NewBookingsScreen()),
      ),
      _DashboardItem(
        title: loc.liveTrip,
        icon: Icons.directions_car,
        onTap: () => navigateTo(context, const LiveTripScreen()),
      ),
      _DashboardItem(
        title: loc.upcomingBookings,
        icon: Icons.schedule,
        onTap: () => navigateTo(context, const UpcomingBookingsScreen()),
      ),
      _DashboardItem(
        title: loc.pastBookings,
        icon: Icons.history,
        onTap: () => navigateTo(context, const PastBookingsScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(loc.dashboardTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: dashboardItems.map((item) => _buildCard(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildCard(_DashboardItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 50, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _DashboardItem(
      {required this.title, required this.icon, required this.onTap});
}
