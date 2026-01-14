import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/drawer/enterprise_drawer.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_vehicle_management.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_driver_management.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_new_offers.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_bookings.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_active_trips.dart';
import 'package:logistics_app/services/location_permission_service.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

class EnterpriseDashboard extends StatefulWidget {
  const EnterpriseDashboard({super.key});

  @override
  State<EnterpriseDashboard> createState() => _EnterpriseDashboardState();
}

class _EnterpriseDashboardState extends State<EnterpriseDashboard> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _enterpriseData;
  String? _userName;
  int _vehicleCount = 0;
  int _driverCount = 0;
  int _newOffersCount = 0;
  int _bookedTripsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEnterpriseData();
    _requestLocationPermission();
  }

  /// Request location permission when enterprise logs in
  Future<void> _requestLocationPermission() async {
    // Wait a bit for the screen to be fully built
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      final permissionService = LocationPermissionService();
      await permissionService.requestLocationPermission(context);
    }
  }

  Future<void> _loadEnterpriseData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🔍 DEBUG: No user found - user is null');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('🔍 DEBUG: Loading enterprise data for user: ${user.uid}');
      print('🔍 DEBUG: User email: ${user.email}');
      
      // Always set loading to false and show dashboard
      setState(() {
        _isLoading = false;
      });
      
      // Try to load data, but don't fail if it doesn't exist
      try {
        final snapshot = await _db.child('users/${user.uid}').get();
        print('🔍 DEBUG: Database snapshot exists: ${snapshot.exists}');
        
        if (snapshot.exists) {
          final userData = Map<String, dynamic>.from(snapshot.value as Map);
          print('🔍 DEBUG: User data loaded: ${userData.keys.toList()}');
          print('🔍 DEBUG: User role: ${userData['role']}');
          print('🔍 DEBUG: Is profile complete: ${userData['isProfileComplete']}');
          
          _enterpriseData = userData['enterpriseDetails'];
          // Get user's name from userData or Firebase Auth
          // Check multiple possible name fields (prioritize 'name' as that's what registration uses)
          String? name = userData['name'] as String?;
          if (name == null || name.trim().isEmpty) {
            name = userData['full_name'] as String?;
          }
          if (name == null || name.trim().isEmpty) {
            name = userData['fullName'] as String?;
          }
          if (name == null || name.trim().isEmpty) {
            name = userData['companyName'] as String?;
          }
          if (name == null || name.trim().isEmpty) {
            name = _enterpriseData?['enterpriseName'] as String?;
          }
          if (name == null || name.trim().isEmpty) {
            name = _enterpriseData?['contactPerson'] as String?;
          }
          if (name == null || name.trim().isEmpty) {
            name = user.displayName;
          }
          if (name == null || name.trim().isEmpty) {
            name = user.email?.split('@')[0];
          }
          _userName = name?.trim();
          print('🔍 DEBUG: Enterprise details: $_enterpriseData');
          print('🔍 DEBUG: User name from DB: ${userData['name']}');
          print('🔍 DEBUG: Final user name: $_userName');
          
          // Update state after loading name
          if (mounted) {
            setState(() {});
          }
        } else {
          print('🔍 DEBUG: No user data found in database for user: ${user.uid}');
          print('🔍 DEBUG: Showing dashboard with default values');
          // Still try to get name from Firebase Auth
          _userName = user.displayName ?? user.email?.split('@')[0];
          
          // Update state after setting fallback name
          if (mounted) {
            setState(() {});
          }
        }
        
        // Always load counts regardless of whether user data exists
        // Drivers and vehicles might exist even if parent node doesn't
        await _loadAllCounts();
        
        print('🔍 DEBUG: Final counts - Vehicles: $_vehicleCount, Drivers: $_driverCount, Offers: $_newOffersCount, Trips: $_bookedTripsCount');
      } catch (e) {
        print('🔍 DEBUG: Error loading enterprise data: $e');
        print('🔍 DEBUG: Error type: ${e.runtimeType}');
        // Still try to load counts even if user data loading fails
        await _loadAllCounts();
      }
    } catch (e) {
      print('🔍 DEBUG: Critical error in _loadEnterpriseData: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllCounts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🔍 DEBUG: Starting to load counts for user: ${user.uid}');

      // Load vehicles count - only from users path (vehicles are stored in users/${user.uid}/vehicles)
      final usersVehiclesSnapshot = await _db.child('users/${user.uid}/vehicles').get();
      
      print('🔍 DEBUG: Users vehicles exists: ${usersVehiclesSnapshot.exists}');
      
      if (usersVehiclesSnapshot.exists) {
        final vehiclesData = usersVehiclesSnapshot.value;
        if (vehiclesData != null && vehiclesData is Map) {
          _vehicleCount = vehiclesData.length;
          print('🔍 DEBUG: Users vehicles count: $_vehicleCount');
        } else {
          _vehicleCount = 0;
          print('🔍 DEBUG: Users vehicles data is null or not a Map');
        }
      } else {
        _vehicleCount = 0;
        print('🔍 DEBUG: Users vehicles snapshot does not exist');
      }
      
      print('🔍 DEBUG: Total vehicles count: $_vehicleCount');
      
      // Load drivers count - only from users path (enterprise_driver_management.dart)
      final usersDriversSnapshot = await _db.child('users/${user.uid}/drivers').get();
      
      print('🔍 DEBUG: Users drivers exists: ${usersDriversSnapshot.exists}');
      
      if (usersDriversSnapshot.exists) {
        final driversData = usersDriversSnapshot.value;
        if (driversData != null && driversData is Map) {
          _driverCount = driversData.length;
          print('🔍 DEBUG: Users drivers count: $_driverCount');
          for (final key in driversData.keys) {
            print('🔍 DEBUG: Users driver key: $key');
          }
        } else {
          _driverCount = 0;
          print('🔍 DEBUG: Users drivers data is null or not a Map');
        }
      } else {
        _driverCount = 0;
        print('🔍 DEBUG: Users drivers snapshot does not exist');
      }
      
      // Load new offers count (requests where enterprise drivers are involved)
      await _loadNewOffersCount();
      
      // Load booked trips count (accepted requests)
      await _loadBookedTripsCount();
      
      print('🔍 DEBUG: Final counts - Vehicles: $_vehicleCount, Drivers: $_driverCount, Offers: $_newOffersCount, Trips: $_bookedTripsCount');
      
      // Force UI update
      setState(() {});
    } catch (e) {
      print('🔍 DEBUG: Error loading counts: $e');
      _vehicleCount = 0;
      _driverCount = 0;
      _newOffersCount = 0;
      _bookedTripsCount = 0;
    }
  }

  Future<void> _loadNewOffersCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Load offers from enterprise_offers collection (direct enterprise offers)
      final enterpriseOffersSnapshot = await _db.child('enterprise_offers/${user.uid}/new_offers').get();
      int enterpriseOffers = enterpriseOffersSnapshot.exists ? enterpriseOffersSnapshot.children.length : 0;

      // Also load offers from driver_offers for enterprise drivers (existing logic)
      final driversSnapshot = await _db.child('users/${user.uid}/drivers').get();
      int driverOffers = 0;
      if (driversSnapshot.exists) {
        for (final driver in driversSnapshot.children) {
          final driverId = driver.key;
          final offersSnapshot = await _db.child('driver_offers/$driverId/new_offers').get();
          if (offersSnapshot.exists) {
            driverOffers += offersSnapshot.children.length;
          }
        }
      }

      _newOffersCount = enterpriseOffers + driverOffers;
      print('🔍 DEBUG: Enterprise offers: $enterpriseOffers, Driver offers: $driverOffers, Total: $_newOffersCount');
    } catch (e) {
      print('🔍 DEBUG: Error loading new offers count: $e');
      _newOffersCount = 0;
    }
  }

  Future<void> _loadBookedTripsCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get all driver IDs for this enterprise
      final driversSnapshot = await _db.child('users/${user.uid}/drivers').get();
      if (!driversSnapshot.exists) {
        _bookedTripsCount = 0;
        return;
      }

      int totalTrips = 0;
      for (final driver in driversSnapshot.children) {
        final driverId = driver.key;
        final tripsSnapshot = await _db.child('requests').get();
        if (tripsSnapshot.exists) {
          for (final request in tripsSnapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            if (requestData['acceptedDriverId'] == driverId && requestData['status'] == 'accepted') {
              totalTrips++;
            }
          }
        }
      }
      _bookedTripsCount = totalTrips;
    } catch (e) {
      print('🔍 DEBUG: Error loading booked trips count: $e');
      _bookedTripsCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    // Define the screens for each tab
    final List<Widget> _screens = [
      _buildDashboardTab(t),
      const EnterpriseVehicleManagement(),
      const EnterpriseDriverManagement(),
      const EnterpriseBookingsScreen(),
      const EnterpriseActiveTripsScreen(),
      const EnterpriseNewOffersScreen(),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kTeal, kTealDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -3),
            )
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          showUnselectedLabels: false,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Refresh counts when switching back to dashboard tab
            if (index == 0) {
              _loadAllCounts();
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard),
              label: t.dashboard,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.local_shipping),
              label: t.vehicles,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: t.drivers,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_turned_in),
              label: t.bookings,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.directions_car),
              label: t.activeTrips,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.notifications_active),
              label: t.newOffers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(AppLocalizations t) {
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(t),
                      const SizedBox(height: 28),
                      _buildSectionTitle(t.keyMetrics),
                      const SizedBox(height: 14),
                      // FULL WIDTH CARDS
                      _buildFullWidthMetricCard(
                        icon: Icons.local_shipping,
                        title: t.totalVehicles,
                        count: _vehicleCount,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(height: 16),
                      _buildFullWidthMetricCard(
                        icon: Icons.person,
                        title: t.totalDrivers,
                        count: _driverCount,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 16),
                      _buildFullWidthMetricCard(
                        icon: Icons.assignment_turned_in,
                        title: t.activeBookings,
                        count: _bookedTripsCount,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(height: 30),
                      _buildSectionTitle(t.quickActions),
                      const SizedBox(height: 12),
                      _buildActionButtons(t),
                    ],
                  ),
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
        centerTitle: true,
        title: const Text(
          'LAARI',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      drawer: const EnterpriseDrawer(),
    );
  }

  Widget _buildFullWidthMetricCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withOpacity(.2),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations t) {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.assignment_turned_in,
          title: t.bookings,
          subtitle: t.viewActiveBookings,
          color: Colors.purple.shade700,
          onTap: () => setState(() => _currentIndex = 3),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.notifications_active,
          title: t.newOffers,
          subtitle: t.viewNewOffers,
          color: Colors.blue.shade700,
          onTap: () => setState(() => _currentIndex = 4),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: color.withOpacity(.2),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(.7),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${t.welcomeBack},",
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _userName ?? _enterpriseData?['enterpriseName'] ?? t.enterpriseUser,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t.manageLogisticsOperations,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  void _navigateToNewOffers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnterpriseNewOffersScreen(),
      ),
    );
  }

}
