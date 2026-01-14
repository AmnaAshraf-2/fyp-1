import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VehicleInfoPage extends StatefulWidget {
  final String cnic;
  final String license;
  final String phone;

  VehicleInfoPage({required this.cnic, required this.license, required this.phone});

  @override
  _VehicleInfoPageState createState() => _VehicleInfoPageState();
}

class _VehicleInfoPageState extends State<VehicleInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController plateController = TextEditingController();
  String? vehicleImageUrl;
  String? regCopyUrl;

  Future<String?> _pickAndUploadImage(String folderName) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return null;

    File file = File(pickedFile.path);
    final ref = FirebaseStorage.instance.ref().child('$folderName/${DateTime.now()}.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  void _saveDriverData() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection("users").doc(userId).set({
      "role": "driver",
      "cnic": widget.cnic,
      "license": widget.license,
      "phone": widget.phone,
      "vehicle": {
        "plateNumber": plateController.text,
        "vehicleImageUrl": vehicleImageUrl,
        "registrationCopyUrl": regCopyUrl,
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Driver Registered!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Driver Registration - Step 2")),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: plateController,
                decoration: InputDecoration(labelText: "Vehicle Plate Number"),
                validator: (value) => value!.isEmpty ? "Enter plate number" : null,
              ),
              Row(
                children: [
                  ElevatedButton(
                    child: Text("Upload Vehicle Image"),
                    onPressed: () async {
                      vehicleImageUrl = await _pickAndUploadImage("vehicles");
                      setState(() {});
                    },
                  ),
                  if (vehicleImageUrl != null) Icon(Icons.check, color: Colors.green),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(
                    child: Text("Upload Registration Copy"),
                    onPressed: () async {
                      regCopyUrl = await _pickAndUploadImage("vehicleCopies");
                      setState(() {});
                    },
                  ),
                  if (regCopyUrl != null) Icon(Icons.check, color: Colors.green),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text("Submit"),
                onPressed: () {
                  if (_formKey.currentState!.validate() && vehicleImageUrl != null && regCopyUrl != null) {
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
