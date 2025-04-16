import 'package:flutter/material.dart';

class CargoDetailsScreen extends StatefulWidget {
  const CargoDetailsScreen({super.key});

  @override
  State<CargoDetailsScreen> createState() => _CargoDetailsScreenState();
}

class _CargoDetailsScreenState extends State<CargoDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  String loadType = 'Fragile';
  TimeOfDay? pickupTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cargo Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(label: 'Load Name'),
              _buildTextField(
                  label: 'Load Weight (kg)',
                  keyboardType: TextInputType.number),
              _buildDropdown(),
              _buildTextField(label: 'Load Dimensions (optional)'),
              _buildTextField(label: 'Quantity of Vehicles'),
              _buildPhoneField(label: 'Sender Phone Number'),
              _buildPhoneField(label: 'Receiver Phone Number'),
              _buildTextField(label: 'Pickup Location'),
              _buildTextField(label: 'Destination Location'),
              _buildTimePicker(),
              _buildTextField(
                  label: 'Your Offer Fare (Rs)',
                  keyboardType: TextInputType.number),
              _buildCheckboxes(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Navigate to summary screen
                  }
                },
                child: const Text("Continue to Summary"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required String label,
      TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Required field' : null,
      ),
    );
  }

  Widget _buildPhoneField({required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
              child: _buildTextField(
                  label: label, keyboardType: TextInputType.phone)),
          IconButton(
            icon: const Icon(Icons.contacts),
            onPressed: () {
              // TODO: Open contact picker
            },
          )
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: loadType,
        items: ['Fragile', 'Heavy', 'Perishable', 'General Goods']
            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
            .toList(),
        onChanged: (value) => setState(() => loadType = value!),
        decoration: const InputDecoration(
          labelText: 'Load Type',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pickupTime == null
                  ? "Pickup Time: Not selected"
                  : "Pickup Time: ${pickupTime!.format(context)}",
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              TimeOfDay? time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                setState(() => pickupTime = time);
              }
            },
            child: const Text("Select Time"),
          ),
        ],
      ),
    );
  }

  bool isPassenger = false;
  bool isInsured = false;

  Widget _buildCheckboxes() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text("Ride as a Passenger"),
          value: isPassenger,
          onChanged: (value) => setState(() => isPassenger = value!),
        ),
        CheckboxListTile(
          title: const Text("Your Cargo is Insured"),
          value: isInsured,
          onChanged: (value) => setState(() => isInsured = value!),
        ),
      ],
    );
  }
}
