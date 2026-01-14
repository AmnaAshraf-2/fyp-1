import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/services/vehicle_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewBookingsScreen extends StatefulWidget {
  const NewBookingsScreen({super.key});

  @override
  State<NewBookingsScreen> createState() => _NewBookingsScreenState();
}

class _NewBookingsScreenState extends State<NewBookingsScreen> {
  final VehicleProvider _vehicleProvider = VehicleProvider();
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;
  String _languageCode = 'en';
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadLanguageCode();
    // Listen to locale changes
    localeNotifier?.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeNotifier?.removeListener(_onLocaleChanged);
    _scrollController.dispose();
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

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vehicles = await _vehicleProvider.loadVehicles(forceRefresh: true);
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoading = false;
          if (vehicles.isEmpty) {
            _errorMessage = 'No vehicles found. Please try again or contact support.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load vehicles: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Color(0xFFF4F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black12,
        centerTitle: true,
        title: Text(
          loc.selectVehicle,
          style: const TextStyle(
            color: Color(0xFF004d4d),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_shipping, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'No vehicles available',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadVehicles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: RefreshIndicator(
                    onRefresh: _loadVehicles,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _vehicles[index];
                        final color = Colors.teal;
                        
                        // Debug: Print vehicle image info
                        debugPrint('🚚 Vehicle: ${vehicle.nameKey}, Image: ${vehicle.image}');

                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/cargo-details',
                              arguments: vehicle,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.only(bottom: 18),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.8),
                                  Colors.white.withOpacity(0.4),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.teal.withOpacity(0.3),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Vehicle Image or Icon Holder
                                Builder(
                                  builder: (context) {
                                    final hasImage = vehicle.image != null && vehicle.image!.isNotEmpty;
                                    
                                    // Debug: print image path
                                    if (hasImage) {
                                      debugPrint('🖼️ Attempting to load vehicle image: ${vehicle.image}');
                                    }
                                    
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color.withOpacity(0.15),
                                        border: Border.all(
                                          color: hasImage ? Colors.transparent : Colors.transparent,
                                          width: 0,
                                        ),
                                      ),
                                      child: hasImage
                                          ? ClipOval(
                                              clipBehavior: Clip.antiAlias,
                                              child: Image.asset(
                                                vehicle.image!,
                                                key: ValueKey(vehicle.image), // Force rebuild if image changes
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                gaplessPlayback: true, // Prevent flicker
                                                errorBuilder: (context, error, stackTrace) {
                                                  // Debug: print error to console
                                                  debugPrint('❌ Error loading vehicle image: ${vehicle.image}');
                                                  debugPrint('Error type: ${error.runtimeType}');
                                                  debugPrint('Error: $error');
                                                  debugPrint('Stack trace: $stackTrace');
                                                  // Fallback to icon if image fails to load
                                                  return Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: color.withOpacity(0.15),
                                                    ),
                                                    child: Icon(
                                                      Icons.local_shipping,
                                                      size: 32,
                                                      color: color,
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Icon(
                                              Icons.local_shipping,
                                              size: 32,
                                              color: color,
                                            ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 18),
                                // Text Section
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicle.getName(_languageCode),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF003d3d),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        vehicle.getCapacity(_languageCode),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF006666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.teal),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
