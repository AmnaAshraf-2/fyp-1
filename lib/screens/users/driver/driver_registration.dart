import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/driver/vehicle_info_page.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DriverRegistration extends StatefulWidget {
  const DriverRegistration({Key? key}) : super(key: key);

  @override
  _DriverRegistrationState createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController licenseExpiryController = TextEditingController();
  final TextEditingController bankAccountController = TextEditingController();

  final MaskTextInputFormatter cnicMaskFormatter = MaskTextInputFormatter(
    mask: '#####-#######-#',
    filter: {'#': RegExp(r'\d')},
    type: MaskAutoCompletionType.lazy,
  );

  //File? profilePhoto;

  //final ImagePicker _picker = ImagePicker();

  Future<void> _pickDate(TextEditingController controller,
      {bool isExpiry = false}) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? now : DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: isExpiry ? DateTime(2100) : now, // expiry allows future
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

  // Future<void> _pickProfilePhoto({bool fromCamera = false}) async {
  //   final XFile? image = await _picker.pickImage(
  //     source: fromCamera ? ImageSource.camera : ImageSource.gallery,
  //     preferredCameraDevice: CameraDevice.front,
  //     imageQuality: 70,
  //   );

  //   if (image != null) {
  //     setState(() {
  //       profilePhoto = File(image.path);
  //     });
  //   }
  // }

  // Future<void> _chooseFromGallery() async {
  //   final XFile? image = await _picker.pickImage(
  //     source: ImageSource.gallery, // 🖼️ gallery
  //     imageQuality: 70,
  //   );
  //   if (image != null) {
  //     setState(() {
  //       profilePhoto = File(image.path);
  //     });
  //   }
  // }

  Future<void> _saveDriverData() async {
    final t = AppLocalizations.of(context)!;
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseDatabase.instance.ref("users/$uid");

      await ref.child("driverDetails").set({
        "dob": dobController.text,
        "cnic": cnicMaskFormatter.getUnmaskedText(),
        "licenseNumber": licenseController.text,
        "licenseExpiry": licenseExpiryController.text,
        "bankAccount": bankAccountController.text,
        "completedAt": ServerValue.timestamp,
      });

      // mark profile complete
      await ref.update({"isProfileComplete": true});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.infoSaved)),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleInfoPage(
            cnic: cnicMaskFormatter.getUnmaskedText(),
            license: licenseController.text,
            phone: FirebaseAuth.instance.currentUser!.phoneNumber ?? "",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${t.error}: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          t.driverRegistrationStep1,
          style: const TextStyle(color: Colors.teal),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.teal),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // GestureDetector(
              //   onTap: () {
              //     showModalBottomSheet(
              //       context: context,
              //       builder: (_) => SafeArea(
              //         child: Wrap(
              //           children: [
              //             ListTile(
              //               leading: const Icon(Icons.camera_alt),
              //               title: Text(t.takePhoto),
              //               onTap: () {
              //                 Navigator.pop(context);
              //                 _pickProfilePhoto(fromCamera: true);
              //               },
              //             ),
              //             ListTile(
              //               leading: const Icon(Icons.photo_library),
              //               title: Text(t.chooseFromGallery),
              //               onTap: () {
              //                 Navigator.pop(context);
              //                 _pickProfilePhoto(fromCamera: false);
              //               },
              //             ),
              //           ],
              //         ),
              //       ),
              //     );
              //   },
              //   child: CircleAvatar(
              //     radius: 50,
              //     backgroundImage:
              //         profilePhoto != null ? FileImage(profilePhoto!) : null,
              //     child: profilePhoto == null
              //         ? const Icon(Icons.camera_alt, size: 40)
              //         : null,
              //   ),
              // ),
 SizedBox(height: 20),
              TextFormField(
                controller: dobController,
                readOnly: true,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: t.dateOfBirth,
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
                onTap: () => _pickDate(dobController),
                validator: (value) =>
                    value == null || value.isEmpty ? t.selectDob : null,
              ),
              const SizedBox(height: 10),

              // Profile Photo

              const SizedBox(height: 20),

              TextFormField(
                controller: cnicController,
                inputFormatters: [cnicMaskFormatter],
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: t.cnic,
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.enterCnic;
                  }
                  String digits = cnicMaskFormatter.getUnmaskedText();
                  if (digits.length != 13) {
                    return t.invalidCnic;
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),
              TextFormField(
                controller: licenseController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: t.licenseNumber,
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.enterLicense;
                  } else if (!RegExp(r'^[A-Za-z0-9]{6,}$').hasMatch(value)) {
                    return t.invalidLicense;
                  }
                  return null;
                },
              ),
               SizedBox(height: 20),
              TextFormField(
                controller: licenseExpiryController,
                readOnly: true,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: t.licenseExpiryDate,
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
                onTap: () => _pickDate(licenseExpiryController, isExpiry: true),
                validator: (value) =>
                    value == null || value.isEmpty ? t.selectLicenseExpiry : null,
              ),
               SizedBox(height: 20),
              TextFormField(
                controller: bankAccountController,
                style: const TextStyle(color: Colors.teal),
                decoration: InputDecoration(
                  labelText: t.bankAccountNumber,
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
                validator: (value) =>
                    value == null || value.isEmpty ? t.enterBankAccount : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: Text(t.next),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // if (profilePhoto == null) {
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //     SnackBar(content: Text(t.uploadProfilePhoto)),
                    //   );
                    //   return;
                    // }
                    _saveDriverData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
