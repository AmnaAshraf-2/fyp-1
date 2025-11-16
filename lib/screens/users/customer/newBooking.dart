import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/data/vehicles.dart';

class NewBookingsScreen extends StatelessWidget {
  const NewBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!; // localization instance

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          loc.selectVehicle,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            itemCount: vehicleList.length,
            itemBuilder: (context, index) {
              final vehicle = vehicleList[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(
                    vehicle.getName(loc),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(vehicle.getCapacity(loc)),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
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
      ),
    );
  }
}
