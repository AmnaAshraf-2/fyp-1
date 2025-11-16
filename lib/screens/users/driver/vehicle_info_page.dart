import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logistics_app/data/vehicles.dart';
import 'package:logistics_app/screens/users/driver/drivers.dart';
import 'package:logistics_app/splash/welcome.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class VehicleInfoPage extends StatefulWidget {
  final String cnic;
  final String license;
  final String phone;

  const VehicleInfoPage({
    Key? key,
    required this.cnic,
    required this.license,
    required this.phone,
  }) : super(key: key);

  @override
  State<VehicleInfoPage> createState() => _VehicleInfoPageState();
}

class _VehicleInfoPageState extends State<VehicleInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController makeModelController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController engineNumberController = TextEditingController();
  final TextEditingController chassisNumberController = TextEditingController();
  final TextEditingController regExpiryController = TextEditingController();
  final TextEditingController insuranceValidityController = TextEditingController();
  final TextEditingController fitnessCertificateController = TextEditingController();
  final TextEditingController trackingIdController = TextEditingController();

  String? selectedVehicleType;

  File? insuranceCopy;
  File? fitnessCopy;

  //final ImagePicker _picker = ImagePicker();

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.teal,
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.teal),
              bodyMedium: TextStyle(color: Colors.teal),
              labelLarge: TextStyle(color: Colors.teal),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = "${picked.toLocal()}".split(' ')[0];
    }
  }

  // Future<File?> _pickDocument() async {
  //   final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
  //   if (file != null) return File(file.path);
  //   return null;
  // }

  Future<String?> _uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _saveVehicleInfo() async {
    final loc = AppLocalizations.of(context)!;
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      final _db = FirebaseDatabase.instance.ref();

      print('🔍 DEBUG: Saving vehicle info for driver: $uid');
      print('🔍 DEBUG: Selected vehicle type: $selectedVehicleType');
      print('🔍 DEBUG: Make/Model: ${makeModelController.text}');

      String? insuranceUrl;
      String? fitnessUrl;

      if (insuranceCopy != null) {
        print('🔍 DEBUG: Uploading insurance copy...');
        insuranceUrl = await _uploadFile(
          insuranceCopy!,
          "vehicle_docs/$uid/insurance.jpg",
        );
      }

      if (fitnessCopy != null) {
        print('🔍 DEBUG: Uploading fitness copy...');
        fitnessUrl = await _uploadFile(
          fitnessCopy!,
          "vehicle_docs/$uid/fitness.jpg",
        );
      }

      final vehicleData = {
        "makeModel": makeModelController.text,
        "type": selectedVehicleType,
        "color": colorController.text,
        "engineNumber": engineNumberController.text,
        "chassisNumber": chassisNumberController.text,
        "registrationExpiry": regExpiryController.text,
        "trackingDeviceId": trackingIdController.text,
        "insuranceCopy": insuranceUrl ?? "",
        "fitnessCopy": fitnessUrl ?? "",
      };

      print('🔍 DEBUG: Vehicle data to save: $vehicleData');

      await _db.child("users").child(uid).update({
        "vehicleInfo": vehicleData,
      });

      print('✅ DEBUG: Vehicle info saved successfully!');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.vehicleInfoSaved)),
      );

      // Navigate to welcome screen after completing registration
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } catch (e) {
      print('❌ DEBUG: Error saving vehicle info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${loc.vehicleInfoError}: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          loc.driverRegStep2,
          style: const TextStyle(color: Colors.teal),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.teal),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: makeModelController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.vehicleMakeModel,
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? loc.enterVehicleMakeModel : null,
              ), SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedVehicleType,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.vehicleType,
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                dropdownColor: Colors.white,
                items: vehicleList
                    .map((v) => DropdownMenuItem<String>(
                          value: v.getName(loc),
                          child: Text(
                            "${v.getName(loc)} (${v.getCapacity(loc)})",
                            style: const TextStyle(color: Colors.teal),
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => selectedVehicleType = val),
                validator: (v) => v == null ? loc.selectVehicleType : null,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: colorController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.vehicleColor,
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? loc.enterVehicleColor : null,
              ),
               SizedBox(height: 20),
              TextFormField(
                controller: engineNumberController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.engineNumber,
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? loc.enterEngineNumber : null,
              ),
               SizedBox(height: 20),
              TextFormField(
                controller: chassisNumberController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.chassisNumber,
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? loc.enterChassisNumber : null,
              ),
               SizedBox(height: 20),
              TextFormField(
                controller: regExpiryController,
                readOnly: true,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.regExpiry,
                  labelStyle: const TextStyle(color: Colors.teal),
                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onTap: () => _pickDate(regExpiryController),
                validator: (v) =>
                    v == null || v.isEmpty ? loc.selectRegExpiry : null,
              ),

              const SizedBox(height: 10),

              // Insurance Section
              const SizedBox(height: 10),
              Text(
                loc.vehicleInsurance,
                style: const TextStyle(color: Colors.teal, fontSize: 16),
              ),
               SizedBox(height: 20),
              TextFormField(
                controller: insuranceValidityController,
                readOnly: true,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.insuranceValidity,
                  labelStyle: const TextStyle(color: Colors.teal),
                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onTap: () => _pickDate(insuranceValidityController),
              ),

              const SizedBox(height: 20),

              // Fitness Certificate Section
              Text(
                loc.fitnessCertificate,
                style: const TextStyle(color: Colors.teal, fontSize: 16),
              ),
               SizedBox(height: 20),
              TextFormField(
                controller: fitnessCertificateController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.fitnessCertNumber,
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: trackingIdController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: loc.trackingId,
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _saveVehicleInfo();
                  }
                },
                child: Text(loc.submitRegistration),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
