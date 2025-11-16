import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/customer/customer_accepted_offer.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';

class WaitingForResponseScreen extends StatefulWidget {
  final String requestId;

  const WaitingForResponseScreen({super.key, required this.requestId});

  @override
  State<WaitingForResponseScreen> createState() => _WaitingForResponseScreenState();
}

class _WaitingForResponseScreenState extends State<WaitingForResponseScreen> {
  final _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  List<Map<String, dynamic>> _driverOffers = [];

  @override
  void initState() {
    super.initState();
    _loadRequestData();
    _listenForOffers();
  }

  Future<void> _loadRequestData() async {
    try {
      final snapshot = await _db.child('requests/${widget.requestId}').get();
      if (snapshot.exists) {
        setState(() {
          _requestData = Map<String, dynamic>.from(snapshot.value as Map);
        });
      }
    } catch (e) {
      print('Error loading request data: $e');
    }
  }

  void _listenForOffers() {
    // Listen for driver offers on this request
    _db.child('customer_offers/${widget.requestId}').onValue.listen((event) {
      if (event.snapshot.exists) {
        final offers = <Map<String, dynamic>>[];
        for (final offer in event.snapshot.children) {
          final offerData = Map<String, dynamic>.from(offer.value as Map);
          offerData['offerId'] = offer.key;
          offers.add(offerData);
        }
        setState(() {
          _driverOffers = offers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _driverOffers = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _acceptOffer(String offerId, double offeredFare) async {
    final t = AppLocalizations.of(context)!;
    try {
      print('🔍 DEBUG: Customer accepting offer: $offerId with fare: $offeredFare');
      
      // Find the selected offer
      final selectedOffer = _driverOffers.firstWhere((offer) => offer['offerId'] == offerId);
      final driverId = selectedOffer['driverId'];
      
      print('🔍 DEBUG: Selected driver ID: $driverId');
      
      // Update request status to accepted
      await _db.child('requests/${widget.requestId}').update({
        'status': 'accepted',
        'acceptedOfferId': offerId,
        'acceptedDriverId': driverId,
        'finalFare': offeredFare,
      });

      print('🔍 DEBUG: Request status updated to accepted');

      // Update offer status
      await _db.child('customer_offers/${widget.requestId}/$offerId').update({
        'status': 'accepted',
      });

      print('🔍 DEBUG: Offer status updated to accepted');

      // Remove all other offers
      final otherOffers = _driverOffers.where((offer) => offer['offerId'] != offerId).toList();
      for (final offer in otherOffers) {
        await _db.child('customer_offers/${widget.requestId}/${offer['offerId']}').remove();
      }

      print('🔍 DEBUG: Other offers removed');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.offerAccepted)),
      );

      print('🔍 DEBUG: Navigating to customer accepted offer screen');

      // Navigate to accepted offer screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerAcceptedOfferScreen(
            requestId: widget.requestId,
            offerId: offerId,
          ),
        ),
      );
    } catch (e) {
      print('❌ DEBUG: Error accepting offer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorOccurred} $e')),
      );
    }
  }

  Future<void> _rejectOffer(String offerId) async {
    final t = AppLocalizations.of(context)!;
    try {
      await _db.child('customer_offers/${widget.requestId}/$offerId').remove();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.offerRejected)),
      );
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
        title: Text(t.waitingForResponse, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requestData == null
              ? Center(child: Text(t.requestNotFound, style: const TextStyle(color: Color(0xFF004d4d))))
              : Column(
                  children: [
                    // Request details card
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.yourRequest,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004d4d),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${t.load}: ${_requestData!['loadName']}', style: const TextStyle(color: Color(0xFF004d4d))),
                            Text('${t.type}: ${_requestData!['loadType']}', style: const TextStyle(color: Color(0xFF004d4d))),
                            Text('${t.weight}: ${_requestData!['weight']} ${_requestData!['weightUnit']}', style: const TextStyle(color: Color(0xFF004d4d))),
                            Text('${t.fareOffered}: Rs ${_requestData!['offerFare']}', style: const TextStyle(color: Color(0xFF004d4d))),
                            Text('${t.pickupTime}: ${_requestData!['pickupTime']}', style: const TextStyle(color: Color(0xFF004d4d))),
                          ],
                        ),
                      ),
                    ),
                    
                    // Driver offers section
                    Expanded(
                      child: _driverOffers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(t.waitingForDrivers, style: const TextStyle(color: Color(0xFF004d4d))),
                                  const SizedBox(height: 8),
                                  Text(t.driversWillRespondSoon, style: const TextStyle(color: Color(0xFF004d4d))),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _driverOffers.length,
                              itemBuilder: (context, index) {
                                final offer = _driverOffers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.local_offer, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text(
                                              t.driverOffer,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF004d4d),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text('${t.driverName}: ${offer['driverName'] ?? 'Unknown'}', style: const TextStyle(color: Color(0xFF004d4d))),
                                        Text('${t.offeredFare}: Rs ${offer['offeredFare']}', style: const TextStyle(color: Color(0xFF004d4d))),
                                        Text('${t.originalFare}: Rs ${_requestData!['offerFare']}', style: const TextStyle(color: Color(0xFF004d4d))),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.check),
                                              label: Text(t.accept),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                              ),
                                              onPressed: () => _acceptOffer(
                                                offer['offerId'],
                                                offer['offeredFare'].toDouble(),
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.close),
                                              label: Text(t.reject),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              onPressed: () => _rejectOffer(offer['offerId']),
                                            ),
                                          ],
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
    );
  }
}
