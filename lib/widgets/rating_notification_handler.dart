import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logistics_app/screens/users/customer/rate_driver_screen.dart';
import 'package:logistics_app/screens/users/customer/rate_enterprise_screen.dart';

// Global navigator key for accessing navigator from anywhere
final GlobalKey<NavigatorState> ratingNavigatorKey = GlobalKey<NavigatorState>();

class RatingNotificationHandler extends StatefulWidget {
  final Widget child;

  const RatingNotificationHandler({
    super.key,
    required this.child,
  });

  @override
  State<RatingNotificationHandler> createState() => _RatingNotificationHandlerState();
}

class _RatingNotificationHandlerState extends State<RatingNotificationHandler> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  StreamSubscription<DatabaseEvent>? _notificationsSubscription;
  final Set<String> _processedNotifications = <String>{};
  bool _isShowingRating = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    final user = _auth.currentUser;
    if (user == null) {
      // Listen for auth state changes
      _auth.authStateChanges().listen((user) {
        if (user != null && mounted) {
          _startListening();
        }
      });
      return;
    }

    // Check if user is a customer before listening
    _db.child('users/${user.uid}/role').get().then((snapshot) {
      if (!mounted) return;
      final role = snapshot.value as String?;
      // Only listen if user is a customer
      if (role == 'customer') {
        _listenToNotifications(user.uid);
      }
    }).catchError((error) {
      print('Error checking user role: $error');
    });
  }

  void _listenToNotifications(String userId) {
    // Cancel existing subscription if any
    _notificationsSubscription?.cancel();

    // First, check existing notifications
    _db.child('customer_notifications/$userId').get().then((snapshot) {
      if (!mounted) return;
      if (snapshot.exists) {
        for (final notification in snapshot.children) {
          final notificationData = Map<String, dynamic>.from(notification.value as Map);
          final notificationId = notification.key;
          final type = notificationData['type'] as String?;
          final requestId = notificationData['requestId'] as String?;
          final driverId = notificationData['driverId'] as String?;
          final enterpriseId = notificationData['enterpriseId'] as String?;
          final timestamp = notificationData['timestamp'] as int?;

          // Process recent journey_completed notifications (within 10 minutes)
          if (type == 'journey_completed' && requestId != null && notificationId != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final notificationTime = timestamp ?? 0;
            final timeDiff = now - notificationTime;
            
            // Process if notification is recent (within 10 minutes) and not already processed
            if (timeDiff < 600000 && // 10 minutes
                !_processedNotifications.contains(notificationId) &&
                !_isShowingRating) {
              _processedNotifications.add(notificationId);
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && !_isShowingRating) {
                  // Show enterprise rating if enterpriseId exists, otherwise show driver rating
                  if (enterpriseId != null) {
                    _showEnterpriseRatingDialog(requestId, enterpriseId);
                  } else if (driverId != null) {
                    _showRatingDialog(requestId, driverId);
                  }
                }
              });
              break;
            }
          }
        }
      }
    }).catchError((error) {
      print('Error loading existing notifications: $error');
    });

    // Listen to new notifications
    _notificationsSubscription = _db
        .child('customer_notifications/$userId')
        .onChildAdded
        .listen((event) {
      if (!mounted) return;

      final notificationData = Map<String, dynamic>.from(event.snapshot.value as Map);
      final notificationId = event.snapshot.key;
      final type = notificationData['type'] as String?;
      final requestId = notificationData['requestId'] as String?;
      final driverId = notificationData['driverId'] as String?;
      final enterpriseId = notificationData['enterpriseId'] as String?;

      print('New notification received: type=$type, requestId=$requestId, driverId=$driverId, enterpriseId=$enterpriseId');

      // Process journey_completed notifications
      if (type == 'journey_completed' && 
          requestId != null &&
          notificationId != null &&
          !_processedNotifications.contains(notificationId) &&
          !_isShowingRating) {
        print('Processing journey_completed notification: $notificationId');
        _processedNotifications.add(notificationId);
        // Use a delay to ensure the widget tree is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isShowingRating) {
            // Show enterprise rating if enterpriseId exists, otherwise show driver rating
            if (enterpriseId != null) {
              _showEnterpriseRatingDialog(requestId, enterpriseId);
            } else if (driverId != null) {
              _showRatingDialog(requestId, driverId);
            }
          }
        });
      }
    }, onError: (error) {
      print('Error listening to notifications: $error');
    });
  }

  Future<void> _showRatingDialog(String requestId, String driverId) async {
    if (_isShowingRating || !mounted) {
      print('Rating dialog: Already showing or not mounted');
      return;
    }

    print('Rating dialog: Starting for requestId: $requestId, driverId: $driverId');
    _isShowingRating = true;

    // Check if already rated
    try {
      final requestSnapshot = await _db.child('requests/$requestId').get();
      if (requestSnapshot.exists) {
        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        if (requestData['isRated'] == true) {
          print('Rating dialog: Already rated, skipping');
          _isShowingRating = false;
          return;
        }
      }
    } catch (e) {
      print('Error checking rating status: $e');
      _isShowingRating = false;
      return;
    }

    // Load driver name
    String? driverName;
    try {
      final driverSnapshot = await _db.child('users/$driverId').get();
      if (driverSnapshot.exists) {
        final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
        driverName = driverData['name'] ?? driverData['fullName'];
      }
    } catch (e) {
      print('Error loading driver name: $e');
    }

    // Wait a bit to ensure the app is ready and context is available
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) {
      print('Rating dialog: Not mounted after delay');
      _isShowingRating = false;
      return;
    }

    // Try to get navigator from global key first, then from context
    NavigatorState? navigator;
    if (ratingNavigatorKey.currentState != null) {
      navigator = ratingNavigatorKey.currentState;
    } else {
      navigator = Navigator.maybeOf(context, rootNavigator: true);
    }
    
    if (navigator == null || !mounted) {
      print('Rating dialog: Navigator not available');
      _isShowingRating = false;
      return;
    }

    print('Rating dialog: Showing rating screen');
    
    // Show rating screen as a full-screen dialog
    try {
      final result = await navigator.push(
        MaterialPageRoute(
          builder: (context) => RateDriverScreen(
            requestId: requestId,
            driverId: driverId,
            driverName: driverName,
          ),
          fullscreenDialog: true,
        ),
      );

      print('Rating dialog: Result: $result');
    } catch (e) {
      print('Error showing rating dialog: $e');
    } finally {
      _isShowingRating = false;
    }
  }

  Future<void> _showEnterpriseRatingDialog(String requestId, String enterpriseId) async {
    if (_isShowingRating || !mounted) {
      print('Enterprise rating dialog: Already showing or not mounted');
      return;
    }

    print('Enterprise rating dialog: Starting for requestId: $requestId, enterpriseId: $enterpriseId');
    _isShowingRating = true;

    // Check if already rated
    try {
      final requestSnapshot = await _db.child('requests/$requestId').get();
      if (requestSnapshot.exists) {
        final requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        if (requestData['isEnterpriseRated'] == true) {
          print('Enterprise rating dialog: Already rated, skipping');
          _isShowingRating = false;
          return;
        }
      }
    } catch (e) {
      print('Error checking enterprise rating status: $e');
      _isShowingRating = false;
      return;
    }

    // Load enterprise name
    String? enterpriseName;
    try {
      final enterpriseSnapshot = await _db.child('users/$enterpriseId').get();
      if (enterpriseSnapshot.exists) {
        final enterpriseData = Map<String, dynamic>.from(enterpriseSnapshot.value as Map);
        final enterpriseDetails = enterpriseData['enterpriseDetails'] as Map<String, dynamic>?;
        enterpriseName = enterpriseDetails?['enterpriseName'] ?? 
                        enterpriseData['name'] ?? 
                        enterpriseData['companyName'];
      }
    } catch (e) {
      print('Error loading enterprise name: $e');
    }

    // Wait a bit to ensure the app is ready and context is available
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) {
      print('Enterprise rating dialog: Not mounted after delay');
      _isShowingRating = false;
      return;
    }

    // Try to get navigator from global key first, then from context
    NavigatorState? navigator;
    if (ratingNavigatorKey.currentState != null) {
      navigator = ratingNavigatorKey.currentState;
    } else {
      navigator = Navigator.maybeOf(context, rootNavigator: true);
    }
    
    if (navigator == null || !mounted) {
      print('Enterprise rating dialog: Navigator not available');
      _isShowingRating = false;
      return;
    }

    print('Enterprise rating dialog: Showing rating screen');
    
    // Show rating screen as a full-screen dialog
    try {
      final result = await navigator.push(
        MaterialPageRoute(
          builder: (context) => RateEnterpriseScreen(
            requestId: requestId,
            enterpriseId: enterpriseId,
            enterpriseName: enterpriseName,
          ),
          fullscreenDialog: true,
        ),
      );

      print('Enterprise rating dialog: Result: $result');
    } catch (e) {
      print('Error showing enterprise rating dialog: $e');
    } finally {
      _isShowingRating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

