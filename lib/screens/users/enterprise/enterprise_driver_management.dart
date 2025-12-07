import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

class EnterpriseDriverManagement extends StatefulWidget {
  const EnterpriseDriverManagement({super.key});

  @override
  State<EnterpriseDriverManagement> createState() => _EnterpriseDriverManagementState();
}

class _EnterpriseDriverManagementState extends State<EnterpriseDriverManagement> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _db.child('users/${user.uid}/drivers').get();
      if (snapshot.exists) {
        final driversData = snapshot.value as Map;
        _drivers = driversData.entries.map((entry) {
          final driverData = Map<String, dynamic>.from(entry.value as Map);
          driverData['id'] = entry.key;
          return driverData;
        }).toList();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading drivers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addDriver() async {
    final t = AppLocalizations.of(context)!;
    
    final TextEditingController firstNameController = TextEditingController();
    final TextEditingController lastNameController = TextEditingController();
    final TextEditingController dobController = TextEditingController();
    final TextEditingController cnicController = TextEditingController();
    final TextEditingController licenseController = TextEditingController();
    final TextEditingController licenseExpiryController = TextEditingController();
    final TextEditingController bankAccountController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController experienceController = TextEditingController();

    final MaskTextInputFormatter cnicMaskFormatter = MaskTextInputFormatter(
      mask: '#####-#######-#',
      filter: {'#': RegExp(r'\d')},
      type: MaskAutoCompletionType.lazy,
    );

    Future<void> _pickDate(TextEditingController controller, {bool isExpiry = false}) async {
      DateTime now = DateTime.now();
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: isExpiry ? now : DateTime(1990),
        firstDate: DateTime(1950),
        lastDate: isExpiry ? DateTime(2100) : now,
      );
      if (picked != null) {
        controller.text = "${picked.toLocal()}".split(' ')[0];
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(t.addDriver),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: t.firstName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: t.lastName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: t.phoneNumber,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dobController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: t.dateOfBirth,
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                  ),
                  onTap: () => _pickDate(dobController),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cnicController,
                  inputFormatters: [cnicMaskFormatter],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t.cnic,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: licenseController,
                  decoration: InputDecoration(
                    labelText: t.licenseNumber,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: licenseExpiryController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: t.licenseExpiryDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                  ),
                  onTap: () => _pickDate(licenseExpiryController, isExpiry: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bankAccountController,
                  decoration: InputDecoration(
                    labelText: t.bankAccountNumber,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: experienceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t.experienceYears,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (firstNameController.text.isNotEmpty &&
                    lastNameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty &&
                    dobController.text.isNotEmpty &&
                    cnicController.text.isNotEmpty &&
                    licenseController.text.isNotEmpty &&
                    licenseExpiryController.text.isNotEmpty &&
                    bankAccountController.text.isNotEmpty &&
                    experienceController.text.isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(t.add),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _saveDriver({
        'firstName': firstNameController.text,
        'lastName': lastNameController.text,
        'name': '${firstNameController.text} ${lastNameController.text}',
        'phone': phoneController.text,
        'dob': dobController.text,
        'cnic': cnicMaskFormatter.getUnmaskedText(),
        'licenseNumber': licenseController.text,
        'licenseExpiry': licenseExpiryController.text,
        'bankAccount': bankAccountController.text,
        'experienceYears': int.tryParse(experienceController.text) ?? 0,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
        'status': 'active',
      });
    }
  }

  Future<void> _saveDriver(Map<String, dynamic> driverData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final driverRef = _db.child('users/${user.uid}/drivers').push();
      await driverRef.set(driverData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.driverAddedSuccessfully)),
      );

      _loadDrivers();
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
    }
  }

  Future<void> _toggleDriverStatus(String driverId, bool isActive) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final newStatus = isActive ? 'active' : 'inactive';
      await _db.child('users/${user.uid}/drivers/$driverId').update({
        'status': newStatus,
        'statusUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver status changed to ${newStatus}'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDrivers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating driver status: $e')),
      );
    }
  }

  Future<void> _deleteDriver(String driverId) async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteDriver),
        content: Text(t.areYouSureDeleteDriver),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        await _db.child('users/${user.uid}/drivers/$driverId').remove();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.driverDeletedSuccessfully)),
        );

        _loadDrivers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a1a), Color(0xFF2d2d2d)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kTeal, kTealDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.totalDrivers,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _drivers.length.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addDriver,
                        icon: const Icon(Icons.person_add),
                        label: Text(t.addDriver),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Drivers List
                Expanded(
                  child: _drivers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person,
                                size: 64,
                                color: Colors.white.withOpacity(.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.noDriversFound,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.addYourFirstDriver,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(.8),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _drivers.length,
                          itemBuilder: (context, index) {
                            final driver = _drivers[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kTeal, kTealDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade700.withOpacity(.3),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  driver['name'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${t.phoneNumber}: ${driver['phone'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(.9))),
                                    Text('${t.cnic}: ${driver['cnic'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(.9))),
                                    Text('${t.licenseNumber}: ${driver['licenseNumber'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(.9))),
                                    Text('${t.experienceYears}: ${driver['experienceYears'] ?? 0} ${t.years}', style: TextStyle(color: Colors.white.withOpacity(.9))),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Status Toggle Switch
                                    Switch(
                                      value: (driver['status'] ?? 'inactive') == 'active',
                                      onChanged: (value) => _toggleDriverStatus(driver['id'], value),
                                      activeColor: Colors.green,
                                      inactiveThumbColor: Colors.red,
                                      inactiveTrackColor: Colors.red.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: driver['status'] == 'active' ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        driver['status'] == 'active' ? 'Active' : 'Inactive',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteDriver(driver['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
        ),
      ),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a1a), Color(0xFF2d2d2d)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          t.drivers,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
