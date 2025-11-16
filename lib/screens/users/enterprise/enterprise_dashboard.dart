import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/drawer/enterprise_drawer.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_vehicle_management.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_driver_management.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_new_offers.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_bookings.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_profile.dart';

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
  int _vehicleCount = 0;
  int _driverCount = 0;
  int _newOffersCount = 0;
  int _bookedTripsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEnterpriseData();
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
          print('🔍 DEBUG: Enterprise details: $_enterpriseData');
          
          // Count vehicles, drivers, offers, and trips
          await _loadAllCounts();
          
          print('🔍 DEBUG: Final counts - Vehicles: $_vehicleCount, Drivers: $_driverCount, Offers: $_newOffersCount, Trips: $_bookedTripsCount');
        } else {
          print('🔍 DEBUG: No user data found in database for user: ${user.uid}');
          print('🔍 DEBUG: Showing dashboard with default values');
        }
      } catch (e) {
        print('🔍 DEBUG: Error loading enterprise data: $e');
        print('🔍 DEBUG: Error type: ${e.runtimeType}');
        // Continue to show dashboard even if data loading fails
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

      // Load vehicles count - check both paths
      final usersVehiclesSnapshot = await _db.child('users/${user.uid}/vehicles').get();
      final enterprisesVehiclesSnapshot = await _db.child('enterprises/${user.uid}/vehicles').get();
      
      print('🔍 DEBUG: Users vehicles exists: ${usersVehiclesSnapshot.exists}');
      print('🔍 DEBUG: Enterprises vehicles exists: ${enterprisesVehiclesSnapshot.exists}');
      
      if (usersVehiclesSnapshot.exists) {
        print('🔍 DEBUG: Users vehicles children count: ${usersVehiclesSnapshot.children.length}');
        for (final child in usersVehiclesSnapshot.children) {
          print('🔍 DEBUG: Users vehicle key: ${child.key}');
        }
      }
      
      if (enterprisesVehiclesSnapshot.exists) {
        print('🔍 DEBUG: Enterprises vehicles children count: ${enterprisesVehiclesSnapshot.children.length}');
        for (final child in enterprisesVehiclesSnapshot.children) {
          print('🔍 DEBUG: Enterprises vehicle key: ${child.key}');
        }
      }
      
      int usersVehiclesCount = usersVehiclesSnapshot.exists ? usersVehiclesSnapshot.children.length : 0;
      int enterprisesVehiclesCount = enterprisesVehiclesSnapshot.exists ? enterprisesVehiclesSnapshot.children.length : 0;
      _vehicleCount = usersVehiclesCount + enterprisesVehiclesCount;
      
      // Load drivers count - check both paths
      final usersDriversSnapshot = await _db.child('users/${user.uid}/drivers').get();
      final enterprisesDriversSnapshot = await _db.child('enterprises/${user.uid}/drivers').get();
      
      print('🔍 DEBUG: Users drivers exists: ${usersDriversSnapshot.exists}');
      print('🔍 DEBUG: Enterprises drivers exists: ${enterprisesDriversSnapshot.exists}');
      
      if (usersDriversSnapshot.exists) {
        print('🔍 DEBUG: Users drivers children count: ${usersDriversSnapshot.children.length}');
        for (final child in usersDriversSnapshot.children) {
          print('🔍 DEBUG: Users driver key: ${child.key}');
        }
      }
      
      if (enterprisesDriversSnapshot.exists) {
        print('🔍 DEBUG: Enterprises drivers children count: ${enterprisesDriversSnapshot.children.length}');
        for (final child in enterprisesDriversSnapshot.children) {
          print('🔍 DEBUG: Enterprises driver key: ${child.key}');
        }
      }
      
      int usersDriversCount = usersDriversSnapshot.exists ? usersDriversSnapshot.children.length : 0;
      int enterprisesDriversCount = enterprisesDriversSnapshot.exists ? enterprisesDriversSnapshot.children.length : 0;
      _driverCount = usersDriversCount + enterprisesDriversCount;
      
      // Load new offers count (requests where enterprise drivers are involved)
      await _loadNewOffersCount();
      
      // Load booked trips count (accepted requests)
      await _loadBookedTripsCount();
      
      print('🔍 DEBUG: Final counts - Vehicles: $_vehicleCount (users: $usersVehiclesCount, enterprises: $enterprisesVehiclesCount), Drivers: $_driverCount (users: $usersDriversCount, enterprises: $enterprisesDriversCount), Offers: $_newOffersCount, Trips: $_bookedTripsCount');
      
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
      const EnterpriseProfileScreen(),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_shipping),
            label: 'Vehicles',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'Drivers',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.assignment_turned_in),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(AppLocalizations t) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.enterpriseDashboard, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEnterpriseData,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _addTestData,
          ),
        ],
      ),
      drawer: const EnterpriseDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blueAccent, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.welcomeBack},',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _enterpriseData?['enterpriseName'] ?? 'Enterprise User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage your logistics operations efficiently',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Key Metrics
                  Text(
                    'Key Metrics',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004d4d),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Four main metrics in a 2x2 grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.local_shipping,
                          title: 'Total Vehicles',
                          count: _vehicleCount,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.person,
                          title: 'Total Drivers',
                          count: _driverCount,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.assignment_turned_in,
                          title: 'Active Bookings',
                          count: _bookedTripsCount,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.notifications_active,
                          title: 'Pending Offers',
                          count: _newOffersCount,
                          color: Colors.blue,
                          onTap: () => _navigateToNewOffers(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Text(
                    t.quickActions,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004d4d),
                    ),
                  ),
                  const SizedBox(height: 16),

                   GridView.count(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     crossAxisCount: 2,
                     crossAxisSpacing: 16,
                     mainAxisSpacing: 16,
                     childAspectRatio: 1.5,
                     children: [
                       _buildActionCard(
                         icon: Icons.assignment_turned_in,
                         title: 'Bookings',
                         subtitle: 'View active bookings',
                         color: Colors.purple,
                         onTap: () {
                           setState(() {
                             _currentIndex = 3; // Switch to Bookings tab
                           });
                         },
                       ),
                       _buildActionCard(
                         icon: Icons.settings,
                         title: t.settings,
                         subtitle: t.manageSettings,
                         color: Colors.grey,
                         onTap: () {
                           setState(() {
                             _currentIndex = 4; // Switch to Profile tab
                           });
                         },
                       ),
                     ],
                   ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF004d4d),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004d4d),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF004d4d),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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

  Future<void> _addTestData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Add test vehicle to users path
      await _db.child('users/${user.uid}/vehicles').push().set({
        'makeModel': 'Test Vehicle',
        'type': 'Truck',
        'color': 'Blue',
        'capacity': '5000 kg',
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Add test driver to users path
      await _db.child('users/${user.uid}/drivers').push().set({
        'name': 'Test Driver',
        'phone': '+1234567890',
        'cnic': '12345-1234567-1',
        'licenseNumber': 'LIC123456',
        'experienceYears': 5,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Add test vehicle to enterprises path
      await _db.child('enterprises/${user.uid}/vehicles').push().set({
        'vehicleName': 'Enterprise Vehicle',
        'vehicleType': 'Van',
        'vehicleNumber': 'ABC-123',
        'capacity': 2000.0,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Add test driver to enterprises path
      await _db.child('enterprises/${user.uid}/drivers').push().set({
        'driverName': 'Enterprise Driver',
        'driverPhone': '+0987654321',
        'driverCnic': '98765-9876543-9',
        'licenseNumber': 'LIC789012',
        'experience': 3,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test data added successfully!')),
      );

      // Reload counts
      await _loadAllCounts();
    } catch (e) {
      print('🔍 DEBUG: Error adding test data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding test data: $e')),
      );
    }
  }
}
