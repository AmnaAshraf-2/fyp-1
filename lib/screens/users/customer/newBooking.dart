// lib/screens/new_bookings_screen.dart

import 'package:flutter/material.dart';
import 'package:logistics_app/data/vehicles.dart';

class NewBookingsScreen extends StatelessWidget {
  const NewBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select a Vehicle')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: vehicleList.length,
          itemBuilder: (context, index) {
            final vehicle = vehicleList[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: ListTile(
                //leading: Image.asset(vehicle.image, width: 50),
                title: Text(vehicle.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(vehicle.capacity),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to cargo details screen with selected vehicle
                  Navigator.pushNamed(
                    context,
                    '/cargo-details',
                    arguments: vehicle,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
