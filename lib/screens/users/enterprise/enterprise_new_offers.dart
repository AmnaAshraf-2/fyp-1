import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EnterpriseNewOffersScreen extends StatefulWidget {
  const EnterpriseNewOffersScreen({super.key});

  @override
  State<EnterpriseNewOffersScreen> createState() => _EnterpriseNewOffersScreenState();
}

class _EnterpriseNewOffersScreenState extends State<EnterpriseNewOffersScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _enterpriseOffers = [];
  List<Map<String, dynamic>> _driverOffers = [];
  List<Map<String, dynamic>> _allOffers = [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Load enterprise offers (direct offers to enterprise)
      await _loadEnterpriseOffers(user.uid);
      
      // Load driver offers (offers to enterprise drivers)
      await _loadDriverOffers(user.uid);

      // Combine and sort all offers by timestamp
      _allOffers = [..._enterpriseOffers, ..._driverOffers];
      _allOffers.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('🔍 DEBUG: Error loading offers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEnterpriseOffers(String enterpriseId) async {
    try {
      final offersSnapshot = await _db.child('enterprise_offers/$enterpriseId/new_offers').get();
      _enterpriseOffers.clear();
      
      if (offersSnapshot.exists) {
        for (final offer in offersSnapshot.children) {
          final requestId = offer.key;
          if (requestId != null) {
            // Get the full request details
            final requestSnapshot = await _db.child('requests/$requestId').get();
            if (requestSnapshot.exists) {
              final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
              requestData['requestId'] = requestId;
              requestData['offerType'] = 'enterprise';
              _enterpriseOffers.add(requestData);
            }
          }
        }
      }
    } catch (e) {
      print('🔍 DEBUG: Error loading enterprise offers: $e');
    }
  }

  Future<void> _loadDriverOffers(String enterpriseId) async {
    try {
      // Get all driver IDs for this enterprise
      final driversSnapshot = await _db.child('users/$enterpriseId/drivers').get();
      _driverOffers.clear();
      
      if (driversSnapshot.exists) {
        for (final driver in driversSnapshot.children) {
          final driverId = driver.key;
          if (driverId != null) {
            // Get offers for this driver
            final offersSnapshot = await _db.child('driver_offers/$driverId/new_offers').get();
            if (offersSnapshot.exists) {
              for (final offer in offersSnapshot.children) {
                final requestId = offer.key;
                if (requestId != null) {
                  // Get the full request details
                  final requestSnapshot = await _db.child('requests/$requestId').get();
                  if (requestSnapshot.exists) {
                    final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
                    requestData['requestId'] = requestId;
                    requestData['offerType'] = 'driver';
                    requestData['driverId'] = driverId;
                    _driverOffers.add(requestData);
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('🔍 DEBUG: Error loading driver offers: $e');
    }
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final requestId = offer['requestId'] as String;
      
      // Update request status to accepted
      await _db.child('requests/$requestId').update({
        'status': 'accepted',
        'acceptedEnterpriseId': user.uid,
        'acceptedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Remove from new offers
      if (offer['offerType'] == 'enterprise') {
        await _db.child('enterprise_offers/${user.uid}/new_offers/$requestId').remove();
      } else {
        final driverId = offer['driverId'] as String;
        await _db.child('driver_offers/$driverId/new_offers/$requestId').remove();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.offerAccepted)),
        );
      }

      // Reload offers
      await _loadOffers();
    } catch (e) {
      print('🔍 DEBUG: Error accepting offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorOccurred} $e')),
        );
      }
    }
  }

  Future<void> _rejectOffer(Map<String, dynamic> offer) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final requestId = offer['requestId'] as String;
      
      // Update request status to rejected
      await _db.child('requests/$requestId').update({
        'status': 'rejected',
        'rejectedEnterpriseId': user.uid,
        'rejectedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Remove from new offers
      if (offer['offerType'] == 'enterprise') {
        await _db.child('enterprise_offers/${user.uid}/new_offers/$requestId').remove();
      } else {
        final driverId = offer['driverId'] as String;
        await _db.child('driver_offers/$driverId/new_offers/$requestId').remove();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.offerRejected)),
        );
      }

      // Reload offers
      await _loadOffers();
    } catch (e) {
      print('🔍 DEBUG: Error rejecting offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorOccurred} $e')),
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
        title: Text(t.newOffers, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF004d4d)),
            onPressed: _loadOffers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allOffers.isEmpty
              ? _buildEmptyState(t)
              : _buildOffersList(t),
    );
  }

  Widget _buildEmptyState(AppLocalizations t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            t.noNewOffers,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF004d4d),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New customer requests will appear here',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF004d4d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList(AppLocalizations t) {
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allOffers.length,
        itemBuilder: (context, index) {
          final offer = _allOffers[index];
          return _buildOfferCard(offer, t);
        },
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, AppLocalizations t) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(offer['timestamp'] as int);
    final isEnterpriseOffer = offer['offerType'] == 'enterprise';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEnterpriseOffer ? Icons.business : Icons.person,
                  color: isEnterpriseOffer ? Colors.blue : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEnterpriseOffer ? 'Direct Enterprise Offer' : 'Driver Offer',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF004d4d),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF004d4d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(t.loadName, offer['loadName'] ?? 'N/A'),
            _buildInfoRow(t.loadType, _getLoadTypeLabel(offer['loadType'], t)),
            _buildInfoRow(t.loadWeight, '${offer['weight']} ${offer['weightUnit']}'),
            _buildInfoRow(t.quantity, '${offer['quantity']}'),
            _buildInfoRow(t.vehicleType, offer['vehicleType'] ?? 'N/A'),
            _buildInfoRow(t.offeredFare, 'Rs. ${offer['offerFare']}'),
            _buildInfoRow(t.pickupTime, offer['pickupTime'] ?? 'N/A'),
            _buildInfoRow(t.insurance, offer['isInsured'] == true ? t.yes : t.no),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectOffer(offer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(t.reject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptOffer(offer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t.accept),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF004d4d),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF004d4d)),
            ),
          ),
        ],
      ),
    );
  }

  String _getLoadTypeLabel(String? loadType, AppLocalizations t) {
    switch (loadType) {
      case 'fragile':
        return t.fragile;
      case 'heavy':
        return t.heavy;
      case 'perishable':
        return t.perishable;
      case 'general':
        return t.generalGoods;
      default:
        return loadType ?? 'N/A';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
