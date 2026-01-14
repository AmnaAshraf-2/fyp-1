import 'package:flutter/material.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            dashboardCard(
              context,
              title: "Upcoming Trips",
              icon: Icons.directions_bus,
              page: const UpcomingTripsPage(),
            ),
            dashboardCard(
              context,
              title: "Past Trips",
              icon: Icons.history,
              page: const PastTripsPage(),
            ),
            dashboardCard(
              context,
              title: "Profile",
              icon: Icons.person,
              page: const ProfilePage(),
            ),
            dashboardCard(
              context,
              title: "New Offers",
              icon: Icons.local_offer,
              page: const OffersPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardCard(BuildContext context,
      {required String title, required IconData icon, required Widget page}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent, size: 32),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
      ),
    );
  }
}

// Placeholder Pages
class UpcomingTripsPage extends StatelessWidget {
  const UpcomingTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Upcoming Trips")));
  }
}

class PastTripsPage extends StatelessWidget {
  const PastTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Past Trips")));
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Profile")));
  }
}

class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("New Offers")));
  }
}
