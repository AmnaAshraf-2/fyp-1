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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredDrivers {
    if (_searchQuery.isEmpty) {
      return _drivers;
    }
    return _drivers.where((driver) {
      final name = (driver['name'] ?? '').toString().toLowerCase();
      final phone = (driver['phone'] ?? '').toString().toLowerCase();
      final cnic = (driver['cnic'] ?? '').toString().toLowerCase();
      final licenseNumber = (driver['licenseNumber'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          cnic.contains(_searchQuery) ||
          licenseNumber.contains(_searchQuery);
    }).toList();
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
    final TextEditingController emailController = TextEditingController();
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            t.addDriver,
            style: const TextStyle(
              color: kTealDark,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.firstName,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.lastName,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.phoneNumber,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.email,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dobController,
                  readOnly: true,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.dateOfBirth,
                    labelStyle: const TextStyle(color: kTealDark),
                    suffixIcon: const Icon(Icons.calendar_today, color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                  onTap: () => _pickDate(dobController),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cnicController,
                  inputFormatters: [cnicMaskFormatter],
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.cnic,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: licenseController,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.licenseNumber,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: licenseExpiryController,
                  readOnly: true,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.licenseExpiryDate,
                    labelStyle: const TextStyle(color: kTealDark),
                    suffixIcon: const Icon(Icons.calendar_today, color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                  onTap: () => _pickDate(licenseExpiryController, isExpiry: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bankAccountController,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.bankAccountNumber,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: experienceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.experienceYears,
                    labelStyle: const TextStyle(color: kTealDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kTealDark, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: kTealDark,
              ),
              child: Text(t.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (firstNameController.text.isNotEmpty &&
                    lastNameController.text.isNotEmpty &&
                    emailController.text.isNotEmpty &&
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
              style: ElevatedButton.styleFrom(
                backgroundColor: kTealDark,
                foregroundColor: Colors.white,
              ),
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
        'email': emailController.text.trim(),
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
      final enterpriseUser = _auth.currentUser;
      if (enterpriseUser == null) return;

      final email = driverData['email'] as String;
      final driverName = driverData['name'] as String;
      final enterpriseUid = enterpriseUser.uid;
      
      // Check if email is already registered
      final usersSnapshot = await _db.child('users').get();
      if (usersSnapshot.exists) {
        final users = usersSnapshot.value as Map;
        for (var entry in users.entries) {
          final userData = entry.value as Map?;
          if (userData?['email'] == email) {
            final t = AppLocalizations.of(context)!;
            if (userData?['role'] == 'enterprise_driver') {
              throw Exception(t.emailAlreadyRegisteredAsDriver);
            } else {
              throw Exception(t.emailAlreadyRegisteredDifferentRole);
            }
          }
        }
      }

      // Save driver data under enterprise (without creating auth account yet)
      final driverRef = _db.child('users/$enterpriseUid/drivers').push();
      final driverId = driverRef.key;
      
      // Store driver data with a flag that auth account needs to be created
      await driverRef.set({
        ...driverData,
        'driverId': driverId,
        'authAccountCreated': false, // Flag to indicate auth account not created yet
      });

      // Create user record in main users table with enterprise_driver role
      // We'll use a temporary UID that will be replaced when auth account is created
      // For now, use driverId as a placeholder
      final tempDriverRef = _db.child('enterprise_drivers_pending/$driverId').set({
        'email': email,
        'name': driverName,
        'phone': driverData['phone'],
        'role': 'enterprise_driver',
        'enterpriseId': enterpriseUid,
        'enterpriseDriverId': driverId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isProfileComplete': false,
        'needsPasswordSetup': true,
        'needsAuthAccount': true, // Flag that auth account needs to be created
      });

      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.driverAddedSuccessfully}. ${t.driverCanNowLoginToSetupAccount}'),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
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

      final t = AppLocalizations.of(context)!;
      final newStatus = isActive ? t.active : t.inactive;
      final statusValue = isActive ? 'active' : 'inactive';
      await _db.child('users/${user.uid}/drivers/$driverId').update({
        'status': statusValue,
        'statusUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.driverStatusChangedTo(newStatus)),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadDrivers();
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorUpdatingDriverStatus} $e')),
      );
    }
  }

  Widget _buildDriverDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white.withOpacity(0.8)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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

                // Search Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: t.searchDriversBy,
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.8)),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Drivers List
                Expanded(
                  child: _filteredDrivers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off : Icons.person,
                                size: 64,
                                color: Colors.white.withOpacity(.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ? t.noDriversFoundForSearch : t.noDriversFound,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? t.tryDifferentSearchTerm
                                    : t.addYourFirstDriver,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(.8),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredDrivers.length,
                          itemBuilder: (context, index) {
                            final driver = _filteredDrivers[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kTeal, kTealDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Row with Avatar, Name, and Actions
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.orange.shade700.withOpacity(.3),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              driver['name'] ?? t.unknown,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: driver['status'] == 'active' 
                                                    ? Colors.green.withOpacity(0.3)
                                                    : Colors.red.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: driver['status'] == 'active' ? Colors.green : Colors.red,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                driver['status'] == 'active' ? t.active : t.inactive,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status Toggle and Delete Button
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Switch(
                                            value: (driver['status'] ?? 'inactive') == 'active',
                                            onChanged: (value) => _toggleDriverStatus(driver['id'], value),
                                            activeColor: Colors.green,
                                            inactiveThumbColor: Colors.red,
                                            inactiveTrackColor: Colors.red.withOpacity(0.5),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () => _deleteDriver(driver['id']),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.white24, height: 1),
                                  const SizedBox(height: 12),
                                  // Driver Details
                                  _buildDriverDetailRow(Icons.phone, '${t.phoneNumber}:', driver['phone'] ?? t.nA),
                                  const SizedBox(height: 8),
                                  _buildDriverDetailRow(Icons.badge, '${t.cnic}:', driver['cnic'] ?? t.nA),
                                  const SizedBox(height: 8),
                                  _buildDriverDetailRow(Icons.drive_eta, '${t.licenseNumber}:', driver['licenseNumber'] ?? t.nA),
                                  const SizedBox(height: 8),
                                  _buildDriverDetailRow(Icons.work_history, '${t.experienceYears}:', '${driver['experienceYears'] ?? 0} ${t.years}'),
                                ],
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
