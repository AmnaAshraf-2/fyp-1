import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedTrips = [];
  List<Map<String, dynamic>> _filteredTrips = [];
  StreamSubscription? _historySubscription;
  StreamSubscription? _requestsSubscription;
  Map<String, Map<String, dynamic>> _tripsMap = {};
  DateTime? _startDate;
  DateTime? _endDate;

  // Commission constants
  static const double commissionRate = 0.10; // 10%
  static const double minimumCommission = 100.0;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  double _calculateCommission(double finalFare) {
    final percentageCommission = finalFare * commissionRate;
    return percentageCommission < minimumCommission
        ? minimumCommission
        : percentageCommission;
  }

  double _calculateDriverEarnings(double finalFare) {
    final commission = _calculateCommission(finalFare);
    return finalFare - commission;
  }

  void _updateTripsList() {
    final trips = _tripsMap.values.toList();
    // Sort by completion date (newest first)
    trips.sort((a, b) {
      final aTime = a['completedAt'] ?? a['journeyCompletedAt'] ?? a['timestamp'] ?? 0;
      final bTime = b['completedAt'] ?? b['journeyCompletedAt'] ?? b['timestamp'] ?? 0;
      return bTime.compareTo(aTime);
    });
    if (mounted) {
      setState(() {
        _completedTrips = trips;
        _applyDateFilter();
        _isLoading = false;
      });
    }
  }

  void _applyDateFilter() {
    if (_startDate == null && _endDate == null) {
      _filteredTrips = _completedTrips;
      return;
    }

    _filteredTrips = _completedTrips.where((trip) {
      final completedAt = trip['completedAt'] ?? trip['journeyCompletedAt'] ?? trip['timestamp'];
      if (completedAt == null) return false;
      
      final tripDate = DateTime.fromMillisecondsSinceEpoch(completedAt);
      final tripDateOnly = DateTime(tripDate.year, tripDate.month, tripDate.day);
      
      bool matchesStart = _startDate == null;
      if (_startDate != null) {
        final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        matchesStart = tripDateOnly.isAtSameMomentAs(startDateOnly) || tripDateOnly.isAfter(startDateOnly);
      }
      
      bool matchesEnd = _endDate == null;
      if (_endDate != null) {
        final endDateOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        matchesEnd = tripDateOnly.isAtSameMomentAs(endDateOnly) || tripDateOnly.isBefore(endDateOnly);
      }
      
      return matchesStart && matchesEnd;
    }).toList();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF004d4d),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _applyDateFilter();
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF004d4d),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _applyDateFilter();
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _applyDateFilter();
    });
  }

  Future<void> _generateAndDownloadPDF() async {
    final t = AppLocalizations.of(context)!;
    final user = _auth.currentUser;
    final userName = user?.email ?? 'Driver';
    
    final pdf = pw.Document();
    final filteredTrips = _filteredTrips;
    final totalEarnings = _getFilteredTotalEarnings();
    final totalCommission = _getFilteredTotalCommission();
    final totalRevenue = _getFilteredTotalRevenue();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    t.earnings,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Date Range
            if (_startDate != null || _endDate != null)
              pw.Padding(
                padding: pw.EdgeInsets.only(bottom: 20),
                child: pw.Text(
                  '${t.from}: ${_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : t.nA} - ${t.to}: ${_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : t.nA}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ),
            
            // Summary Section
            pw.Container(
              padding: pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    t.totalEarnings,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('${t.trips}: ${filteredTrips.length}', style: pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(height: 5),
                          pw.Text('${t.revenue}: Rs ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('${t.commission}: Rs ${totalCommission.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            '${t.earnings}: Rs ${totalEarnings.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Trips List
            pw.Text(
              t.earningsHistory,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            
            if (filteredTrips.isEmpty)
              pw.Text(t.noEarningsYet, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.trip, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.fare, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.commission, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.earnings, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.completed, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  // Data rows
                  ...filteredTrips.map((trip) {
                    final fare = (trip['finalFare'] ?? trip['offerFare'] ?? 0).toDouble();
                    final commission = fare > 0 ? _calculateCommission(fare) : 0;
                    final earnings = fare > 0 ? _calculateDriverEarnings(fare) : 0;
                    final completedAt = trip['completedAt'] ?? trip['journeyCompletedAt'] ?? trip['timestamp'];
                    final dateStr = completedAt != null 
                        ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(completedAt))
                        : t.nA;
                    
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            trip['loadName'] ?? t.trip,
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${fare.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${commission.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${earnings.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(dateStr, style: pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
          ];
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      print('Error generating PDF: $e');
    }
  }

  double _getFilteredTotalEarnings() {
    double total = 0;
    for (final trip in _filteredTrips) {
      final fare = (trip['finalFare'] ?? trip['offerFare'] ?? 0).toDouble();
      if (fare > 0) {
        total += _calculateDriverEarnings(fare);
      }
    }
    return total;
  }

  double _getFilteredTotalCommission() {
    double total = 0;
    for (final trip in _filteredTrips) {
      final fare = (trip['finalFare'] ?? trip['offerFare'] ?? 0).toDouble();
      if (fare > 0) {
        total += _calculateCommission(fare);
      }
    }
    return total;
  }

  double _getFilteredTotalRevenue() {
    double total = 0;
    for (final trip in _filteredTrips) {
      final fare = (trip['finalFare'] ?? trip['offerFare'] ?? 0).toDouble();
      if (fare > 0) {
        total += fare;
      }
    }
    return total;
  }

  Future<void> _loadEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final timeout = Duration(seconds: 10);

      // Listen to driver_history for completed trips
      _historySubscription = _db.child('driver_history/${user.uid}').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final trip in event.snapshot.children) {
            final tripKey = trip.key;
            if (tripKey == null) continue;
            
            final tripData = Map<String, dynamic>.from(trip.value as Map);
            tripData['requestId'] = tripKey;
            tripData['status'] = 'completed';
            _tripsMap[tripKey] = tripData;
          }
        }
        _updateTripsList();
      }, onError: (error) {
        print('Error loading driver history: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });

      // Listen to requests for completed trips
      _requestsSubscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final request in event.snapshot.children) {
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final requestId = request.key;
            
            if (requestId == null) continue;
            
            if (requestData['acceptedDriverId'] == user.uid && 
                requestData['status'] == 'completed') {
              if (!_tripsMap.containsKey(requestId)) {
                requestData['requestId'] = requestId;
                requestData['status'] = 'completed';
                if (requestData['journeyCompletedAt'] == null && requestData['completedAt'] == null) {
                  requestData['completedAt'] = DateTime.now().millisecondsSinceEpoch;
                }
                _tripsMap[requestId] = requestData;
              }
            }
          }
        }
        _updateTripsList();
      }, onError: (error) {
        print('Error loading requests: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      print('Error loading earnings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  String _formatTimestamp(int? timestamp, AppLocalizations t) {
    if (timestamp == null) return t.nA;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final totalEarnings = _getFilteredTotalEarnings();
    final totalCommission = _getFilteredTotalCommission();
    final totalRevenue = _getFilteredTotalRevenue();
    final tripCount = _filteredTrips.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.earnings, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _filteredTrips.isEmpty ? null : _generateAndDownloadPDF,
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF004d4d)),
                  SizedBox(height: 10),
                  Text(t.loadingEarnings, style: TextStyle(color: Color(0xFF004d4d))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEarnings,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Date Range Filter
                    Container(
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Date Range Filter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              if (_startDate != null || _endDate != null)
                                TextButton.icon(
                                  onPressed: _clearDateFilter,
                                  icon: Icon(Icons.clear, size: 16),
                                  label: Text('Clear'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _selectStartDate,
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 18, color: Color(0xFF004d4d)),
                                        SizedBox(width: 8),
                                        Text(
                                          _startDate == null
                                              ? 'Start Date'
                                              : DateFormat('dd/MM/yyyy').format(_startDate!),
                                          style: TextStyle(
                                            color: _startDate == null ? Colors.grey : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _selectEndDate,
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 18, color: Color(0xFF004d4d)),
                                        SizedBox(width: 8),
                                        Text(
                                          _endDate == null
                                              ? 'End Date'
                                              : DateFormat('dd/MM/yyyy').format(_endDate!),
                                          style: TextStyle(
                                            color: _endDate == null ? Colors.grey : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Summary Cards
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF006A6A), Color(0xFF008B8B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Total Earnings Card
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  t.totalEarnings,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Rs ${totalEarnings.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF004d4d),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(t.trips, tripCount.toString(), Icons.directions_bus),
                                    _buildStatItem(t.revenue, 'Rs ${totalRevenue.toStringAsFixed(2)}', Icons.attach_money),
                                    _buildStatItem(t.commission, 'Rs ${totalCommission.toStringAsFixed(2)}', Icons.receipt),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Earnings List
                    if (_filteredTrips.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet, size: 70, color: Colors.grey.shade400),
                            SizedBox(height: 10),
                            Text(
                              t.noEarningsYet,
                              style: TextStyle(fontSize: 18, color: Color(0xFF004d4d)),
                            ),
                            SizedBox(height: 5),
                            Text(
                              t.earningsWillAppearAfterTrips,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.earningsHistory,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004d4d),
                              ),
                            ),
                            SizedBox(height: 16),
                            ..._filteredTrips.map((trip) {
                              final fare = (trip['finalFare'] ?? trip['offerFare'] ?? 0).toDouble();
                              final commission = fare > 0 ? _calculateCommission(fare) : 0;
                              final earnings = fare > 0 ? _calculateDriverEarnings(fare) : 0;
                              final completedAt = trip['completedAt'] ?? trip['journeyCompletedAt'] ?? trip['timestamp'];

                              return Container(
                                margin: EdgeInsets.only(bottom: 12),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            trip['loadName'] ?? t.trip,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF004d4d),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(completedAt, t),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.fare,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              'Rs ${fare.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF004d4d),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.commission,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              'Rs ${commission.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              t.earnings,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              'Rs ${earnings.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFF004d4d), size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF004d4d),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

