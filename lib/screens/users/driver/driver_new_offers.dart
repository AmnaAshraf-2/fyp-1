import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/driver/driver_waiting_for_response.dart';

class DriverNewOffersScreen extends StatefulWidget {
  const DriverNewOffersScreen({super.key});

  @override
  State<DriverNewOffersScreen> createState() => _DriverNewOffersScreenState();
}

class _DriverNewOffersScreenState extends State<DriverNewOffersScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  String? _driverId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    print('🔍 DEBUG: Starting to load offers...');
    
    final driver = _auth.currentUser;
    if (driver == null) {
      print('❌ DEBUG: No authenticated driver found');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _driverId = driver.uid;
    print('🔍 DEBUG: Loading offers for driver: $_driverId');

    try {
      // Check if driver_offers exists
      final driverOffersSnapshot = await _db.child('driver_offers').get();
      print('🔍 DEBUG: driver_offers exists: ${driverOffersSnapshot.exists}');
      
      if (!driverOffersSnapshot.exists) {
        print('❌ DEBUG: No driver_offers found');
        setState(() {
          _offers = [];
          _isLoading = false;
        });
        return;
      }

      // Check for offers for this specific driver
      final offersSnapshot = await _db.child('driver_offers/$_driverId/new_offers').get();
      print('🔍 DEBUG: Offers for driver $_driverId exist: ${offersSnapshot.exists}');
      print('🔍 DEBUG: Number of offers: ${offersSnapshot.children.length}');

      if (!offersSnapshot.exists || offersSnapshot.children.isEmpty) {
        print('❌ DEBUG: No offers found for driver $_driverId');
        setState(() {
          _offers = [];
          _isLoading = false;
        });
        return;
      }

      // Load request details for each offer
      final List<Map<String, dynamic>> loadedOffers = [];
      
      for (final offer in offersSnapshot.children) {
        final requestId = offer.key;
        print('🔍 DEBUG: Processing offer with requestId: $requestId');
        
        try {
          final requestSnapshot = await _db.child('requests/$requestId').get();
          if (requestSnapshot.exists) {
            final data = Map<String, dynamic>.from(requestSnapshot.value as Map);
            print('🔍 DEBUG: Request data loaded: ${data['loadName']}');
            loadedOffers.add(data);
          } else {
            print('❌ DEBUG: Request $requestId not found');
          }
        } catch (e) {
          print('❌ DEBUG: Error loading request $requestId: $e');
        }
      }

      print('🔍 DEBUG: Final loaded offers count: ${loadedOffers.length}');
      
      setState(() {
        _offers = loadedOffers;
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ DEBUG: Error in _loadOffers: $e');
      setState(() {
        _offers = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _makeCounterOffer(String requestId, double originalFare) async {
    final t = AppLocalizations.of(context)!;

    final TextEditingController fareController = TextEditingController(
      text: originalFare.toString(),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.makeCounterOffer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${t.originalFare}: Rs $originalFare'),
            const SizedBox(height: 16),
            TextField(
              controller: fareController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.yourOffer,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final offeredFare = double.tryParse(fareController.text);
              if (offeredFare != null && offeredFare > 0) {
                Navigator.pop(context, offeredFare);
              }
            },
            child: Text(t.sendOffer),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Create counter offer for customer
        final offerRef = _db.child('customer_offers/$requestId').push();
        await offerRef.set({
          'driverId': _driverId,
          'driverName': 'Driver', // You can get this from user profile
          'originalFare': originalFare,
          'offeredFare': result,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
        });

        // Update request with final fare
        await _db.child('requests/$requestId').update({
          'finalFare': result,
        });

        // Remove from driver's new offers
        await _db.child('driver_offers/$_driverId/new_offers/$requestId').remove();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.offerSent)),
        );

        // Navigate to waiting screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverWaitingForResponseScreen(
              requestId: requestId,
              offeredFare: result,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.errorOccurred} $e')),
        );
      }
    }
  }

  Future<void> _dismissOffer(String requestId) async {
    final t = AppLocalizations.of(context)!;
    try {
      await _db.child('driver_offers/$_driverId/new_offers/$requestId').remove();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.offerDismissed)),
      );

      _loadOffers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorOccurred} $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.newOffersTitle, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(t.noNewOffers, style: const TextStyle(color: Color(0xFF004d4d))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOffers,
                        child: Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOffers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _offers.length,
                    itemBuilder: (context, index) {
                      final offer = _offers[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${t.load}: ${offer['loadName'] ?? 'N/A'}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(t.type, offer['loadType'] ?? 'N/A'),
                              _buildInfoRow(t.weight, '${offer['weight'] ?? 'N/A'} ${offer['weightUnit'] ?? ''}'),
                              _buildInfoRow(t.fareOffered, 'Rs ${offer['offerFare'] ?? 'N/A'}'),
                              _buildInfoRow(t.pickupTime, offer['pickupTime'] ?? 'N/A'),
                              _buildInfoRow(t.insurance, (offer['isInsured'] == true) ? t.yes : t.no),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.local_offer),
                                    label: Text(t.makeCounterOffer),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                    onPressed: () => _makeCounterOffer(
                                      offer['requestId'] ?? '',
                                      (offer['offerFare'] ?? 0).toDouble(),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.close),
                                    label: Text(t.dismiss),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () => _dismissOffer(offer['requestId'] ?? ''),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF004d4d)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFF004d4d))),
          ),
        ],
      ),
    );
  }
}