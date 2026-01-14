import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_bookings.dart';
import 'package:audioplayers/audioplayers.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

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
  
  // Audio playback variables
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, bool> _isPlaying = {};
  final Map<String, Duration> _playbackDuration = {};

  @override
  void initState() {
    super.initState();
    _loadOffers();
    // Set up periodic check for expired counter offers (every second)
    _startCounterOfferTimeoutCheck();
    // Set up periodic check for request timeout (every 10 seconds)
    _startRequestTimeoutCheck();
  }

  void _startCounterOfferTimeoutCheck() {
    // Check for expired counter offers every second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkAndRemoveExpiredCounterOffers();
        _startCounterOfferTimeoutCheck(); // Schedule next check
      }
    });
  }

  Future<void> _checkAndRemoveExpiredCounterOffers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check enterprise offers
      for (final offer in _enterpriseOffers) {
        if (offer['hasCounterOffer'] == true) {
          final counterOfferTimestamp = offer['counterOfferTimestamp'] as int?;
          if (counterOfferTimestamp != null) {
            final elapsedSeconds = (now - counterOfferTimestamp) / 1000;
            if (elapsedSeconds > 10) {
              // Counter offer expired, remove it
              final requestId = offer['requestId'] as String?;
              final counterOfferId = offer['counterOfferId'] as String?;
              if (requestId != null && counterOfferId != null) {
                await _db.child('customer_offers/$requestId/$counterOfferId').remove();
                // Reload offers to update UI
                await _loadOffers();
              }
              return; // Exit after removing one to avoid multiple reloads
            }
          }
        }
      }

      // Check driver offers if no expired found in enterprise offers
      for (final offer in _driverOffers) {
        if (offer['hasCounterOffer'] == true) {
          final counterOfferTimestamp = offer['counterOfferTimestamp'] as int?;
          if (counterOfferTimestamp != null) {
            final elapsedSeconds = (now - counterOfferTimestamp) / 1000;
            if (elapsedSeconds > 10) {
              // Counter offer expired, remove it
              final requestId = offer['requestId'] as String?;
              final counterOfferId = offer['counterOfferId'] as String?;
              if (requestId != null && counterOfferId != null) {
                await _db.child('customer_offers/$requestId/$counterOfferId').remove();
                // Reload offers to update UI
                await _loadOffers();
              }
              return; // Exit after removing one to avoid multiple reloads
            }
          }
        }
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking expired counter offers: $e');
    }
  }

  void _startRequestTimeoutCheck() {
    // Check for expired requests every 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _checkAndRemoveExpiredRequests();
        _startRequestTimeoutCheck(); // Schedule next check
      }
    });
  }

  Future<void> _checkAndRemoveExpiredRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      bool foundExpired = false;

      // Check enterprise offers
      for (final offer in _enterpriseOffers) {
        final requestId = offer['requestId'] as String?;
        if (requestId == null) continue;

        // Skip if counter offer was made (they're still considering)
        if (offer['hasCounterOffer'] == true) continue;

        // Check request timestamp
        final requestTimestamp = offer['timestamp'] as int? ?? 0;
        if (requestTimestamp == 0) continue;

        final elapsedMinutes = (now - requestTimestamp) / (1000 * 60);

        // If 2 minutes passed and no action taken, remove from new_offers
        if (elapsedMinutes >= 2) {
          // Verify request is still pending (not accepted/rejected)
          final requestSnapshot = await _db.child('requests/$requestId').get();
          if (requestSnapshot.exists) {
            final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
            final status = requestData['status'] as String?;
            
            // Only remove if still pending and no counter offer exists
            if (status == 'pending') {
              // Double-check no counter offer exists
              final customerOffersSnapshot = await _db.child('customer_offers/$requestId').get();
              bool hasActiveCounterOffer = false;
              
              if (customerOffersSnapshot.exists) {
                for (final counterOffer in customerOffersSnapshot.children) {
                  final offerData = Map<String, dynamic>.from(counterOffer.value as Map);
                  if (offerData['enterpriseId'] == user.uid && 
                      offerData['status'] == 'pending' &&
                      offerData['offerType'] == 'counter') {
                    hasActiveCounterOffer = true;
                    break;
                  }
                }
              }
              
              if (!hasActiveCounterOffer) {
                // Remove from enterprise's new_offers
                await _db.child('enterprise_offers/${user.uid}/new_offers/$requestId').remove();
                foundExpired = true;
                break; // Exit after removing one to avoid multiple reloads
              }
            }
          }
        }
      }

      // Check driver offers if no expired found in enterprise offers
      if (!foundExpired) {
        for (final offer in _driverOffers) {
          final requestId = offer['requestId'] as String?;
          if (requestId == null) continue;

          // Skip if counter offer was made (they're still considering)
          if (offer['hasCounterOffer'] == true) continue;

          // Check request timestamp
          final requestTimestamp = offer['timestamp'] as int? ?? 0;
          if (requestTimestamp == 0) continue;

          final elapsedMinutes = (now - requestTimestamp) / (1000 * 60);

          // If 2 minutes passed and no action taken, remove from new_offers
          if (elapsedMinutes >= 2) {
            // Verify request is still pending (not accepted/rejected)
            final requestSnapshot = await _db.child('requests/$requestId').get();
            if (requestSnapshot.exists) {
              final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
              final status = requestData['status'] as String?;
              
              // Only remove if still pending and no counter offer exists
              if (status == 'pending') {
                // Double-check no counter offer exists
                final customerOffersSnapshot = await _db.child('customer_offers/$requestId').get();
                bool hasActiveCounterOffer = false;
                
                if (customerOffersSnapshot.exists) {
                  for (final counterOffer in customerOffersSnapshot.children) {
                    final offerData = Map<String, dynamic>.from(counterOffer.value as Map);
                    final driverId = offer['driverId'] as String?;
                    if (driverId != null &&
                        offerData['driverId'] == driverId && 
                        offerData['status'] == 'pending' &&
                        offerData['offerType'] == 'counter') {
                      hasActiveCounterOffer = true;
                      break;
                    }
                  }
                }
                
                if (!hasActiveCounterOffer) {
                  // Remove from driver's new_offers
                  final driverId = offer['driverId'] as String?;
                  if (driverId != null) {
                    await _db.child('driver_offers/$driverId/new_offers/$requestId').remove();
                    foundExpired = true;
                    break; // Exit after removing one to avoid multiple reloads
                  }
                }
              }
            }
          }
        }
      }

      // Reload offers if we removed an expired request
      if (foundExpired && mounted) {
        await _loadOffers();
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking expired requests: $e');
    }
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

      // Combine and sort all offers by timestamp (newest first)
      _allOffers = [..._enterpriseOffers, ..._driverOffers];
      _allOffers.sort((a, b) {
        // Sort by request timestamp (newest first)
        final timestampA = a['timestamp'] as int? ?? 0;
        final timestampB = b['timestamp'] as int? ?? 0;
        return timestampB.compareTo(timestampA);
      });

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
              
              // Skip if request is already accepted/rejected or allocated to someone else
              final status = requestData['status'] as String?;
              final acceptedEnterpriseId = requestData['acceptedEnterpriseId'] as String?;
              final acceptedDriverId = requestData['acceptedDriverId'] as String?;
              
              // Skip if already accepted/rejected
              if (status != 'pending') {
                // Remove from new_offers if it's already accepted/rejected
                await _db.child('enterprise_offers/$enterpriseId/new_offers/$requestId').remove();
                continue;
              }
              
              // Skip if accepted by someone else (different enterprise or any driver)
              if (acceptedEnterpriseId != null && acceptedEnterpriseId != enterpriseId) {
                // Remove from new_offers if accepted by another enterprise
                await _db.child('enterprise_offers/$enterpriseId/new_offers/$requestId').remove();
                continue;
              }
              
              if (acceptedDriverId != null) {
                // Remove from new_offers if accepted by a driver
                await _db.child('enterprise_offers/$enterpriseId/new_offers/$requestId').remove();
                continue;
              }
              
              requestData['requestId'] = requestId;
              requestData['offerType'] = 'enterprise';
              print('🎵 DEBUG: Enterprise offer - Audio note URL: ${requestData['audioNoteUrl']}');
              
              // Check if this enterprise has made a counter offer for this request
              bool hasCounterOffer = false;
              final customerOffersSnapshot = await _db.child('customer_offers/$requestId').get();
              if (customerOffersSnapshot.exists) {
                for (final counterOffer in customerOffersSnapshot.children) {
                  final offerData = Map<String, dynamic>.from(counterOffer.value as Map);
                  if (offerData['enterpriseId'] == enterpriseId && offerData['status'] == 'pending') {
                    // Check if counter offer has expired (10 seconds timeout)
                    final offerTimestamp = offerData['timestamp'] as int? ?? 0;
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final elapsedSeconds = (now - offerTimestamp) / 1000;
                    
                    if (elapsedSeconds > 10) {
                      // Counter offer expired, remove it
                      await _db.child('customer_offers/$requestId/${counterOffer.key}').remove();
                    } else {
                      hasCounterOffer = true;
                      requestData['counterOfferId'] = counterOffer.key;
                      requestData['counterOfferFare'] = offerData['offeredFare'];
                      requestData['counterOfferTimestamp'] = offerTimestamp;
                      break;
                    }
                  }
                }
              }
              requestData['hasCounterOffer'] = hasCounterOffer;
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
                    
                    // Skip if request is already accepted/rejected or allocated to someone else
                    final status = requestData['status'] as String?;
                    final acceptedEnterpriseId = requestData['acceptedEnterpriseId'] as String?;
                    final acceptedDriverId = requestData['acceptedDriverId'] as String?;
                    
                    // Skip if already accepted/rejected
                    if (status != 'pending') {
                      // Remove from new_offers if it's already accepted/rejected
                      await _db.child('driver_offers/$driverId/new_offers/$requestId').remove();
                      continue;
                    }
                    
                    // Skip if accepted by someone else (different driver or any enterprise)
                    if (acceptedDriverId != null && acceptedDriverId != driverId) {
                      // Remove from new_offers if accepted by another driver
                      await _db.child('driver_offers/$driverId/new_offers/$requestId').remove();
                      continue;
                    }
                    
                    if (acceptedEnterpriseId != null) {
                      // Remove from new_offers if accepted by an enterprise
                      await _db.child('driver_offers/$driverId/new_offers/$requestId').remove();
                      continue;
                    }
                    
                    requestData['requestId'] = requestId;
                    requestData['offerType'] = 'driver';
                    requestData['driverId'] = driverId;
                    
                    // Check if this driver has made a counter offer for this request
                    bool hasCounterOffer = false;
                    final customerOffersSnapshot = await _db.child('customer_offers/$requestId').get();
                    if (customerOffersSnapshot.exists) {
                      for (final counterOffer in customerOffersSnapshot.children) {
                        final offerData = Map<String, dynamic>.from(counterOffer.value as Map);
                        if (offerData['driverId'] == driverId && offerData['status'] == 'pending') {
                          // Check if counter offer has expired (10 seconds timeout)
                          final offerTimestamp = offerData['timestamp'] as int? ?? 0;
                          final now = DateTime.now().millisecondsSinceEpoch;
                          final elapsedSeconds = (now - offerTimestamp) / 1000;
                          
                          if (elapsedSeconds > 10) {
                            // Counter offer expired, remove it
                            await _db.child('customer_offers/$requestId/${counterOffer.key}').remove();
                          } else {
                            hasCounterOffer = true;
                            requestData['counterOfferId'] = counterOffer.key;
                            requestData['counterOfferFare'] = offerData['offeredFare'];
                            requestData['counterOfferTimestamp'] = offerTimestamp;
                            break;
                          }
                        }
                      }
                    }
                    requestData['hasCounterOffer'] = hasCounterOffer;
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
    final t = AppLocalizations.of(context)!;
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final requestId = offer['requestId'] as String;
      final originalFare = (offer['offerFare'] ?? 0).toDouble();

      // Get enterprise name from user profile
      final t = AppLocalizations.of(context)!;
      String enterpriseName = t.enterpriseUser;
      final enterpriseSnapshot = await _db.child('users/${user.uid}').get();
      if (enterpriseSnapshot.exists) {
        final enterpriseData = Map<String, dynamic>.from(enterpriseSnapshot.value as Map);
        final enterpriseDetailsRaw = enterpriseData['enterpriseDetails'];
        Map<String, dynamic>? enterpriseDetails;
        if (enterpriseDetailsRaw != null && enterpriseDetailsRaw is Map) {
          enterpriseDetails = Map<String, dynamic>.from(enterpriseDetailsRaw);
        }
        enterpriseName = enterpriseDetails?['enterpriseName'] ?? 
                        enterpriseData['companyName'] ?? 
                        enterpriseData['full_name'] ?? 
                        enterpriseData['name'] ?? 
                        t.enterpriseUser;
      }

      // Create acceptance offer for customer (shows as response for 10 seconds)
      final offerRef = _db.child('customer_offers/$requestId').push();
      await offerRef.set({
        'enterpriseId': user.uid,
        'enterpriseName': enterpriseName,
        'originalFare': originalFare,
        'offeredFare': originalFare, // Accepting original fare
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
        'offerType': 'acceptance', // Mark as acceptance (not counter offer)
      });

      // DO NOT update request status yet - wait for customer to confirm
      // DO NOT remove from new offers - keep it visible

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.offerSentToCustomer),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload offers to update the list
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

  Future<void> _makeCounterOffer(Map<String, dynamic> offer) async {
    final t = AppLocalizations.of(context)!;
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final requestId = offer['requestId'] as String;
      final originalFare = (offer['offerFare'] ?? 0).toDouble();

      final TextEditingController fareController = TextEditingController(
        text: originalFare.toString(),
      );

      final result = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.teal.shade800, width: 1),
          ),
          title: Text(
            t.makeCounterOffer,
            style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${t.originalFare}: Rs ${originalFare.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF004d4d), fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fareController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t.yourOffer,
                  labelStyle: const TextStyle(color: Colors.teal),
                  prefixText: 'Rs ',
                  prefixStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal.shade800,
              ),
              child: Text(t.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final offeredFare = double.tryParse(fareController.text);
                if (offeredFare != null && offeredFare > 0) {
                  Navigator.pop(context, offeredFare);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.pleaseEnterValidFareAmount)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
              ),
              child: Text(t.sendOffer),
            ),
          ],
        ),
      );

      if (result != null) {
        // Get enterprise name from user profile
        final t = AppLocalizations.of(context)!;
        String enterpriseName = t.enterpriseUser;
        final enterpriseSnapshot = await _db.child('users/${user.uid}').get();
        if (enterpriseSnapshot.exists) {
          final enterpriseData = Map<String, dynamic>.from(enterpriseSnapshot.value as Map);
          final enterpriseDetailsRaw = enterpriseData['enterpriseDetails'];
          Map<String, dynamic>? enterpriseDetails;
          if (enterpriseDetailsRaw != null && enterpriseDetailsRaw is Map) {
            enterpriseDetails = Map<String, dynamic>.from(enterpriseDetailsRaw);
          }
          enterpriseName = enterpriseDetails?['enterpriseName'] ?? 
                          enterpriseData['companyName'] ?? 
                          enterpriseData['full_name'] ?? 
                          enterpriseData['name'] ?? 
                          t.enterpriseUser;
        }

        // Create counter offer for customer
        final offerRef = _db.child('customer_offers/$requestId').push();
        await offerRef.set({
          'enterpriseId': user.uid,
          'enterpriseName': enterpriseName,
          'originalFare': originalFare,
          'offeredFare': result,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
          'offerType': 'counter',
        });

        // DO NOT remove from new offers - keep it visible with "waiting for response"
        // The offer will be removed when customer accepts/rejects

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.offerSent),
            backgroundColor: Colors.green,
          ),
        );

        // Reload offers to update the list and show "waiting for response"
        await _loadOffers();
      }
    } catch (e) {
      print('🔍 DEBUG: Error making counter offer: $e');
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
              : _allOffers.isEmpty
                  ? _buildEmptyState(t)
                  : _buildOffersList(t),
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
        title: Text(
          t.newOffers,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOffers,
            tooltip: t.refresh,
          ),
        ],
      ),
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
            color: Colors.white.withOpacity(.5),
          ),
          const SizedBox(height: 16),
          Text(
            t.noNewOffers,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.newCustomerRequestsWillAppearHere,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(.8),
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
                  isEnterpriseOffer ? t.directEnterpriseOffer : t.driverOffer,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(t.loadName, offer['loadName'] ?? t.nA),
            _buildInfoRow(t.loadType, _getLoadTypeLabel(offer['loadType'], t)),
            _buildInfoRow(t.loadWeight, '${offer['weight']} ${offer['weightUnit']}'),
            _buildInfoRow(t.quantity, '${offer['quantity']}'),
            _buildInfoRow(t.vehicleType, offer['vehicleType'] ?? t.nA),
            _buildInfoRow(t.offeredFare, 'Rs. ${offer['offerFare']}'),
            _buildInfoRow(t.pickupTime, offer['pickupTime'] ?? t.nA),
            _buildInfoRow(t.insurance, offer['isInsured'] == true ? t.yes : t.no),
            // Show audio note if available
            if (offer['audioNoteUrl'] != null && 
                offer['audioNoteUrl'].toString().isNotEmpty && 
                offer['audioNoteUrl'] != '') ...[
              const SizedBox(height: 12),
              _buildAudioNoteWidget(offer['requestId'] ?? '', offer['audioNoteUrl']),
            ],
            // Show locations if available
            if (offer['pickupLocation'] != null && offer['destinationLocation'] != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(t.pickupLocation, offer['pickupLocation'] ?? t.nA),
              _buildInfoRow(t.destinationLocation, offer['destinationLocation'] ?? t.nA),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text(t.viewRouteOnMap, style: const TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RouteMapView(
                          pickupLocation: offer['pickupLocation'] ?? '',
                          destinationLocation: offer['destinationLocation'] ?? '',
                          loadName: offer['loadName'],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Show "waiting for response" if counter offer was made
            if (offer['hasCounterOffer'] == true) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      t.waitingForCustomerResponse,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${t.counterOfferLabel} Rs ${offer['counterOfferFare']?.toStringAsFixed(0) ?? t.nA}',
                style: const TextStyle(
                  color: Color(0xFF004d4d),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: Text(t.accept),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _acceptOffer(offer),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_offer, color: Colors.white),
                      label: Text(t.makeCounterOffer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _makeCounterOffer(offer),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: Text(t.reject),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _rejectOffer(offer),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all audio players
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    _audioPlayers.clear();
    super.dispose();
  }

  Widget _buildAudioNoteWidget(String requestId, String audioUrl) {
    if (audioUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final t = AppLocalizations.of(context)!;

    // Get or create audio player for this request
    if (!_audioPlayers.containsKey(requestId)) {
      _audioPlayers[requestId] = AudioPlayer();
      _isPlaying[requestId] = false;
      _playbackDuration[requestId] = Duration.zero;
    }

    final player = _audioPlayers[requestId]!;
    final isPlaying = _isPlaying[requestId] ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: Colors.teal,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.audioNote,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF004d4d),
                  ),
                ),
                const SizedBox(height: 4),
                if (isPlaying)
                  StreamBuilder<Duration>(
                    stream: player.onPositionChanged,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = _playbackDuration[requestId] ?? Duration.zero;
                      return Text(
                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    },
                  )
                else
                  Text(
                    t.tapToPlayCustomerAudioNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.teal,
            ),
            onPressed: () => _playAudioNote(requestId, audioUrl),
            tooltip: isPlaying ? t.pause : t.play,
          ),
        ],
      ),
    );
  }

  Future<void> _playAudioNote(String requestId, String audioUrl) async {
    if (audioUrl.isEmpty) return;

    final player = _audioPlayers[requestId] ?? AudioPlayer();
    if (!_audioPlayers.containsKey(requestId)) {
      _audioPlayers[requestId] = player;
    }

    try {
      final isCurrentlyPlaying = _isPlaying[requestId] ?? false;
      
      if (isCurrentlyPlaying) {
        await player.pause();
        setState(() {
          _isPlaying[requestId] = false;
        });
      } else {
        await player.play(UrlSource(audioUrl));
        setState(() {
          _isPlaying[requestId] = true;
        });

        // Get duration
        final duration = await player.getDuration();
        if (duration != null) {
          setState(() {
            _playbackDuration[requestId] = duration;
          });
        }

        // Listen for completion
        player.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlaying[requestId] = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.errorPlayingAudio(e.toString()))),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(.9)),
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
        return loadType ?? t.nA;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final t = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? t.dayAgo : t.daysAgo}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? t.hourAgo : t.hoursAgo}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? t.minuteAgo : t.minutesAgo}';
    } else {
      return t.justNow;
    }
  }
}
