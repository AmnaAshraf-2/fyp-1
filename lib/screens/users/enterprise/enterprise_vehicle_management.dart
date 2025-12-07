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

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadVehicleTypes();
    _loadLanguageCode();
    // Listen to locale changes
    localeNotifier?.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeNotifier?.removeListener(_onLocaleChanged);
    super.dispose();
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
          title: Text(t.addVehicle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: makeModelController,
                  decoration: InputDecoration(
                    labelText: t.makeModel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: registrationController,
                  decoration: InputDecoration(
                    labelText: t.registrationNumber,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: colorController,
                  decoration: InputDecoration(
                    labelText: t.color,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t.capacity,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: t.vehicleType,
                    border: const OutlineInputBorder(),
                  ),
                  items: _isLoadingVehicleTypes
                      ? [const DropdownMenuItem<String>(value: null, child: Text('Loading...'))]
                      : _vehicleTypes
                          .map((v) => DropdownMenuItem<String>(
                                value: v.getName(languageCode),
                                child: Text("${v.getName(languageCode)} (${v.getCapacity(languageCode)})"),
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
        'type': selectedType ?? 'Unknown',
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

      final newStatus = isActive ? 'active' : 'inactive';
      await _db.child('users/${user.uid}/vehicles/$vehicleId').update({
        'status': newStatus,
        'statusUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle status changed to ${newStatus}'),
          duration: const Duration(seconds: 2),
        ),
      );

      _loadVehicles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating vehicle status: $e')),
      );
    }
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

                // Vehicles List
                Expanded(
                  child: _vehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_shipping,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.noVehiclesFound,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.addYourFirstVehicle,
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
                          itemCount: _vehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = _vehicles[index];
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
                                  backgroundColor: Colors.green.shade700.withOpacity(.3),
                                  child: Icon(
                                    Icons.local_shipping,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  vehicle['makeModel'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${t.registrationNumber}: ${vehicle['registrationNumber'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(.9))),
                                    Text('${t.type}: ${vehicle['type'] ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(.9))),
                                    Text('${t.capacity}: ${vehicle['capacity'] ?? 'N/A'} kg', style: TextStyle(color: Colors.white.withOpacity(.9))),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Status Toggle Switch
                                    Switch(
                                      value: (vehicle['status'] ?? 'inactive') == 'active',
                                      onChanged: (value) => _toggleVehicleStatus(vehicle['id'], value),
                                      activeColor: Colors.green,
                                      inactiveThumbColor: Colors.red,
                                      inactiveTrackColor: Colors.red.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: vehicle['status'] == 'active' ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        vehicle['status'] == 'active' ? 'Active' : 'Inactive',
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
                                      onPressed: () => _deleteVehicle(vehicle['id']),
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
