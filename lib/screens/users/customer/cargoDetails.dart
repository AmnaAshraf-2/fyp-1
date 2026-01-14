
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:logistics_app/data/modals.dart';
import 'package:logistics_app/services/vehicle_provider.dart';
import 'package:logistics_app/screens/users/customer/summary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logistics_app/screens/users/customer/location_map_view.dart';
import 'package:logistics_app/screens/users/customer/location_picker_screen.dart';
import 'package:logistics_app/services/fare_calculator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/audio_recorder_service.dart';
import 'dart:io';

class CargoDetailsScreen extends StatefulWidget {
  final CargoDetails? initialData;
  const CargoDetailsScreen({super.key, this.initialData});

  @override
  State<CargoDetailsScreen> createState() => _CargoDetailsScreenState();
}

class _CargoDetailsScreenState extends State<CargoDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final VehicleProvider _vehicleProvider = VehicleProvider();
  List<VehicleModel> _vehicles = [];
  String _languageCode = 'en';

  String loadType = 'fragile';
  String weightUnit = 'kg';
  String vehicleType = 'Suzuki Pickup';
  bool _termsAgreed = false;
  DateTime? pickupDate;
  TimeOfDay? pickupTime;

  final _loadNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _offerFareController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _destinationLocationController = TextEditingController();

  bool isInsured = false;

  // Audio recording service
  final AudioRecorderService _audioService = AudioRecorderService();
  String? _audioNoteUrl; // Firebase Storage URL after upload
  final ScrollController _scrollController = ScrollController();

  // Minimum fare (80% of suggested fare)
  double? _minimumFare;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadLanguageCode();
    // Listen to locale changes
    localeNotifier?.addListener(_onLocaleChanged);
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
      pickupDate = widget.initialData!.pickupDate;
      pickupTime = widget.initialData!.pickupTime;
      isInsured = widget.initialData!.isInsured;
      _audioNoteUrl = widget.initialData!.audioNoteUrl;
      // Set minimum fare to 80% of initial fare
      _minimumFare = widget.initialData!.offerFare * 0.8;
    }
    _pickupLocationController.addListener(_autoCalculateFare);
    _destinationLocationController.addListener(_autoCalculateFare);
    _weightController.addListener(_autoCalculateFare);
    _weightController.addListener(_onWeightChanged);
    _offerFareController.addListener(_onFareChanged);
  }

  void _onLocaleChanged() {
    _loadLanguageCode();
  }

  Future<void> _loadLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      String code = 'en';
      if (user != null) {
        code = prefs.getString('languageCode_${user.uid}') ?? 'en';
      } else {
        code = prefs.getString('languageCode') ?? 'en';
      }
      if (mounted) {
        setState(() {
          _languageCode = code;
        });
      }
    } catch (e) {
      // Default to English
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _vehicleProvider.loadVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  String _getVehicleDisplayName(String nameKey) {
    for (VehicleModel vehicle in _vehicles) {
      if (vehicle.nameKey == nameKey) {
        return vehicle.getName(_languageCode);
      }
    }
    return nameKey; // Fallback to nameKey if not found
  }

  @override
  void dispose() {
    localeNotifier?.removeListener(_onLocaleChanged);
    _pickupLocationController.removeListener(_autoCalculateFare);
    _destinationLocationController.removeListener(_autoCalculateFare);
    _weightController.removeListener(_autoCalculateFare);
    _weightController.removeListener(_onWeightChanged);
    _offerFareController.removeListener(_onFareChanged);
    _audioService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onWeightChanged() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
    _autoCalculateQuantity(_weightController.text);
  }

  void _autoCalculateQuantity(String weightText) {
    if (weightText.isEmpty) {
      _quantityController.text = '1';
      return;
    }
    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0) return;
    final maxCapacity = _getVehicleMaxCapacity();
    if (maxCapacity == null) return;

    double weightInKg = weight;
    if (weightUnit == 'tons') {
      weightInKg = weight * 1000;
    }

    final currentQuantity = int.tryParse(_quantityController.text) ?? 1;
    
    if (weightInKg > maxCapacity) {
      int requiredVehicles = (weightInKg / maxCapacity).ceil();
      if (currentQuantity != requiredVehicles) {
        _quantityController.text = requiredVehicles.toString();
        if (mounted) {
          final t = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t.weightExceedsSingleVehicle(requiredVehicles.toString()),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      // Weight is within single vehicle capacity, so quantity should be 1
      if (currentQuantity > 1) {
        _quantityController.text = '1';
      } else if (currentQuantity < 1) {
        _quantityController.text = '1';
      }
    }
  }

  double? _getVehicleMaxCapacity() {
    for (VehicleModel vehicle in _vehicles) {
      if (vehicle.nameKey == vehicleType) { // Match by nameKey instead of localized name
        String capacityText = vehicle.getCapacity(_languageCode);
        RegExp regex = RegExp(r'(\d+(?:,\d+)*(?:\.\d+)?)');
        Match? match = regex.firstMatch(capacityText);
        if (match != null) {
          String numberStr = match.group(1)!.replaceAll(',', '');
          double? capacity = double.tryParse(numberStr);
          if (capacity != null) {
            if (capacityText.toLowerCase().contains('ton')) {
              return capacity * 1000;
            } else if (capacityText.toLowerCase().contains('liter')) {
              return capacity;
            } else {
              return capacity;
            }
          }
        }
        break;
      }
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialData == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is VehicleModel) {
        vehicleType = args.nameKey; // Store nameKey instead of localized name
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
      body: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(t.cargoDetailsSection),
              _card(
                Column(
                  children: [
                    _buildTextField(t.loadName, _loadNameController),
                    _buildDropdown(t, loadTypeLabels),
                    _buildTextField(t.loadDimensions, null, TextInputType.text, false),
                  ],
                ),
              ),
              _sectionTitle(t.weightVehicleSection),
              _card(
                Column(
                  children: [
                    _buildWeightField(t),
                    _capacityIndicator(t),
                    const SizedBox(height: 8),
                    _infoTile(
                      title: t.vehicleType,
                      value: _getVehicleDisplayName(vehicleType),
                      icon: Icons.local_shipping,
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(t.quantityOfVehicles, _quantityController, TextInputType.number, true),
                  ],
                ),
              ),
              _sectionTitle(t.contactDetailsSection),
              _card(
                Column(
                  children: [
                    _buildPhoneField(t.senderPhoneNumber, _senderPhoneController),
                    _buildPhoneField(t.receiverPhoneNumber, _receiverPhoneController),
                  ],
                ),
              ),
              _sectionTitle(t.locationsSection),
              _card(
                Column(
                  children: [
                    _buildLocationField(t.pickupLocation, _pickupLocationController),
                    _buildLocationField(t.destinationLocation, _destinationLocationController),
                  ],
                ),
              ),
              _sectionTitle(t.scheduleSection),
              _card(
                Column(
                  children: [
                    _buildDatePicker(t),
                    _buildTimePicker(t),
                  ],
                ),
              ),
              _sectionTitle(t.audioNote),
              _card(
                _buildAudioNoteSection(t),
              ),
              _sectionTitle(t.fareInsuranceSection),
              _card(
                Column(
                  children: [
                    _buildFareField(t),
                    _buildCheckboxes(t),
                  ],
                ),
              ),
              
              const SizedBox(height: 80),
            ],
          ),
            ),
          ),
        ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              child: Text(
                t.continueToSummary,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoTile({required String title, required String value, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004d4d),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _capacityIndicator(AppLocalizations t) {
    final maxCapacity = _getVehicleMaxCapacity();
    final currentWeight = double.tryParse(_weightController.text);
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    
    double capacityPercentage = 0.0;
    if (maxCapacity != null && currentWeight != null) {
      double weightInKg = currentWeight;
      if (weightUnit == 'tons') weightInKg = currentWeight * 1000;
      final totalCapacity = maxCapacity * quantity;
      capacityPercentage = (weightInKg / totalCapacity).clamp(0.0, 1.0);
    }

    Color progressColor = Colors.green;
    if (capacityPercentage > 0.9) {
      progressColor = Colors.red;
    } else if (capacityPercentage > 0.7) {
      progressColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.capacityStatus,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (maxCapacity != null && currentWeight != null)
              Text(
                "${(capacityPercentage * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: capacityPercentage,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
        if (maxCapacity != null && currentWeight != null) ...[
          const SizedBox(height: 8),
          Text(
            _getWeightHelperText(),
            style: TextStyle(
              fontSize: 12,
              color: capacityPercentage > 0.9 ? Colors.red : Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController? controller,
      [TextInputType inputType = TextInputType.text, bool isRequired = true]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                hintText: t.phoneNumberExample,
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
                helperText: t.phoneNumberFormat,
                helperMaxLines: 2,
                helperStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                isDense: true,
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
            height: 54, // Match the height of TextFormField
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal, width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.contacts, color: Colors.teal),
              onPressed: () => _pickContact(controller),
              tooltip: t.selectFromContacts,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  String? _validatePhoneNumber(String phoneNumber) {
    final t = AppLocalizations.of(context)!;
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.isEmpty) return t.phoneNumberRequired;
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return t.phoneNumberOnlyDigits;
    if (!cleaned.startsWith('0')) return t.phoneNumberMustStartWith0;
    if (cleaned.length != 11) return t.phoneNumberMustBe11Digits;
    String prefix = cleaned.substring(0, 2);
    String firstFour = cleaned.substring(0, 4);
    if (prefix == '03') {
      int prefixNum = int.tryParse(firstFour) ?? 0;
      if (prefixNum < 300 || prefixNum > 399) return t.invalidMobilePrefix03XX;
    } else if (prefix == '04') {
      int prefixNum = int.tryParse(firstFour) ?? 0;
      if (prefixNum < 400 || prefixNum > 499) return t.invalidMobilePrefix04XX;
    } else if (prefix == '05') {
      int prefixNum = int.tryParse(firstFour) ?? 0;
      if (prefixNum < 500 || prefixNum > 599) return t.invalidMobilePrefix05XX;
    } else if (prefix == '02' || prefix == '01') {
      return null;
    } else {
      return t.invalidPhoneFormat;
    }
    String remainingDigits = cleaned.substring(4);
    if (remainingDigits.length != 7) return t.invalidPhoneFormatAfterPrefix;
    if (RegExp(r'^(\d)\1{6}$').hasMatch(remainingDigits)) return t.phoneNumberAllSameDigits;
    if (remainingDigits == '0000000') return t.phoneNumberInvalid;
    return null;
  }

  Widget _buildLocationField(String label, TextEditingController controller) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => LocationPickerScreen(
                title: label,
                initialValue: controller.text.trim().isNotEmpty ? controller.text.trim() : null,
              ),
            ),
          );
          if (result != null && mounted) {
            controller.text = result;
            _formKey.currentState?.validate();
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
            hintText: t.tapToChooseLocation,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: const TextStyle(color: Colors.black87),
          validator: (value) => (value == null || value.isEmpty) ? AppLocalizations.of(context)!.required : null,
        ),
      ),
    );
  }

  Widget _buildWeightField(AppLocalizations t) {
    final maxCapacity = _getVehicleMaxCapacity();
    final maxCapacityInSelectedUnit = maxCapacity != null ? (weightUnit == 'tons' ? maxCapacity / 1000 : maxCapacity) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                if (maxCapacityInSelectedUnit != null)
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.isEmpty) return newValue;
                    final enteredValue = double.tryParse(newValue.text);
                    if (enteredValue != null && enteredValue > maxCapacityInSelectedUnit) {
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
                isDense: true,
              ),
              style: const TextStyle(color: Colors.black87),
              onChanged: (value) {
                setState(() {});
                _autoCalculateQuantity(value);
                if (_formKey.currentState != null) {
                  _formKey.currentState!.validate();
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) return t.required;
                final weight = double.tryParse(value);
                if (weight == null || weight <= 0) return t.pleaseEnterValidWeight;
                if (maxCapacity != null) {
                  double weightInKg = weight;
                  if (weightUnit == 'tons') weightInKg = weight * 1000;
                  final quantity = int.tryParse(_quantityController.text) ?? 1;
                  final totalCapacity = maxCapacity * quantity;
                  if (weightInKg > totalCapacity) {
                    final requiredVehicles = (weightInKg / maxCapacity).ceil();
                    return '${t.weightExceedsCapacity}\n${t.requiredVehicles}: $requiredVehicles ${t.vehicles}\n${t.currentVehicles}: $quantity ${t.vehicles}';
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
                });
                _formKey.currentState?.validate();
              },
              items: [
                DropdownMenuItem(value: 'kg', child: Text(t.kg)),
                DropdownMenuItem(value: 'tons', child: Text(t.tons)),
              ],
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
                isDense: true,
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
    final t = AppLocalizations.of(context)!;
    final maxCapacity = _getVehicleMaxCapacity();
    if (maxCapacity != null) {
      final currentWeight = double.tryParse(_weightController.text);
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final totalCapacity = maxCapacity * quantity;
      if (currentWeight != null) {
        double weightInKg = currentWeight;
        if (weightUnit == 'tons') weightInKg = currentWeight * 1000;
        if (weightInKg > totalCapacity) {
          final requiredVehicles = (weightInKg / maxCapacity).ceil();
          return '⚠️ ${t.exceedsCapacityNeed} $requiredVehicles ${t.vehicles} (${(requiredVehicles * maxCapacity).toInt()} ${t.kg} ${t.totalCapacity})';
        } else if (weightInKg > totalCapacity * 0.9) {
          return '⚠️ ${t.approachingCapacityLimit}: ${totalCapacity.toInt()} ${t.kg} ($quantity ${t.vehicles})';
        } else {
          final remaining = totalCapacity - weightInKg;
          if (quantity > 1) {
            return '${t.totalCapacity}: ${totalCapacity.toInt()} ${t.kg} ($quantity ${t.vehicles} × ${maxCapacity.toInt()} ${t.kg} each) - ${remaining.toInt()} ${t.kg} ${t.remaining}';
          } else {
            return '${t.maximumCapacity}: ${maxCapacity.toInt()} ${t.kg} (${remaining.toInt()} ${t.kg} ${t.remaining})';
          }
        }
      }
      if (quantity > 1) {
        return '${t.totalCapacity}: ${totalCapacity.toInt()} ${t.kg} ($quantity ${t.vehicles} × ${maxCapacity.toInt()} ${t.kg} each)';
      }
      return '${t.maximumCapacity}: ${maxCapacity.toInt()} ${t.kg} (${(maxCapacity / 1000).toStringAsFixed(1)} ${t.tons})';
    }
    return '';
  }

  Widget _buildDropdown(AppLocalizations t, Map<String, String> loadTypeLabels) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: const Key('loadTypeDropdown'),
        value: loadType,
        onChanged: (value) => setState(() => loadType = value!),
        items: loadTypeLabels.entries
            .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            .toList(),
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

  Widget _buildDatePicker(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.teal.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pickupDate == null
                    ? t.pickupDateNotSelected
                    : '${t.pickupDate}: ${_formatDate(pickupDate!)}',
                style: TextStyle(
                  color: pickupDate == null ? Colors.grey : Colors.teal.shade800,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Colors.teal,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black87,
                        ),
                        dialogBackgroundColor: Colors.white,
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) setState(() => pickupDate = date);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(t.selectDate),
            )
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Widget _buildTimePicker(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.teal.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pickupTime == null
                    ? t.pickupTimeNotSelected
                    : '${t.pickupTime}: ${pickupTime!.format(context)}',
                style: TextStyle(
                  color: pickupTime == null ? Colors.grey : Colors.teal.shade800,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Colors.teal,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black87,
                        ),
                        dialogBackgroundColor: Colors.white,
                      ),
                      child: child!,
                    );
                  },
                );
                if (time != null) setState(() => pickupTime = time);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              style: const TextStyle(color: Color(0xFF004d4d), fontWeight: FontWeight.w500),
            ),
            value: isInsured,
            activeColor: Colors.teal,
            checkColor: Colors.white,
            fillColor: MaterialStateProperty.all(Colors.teal),
            side: const BorderSide(color: Colors.teal, width: 2),
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
      color: Colors.white,
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
              style: const TextStyle(color: Color(0xFF004d4d), fontSize: 14),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: Text(
                t.agreeTerms,
                style: const TextStyle(color: Color(0xFF004d4d), fontWeight: FontWeight.w500),
              ),
              value: _termsAgreed,
              activeColor: Colors.teal,
              checkColor: Colors.white,
              fillColor: MaterialStateProperty.all(Colors.teal),
              side: const BorderSide(color: Colors.teal, width: 2),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.pleaseAgree)));
      return;
    }
    final weight = double.tryParse(_weightController.text.trim());
    final offerFare = double.tryParse(_offerFareController.text.trim());
    if (weight == null || offerFare == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidValues)));
      return;
    }
    final maxCapacity = _getVehicleMaxCapacity();
    if (maxCapacity != null) {
      double weightInKg = weight;
      if (weightUnit == 'tons') weightInKg = weight * 1000;
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final totalCapacity = maxCapacity * quantity;
      if (weightInKg > totalCapacity) {
        final requiredVehicles = (weightInKg / maxCapacity).ceil();
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.weightExceedsCapacityAutoUpdate(requiredVehicles.toString(), quantity.toString())),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        _quantityController.text = requiredVehicles.toString();
        return;
      }
    }
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.pleaseEnterValidQuantity)));
      return;
    }
    _navigateToSummary(weight, offerFare);
  }

  void _navigateToSummary(double weight, double offerFare) {
    final t = AppLocalizations.of(context)!;
    final maxCapacity = _getVehicleMaxCapacity();
    if (maxCapacity != null) {
      double weightInKg = weight;
      if (weightUnit == 'tons') weightInKg = weight * 1000;
      final quantity = int.tryParse(_quantityController.text) ?? 1;
      final totalCapacity = maxCapacity * quantity;
      if (weightInKg > totalCapacity) {
        final requiredVehicles = (weightInKg / maxCapacity).ceil();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.weightExceedsCapacityAutoUpdate(requiredVehicles.toString(), quantity.toString())),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        _quantityController.text = requiredVehicles.toString();
        return;
      }
    }
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.pleaseEnterValidQuantity)));
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
            pickupDate: pickupDate,
            pickupTime: pickupTime,
            offerFare: offerFare,
            isInsured: isInsured,
            vehicleType: vehicleType,
            isEnterprise: false,
            senderPhone: _senderPhoneController.text.trim(),
            receiverPhone: _receiverPhoneController.text.trim(),
            pickupLocation: _pickupLocationController.text.trim(),
            destinationLocation: _destinationLocationController.text.trim(),
            audioNoteUrl: _audioNoteUrl,
          ),
        ),
      ),
    );
  }

  Widget _buildFareField(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.offerFare,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _offerFareController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: t.fare,
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
            onChanged: (value) {
              // Validate and show warning if below minimum, but allow typing
              if (value.trim().isNotEmpty) {
                final fareValue = double.tryParse(value.trim());
                if (fareValue != null) {
                  if (fareValue <= 0) {
                    // Show warning for zero or negative
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.fareCannotBeZero),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (_minimumFare != null && fareValue < _minimumFare!) {
                    // Show warning for below minimum
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.fareBelowMinimum(_minimumFare!.toStringAsFixed(0))),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                }
              }
              // Trigger validation
              if (_formKey.currentState != null) {
                _formKey.currentState!.validate();
              }
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) return t.pleaseEnterFareAmount;
              final fareValue = double.tryParse(value.trim());
              if (fareValue == null) return t.pleaseEnterValidAmount;
              if (fareValue <= 0) return t.fareCannotBeZero;
              if (_minimumFare != null && fareValue < _minimumFare!) {
                return t.fareBelowMinimum(_minimumFare!.toStringAsFixed(0));
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  void _autoCalculateFare() {
    if (_pickupLocationController.text.trim().isNotEmpty &&
        _destinationLocationController.text.trim().isNotEmpty &&
        _weightController.text.trim().isNotEmpty) {
      final weight = double.tryParse(_weightController.text.trim());
      if (weight != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _calculateFareSilently();
        });
      }
    }
  }

  Future<void> _calculateFareSilently() async {
    try {
      final weight = double.tryParse(_weightController.text.trim());
      if (weight == null) return;
      Map<String, dynamic> fareData = await FareCalculator.calculateFareWithCommission(
        pickupLocation: _pickupLocationController.text.trim(),
        destinationLocation: _destinationLocationController.text.trim(),
        weight: weight,
        weightUnit: weightUnit,
        cargoType: loadType,
        vehicleType: vehicleType,
        isInsured: isInsured,
      );
      if (fareData.containsKey('error')) {
        print('Auto-calculation error: ${fareData['error']}');
        return;
      }
      double finalFare = fareData['finalFare'] ?? 0.0;
      // Set minimum fare to 80% of suggested fare
      _minimumFare = finalFare * 0.8;
      _offerFareController.text = finalFare.toStringAsFixed(0);
    } catch (e) {
      print('Auto-calculation error: $e');
    }
  }

  void _onFareChanged() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
  }

  Widget _buildAudioNoteSection(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.audioNoteOptional,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 12),
        
        // Record button (when not recording and no audio)
        if (!_audioService.isRecording && _audioService.path == null && _audioNoteUrl == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mic, color: Colors.white),
              label: Text(
                t.recordAudioNote,
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final success = await _audioService.startRecording();
                if (success) {
                  setState(() {});
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.failedToStartRecording),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),

        // Stop recording button
        if (_audioService.isRecording)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: Text(
                    t.stopRecording,
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await _audioService.stopRecording();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<Duration>(
                      stream: Stream.periodic(const Duration(seconds: 1), (i) {
                        return _audioService.getRecordingDuration() ?? Duration.zero;
                      }),
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? Duration.zero;
                        return Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

        // Preview + Upload (when recording stopped but not uploaded)
        if (!_audioService.isRecording && _audioService.path != null && _audioNoteUrl == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.teal,
                        size: 32,
                      ),
                      onPressed: () async {
                        try {
                          await _audioService.play();
                          setState(() {});
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.errorPlayingAudio(e.toString()))),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                      onPressed: () {
                        _audioService.deleteRecording();
                        setState(() {});
                      },
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t.uploadingAudioNote),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                          final url = await _audioService.upload();
                          if (mounted) {
                            setState(() {
                              _audioNoteUrl = url;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t.audioNoteUploadedSuccessfully),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t.errorUploadingAudio(e.toString())),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(t.upload),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Uploaded success indicator
        if (_audioNoteUrl != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  t.audioNoteAttached,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _audioNoteUrl = null;
                      _audioService.deleteRecording();
                    });
                  },
                  child: Text(t.remove, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _pickContact(TextEditingController controller) async {
    final permission = await Permission.contacts.request();
    if (permission.isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null && contact.phones.isNotEmpty) {
        String phoneNumber = contact.phones.first.number;
        String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        if (cleaned.startsWith('92')) cleaned = '0' + cleaned.substring(2);
        cleaned = cleaned.replaceAll('+', '');
        if (cleaned.isNotEmpty) {
          controller.text = cleaned;
          _formKey.currentState?.validate();
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.contactsPermissionDenied)),
      );
    }
  }
}
