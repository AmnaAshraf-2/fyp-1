import 'package:flutter/material.dart';
import 'package:logistics_app/data/modals.dart';
import 'cargoDetails.dart'; // Your existing screen

class SummaryScreen extends StatefulWidget {
  final CargoDetails initialDetails;

  const SummaryScreen({super.key, required this.initialDetails});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late CargoDetails _currentDetails;

  @override
  void initState() {
    super.initState();
    _currentDetails = widget.initialDetails;
  }

  Future<void> _editDetails() async {
    final result = await Navigator.push<CargoDetails>(
      context,
      MaterialPageRoute(
        builder: (context) => CargoDetailsScreen(
          initialData: _currentDetails,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentDetails = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Summary"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editDetails,
            tooltip: 'Edit All Details',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildSummaryItem('Load Name', _currentDetails.loadName),
                  _buildSummaryItem('Load Type', _currentDetails.loadType),
                  _buildSummaryItem(
                    'Load Weight',
                    '${_currentDetails.weight} ${_currentDetails.weightUnit}',
                  ),
                  _buildSummaryItem(
                      'Quantity', _currentDetails.quantity.toString()),
                  _buildSummaryItem(
                    'Pickup Time',
                    _currentDetails.pickupTime?.format(context) ??
                        'Not selected',
                  ),
                  _buildSummaryItem(
                      'Offered Fare', 'Rs ${_currentDetails.offerFare}'),
                  _buildSummaryItem(
                    'Insurance Status',
                    _currentDetails.isInsured ? 'Insured' : 'Uninsured',
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  Text(
                    'Terms Agreement: ${_currentDetails.isInsured ? 'Insured Policy Accepted' : 'Uninsured Policy Accepted'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Implement booking submission logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking confirmed!')),
                );
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("Send Request"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        "$title: $value",
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
