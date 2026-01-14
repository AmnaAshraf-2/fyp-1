import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EnterpriseDriverAssignmentsScreen extends StatefulWidget {
  const EnterpriseDriverAssignmentsScreen({super.key});

  @override
  State<EnterpriseDriverAssignmentsScreen> createState() => _EnterpriseDriverAssignmentsScreenState();
}

class _EnterpriseDriverAssignmentsScreenState extends State<EnterpriseDriverAssignmentsScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription? _assignmentsSubscription;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    _assignmentsSubscription?.cancel();
    super.dispose();
  }

  void _loadAssignments() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Listen to real-time updates
      _assignmentsSubscription = _db
          .child('enterprise_driver_assignments/${user.uid}')
          .orderByChild('assignedAt')
          .onValue
          .listen(
        (event) {
          if (mounted) {
            if (event.snapshot.exists) {
              final assignments = <Map<String, dynamic>>[];
              for (final assignment in event.snapshot.children) {
                final assignmentData = Map<String, dynamic>.from(assignment.value as Map);
                assignmentData['assignmentId'] = assignment.key;
                assignments.add(assignmentData);
              }
              // Filter out accepted assignments - they should appear in upcoming trips
              final pendingAssignments = assignments.where((assignment) {
                final status = assignment['status'] as String? ?? 'pending';
                return status != 'accepted';
              }).toList();
              
              // Sort by assignedAt (newest first)
              pendingAssignments.sort((a, b) => (b['assignedAt'] ?? 0).compareTo(a['assignedAt'] ?? 0));
              setState(() {
                _assignments = pendingAssignments;
                _isLoading = false;
              });
            } else {
              setState(() {
                _assignments = [];
                _isLoading = false;
              });
            }
          }
        },
        onError: (error) {
          print('Error loading assignments: $error');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      print('Error loading assignments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToAssignment(
    String assignmentId,
    String requestId,
    String resourceIndex,
    String driverId,
    String vehicleId,
    String enterpriseId,
    bool accept,
  ) async {
    final t = AppLocalizations.of(context)!;
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update assignment status
      if (accept) {
        // If accepting, update status
        await _db.child('enterprise_driver_assignments/${user.uid}/$assignmentId').update({
          'status': 'accepted',
          'respondedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // If rejecting, delete the assignment from enterprise_driver_assignments
        await _db.child('enterprise_driver_assignments/${user.uid}/$assignmentId').remove();
      }

      // Update the request's assignedResources status
      print('🔍 DEBUG: Updating assignment - requestId: $requestId, resourceIndex: $resourceIndex, accept: $accept');
      final requestSnapshot = await _db.child('requests/$requestId').get();
      if (requestSnapshot.exists) {
        // Handle both Map and List types from Firebase
        Map<String, dynamic> requestData;
        if (requestSnapshot.value is Map) {
          requestData = Map<String, dynamic>.from(requestSnapshot.value as Map);
        } else if (requestSnapshot.value is List) {
          // If it's a List, we can't process it as a request - log and skip
          print('⚠️ Warning: request data is a List, not a Map. RequestId: $requestId');
          return;
        } else {
          print('⚠️ Warning: request data is neither Map nor List. Type: ${requestSnapshot.value.runtimeType}');
          return;
        }
        
        final assignedResources = requestData['assignedResources'];
        Map<String, dynamic>? assignedResourcesMap;
        
        // Handle assignedResources as either Map or List
        if (assignedResources is Map) {
          assignedResourcesMap = Map<String, dynamic>.from(assignedResources);
        } else if (assignedResources is List) {
          // Convert List to Map if needed (index-based)
          print('⚠️ Warning: assignedResources is a List, converting to Map');
          assignedResourcesMap = {};
          for (int i = 0; i < assignedResources.length; i++) {
            if (assignedResources[i] is Map) {
              assignedResourcesMap![i.toString()] = assignedResources[i];
            }
          }
        }
        
        print('🔍 DEBUG: assignedResources keys: ${assignedResourcesMap?.keys.toList()}');
        print('🔍 DEBUG: Looking for resourceIndex: "$resourceIndex" (type: ${resourceIndex.runtimeType})');
        
        // Try to find the resource by resourceIndex (try both string and int)
        String? foundKey;
        if (assignedResourcesMap != null) {
          // Try exact match first
          if (assignedResourcesMap.containsKey(resourceIndex)) {
            foundKey = resourceIndex;
          } else {
            // Try converting resourceIndex to int and back to string
            final resourceIndexInt = int.tryParse(resourceIndex);
            if (resourceIndexInt != null) {
              final intKey = resourceIndexInt.toString();
              if (assignedResourcesMap.containsKey(intKey)) {
                foundKey = intKey;
              }
            }
            // Try all keys to find matching driverAuthUid or driverId as fallback
            if (foundKey == null) {
              print('🔍 DEBUG: resourceIndex not found, searching by driverId: $driverId');
              for (final key in assignedResourcesMap.keys) {
                final resource = assignedResourcesMap[key];
                if (resource is Map) {
                  final resourceData = Map<String, dynamic>.from(resource);
                  final resourceDriverAuthUid = resourceData['driverAuthUid'] as String?;
                  final resourceDriverId = resourceData['driverId'] as String?;
                  
                  print('🔍 DEBUG: Checking key $key - driverId: $resourceDriverId, driverAuthUid: $resourceDriverAuthUid');
                  
                  // Match by driverId if driverAuthUid is null or matches
                  if (resourceDriverId == driverId) {
                    foundKey = key;
                    print('✅ DEBUG: Found resource by driverId match at key: $key');
                    break;
                  }
                  // Also check driverAuthUid if it exists
                  if (resourceDriverAuthUid == user.uid) {
                    foundKey = key;
                    print('✅ DEBUG: Found resource by driverAuthUid match at key: $key');
                    break;
                  }
                }
              }
            }
          }
        }
        
        if (foundKey != null && assignedResourcesMap != null) {
          // Prepare update data
          final updateData = <String, dynamic>{
            'status': accept ? 'accepted' : 'rejected',
            'respondedAt': DateTime.now().millisecondsSinceEpoch,
          };
          
          // If accepting, ALWAYS set driverAuthUid to current user's UID
          // This ensures the driverAuthUid is set even if it was null initially
          if (accept) {
            updateData['driverAuthUid'] = user.uid;
            print('🔍 DEBUG: Setting driverAuthUid to: ${user.uid}');
            
            // Also verify the driverId matches (safety check)
            final currentAssignment = assignedResourcesMap[foundKey];
            if (currentAssignment is Map) {
              final currentData = Map<String, dynamic>.from(currentAssignment);
              final currentDriverId = currentData['driverId'] as String?;
              if (currentDriverId != null && currentDriverId != driverId) {
                print('⚠️ Warning: driverId mismatch - expected: $driverId, found: $currentDriverId');
              }
            }
          }
          
          try {
            print('🔍 DEBUG: Updating assignedResources at key: $foundKey with data: $updateData');
            await _db.child('requests/$requestId/assignedResources/$foundKey').update(updateData);
            print('✅ Successfully updated assignedResources status for key: $foundKey (original resourceIndex: $resourceIndex)');
            
            // Verify the update by reading it back
            final verifySnapshot = await _db.child('requests/$requestId/assignedResources/$foundKey').get();
            if (verifySnapshot.exists) {
              final verifyData = Map<String, dynamic>.from(verifySnapshot.value as Map);
              print('✅ Verification - status: ${verifyData['status']}, driverAuthUid: ${verifyData['driverAuthUid']}');
            }
          } catch (e) {
            print('❌ Error updating assignedResources: $e');
            print('❌ Stack trace: ${StackTrace.current}');
            // Don't return here - continue with notifications even if update fails
          }
        } else {
          print('⚠️ Warning: Could not find resourceIndex "$resourceIndex" in assignedResources');
          print('⚠️ DEBUG: Available keys: ${assignedResourcesMap?.keys.toList()}');
          print('⚠️ DEBUG: assignedResourcesMap is null: ${assignedResourcesMap == null}');
        }
      } else {
        print('⚠️ Warning: Request not found - requestId: $requestId');
      }

      // Notify enterprise
      final requestSnapshot2 = await _db.child('requests/$requestId').get();
      String loadName = 'a booking';
      if (requestSnapshot2.exists) {
        // Handle both Map and List types from Firebase
        if (requestSnapshot2.value is Map) {
          final requestData = Map<String, dynamic>.from(requestSnapshot2.value as Map);
          loadName = requestData['loadName'] as String? ?? 'a booking';
        } else {
          print('⚠️ Warning: requestSnapshot2.value is not a Map. Type: ${requestSnapshot2.value.runtimeType}');
        }
      }

      final driverSnapshot = await _db.child('users/$enterpriseId/drivers/$driverId').get();
      String driverName = 'Driver';
      if (driverSnapshot.exists) {
        final driverData = Map<String, dynamic>.from(driverSnapshot.value as Map);
        driverName = driverData['name'] ?? driverData['fullName'] ?? 'Driver';
      }

      final enterpriseNotificationRef = _db.child('enterprise_notifications/$enterpriseId').push();
      await enterpriseNotificationRef.set({
        'type': 'assignment_response',
        'requestId': requestId,
        'assignmentId': assignmentId,
        'driverId': driverId,
        'driverName': driverName,
        'status': accept ? 'accepted' : 'rejected',
        'message': accept 
            ? t.driverAcceptedAssignment(driverName, loadName)
            : t.driverRejectedAssignment(driverName, loadName),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });

      // Note: Customer notification will be handled by enterprise when they explicitly choose to notify
      // after all drivers have accepted their assignments

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? t.assignmentAccepted : t.assignmentRejected),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.errorRespondingToAssignment} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  String _formatTimestamp(int timestamp, AppLocalizations t) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.newAssignments),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF004d4d),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.noNewAssignments,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    final status = assignment['status'] as String? ?? 'pending';
                    final isPending = status == 'pending';
                    final isAccepted = status == 'accepted';
                    final isRejected = status == 'rejected';

                    final loadName = assignment['loadName'] as String? ?? t.booking;
                    final pickupLocation = assignment['pickupLocation'] as String? ?? t.nA;
                    final destinationLocation = assignment['destinationLocation'] as String? ?? t.nA;
                    final vehicleInfo = assignment['vehicleInfo'] as Map?;
                    final vehicleName = vehicleInfo != null
                        ? '${vehicleInfo['makeModel'] ?? ''} (${vehicleInfo['registrationNumber'] ?? ''})'
                        : t.vehicle;
                    final assignedAt = assignment['assignedAt'] as int? ?? 0;

                    return Column(
                      children: [
                        Material(
                          color: Colors.white,
                          child: InkWell(
                            onTap: null,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: isPending
                                        ? Colors.orange
                                        : isAccepted
                                            ? Colors.green
                                            : Colors.red,
                                    width: 4,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          loadName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF004d4d),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPending
                                              ? Colors.orange
                                              : isAccepted
                                                  ? Colors.green
                                                  : Colors.red,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isPending
                                              ? t.pending
                                              : isAccepted
                                                  ? t.accepted
                                                  : t.rejected,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(Icons.location_on, t.from, pickupLocation),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(Icons.location_on, t.to, destinationLocation),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(Icons.directions_car, t.vehicle, vehicleName),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.access_time,
                                    t.assigned,
                                    _formatTimestamp(assignedAt, t),
                                  ),
                                  if (isPending) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.check, color: Colors.white),
                                            label: Text(
                                              t.accept,
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            onPressed: () {
                                              _respondToAssignment(
                                                assignment['assignmentId'] as String,
                                                assignment['requestId'] as String,
                                                assignment['resourceIndex'] as String,
                                                assignment['driverId'] as String,
                                                assignment['vehicleId'] as String,
                                                assignment['enterpriseId'] as String,
                                                true,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.close, color: Colors.white),
                                            label: Text(
                                              t.reject,
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            onPressed: () {
                                              _respondToAssignment(
                                                assignment['assignmentId'] as String,
                                                assignment['requestId'] as String,
                                                assignment['resourceIndex'] as String,
                                                assignment['driverId'] as String,
                                                assignment['vehicleId'] as String,
                                                assignment['enterpriseId'] as String,
                                                false,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (index < _assignments.length - 1)
                          Divider(height: 1, color: Colors.grey[300]),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }
}

