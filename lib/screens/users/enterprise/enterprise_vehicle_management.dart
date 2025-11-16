import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/data/vehicles.dart';

class EnterpriseVehicleManagement extends StatefulWidget {
  const EnterpriseVehicleManagement({super.key});

  @override
  State<EnterpriseVehicleManagement> createState() => _EnterpriseVehicleManagementState();
}

class _EnterpriseVehicleManagementState extends State<EnterpriseVehicleManagement> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
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
                  items: vehicleList
                      .map((v) => DropdownMenuItem<String>(
                            value: v.getName(t),
                            child: Text("${v.getName(t)} (${v.getCapacity(t)})"),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.vehicleManagement, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.shade50,
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
                              color: Color(0xFF004d4d),
                            ),
                          ),
                          Text(
                            _vehicles.length.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF004d4d),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addVehicle,
                        icon: const Icon(Icons.add),
                        label: Text(t.addVehicle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.addYourFirstVehicle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF004d4d),
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
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  child: Icon(
                                    Icons.local_shipping,
                                    color: Colors.green,
                                  ),
                                ),
                                title: Text(
                                  vehicle['makeModel'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${t.registrationNumber}: ${vehicle['registrationNumber'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF004d4d))),
                                    Text('${t.type}: ${vehicle['type'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFF004d4d))),
                                    Text('${t.capacity}: ${vehicle['capacity'] ?? 'N/A'} kg', style: const TextStyle(color: Color(0xFF004d4d))),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteVehicle(vehicle['id']),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
