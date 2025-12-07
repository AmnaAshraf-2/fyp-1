import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:email_validator/email_validator.dart';
import 'shareholder_details.dart';

class EnterpriseDetailsScreen extends StatefulWidget {
  const EnterpriseDetailsScreen({super.key});

  @override
  State<EnterpriseDetailsScreen> createState() => _EnterpriseDetailsScreenState();
}

class _EnterpriseDetailsScreenState extends State<EnterpriseDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();

  // Controllers for enterprise details
  final TextEditingController enterpriseNameController = TextEditingController();
  final TextEditingController regNumberController = TextEditingController();
  final TextEditingController ntnNumberController = TextEditingController();
  final TextEditingController cooperateNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController businessTypeController = TextEditingController();
  final TextEditingController businessAddressController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController provinceController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController contactPhoneController = TextEditingController();

  // Mask formatters
  late MaskTextInputFormatter phoneMaskFormatter;
  late MaskTextInputFormatter ntnMaskFormatter;
  late MaskTextInputFormatter regNumberMaskFormatter;

  bool _isLoading = false;
  String? _selectedBusinessType;

  List<String> _getBusinessTypes(AppLocalizations t) {
    return [
      t.privateLimitedCompany,
      t.publicLimitedCompany,
      t.partnership,
      t.soleProprietorship,
      t.nonProfitOrganization,
      t.governmentEntity,
      t.other
    ];
  }

  @override
  void initState() {
    super.initState();
    phoneMaskFormatter = MaskTextInputFormatter(
      mask: '+92 ### ### ####',
      filter: {"#": RegExp(r'[0-9]')},
    );
    ntnMaskFormatter = MaskTextInputFormatter(
      mask: '########-#',
      filter: {"#": RegExp(r'[0-9]')},
    );
    regNumberMaskFormatter = MaskTextInputFormatter(
      mask: '##########',
      filter: {"#": RegExp(r'[0-9]')},
    );
  }

  @override
  void dispose() {
    enterpriseNameController.dispose();
    regNumberController.dispose();
    ntnNumberController.dispose();
    cooperateNumberController.dispose();
    emailController.dispose();
    businessTypeController.dispose();
    businessAddressController.dispose();
    cityController.dispose();
    provinceController.dispose();
    postalCodeController.dispose();
    websiteController.dispose();
    contactPersonController.dispose();
    contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveEnterpriseDetails() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLogin)),
          );
          return;
        }

        // Save enterprise details to user's record
        await _dbRef.child('users').child(user.uid).update({
          'role': 'enterprise',
          'enterpriseDetails': {
            'enterpriseName': enterpriseNameController.text.trim(),
            'registrationNumber': regNumberController.text.trim(),
            'ntnNumber': ntnNumberController.text.trim(),
            'cooperateNumber': cooperateNumberController.text.trim(),
            'email': emailController.text.trim(),
            'businessType': _selectedBusinessType ?? businessTypeController.text.trim(),
            'businessAddress': businessAddressController.text.trim(),
            'city': cityController.text.trim(),
            'province': provinceController.text.trim(),
            'postalCode': postalCodeController.text.trim(),
            'website': websiteController.text.trim(),
            'contactPerson': contactPersonController.text.trim(),
            'contactPhone': contactPhoneController.text.trim(),
            'completedAt': DateTime.now().millisecondsSinceEpoch,
          },
          'isProfileComplete': false, // Will be true after shareholder details
        });

        // Navigate to shareholder details screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ShareholderDetailsScreen(),
          ),
        );
      } catch (e) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.error}: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(loc.enterpriseDetails, style: const TextStyle(color: Color(0xFF004d4d))),
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
                      Icons.business,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loc.enterpriseRegistration,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      loc.enterpriseDetailsDesc,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Enterprise Information Section
              _buildSectionHeader(loc.enterpriseInformation),
              const SizedBox(height: 16),

              // Enterprise Name
              TextFormField(
                controller: enterpriseNameController,
                decoration: InputDecoration(
                  labelText: loc.enterpriseName,
                  hintText: loc.enterpriseNameHint,
                  prefixIcon: const Icon(Icons.business),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterEnterpriseName;
                  }
                  if (value.length < 3) {
                    return loc.enterpriseNameTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Registration Number
              TextFormField(
                controller: regNumberController,
                inputFormatters: [regNumberMaskFormatter],
                decoration: InputDecoration(
                  labelText: loc.registrationNumber,
                  hintText: '1234567890',
                  prefixIcon: const Icon(Icons.assignment),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterRegistrationNumber;
                  }
                  if (value.length < 8) {
                    return loc.registrationNumberTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // NTN Number
              TextFormField(
                controller: ntnNumberController,
                inputFormatters: [ntnMaskFormatter],
                decoration: InputDecoration(
                  labelText: loc.ntnNumber,
                  hintText: '12345678-9',
                  prefixIcon: const Icon(Icons.receipt),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterNtnNumber;
                  }
                  if (value.length < 9) {
                    return loc.ntnNumberTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cooperate Number
              TextFormField(
                controller: cooperateNumberController,
                decoration: InputDecoration(
                  labelText: loc.cooperateNumber,
                  hintText: loc.cooperateNumberHint,
                  prefixIcon: const Icon(Icons.corporate_fare),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterCooperateNumber;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Address
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: loc.emailAddress,
                  hintText: 'enterprise@company.com',
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterEmail;
                  }
                  if (!EmailValidator.validate(value)) {
                    return loc.pleaseEnterValidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Business Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBusinessType,
                decoration: InputDecoration(
                  labelText: loc.businessType,
                  prefixIcon: const Icon(Icons.category),
                  border: const OutlineInputBorder(),
                ),
                items: _getBusinessTypes(loc).map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedBusinessType = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseSelectBusinessType;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Business Address Section
              _buildSectionHeader(loc.businessAddress),
              const SizedBox(height: 16),

              // Business Address
              TextFormField(
                controller: businessAddressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: loc.businessAddress,
                  hintText: loc.businessAddressHint,
                  prefixIcon: const Icon(Icons.location_on),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterBusinessAddress;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // City and Province Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: cityController,
                      decoration: InputDecoration(
                        labelText: loc.city,
                        prefixIcon: const Icon(Icons.location_city),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterCity;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: provinceController,
                      decoration: InputDecoration(
                        labelText: loc.province,
                        prefixIcon: const Icon(Icons.map),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterProvince;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Postal Code
              TextFormField(
                controller: postalCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: loc.postalCode,
                  hintText: '12345',
                  prefixIcon: const Icon(Icons.local_post_office),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterPostalCode;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Contact Information Section
              _buildSectionHeader(loc.contactInformation),
              const SizedBox(height: 16),

              // Contact Person
              TextFormField(
                controller: contactPersonController,
                decoration: InputDecoration(
                  labelText: loc.contactPerson,
                  hintText: loc.contactPersonHint,
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterContactPerson;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Contact Phone
              TextFormField(
                controller: contactPhoneController,
                inputFormatters: [phoneMaskFormatter],
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: loc.contactPhone,
                  hintText: '+92 300 123 4567',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterContactPhone;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Website (Optional)
              TextFormField(
                controller: websiteController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: '${loc.website} (${loc.optional})',
                  hintText: 'https://www.company.com',
                  prefixIcon: const Icon(Icons.web),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEnterpriseDetails,
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
                          loc.continueToShareholders,
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
