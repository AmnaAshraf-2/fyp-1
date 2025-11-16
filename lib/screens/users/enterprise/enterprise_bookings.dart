import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EnterpriseBookingsScreen extends StatefulWidget {
  const EnterpriseBookingsScreen({super.key});

  @override
  State<EnterpriseBookingsScreen> createState() => _EnterpriseBookingsScreenState();
}

class _EnterpriseBookingsScreenState extends State<EnterpriseBookingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bookings', style: TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF004d4d),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'New'),
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent('New Bookings', 'New booking requests will appear here', Icons.new_releases),
          _buildTabContent('Active Bookings', 'Currently active bookings will appear here', Icons.play_circle),
          _buildTabContent('Pending Bookings', 'Pending booking confirmations will appear here', Icons.schedule),
        ],
      ),
    );
  }

  Widget _buildTabContent(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF004d4d),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF004d4d),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
