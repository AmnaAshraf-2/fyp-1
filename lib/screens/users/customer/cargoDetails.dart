import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:logistics_app/data/modals.dart';
import 'package:logistics_app/data/vehicles.dart';
import 'package:logistics_app/screens/users/customer/summary.dart';
import 'package:logistics_app/screens/users/customer/location_map_view.dart';
import 'package:logistics_app/screens/users/customer/location_picker_screen.dart';
import 'package:logistics_app/services/fare_calculator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CargoDetailsScreen extends StatefulWidget {
  final CargoDetails? initialData;
  const CargoDetailsScreen({super.key, this.initialData});

  @override
  State<CargoDetailsScreen> createState() => _CargoDetailsScreenState();
}

class _CargoDetailsScreenState extends State<CargoDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  // ✅ Use internal keys instead of localized text
  String loadType = 'fragile';
  String weightUnit = 'kg';
  String vehicleType = 'Suzuki Pickup'; // Default vehicle type
  bool _termsAgreed = false;
  TimeOfDay? pickupTime;

  final _loadNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _quantityController = TextEditingController(text: '1'); // Default to 1
  final _offerFareController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _destinationLocationController = TextEditingController();

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
      _senderPhoneController.text = widget.initialData!.senderPhone;
      _receiverPhoneController.text = widget.initialData!.receiverPhone;
      _pickupLocationController.text = widget.initialData!.pickupLocation;
      _destinationLocationController.text = widget.initialData!.destinationLocation;
      loadType = widget.initialData!.loadType;
      weightUnit = widget.initialData!.weightUnit;
      vehicleType = widget.initialData!.vehicleType;
      pickupTime = widget.initialData!.pickupTime;
      isInsured = widget.initialData!.isInsured;
    }
    
    // Add listeners to auto-calculate fare when key fields change
    _pickupLocationController.addListener(_autoCalculateFare);
    _destinationLocationController.addListener(_autoCalculateFare);
    _weightController.addListener(_autoCalculateFare);
    _weightController.addListener(_onWeightChanged);
  }

  @override
  void dispose() {
    _pickupLocationController.removeListener(_autoCalculateFare);
    _destinationLocationController.removeListener(_autoCalculateFare);
    _weightController.removeListener(_autoCalculateFare);
    _weightController.removeListener(_onWeightChanged);
    super.dispose();
  }

  void _onWeightChanged() {
    // Trigger validation when weight changes
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
  }

  // Get the maximum capacity of the selected vehicle
  double? _getVehicleMaxCapacity() {
    final loc = AppLocalizations.of(context)!;
    for (Vehicle vehicle in vehicleList) {
      if (vehicle.getName(loc) == vehicleType) {
        String capacityText = vehicle.getCapacity(loc);
        // Extract numeric value from capacity text
        RegExp regex = RegExp(r'(\d+(?:,\d+)*(?:\.\d+)?)');
        Match? match = regex.firstMatch(capacityText);
        if (match != null) {
          String numberStr = match.group(1)!.replaceAll(',', '');
          double? capacity = double.tryParse(numberStr);
          if (capacity != null) {
            // Convert to kg if the capacity is in tons or other units
            if (capacityText.toLowerCase().contains('ton')) {
              return capacity * 1000; // Convert tons to kg
            } else if (capacityText.toLowerCase().contains('liter')) {
              // For liquid capacity, assume 1 liter = 1 kg for simplicity
              return capacity;
            } else {
              // Assume it's already in kg
              return capacity;
            }
          }
        }
        break;
      }
    }
    return null; // Return null if vehicle not found or capacity can't be parsed
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get vehicle type from route arguments after context is ready
    if (widget.initialData == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Vehicle) {
        final loc = AppLocalizations.of(context)!;
        vehicleType = args.getName(loc);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // ✅ Map of internal keys to localized labels
    final Map<String, String> loadTypeLabels = {
      'fragile': t.fragile,
      'heavy': t.heavy,
      'perishable': t.perishable,
      'general': t.generalGoods,
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          t.cargoDetails,
          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.teal),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
               _buildTextField(t.loadName, _loadNameController),
               _buildWeightField(t),
               _buildDropdown(t, loadTypeLabels),
               _buildTextField(t.loadDimensions, null, TextInputType.text, false),
               _buildPhoneField(t.senderPhoneNumber, _senderPhoneController),
               _buildPhoneField(t.receiverPhoneNumber, _receiverPhoneController),
               _buildLocationField(t.pickupLocation, _pickupLocationController),
               _buildLocationField(t.destinationLocation, _destinationLocationController),
               _buildTextField(
                   t.quantityOfVehicles, _quantityController, TextInputType.number, true),
               _buildTimePicker(t),
              _buildFareField(t),
              _buildCheckboxes(t),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    t.continueToSummary,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController? controller,
      [TextInputType inputType = TextInputType.text, bool isRequired = true]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.teal),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(color: Colors.black87),
        validator: (value) =>
            (controller != null && isRequired && (value == null || value.isEmpty))
                ? AppLocalizations.of(context)!.required
                : null,
      ),
    );
  }

  Widget _buildPhoneField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.teal),
                hintText: 'e.g., 03001234567',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                prefixIcon: const Icon(Icons.phone, color: Colors.teal),
                helperText: 'Format: 03XX-XXXXXXX or 0XXX-XXXXXXX',
                helperMaxLines: 2,
                helperStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(color: Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.required;
                }
                return _validatePhoneNumber(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal, width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.contacts, color: Colors.teal),
              onPressed: () => _pickContact(controller),
              tooltip: 'Select from contacts',
            ),
          ),
        ],
      ),
    );
  }

  String? _validatePhoneNumber(String phoneNumber) {
    // Remove any spaces, dashes, or other formatting
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Check if empty
    if (cleaned.isEmpty) {
      return 'Phone number is required';
    }
    
    // Check if it contains only digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Phone number must contain only digits';
    }
    
    // Check if it starts with 0
    if (!cleaned.startsWith('0')) {
      return 'Phone number must start with 0';
    }
    
    // Check for valid length (Pakistani numbers are 11 digits)
    if (cleaned.length != 11) {
      return 'Phone number must be exactly 11 digits (e.g., 03001234567)';
    }
    
    // Validate Pakistani mobile number prefixes (03XX, 04XX, 05XX)
    String prefix = cleaned.substring(0, 2);
    String firstFour = cleaned.substring(0, 4);
    
    // Validate mobile number prefixes
    if (prefix == '03') {
      // Check if it's a valid 03XX prefix (0300-0399)
      int prefixNum = int.tryParse(firstFour) ?? 0;
      if (prefixNum < 300 || prefixNum > 399) {
        return 'Invalid mobile number prefix. Must be 03XX (e.g., 0300-0399)';
      }
    } else if (prefix == '04') {
      // Check if it's a valid 04XX prefix (0400-0499)
      int prefixNum = int.tryParse(firstFour) ?? 0;
      if (prefixNum < 400 || prefixNum > 499) {
        return 'Invalid mobile number prefix. Must be 04XX (e.g., 0400-0499)';
      }
    } else if (prefix == '05') {
      // Check if it's a valid 05XX prefix (0500-0599)
      int prefixNum = int.tryParse(firstFour) ?? 0;
      if (prefixNum < 500 || prefixNum > 599) {
        return 'Invalid mobile number prefix. Must be 05XX (e.g., 0500-0599)';
      }
    } else if (prefix == '02' || prefix == '01') {
      // Landline numbers (021, 022, etc.) - allow them
      return null; // Valid landline number
    } else {
      return 'Invalid phone number format. Must start with 03, 04, or 05 for mobile numbers';
    }
    
    // Additional check: Ensure the remaining digits are valid (7 digits after prefix)
    String remainingDigits = cleaned.substring(4);
    if (remainingDigits.length != 7) {
      return 'Invalid phone number format. After prefix, must have 7 digits';
    }
    
    // Check if remaining digits are all the same (likely invalid, e.g., 0000000, 1111111)
    if (RegExp(r'^(\d)\1{6}$').hasMatch(remainingDigits)) {
      return 'Phone number appears to be invalid (all digits are the same)';
    }
    
    // Check if remaining digits are all zeros
    if (remainingDigits == '0000000') {
      return 'Phone number appears to be invalid';
    }
    
    return null; // Valid phone number
  }

  Widget _buildLocationField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => LocationPickerScreen(
                title: label,
                initialValue: controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : null,
              ),
            ),
          );

          if (result != null && mounted) {
            controller.text = result;
            // Trigger validation
            _formKey.currentState?.validate();
            // Trigger fare calculation if needed
            _autoCalculateFare();
          }
        },
        child: TextFormField(
          controller: controller,
          enabled: false,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.teal),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.teal),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.teal, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.teal, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.location_on, color: Colors.teal),
            suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
            hintText: 'Tap to choose location',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(color: Colors.black87),
          validator: (value) =>
              (value == null || value.isEmpty) ? AppLocalizations.of(context)!.required : null,
        ),
      ),
    );
  }

  Widget _buildWeightField(AppLocalizations t) {
    final maxCapacity = _getVehicleMaxCapacity();
    final maxCapacityInSelectedUnit = maxCapacity != null
        ? (weightUnit == 'tons' ? maxCapacity / 1000 : maxCapacity)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                // Prevent entering values that exceed capacity
                if (maxCapacityInSelectedUnit != null)
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) {
                      return newValue;
                    }
                    final enteredValue = double.tryParse(newValue.text);
                    if (enteredValue != null && enteredValue > maxCapacityInSelectedUnit) {
                      // Show error but allow typing (validation will catch it)
                      return newValue;
                    }
                    return newValue;
                  }),
              ],
              decoration: InputDecoration(
                labelText: t.loadWeight,
                labelStyle: const TextStyle(color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                helperText: _getWeightHelperText(),
                helperMaxLines: 2,
                errorMaxLines: 3,
                helperStyle: const TextStyle(color: Colors.grey),
                suffixText: weightUnit,
                suffixStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(color: Colors.black87),
              onChanged: (value) {
                // Update helper text and trigger validation in real-time
                setState(() {
                  // Helper text will update automatically via _getWeightHelperText()
                });
                if (_formKey.currentState != null) {
                  _formKey.currentState!.validate();
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return t.required;
                }
                
                final weight = double.tryParse(value);
                if (weight == null || weight <= 0) {
                  return 'Please enter a valid weight';
                }
                
                // Check if weight exceeds vehicle capacity
                if (maxCapacity != null) {
                  double weightInKg = weight;
                  if (weightUnit == 'tons') {
                    weightInKg = weight * 1000; // Convert tons to kg
                  }
                  
                  if (weightInKg > maxCapacity) {
                    return 'Weight exceeds vehicle capacity!\nMaximum: ${maxCapacity.toInt()} kg (${(maxCapacity / 1000).toStringAsFixed(1)} tons)';
                  }
                  
                  // Warn if approaching capacity (within 10%)
                  if (weightInKg > maxCapacity * 0.9) {
                    // This is just a warning, not an error
                    // We'll show it in helper text instead
                  }
                }
                
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              key: const Key('unitDropdown'),
              value: weightUnit,
              onChanged: (value) {
                setState(() {
                  weightUnit = value!;
                  // Helper text will update automatically via _getWeightHelperText()
                });
                // Trigger validation when unit changes
                _formKey.currentState?.validate();
              },
              items: ['kg', 'tons']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              decoration: InputDecoration(
                labelText: t.unit,
                labelStyle: const TextStyle(color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87),
              iconEnabledColor: Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  String _getWeightHelperText() {
    final maxCapacity = _getVehicleMaxCapacity();
    if (maxCapacity != null) {
      final currentWeight = double.tryParse(_weightController.text);
      if (currentWeight != null) {
        double weightInKg = currentWeight;
        if (weightUnit == 'tons') {
          weightInKg = currentWeight * 1000;
        }
        
        if (weightInKg > maxCapacity) {
          return '⚠️ Exceeds capacity! Max: ${maxCapacity.toInt()} kg';
        } else if (weightInKg > maxCapacity * 0.9) {
          return '⚠️ Approaching capacity limit. Max: ${maxCapacity.toInt()} kg';
        } else {
          final remaining = maxCapacity - weightInKg;
          return 'Maximum capacity: ${maxCapacity.toInt()} kg (${remaining.toInt()} kg remaining)';
        }
      }
      return 'Maximum capacity: ${maxCapacity.toInt()} kg (${(maxCapacity / 1000).toStringAsFixed(1)} tons)';
    }
    return '';
  }

  Widget _buildDropdown(AppLocalizations t, Map<String, String> loadTypeLabels) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        key: const Key('loadTypeDropdown'),
        value: loadType,
        onChanged: (value) => setState(() => loadType = value!),
        items: loadTypeLabels.entries.map((entry) {
          return DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: t.loadType,
          labelStyle: const TextStyle(color: Colors.teal),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(color: Colors.black87),
        iconEnabledColor: Colors.teal,
      ),
    );
  }

  Widget _buildTimePicker(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pickupTime == null
                    ? t.pickupTimeNotSelected
                    : '${t.pickupTime}: ${pickupTime!.format(context)}',
                style: TextStyle(
                  color: pickupTime == null ? Colors.grey : Colors.black87,
                  fontSize: 16,
                ),
              ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(t.selectTime),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxes(AppLocalizations t) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1),
          ),
          child: CheckboxListTile(
            title: Text(
              t.cargoInsured,
              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
            ),
            value: isInsured,
            activeColor: Colors.teal,
            onChanged: (value) {
              setState(() {
                isInsured = value ?? false;
                _termsAgreed = false;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildPolicyCard(isInsured ? t.insuredPolicy : t.uninsuredPolicy, t),
      ],
    );
  }

  Widget _buildPolicyCard(String text, AppLocalizations t) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.teal, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: Text(
                t.agreeTerms,
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w500),
              ),
              value: _termsAgreed,
              activeColor: Colors.teal,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _termsAgreed = val ?? false),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubmit() {
    final t = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) return;

    if (!_termsAgreed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.pleaseAgree)));
      return;
    }

    final weight = double.tryParse(_weightController.text.trim());
    final offerFare = double.tryParse(_offerFareController.text.trim());

    if (weight == null || offerFare == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.invalidValues)));
      return;
    }

    // Additional weight capacity validation before proceeding
    final maxCapacity = _getVehicleMaxCapacity();
    if (maxCapacity != null) {
      double weightInKg = weight;
      if (weightUnit == 'tons') {
        weightInKg = weight * 1000; // Convert tons to kg
      }
      
      if (weightInKg > maxCapacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weight exceeds vehicle capacity (${maxCapacity.toInt()} kg). Please reduce the weight or select a different vehicle.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // Validate quantity and proceed directly to summary
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please enter a valid quantity (minimum 1)')));
      return;
    }
    _navigateToSummary(weight, offerFare);
  }

  void _navigateToSummary(double weight, double offerFare) {
    // Final weight capacity validation before navigating to summary
    final maxCapacity = _getVehicleMaxCapacity();
    if (maxCapacity != null) {
      double weightInKg = weight;
      if (weightUnit == 'tons') {
        weightInKg = weight * 1000; // Convert tons to kg
      }
      
      if (weightInKg > maxCapacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weight exceeds vehicle capacity (${maxCapacity.toInt()} kg). Please reduce the weight or select a different vehicle.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // Parse quantity
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please enter a valid quantity (minimum 1)')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SummaryScreen(
          initialDetails: CargoDetails(
            loadName: _loadNameController.text.trim(),
            loadType: loadType, // internal key (e.g., 'fragile')
            weight: weight,
            weightUnit: weightUnit,
            quantity: quantity,
            pickupTime: pickupTime,
            offerFare: offerFare,
            isInsured: isInsured,
            vehicleType: vehicleType,
            isEnterprise: false, // Default to false, can be changed later if needed
            senderPhone: _senderPhoneController.text.trim(),
            receiverPhone: _receiverPhoneController.text.trim(),
            pickupLocation: _pickupLocationController.text.trim(),
            destinationLocation: _destinationLocationController.text.trim(),
          ),
        ),
      ),
    );
  }

  Widget _buildFareField(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.offerFare,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _offerFareController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Fare',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              prefixText: 'Rs ',
              prefixStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(color: Colors.black87),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter fare amount';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'Please enter valid amount';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  void _autoCalculateFare() {
    // Only auto-calculate if all required fields are filled
    if (_pickupLocationController.text.trim().isNotEmpty &&
        _destinationLocationController.text.trim().isNotEmpty &&
        _weightController.text.trim().isNotEmpty) {
      
      final weight = double.tryParse(_weightController.text.trim());
      if (weight != null) {
        // Debounce the calculation to avoid too many calls
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _calculateFareSilently();
          }
        });
      }
    }
  }

  Future<void> _calculateFareSilently() async {
    try {
      final weight = double.tryParse(_weightController.text.trim());
      if (weight == null) return;

      // Calculate suggested fare
      double suggestedFare = await FareCalculator.calculateSuggestedFare(
        pickupLocation: _pickupLocationController.text.trim(),
        destinationLocation: _destinationLocationController.text.trim(),
        weight: weight,
        weightUnit: weightUnit,
        cargoType: loadType,
        vehicleType: vehicleType,
        isInsured: isInsured,
      );

      // Fill the fare field with calculated amount
      _offerFareController.text = suggestedFare.toStringAsFixed(0);
    } catch (e) {
      // Silently handle errors for auto-calculation
      print('Auto-calculation error: $e');
    }
  }

  Future<void> _calculateFare() async {
    // Validate required fields for fare calculation
    if (_pickupLocationController.text.trim().isEmpty ||
        _destinationLocationController.text.trim().isEmpty ||
        _weightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill pickup location, destination, and weight first'),
        ),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid weight')),
      );
      return;
    }

    try {
      // Calculate suggested fare
      double suggestedFare = await FareCalculator.calculateSuggestedFare(
        pickupLocation: _pickupLocationController.text.trim(),
        destinationLocation: _destinationLocationController.text.trim(),
        weight: weight,
        weightUnit: weightUnit,
        cargoType: loadType,
        vehicleType: vehicleType,
        isInsured: isInsured,
      );

      // Fill the fare field with calculated amount
      _offerFareController.text = suggestedFare.toStringAsFixed(0);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estimated fare: Rs ${suggestedFare.toStringAsFixed(0)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating fare: $e')),
      );
    }
  }

  Future<void> _pickContact(TextEditingController controller) async {
    final permission = await Permission.contacts.request();
    if (permission.isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null && contact.phones.isNotEmpty) {
        String phoneNumber = contact.phones.first.number;
        
        // Clean and format the phone number
        String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        
        // Remove country code if present (e.g., +92 becomes 0)
        if (cleaned.startsWith('92')) {
          cleaned = '0' + cleaned.substring(2);
        }
        
        // Remove + sign if present
        cleaned = cleaned.replaceAll('+', '');
        
        // Validate and set the phone number
        if (cleaned.isNotEmpty) {
          controller.text = cleaned;
          // Trigger validation after setting the number
          _formKey.currentState?.validate();
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission denied')),
      );
    }
  }
}
