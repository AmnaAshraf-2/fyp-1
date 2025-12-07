import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/driver/drivers.dart';
import 'package:logistics_app/screens/users/driver/driver_accepted_offer.dart';

class DriverWaitingForResponseScreen extends StatefulWidget {
  final String requestId;
  final double offeredFare;

  const DriverWaitingForResponseScreen({
    super.key, 
    required this.requestId, 
    required this.offeredFare
  });

  @override
  State<DriverWaitingForResponseScreen> createState() => _DriverWaitingForResponseScreenState();
}

class _DriverWaitingForResponseScreenState extends State<DriverWaitingForResponseScreen> {
  final _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  String? _offerId;
  bool _offerAccepted = false;
  bool _offerRejected = false;

  @override
  void initState() {
    super.initState();
    _loadRequestData();
    _listenForOfferResponse();
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

  void _listenForOfferResponse() {
    // Listen for request status changes (primary way to detect acceptance)
    _db.child('requests/${widget.requestId}').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (data['status'] == 'accepted') {
          setState(() {
            _offerAccepted = true;
            _isLoading = false;
          });
        }
      }
    });

    // Also listen for offer response from customer (backup)
    _db.child('customer_offers/${widget.requestId}').onValue.listen((event) {
      if (!event.snapshot.exists) {
        // Offer was removed (rejected)
        setState(() {
          _offerRejected = true;
          _isLoading = false;
        });
        return;
      }

      // Check if any offer was accepted
      for (final offer in event.snapshot.children) {
        final offerData = Map<String, dynamic>.from(offer.value as Map);
        if (offerData['status'] == 'accepted') {
          setState(() {
            _offerId = offer.key;
            _offerAccepted = true;
            _isLoading = false;
          });
          return;
        }
      }
    });
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
          : _offerAccepted
              ? _buildAcceptedView()
              : _offerRejected
                  ? _buildRejectedView()
                  : _buildWaitingView(),
    );
  }

  Widget _buildWaitingView() {
    final t = AppLocalizations.of(context)!;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              t.waitingForCustomerResponse,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 10),
            Text(
              t.customerWillRespondSoon,
              style: const TextStyle(fontSize: 16, color: Color(0xFF004d4d)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_requestData != null) ...[
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.offerDetails,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                      ),
                      const SizedBox(height: 10),
                      Text('${t.load}: ${_requestData!['loadName']}', style: const TextStyle(color: Color(0xFF004d4d))),
                      Text('${t.originalFare}: Rs ${_requestData!['offerFare']}', style: const TextStyle(color: Color(0xFF004d4d))),
                      Text('${t.yourOffer}: Rs ${widget.offeredFare}', style: const TextStyle(color: Color(0xFF004d4d))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView() {
    final t = AppLocalizations.of(context)!;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              t.offerRejected,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 10),
            Text(
              t.customerRejectedYourOffer,
              style: const TextStyle(fontSize: 16, color: Color(0xFF004d4d)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const DriversScreen()),
                  (route) => false,
                );
              },
              child: Text(t.backToDashboard),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedView() {
    // Navigate to accepted offer screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DriverAcceptedOfferScreen(
            requestId: widget.requestId,
            offerId: _offerId ?? 'default', // Use default if offerId is null
          ),
        ),
      );
    });
    
    return const Center(child: CircularProgressIndicator());
  }
}
