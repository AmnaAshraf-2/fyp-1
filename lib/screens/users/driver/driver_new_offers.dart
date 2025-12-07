import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/driver/upcoming_trips.dart';
import 'package:logistics_app/screens/users/customer/route_map_view.dart';
import 'package:audioplayers/audioplayers.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

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
      if (_driverId == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check all offers for expired counter offers
      for (final offer in _offers) {
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
      if (_driverId == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      bool foundExpired = false;

      // Check all offers for expired requests (2 minutes without action)
      for (final offer in _offers) {
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
                  if (offerData['driverId'] == _driverId && 
                      offerData['status'] == 'pending' &&
                      offerData['offerType'] == 'counter') {
                    hasActiveCounterOffer = true;
                    break;
                  }
                }
              }
              
              if (!hasActiveCounterOffer) {
                // Remove from driver's new_offers
                await _db.child('driver_offers/$_driverId/new_offers/$requestId').remove();
                foundExpired = true;
                break; // Exit after removing one to avoid multiple reloads
              }
            }
          }
        }
      }

      // Reload offers if we removed an expired request
      if (foundExpired) {
        await _loadOffers();
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking expired requests: $e');
    }
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
            
            // Skip if request is already accepted/rejected or allocated to someone else
            final status = data['status'] as String?;
            final acceptedEnterpriseId = data['acceptedEnterpriseId'] as String?;
            final acceptedDriverId = data['acceptedDriverId'] as String?;
            
            // Skip if already accepted/rejected
            if (status != 'pending') {
              // Remove from new_offers if it's already accepted/rejected
              await _db.child('driver_offers/$_driverId/new_offers/$requestId').remove();
              continue;
            }
            
            // Skip if accepted by someone else (different driver or any enterprise)
            if (acceptedDriverId != null && acceptedDriverId != _driverId) {
              // Remove from new_offers if accepted by another driver
              await _db.child('driver_offers/$_driverId/new_offers/$requestId').remove();
              continue;
            }
            
            if (acceptedEnterpriseId != null) {
              // Remove from new_offers if accepted by an enterprise
              await _db.child('driver_offers/$_driverId/new_offers/$requestId').remove();
              continue;
            }
            
            print('🔍 DEBUG: Request data loaded: ${data['loadName']}');
            print('🎵 DEBUG: Audio note URL: ${data['audioNoteUrl']}');
            
            // Check if this driver has made a counter offer for this request
            bool hasCounterOffer = false;
            final customerOffersSnapshot = await _db.child('customer_offers/$requestId').get();
            if (customerOffersSnapshot.exists) {
              for (final counterOffer in customerOffersSnapshot.children) {
                final offerData = Map<String, dynamic>.from(counterOffer.value as Map);
                if (offerData['driverId'] == _driverId && offerData['status'] == 'pending') {
                  // Check if counter offer has expired (10 seconds timeout)
                  final offerTimestamp = offerData['timestamp'] as int? ?? 0;
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final elapsedSeconds = (now - offerTimestamp) / 1000;
                  
                  if (elapsedSeconds > 10) {
                    // Counter offer expired, remove it
                    await _db.child('customer_offers/$requestId/${counterOffer.key}').remove();
                  } else {
                    hasCounterOffer = true;
                    data['counterOfferId'] = counterOffer.key;
                    data['counterOfferFare'] = offerData['offeredFare'];
                    data['counterOfferTimestamp'] = offerTimestamp;
                    break;
                  }
                }
              }
            }
            data['hasCounterOffer'] = hasCounterOffer;
            data['requestId'] = requestId; // Ensure requestId is in the data
            loadedOffers.add(data);
          } else {
            print('❌ DEBUG: Request $requestId not found');
          }
        } catch (e) {
          print('❌ DEBUG: Error loading request $requestId: $e');
        }
      }

      print('🔍 DEBUG: Final loaded offers count: ${loadedOffers.length}');
      
      // Sort offers by timestamp (newest first)
      loadedOffers.sort((a, b) {
        final timestampA = a['timestamp'] as int? ?? 0;
        final timestampB = b['timestamp'] as int? ?? 0;
        return timestampB.compareTo(timestampA);
      });
      
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
      try {
        // Get driver name from user profile
        String driverName = 'Driver';
        if (_driverId != null) {
          final driverSnapshot = await _db.child('users/$_driverId').get();
          if (driverSnapshot.exists) {
            final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
            driverName = driverData['full_name'] ?? driverData['name'] ?? 'Driver';
          }
        }

        // Create counter offer for customer
        final offerRef = _db.child('customer_offers/$requestId').push();
        final offerId = offerRef.key;
        await offerRef.set({
          'driverId': _driverId,
          'driverName': driverName,
          'originalFare': originalFare,
          'offeredFare': result,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
          'offerType': 'counter',
        });

        // DO NOT remove from driver's new offers - keep it visible with "waiting for response"
        // The offer will be removed when customer accepts/rejects

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.offerSent),
            backgroundColor: Colors.green,
          ),
        );

        // Reload offers to update the list and show "waiting for response"
        _loadOffers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.errorOccurred} $e')),
        );
      }
    }
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    final t = AppLocalizations.of(context)!;
    try {
      final requestId = offer['requestId'] as String?;
      if (requestId == null) return;

      final originalFare = (offer['offerFare'] ?? 0).toDouble();
      
      // Get driver name from user profile
      String driverName = 'Driver';
      if (_driverId != null) {
        final driverSnapshot = await _db.child('users/$_driverId').get();
        if (driverSnapshot.exists) {
          final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
          driverName = driverData['full_name'] ?? driverData['name'] ?? 'Driver';
        }
      }

      // Create acceptance offer for customer (shows as response for 10 seconds)
      final offerRef = _db.child('customer_offers/$requestId').push();
      await offerRef.set({
        'driverId': _driverId,
        'driverName': driverName,
        'originalFare': originalFare,
        'offeredFare': originalFare, // Accepting original fare
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
        'offerType': 'acceptance', // Mark as acceptance (not counter offer)
      });

      // DO NOT update request status yet - wait for customer to confirm
      // DO NOT remove from new offers - keep it visible

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.offerSentToCustomer),
          backgroundColor: Colors.green,
        ),
      );

      // Reload offers to update the list
      _loadOffers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.errorOccurred} $e')),
      );
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
                        child: Text(t.refresh),
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
                        color: Colors.white,
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
                                _buildInfoRow(t.pickupLocation, offer['pickupLocation'] ?? 'N/A'),
                                _buildInfoRow(t.destinationLocation, offer['destinationLocation'] ?? 'N/A'),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.map, color: Color(0xFF004d4d)),
                                    label: Text(t.viewRouteOnMap, style: const TextStyle(color: Color(0xFF004d4d))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF004d4d)),
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
                                        'Waiting for customer\'s response',
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
                                  'Counter offer: Rs ${offer['counterOfferFare']?.toStringAsFixed(0) ?? 'N/A'}',
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
                                        onPressed: () => _makeCounterOffer(
                                          offer['requestId'] ?? '',
                                          (offer['offerFare'] ?? 0).toDouble(),
                                        ),
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
                                        onPressed: () => _dismissOffer(offer['requestId'] ?? ''),
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
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
                const Text(
                  'Audio Note',
                  style: TextStyle(
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
                  const Text(
                    'Tap to play customer audio note',
                    style: TextStyle(
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
            tooltip: isPlaying ? 'Pause' : 'Play',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
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