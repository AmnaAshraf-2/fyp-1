import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/vehicle_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/main.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

class EnterpriseVehicleManagement extends StatefulWidget {
  const EnterpriseVehicleManagement({super.key});

  @override
  State<EnterpriseVehicleManagement> createState() => _EnterpriseVehicleManagementState();
}

class _EnterpriseVehicleManagementState extends State<EnterpriseVehicleManagement> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  final VehicleProvider _vehicleProvider = VehicleProvider();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicles = [];
  List<VehicleModel> _vehicleTypes = [];
  bool _isLoadingVehicleTypes = true;
  String _languageCode = 'en';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadVehicleTypes();
    _loadLanguageCode();
    // Listen to locale changes
    localeNotifier?.addListener(_onLocaleChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    localeNotifier?.removeListener(_onLocaleChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    if (_searchQuery.isEmpty) {
      return _vehicles;
    }
    return _vehicles.where((vehicle) {
      final makeModel = (vehicle['makeModel'] ?? '').toString().toLowerCase();
      final registrationNumber = (vehicle['registrationNumber'] ?? '').toString().toLowerCase();
      final type = (vehicle['type'] ?? '').toString().toLowerCase();
      final color = (vehicle['color'] ?? '').toString().toLowerCase();
      return makeModel.contains(_searchQuery) ||
          registrationNumber.contains(_searchQuery) ||
          type.contains(_searchQuery) ||
          color.contains(_searchQuery);
    }).toList();
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

  Future<void> _loadVehicleTypes() async {
    try {
      final vehicles = await _vehicleProvider.loadVehicles();
      if (mounted) {
        setState(() {
          _vehicleTypes = vehicles;
          _isLoadingVehicleTypes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVehicleTypes = false;
        });
      }
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _db.child('users/${user.uid}/vehicles').get();
      if (snapshot.exists) {
        final vehiclesData = snapshot.value as Map;
        _vehicles = vehiclesData.entries.map((entry) {
          final vehicleData = Map<String, dynamic>.from(entry.value as Map);
          vehicleData['id'] = entry.key;
          return vehicleData;
        }).toList();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading vehicles: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addVehicle() async {
    final t = AppLocalizations.of(context)!;
    final languageCode = _languageCode; // Capture current language code
    
    final TextEditingController makeModelController = TextEditingController();
    final TextEditingController registrationController = TextEditingController();
    final TextEditingController colorController = TextEditingController();
    final TextEditingController capacityController = TextEditingController();
    String? selectedType;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            t.addVehicle,
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
                  controller: makeModelController,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.makeModel,
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
                  controller: registrationController,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.registrationNumber,
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
                  controller: colorController,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.color,
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
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.capacity,
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
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: kTealDark),
                  decoration: InputDecoration(
                    labelText: t.vehicleType,
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
                  items: _isLoadingVehicleTypes
                      ? [DropdownMenuItem<String>(
                          value: null, 
                          child: Text(t.loading, style: const TextStyle(color: kTealDark)),
                        )]
                      : _vehicleTypes
                          .map((v) => DropdownMenuItem<String>(
                                value: v.getName(languageCode),
                                child: Text(
                                  "${v.getName(languageCode)} (${v.getCapacity(languageCode)})",
                                  style: const TextStyle(color: kTealDark),
                                ),
                              ))
                          .toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() {
                      selectedType = newValue!;
                    });
                  },
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
                if (makeModelController.text.isNotEmpty &&
                    registrationController.text.isNotEmpty &&
                    colorController.text.isNotEmpty &&
                    capacityController.text.isNotEmpty &&
                    selectedType != null) {
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
      await _saveVehicle({
        'makeModel': makeModelController.text,
        'registrationNumber': registrationController.text,
        'color': colorController.text,
        'capacity': capacityController.text,
        'type': selectedType ?? t.unknown,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
        'status': 'active', // Default to active when adding
      });
    }
  }

  Future<void> _saveVehicle(Map<String, dynamic> vehicleData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final vehicleRef = _db.child('users/${user.uid}/vehicles').push();
      await vehicleRef.set(vehicleData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.vehicleAddedSuccessfully)),
      );

      _loadVehicles();
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
    }
  }

  Future<void> _toggleVehicleStatus(String vehicleId, bool isActive) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final t = AppLocalizations.of(context)!;
      final newStatus = isActive ? t.active : t.inactive;
      final statusValue = isActive ? 'active' : 'inactive';
      await _db.child('users/${user.uid}/vehicles/$vehicleId').update({
        'status': statusValue,
        'statusUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.vehicleStatusChangedTo(newStatus)),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadVehicles();
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorUpdatingVehicleStatus} $e')),
      );
    }
  }

  Widget _buildVehicleDetailRow(IconData icon, String label, String value) {
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

  Future<void> _deleteVehicle(String vehicleId) async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteVehicle),
        content: Text(t.areYouSureDeleteVehicle),
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

        await _db.child('users/${user.uid}/vehicles/$vehicleId').remove();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.vehicleDeletedSuccessfully)),
        );

        _loadVehicles();
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
                            t.totalVehicles,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _vehicles.length.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addVehicle,
                        icon: const Icon(Icons.add),
                        label: Text(t.addVehicle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
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
                      hintText: t.searchVehiclesBy,
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

                // Vehicles List
                Expanded(
                  child: _filteredVehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off : Icons.local_shipping,
                                size: 64,
                                color: Colors.white.withOpacity(.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ? t.noVehiclesFoundForSearch : t.noVehiclesFound,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? t.tryDifferentSearchTerm
                                    : t.addYourFirstVehicle,
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
                          itemCount: _filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = _filteredVehicles[index];
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
                                  // Header Row with Icon, Name, and Actions
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.green.shade700.withOpacity(.3),
                                        child: const Icon(
                                          Icons.local_shipping,
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
                                              vehicle['makeModel'] ?? t.unknown,
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
                                                color: vehicle['status'] == 'active' 
                                                    ? Colors.green.withOpacity(0.3)
                                                    : Colors.red.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: vehicle['status'] == 'active' ? Colors.green : Colors.red,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                vehicle['status'] == 'active' ? t.active : t.inactive,
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
                                            value: (vehicle['status'] ?? 'inactive') == 'active',
                                            onChanged: (value) => _toggleVehicleStatus(vehicle['id'], value),
                                            activeColor: Colors.green,
                                            inactiveThumbColor: Colors.red,
                                            inactiveTrackColor: Colors.red.withOpacity(0.5),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () => _deleteVehicle(vehicle['id']),
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
                                  // Vehicle Details
                                  _buildVehicleDetailRow(Icons.confirmation_number, '${t.registrationNumber}:', vehicle['registrationNumber'] ?? t.nA),
                                  const SizedBox(height: 8),
                                  _buildVehicleDetailRow(Icons.category, '${t.type}:', vehicle['type'] ?? t.nA),
                                  const SizedBox(height: 8),
                                  _buildVehicleDetailRow(Icons.scale, '${t.capacity}:', '${vehicle['capacity'] ?? t.nA} kg'),
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
          t.vehicles,
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
