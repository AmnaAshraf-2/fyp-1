import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:logistics_app/data/modals.dart';
import 'package:logistics_app/screens/users/customer/summary.dart';
import 'package:permission_handler/permission_handler.dart';

class CargoDetailsScreen extends StatefulWidget {
  final CargoDetails? initialData;
  const CargoDetailsScreen({super.key, this.initialData});

  @override
  State<CargoDetailsScreen> createState() => _CargoDetailsScreenState();
}

class _CargoDetailsScreenState extends State<CargoDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  String loadType = 'Fragile';
  String weightUnit = 'kg';
  bool _termsAgreed = false;
  TimeOfDay? pickupTime;

  // LatLng? pickupLocation;
  // LatLng? destinationLocation;

  // final _pickupController = TextEditingController();
  // final _destinationController = TextEditingController();
  final _loadNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _quantityController = TextEditingController();
  final _offerFareController = TextEditingController();
  // final _senderPhoneController = TextEditingController();
  // final _receiverPhoneController = TextEditingController();

  bool isPassenger = false;
  bool isInsured = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadNameController.text = widget.initialData!.loadName;
      _weightController.text = widget.initialData!.weight.toString();
      _quantityController.text = widget.initialData!.quantity.toString();
      _offerFareController.text = widget.initialData!.offerFare.toString();
      loadType = widget.initialData!.loadType;
      weightUnit = widget.initialData!.weightUnit;
      pickupTime = widget.initialData!.pickupTime;
      isInsured = widget.initialData!.isInsured;
    }
  }

  /*
  Future<void> _pickContact(TextEditingController controller) async {
    final permission = await Permission.contacts.request();
    if (permission.isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null && contact.phones.isNotEmpty) {
        controller.text = contact.phones.first.number;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied')),
      );
    }
  }

  Future<void> _selectLocation(BuildContext context, bool isPickup) async {
    final selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLocation: isPickup ? pickupLocation : destinationLocation,
        ),
      ),
    );

    if (selectedLocation != null) {
      final address = await _getAddress(selectedLocation);
      setState(() {
        if (isPickup) {
          pickupLocation = selectedLocation;
          _pickupController.text = address;
        } else {
          destinationLocation = selectedLocation;
          _destinationController.text = address;
        }
      });
    }
  }

  Future<String> _getAddress(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.first;
      return '${place.street}, ${place.locality}, ${place.postalCode}';
    } catch (_) {
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    }
  }
  */

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
              _buildTextField('Load Name', _loadNameController),
              _buildWeightField(),
              _buildDropdown(),
              _buildTextField('Load Dimensions (optional)', null),
              _buildTextField('Quantity of Vehicles', _quantityController,
                  TextInputType.number),
              // _buildPhoneField('Sender Phone Number', _senderPhoneController),
              // _buildPhoneField('Receiver Phone Number', _receiverPhoneController),
              // _buildLocationField('Pickup Location', _pickupController,
              //     () => _selectLocation(context, true)),
              // _buildLocationField(
              //     'Destination Location',
              //     _destinationController,
              //     () => _selectLocation(context, false)),
              _buildTimePicker(),
              _buildTextField('Your Offer Fare (Rs)', _offerFareController,
                  TextInputType.number),
              _buildCheckboxes(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onSubmit,
                child: const Text("Continue to Summary"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController? controller,
      [TextInputType inputType = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: (value) =>
            (controller != null && (value == null || value.isEmpty))
                ? 'Required'
                : null,
      ),
    );
  }

  /*
  Widget _buildPhoneField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
              child: _buildTextField(label, controller, TextInputType.phone)),
          IconButton(
            icon: const Icon(Icons.contacts),
            onPressed: () => _pickContact(controller),
          ),
        ],
      ),
    );
  }
  */

  Widget _buildWeightField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildTextField(
                'Load Weight', _weightController, TextInputType.number),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              key: const Key('unitDropdown'),
              value: weightUnit,
              onChanged: (value) => setState(() => weightUnit = value!),
              items: ['kg', 'tons']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              decoration: const InputDecoration(
                  labelText: 'Unit', border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: const Key('loadTypeDropdown'),
        value: loadType,
        onChanged: (value) => setState(() => loadType = value!),
        items: ['Fragile', 'Heavy', 'Perishable', 'General Goods']
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        decoration: const InputDecoration(
            labelText: 'Load Type', border: OutlineInputBorder()),
      ),
    );
  }

  /*
  Widget _buildLocationField(
      String label, TextEditingController controller, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(icon: const Icon(Icons.map), onPressed: onTap),
        ),
        validator: (value) =>
            (value == null || value.isEmpty) ? 'Required' : null,
        onTap: onTap,
      ),
    );
  }
  */

  Widget _buildTimePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(pickupTime == null
                ? 'Pickup Time: Not selected'
                : 'Pickup Time: ${pickupTime!.format(context)}'),
          ),
          ElevatedButton(
            onPressed: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                setState(() => pickupTime = time);
              }
            },
            child: const Text("Select Time"),
          )
        ],
      ),
    );
  }

  Widget _buildCheckboxes() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text("Your Cargo is Insured"),
          value: isInsured,
          onChanged: (value) {
            setState(() {
              isInsured = value ?? false;
              _termsAgreed = false;
            });
          },
        ),
        _buildPolicyCard(isInsured
            ? "Insured shipments are covered up to Rs. 500,000. Claims must be filed within 7 days of delivery."
            : "Uninsured shipments are transported at owner's risk. The company is not liable for any damages."),
      ],
    );
  }

  Widget _buildPolicyCard(String text) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            CheckboxListTile(
              title: const Text("I agree to the terms and conditions"),
              value: _termsAgreed,
              onChanged: (val) => setState(() => _termsAgreed = val ?? false),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the terms')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.trim());
    final quantity = int.tryParse(_quantityController.text.trim());
    final offerFare = double.tryParse(_offerFareController.text.trim());

    if (weight == null || quantity == null || offerFare == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid numeric values')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SummaryScreen(
          initialDetails: CargoDetails(
            loadName: _loadNameController.text.trim(),
            loadType: loadType,
            weight: weight,
            weightUnit: weightUnit,
            quantity: quantity,
            pickupTime: pickupTime,
            offerFare: offerFare,
            isInsured: isInsured,
          ),
        ),
      ),
    );
  }
}

/*
class MapPickerScreen extends StatelessWidget {
  final LatLng? initialLocation;
  const MapPickerScreen({super.key, this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a Location')),
      body: const Center(child: Text('Map integration here...')),
    );
  }
}
*/
