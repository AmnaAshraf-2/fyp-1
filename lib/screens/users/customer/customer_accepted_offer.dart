import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'waiting_for_response.dart';

class CustomerAcceptedOfferScreen extends StatefulWidget {
  final String requestId;
  final String offerId;

  const CustomerAcceptedOfferScreen({
    super.key, 
    required this.requestId, 
    required this.offerId
  });

  @override
  State<CustomerAcceptedOfferScreen> createState() => _CustomerAcceptedOfferScreenState();
}

class _CustomerAcceptedOfferScreenState extends State<CustomerAcceptedOfferScreen> {
  final _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _vehicleData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load request data
      final requestSnapshot = await _db.child('requests/${widget.requestId}').get();
      if (requestSnapshot.exists) {
        _requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        
        // Load driver data
        final driverId = _requestData!['acceptedDriverId'];
        if (driverId != null) {
          final driverSnapshot = await _db.child('users/$driverId').get();
          if (driverSnapshot.exists) {
            _driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
            _vehicleData = _driverData!['vehicleInfo'];
          }
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _callDriver() async {
    if (_driverData?['phone'] != null) {
      final phoneNumber = _driverData!['phone'].toString();
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

  // This screen is for already accepted offers, so no accept method needed

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
        // Remove the offer
        await _db.child('customer_offers/${widget.requestId}/${widget.offerId}').remove();

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

  Future<void> _cancelRequest() async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.cancelRequest),
        content: Text(t.areYouSureCancelRequest),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.cancelRequest),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update request status to cancelled
        await _db.child('requests/${widget.requestId}').update({
          'status': 'cancelled',
          'cancelledBy': 'customer',
          'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Remove all offers for this request
        await _db.child('customer_offers/${widget.requestId}').remove();

        // Notify driver about cancellation
        final driverId = _requestData?['acceptedDriverId'];
        if (driverId != null) {
          await _db.child('driver_notifications/$driverId').push().set({
            'type': 'request_cancelled',
            'requestId': widget.requestId,
            'message': 'Customer cancelled the request',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.requestCancelled)),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _findNewDriver() async {
    final t = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find New Driver'),
        content: const Text('Are you sure you want to find a new driver for this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Find New Driver'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Reset request status to pending
        await _db.child('requests/${widget.requestId}').update({
          'status': 'pending',
          'acceptedDriverId': null,
          'acceptedOfferId': null,
          'finalFare': null,
        });

        // Remove all existing offers
        await _db.child('customer_offers/${widget.requestId}').remove();

        // Notify current driver about cancellation
        final driverId = _requestData?['acceptedDriverId'];
        if (driverId != null) {
          await _db.child('driver_notifications/$driverId').push().set({
            'type': 'request_cancelled',
            'requestId': widget.requestId,
            'message': 'Customer cancelled the request to find a new driver',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finding new driver...')),
        );

        // Navigate to waiting for response screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingForResponseScreen(requestId: widget.requestId),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding new driver: $e')),
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
        title: Text(t.driverOffer, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requestData == null || _driverData == null
              ? Center(child: Text(t.dataNotFound, style: const TextStyle(color: Color(0xFF004d4d))))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.driverInformation,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildInfoRow(t.driverName, _driverData!['name'] ?? 'N/A'),
                              _buildInfoRow(t.phoneNumber, _driverData!['phone'] ?? 'N/A'),
                              if (_vehicleData != null) ...[
                                _buildInfoRow(t.vehicleName, _vehicleData!['makeModel'] ?? 'N/A'),
                                _buildInfoRow(t.vehicleNumber, _vehicleData!['registrationNumber'] ?? 'N/A'),
                                _buildInfoRow(t.vehicleType, _vehicleData!['type'] ?? 'N/A'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Offer details
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.offerDetails,
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
                              _buildInfoRow(t.originalFare, 'Rs ${_requestData!['offerFare']}'),
                              _buildInfoRow(t.offeredFare, 'Rs ${_requestData!['finalFare'] ?? _requestData!['offerFare']}'),
                              _buildInfoRow(t.pickupTime, _requestData!['pickupTime'] ?? 'N/A'),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Action buttons
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.phone),
                              label: Text(t.callDriver),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _callDriver,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
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
                            child: TextButton.icon(
                              icon: const Icon(Icons.search),
                              label: const Text('Find New Driver'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _findNewDriver,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel),
                              label: Text(t.cancelRequest),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _cancelRequest,
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
