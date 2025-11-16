import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'enterprise_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../customer/customerDashboard.dart';

class ShareholderDetailsScreen extends StatefulWidget {
  const ShareholderDetailsScreen({super.key});

  @override
  State<ShareholderDetailsScreen> createState() => _ShareholderDetailsScreenState();
}

class _ShareholderDetailsScreenState extends State<ShareholderDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();

  // Controllers for shareholder details
  final TextEditingController shareholderNameController = TextEditingController();
  final TextEditingController shareholderCnicController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController sharePercentageController = TextEditingController();
  final TextEditingController designationController = TextEditingController();

  // Mask formatters
  late MaskTextInputFormatter phoneMaskFormatter;
  late MaskTextInputFormatter cnicMaskFormatter;

  bool _isLoading = false;
  List<Map<String, dynamic>> _shareholders = [];
  String? _selectedDesignation;

  final List<String> _designations = [
    'CEO',
    'Managing Director',
    'Director',
    'Shareholder',
    'Partner',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    phoneMaskFormatter = MaskTextInputFormatter(
      mask: '+92 ### ### ####',
      filter: {"#": RegExp(r'[0-9]')},
    );
    cnicMaskFormatter = MaskTextInputFormatter(
      mask: '#####-#######-#',
      filter: {"#": RegExp(r'[0-9]')},
    );
  }

  @override
  void dispose() {
    shareholderNameController.dispose();
    shareholderCnicController.dispose();
    phoneController.dispose();
    addressController.dispose();
    sharePercentageController.dispose();
    designationController.dispose();
    super.dispose();
  }

  void _addShareholder() {
    if (_formKey.currentState!.validate()) {
      final shareholder = {
        'name': shareholderNameController.text.trim(),
        'cnic': shareholderCnicController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'sharePercentage': double.tryParse(sharePercentageController.text) ?? 0.0,
        'designation': _selectedDesignation ?? designationController.text.trim(),
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      };

      setState(() {
        _shareholders.add(shareholder);
        _clearForm();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.shareholderAdded),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _removeShareholder(int index) {
    setState(() {
      _shareholders.removeAt(index);
    });
  }

  void _clearForm() {
    shareholderNameController.clear();
    shareholderCnicController.clear();
    phoneController.clear();
    addressController.clear();
    sharePercentageController.clear();
    designationController.clear();
    _selectedDesignation = null;
  }

  Future<void> _completeRegistration() async {
    if (_shareholders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseAddAtLeastOneShareholder),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate total share percentage
    double totalPercentage = _shareholders.fold(0.0, (sum, shareholder) => 
        sum + (shareholder['sharePercentage'] as double));
    
    if (totalPercentage > 100.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.totalSharePercentageExceeded),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLogin)),
        );
        return;
      }

      // Save shareholders to user's record
      await _dbRef.child('users').child(user.uid).update({
        'shareholders': _shareholders,
        'isProfileComplete': true,
        'profileCompletedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Save user name to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('full_name', _shareholders.first['name']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.enterpriseRegistrationComplete),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to enterprise dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const EnterpriseDashboard()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(loc.shareholderDetails, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blueAccent, Colors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.people,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loc.shareholderDetails,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      loc.shareholderDetailsDesc,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Add Shareholder Form
              _buildSectionHeader(loc.addShareholder),
              const SizedBox(height: 16),

              // Shareholder Name
              TextFormField(
                controller: shareholderNameController,
                decoration: InputDecoration(
                  labelText: loc.shareholderName,
                  hintText: loc.shareholderNameHint,
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterShareholderName;
                  }
                  if (value.length < 2) {
                    return loc.shareholderNameTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // CNIC and Phone Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: shareholderCnicController,
                      inputFormatters: [cnicMaskFormatter],
                      decoration: InputDecoration(
                        labelText: loc.cnic,
                        hintText: '12345-1234567-1',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterCnic;
                        }
                        if (value.length < 15) {
                          return loc.cnicTooShort;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: phoneController,
                      inputFormatters: [phoneMaskFormatter],
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: loc.phoneNumber,
                        hintText: '+92 300 123 4567',
                        prefixIcon: const Icon(Icons.phone),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterPhoneNumber;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: loc.address,
                  hintText: loc.addressHint,
                  prefixIcon: const Icon(Icons.location_on),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterAddress;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Share Percentage and Designation Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: sharePercentageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.sharePercentage,
                        hintText: '25.5',
                        prefixIcon: const Icon(Icons.percent),
                        suffixText: '%',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterSharePercentage;
                        }
                        final percentage = double.tryParse(value);
                        if (percentage == null || percentage <= 0 || percentage > 100) {
                          return loc.sharePercentageInvalid;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDesignation,
                      decoration: InputDecoration(
                        labelText: loc.designation,
                        prefixIcon: const Icon(Icons.work),
                        border: const OutlineInputBorder(),
                      ),
                      items: _designations.map((String designation) {
                        return DropdownMenuItem<String>(
                          value: designation,
                          child: Text(designation),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDesignation = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseSelectDesignation;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Add Shareholder Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _addShareholder,
                  icon: const Icon(Icons.add),
                  label: Text(loc.addShareholder),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Shareholders List
              if (_shareholders.isNotEmpty) ...[
                _buildSectionHeader(loc.shareholdersList),
                const SizedBox(height: 16),
                ...List.generate(_shareholders.length, (index) {
                  final shareholder = _shareholders[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Text(
                          shareholder['name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        shareholder['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CNIC: ${shareholder['cnic']}', style: const TextStyle(color: Color(0xFF004d4d))),
                          Text('Phone: ${shareholder['phone']}', style: const TextStyle(color: Color(0xFF004d4d))),
                          Text('${shareholder['designation']} - ${shareholder['sharePercentage']}%', style: const TextStyle(color: Color(0xFF004d4d))),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeShareholder(index),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Total Share Percentage
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.totalSharePercentage,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF004d4d),
                        ),
                      ),
                      Text(
                        '${_shareholders.fold(0.0, (sum, shareholder) => sum + (shareholder['sharePercentage'] as double)).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF004d4d),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Complete Registration Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          loc.completeRegistration,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF004d4d),
        ),
      ),
    );
  }
}
