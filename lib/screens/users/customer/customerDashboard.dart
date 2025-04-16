import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': loc.newBookings,
        'icon': Icons.add_box_outlined,
        'route': '/newBookings',
      },
      {
        'title': loc.liveTrip,
        'icon': Icons.directions_car,
        'route': '/liveTrip',
      },
      {
        'title': loc.upcomingBookings,
        'icon': Icons.schedule,
        'route': '/upcomingBookings',
      },
      {
        'title': loc.pastBookings,
        'icon': Icons.history,
        'route': '/pastBookings',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: Text(loc.dashboardTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: dashboardItems.map((item) {
            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, item['route']),
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
                    Icon(item['icon'], size: 50, color: Colors.blueAccent),
                    const SizedBox(height: 12),
                    Text(
                      item['title'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
