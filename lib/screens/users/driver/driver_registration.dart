import 'package:flutter/material.dart';
import 'package:logistics_app/screens/users/driver/vehicle_info_page.dart';

class DriverRegistration extends StatefulWidget {
  const DriverRegistration({Key? key}) : super(key: key);

  @override
  _DriverRegistrationState createState() => _DriverRegistrationState();
}

class _DriverRegistrationState extends State<DriverRegistration> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController cnicController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Driver Registration - Step 1")),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: cnicController,
                decoration: InputDecoration(labelText: "CNIC"),
                validator: (value) => value!.isEmpty ? "Enter CNIC" : null,
              ),
              TextFormField(
                controller: licenseController,
                decoration: InputDecoration(labelText: "License Number"),
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: "Phone Number"),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text("Next"),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VehicleInfoPage(
                          cnic: cnicController.text,
                          license: licenseController.text,
                          phone: phoneController.text,
                        ),
                      ),
                    );
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
