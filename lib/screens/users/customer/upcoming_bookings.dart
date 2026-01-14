import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'customer_accepted_offer.dart';
import 'waiting_for_response.dart';

class UpcomingBookingsScreen extends StatefulWidget {
  const UpcomingBookingsScreen({super.key});

  @override
  State<UpcomingBookingsScreen> createState() => _UpcomingBookingsScreenState();
}

class _UpcomingBookingsScreenState extends State<UpcomingBookingsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingBookings = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadUpcomingBookings();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUpcomingBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final timeout = Duration(seconds: 10);

      _subscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          final requests = <Map<String, dynamic>>[];
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final status = requestData['status'] as String?;
            // Include accepted, dispatched, and in_progress statuses
            // Also include bookings accepted by enterprise (acceptedEnterpriseId) or driver (acceptedDriverId)
            if (requestData['customerId'] == user.uid &&
                (status == 'accepted' || status == 'dispatched' || status == 'in_progress')) {
              requestData['requestId'] = request.key;
              requests.add(requestData);
            }
          }
          setState(() {
            _upcomingBookings = requests;
            _isLoading = false;
          });
        } else {
          setState(() {
            _upcomingBookings = [];
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callDriver(String driverId) async {
    try {
      final snapshot = await _db.child('users/$driverId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final phone = data['phone']?.toString();

        if (phone != null) {
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) launchUrl(uri);
        }
      }
    } catch (e) {}
  }

  Future<void> _callEnterprise(String enterpriseId) async {
    try {
      final snapshot = await _db.child('users/$enterpriseId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final enterpriseDetails = data['enterpriseDetails'] as Map<String, dynamic>?;
        
        // Try to get phone from enterpriseDetails first, then from user data
        final phone = enterpriseDetails?['contactPhone']?.toString() ?? 
                     enterpriseDetails?['cooperateNumber']?.toString() ??
                     data['phone']?.toString() ?? 
                     data['phoneNumber']?.toString();

        if (phone != null && phone.isNotEmpty) {
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.cannotMakeCall(phone))),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.enterpriseContactNotAvailable)),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.errorContactingEnterprise}: $e')),
      );
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    final t = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.cancelRequest),
        content: Text(t.areYouSureCancelRequest),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
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
        // Get request data to find the accepted driver
        final requestSnapshot = await _db.child('requests/$requestId').get();
        if (requestSnapshot.exists) {
          final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
          final driverId = requestData['acceptedDriverId'];
          
          // Update request status to cancelled
          await _db.child('requests/$requestId').update({
            'status': 'cancelled',
            'cancelledBy': 'customer',
            'cancelledAt': DateTime.now().millisecondsSinceEpoch,
          });

          await _db.child('customer_offers/$requestId').remove();

          // Notify driver about cancellation if there's an accepted driver
          if (driverId != null) {
            await _db.child('driver_notifications/$driverId').push().set({
              'type': 'request_cancelled',
              'requestId': requestId,
              'message': t.customerCancelledRequest,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorCancellingRequest}: $e')),
        );
      }
    }
  }

  Future<void> _findNewDriver(String requestId) async {
    await _db.child('requests/$requestId').update({
      'status': 'pending',
      'acceptedDriverId': null,
      'acceptedOfferId': null,
      'finalFare': null,
    });

    await _db.child('customer_offers/$requestId').remove();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => WaitingForResponseScreen(requestId: requestId)),
    );
  }

  // Helper widget for status badge (small, clean)
  Widget _statusBadge(String status, AppLocalizations t) {
    Color color;
    String text;
    switch (status) {
      case 'accepted':
        color = Colors.orange;
        text = t.statusAccepted;
        break;
      case 'dispatched':
        color = Colors.blue;
        text = t.statusDispatched;
        break;
      default:
        color = Colors.green;
        text = t.statusInProgress;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Helper widget for info row (neutral)
  Widget _Row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(t.upcomingBookings, style: const TextStyle(color: Color(0xFF004d4d))),
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF004d4d),
                  ),
                  SizedBox(height: 10),
                  Text(t.loading, style: TextStyle(color: Color(0xFF004d4d))),
                ],
              ),
            )
          : _upcomingBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade400),
                      SizedBox(height: 10),
                      Text(t.noUpcomingBookings,
                          style: TextStyle(fontSize: 18, color: Color(0xFF004d4d))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _upcomingBookings.length,
                  itemBuilder: (_, i) {
                    final b = _upcomingBookings[i];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row (Clean & Balanced)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  b['loadName'] ?? t.nA,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              _statusBadge(b['status'], t),
                            ],
                          ),

                          // Compact Tile Info (NO TEAL)
                          const SizedBox(height: 8),
                          _Row(Icons.inventory_2_outlined,
                              '${b['loadType']} • ${b['weight']} ${b['weightUnit']}'),
                          _Row(Icons.access_time_outlined,
                              '${t.pickupLabel}: ${b['pickupTime'] ?? t.nA}'),
                          _Row(Icons.currency_rupee,
                              '${t.fareLabel}: Rs ${b['finalFare'] ?? b['offerFare']}'),

                          // Action Buttons (Tile Style)
                          const SizedBox(height: 12),
                          if (b['acceptedDriverId'] != null || b['acceptedEnterpriseId'] != null)
                            Row(
                              children: [
                                if (b['acceptedDriverId'] != null)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.phone, size: 18),
                                      label: Text(t.callDriver),
                                      onPressed: () => _callDriver(b['acceptedDriverId']),
                                    ),
                                  ),
                                if (b['acceptedEnterpriseId'] != null) ...[
                                  const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.business, size: 18),
                                        label: Text(t.contactEnterprise),
                                        onPressed: () => _callEnterprise(b['acceptedEnterpriseId']),
                                      ),
                                    ),
                                ],
                              ],
                            ),

                          // Secondary Actions (Muted)
                          const SizedBox(height: 6),
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                            label: Text(
                              t.cancelRequest,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            onPressed: () => _cancelRequest(b['requestId']),
                          ),
                          if (b['status'] == 'accepted')
                            TextButton.icon(
                              icon: const Icon(Icons.search),
                              label: Text(t.findNewDriver),
                              onPressed: () => _findNewDriver(b['requestId']),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
