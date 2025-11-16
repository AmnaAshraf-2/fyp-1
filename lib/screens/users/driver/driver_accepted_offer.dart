import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverAcceptedOfferScreen extends StatefulWidget {
  final String requestId;
  final String offerId;

  const DriverAcceptedOfferScreen({
    super.key, 
    required this.requestId, 
    required this.offerId
  });

  @override
  State<DriverAcceptedOfferScreen> createState() => _DriverAcceptedOfferScreenState();
}

class _DriverAcceptedOfferScreenState extends State<DriverAcceptedOfferScreen> {
  final _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _customerData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      print('🔍 DEBUG: Loading driver accepted offer data for request: ${widget.requestId}');
      
      // Load request data
      final requestSnapshot = await _db.child('requests/${widget.requestId}').get();
      if (requestSnapshot.exists) {
        _requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        print('🔍 DEBUG: Request data loaded: $_requestData');
        
        // Load customer data
        final customerId = _requestData?['customerId'];
        print('🔍 DEBUG: Customer ID: $customerId');
        
        if (customerId != null) {
          final customerSnapshot = await _db.child('users/$customerId').get();
          if (customerSnapshot.exists) {
            _customerData = Map<String, dynamic>.from(customerSnapshot.value as Map);
            print('🔍 DEBUG: Customer data loaded: $_customerData');
          } else {
            print('❌ DEBUG: Customer data not found for ID: $customerId');
          }
        } else {
          print('❌ DEBUG: No customer ID in request data');
        }
      } else {
        print('❌ DEBUG: Request not found: ${widget.requestId}');
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ DEBUG: Error loading driver accepted offer data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _callCustomer() async {
    if (_customerData?['phone'] != null) {
      final phoneNumber = _customerData!['phone'].toString();
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot make call to $phoneNumber')),
        );
      }
    }
  }

  Future<void> _rejectOffer() async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.rejectOffer),
        content: Text(t.areYouSureRejectOffer),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.reject),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update request status to cancelled
        await _db.child('requests/${widget.requestId}').update({
          'status': 'cancelled',
          'cancelledBy': 'driver',
          'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Remove from customer offers
        await _db.child('customer_offers/${widget.requestId}').remove();

        // Notify customer about cancellation
        final customerId = _requestData?['customerId'];
        if (customerId != null) {
          await _db.child('customer_notifications/$customerId').push().set({
            'type': 'request_cancelled',
            'requestId': widget.requestId,
            'message': 'Driver cancelled the request',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.offerRejected)),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _startJourney() async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Journey'),
        content: const Text('Are you sure you want to start this journey?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Start Journey'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update request status to in_progress
        await _db.child('requests/${widget.requestId}').update({
          'status': 'in_progress',
          'journeyStartedAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Notify customer that journey has started
        final customerId = _requestData?['customerId'];
        if (customerId != null) {
          await _db.child('customer_notifications/$customerId').push().set({
            'type': 'journey_started',
            'requestId': widget.requestId,
            'message': 'Driver has started the journey',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey started successfully')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting journey: $e')),
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
        title: Text(t.offerAccepted, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requestData == null || _customerData == null
              ? Center(child: Text(t.dataNotFound, style: const TextStyle(color: Color(0xFF004d4d))))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Success message
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t.offerAcceptedSuccessfully,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Customer information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.customerInformation,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildInfoRow(t.customerName, _customerData!['name'] ?? 'N/A'),
                              _buildInfoRow(t.phoneNumber, _customerData!['phone'] ?? 'N/A'),
                              _buildInfoRow(t.email, _customerData!['email'] ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Request details
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.requestDetails,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildInfoRow(t.load, _requestData!['loadName'] ?? 'N/A'),
                              _buildInfoRow(t.type, _requestData!['loadType'] ?? 'N/A'),
                              _buildInfoRow(t.weight, '${_requestData!['weight']} ${_requestData!['weightUnit']}'),
                              _buildInfoRow(t.finalFare, 'Rs ${_requestData!['finalFare'] ?? _requestData!['offerFare']}'),
                              _buildInfoRow(t.pickupTime, _requestData!['pickupTime'] ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Action buttons
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.phone),
                                  label: Text(t.callCustomer),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _callCustomer,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.close),
                                  label: Text(t.reject),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _rejectOffer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Journey'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _startJourney,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF004d4d)),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFF004d4d))),
          ),
        ],
      ),
    );
  }
}
