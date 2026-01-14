import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// Teal color palette
const kTealDark = Color(0xFF004D4D);
const kTeal = Color(0xFF007D7D);
const kTealLight = Color(0xFFB2DFDB);
const kTealBg = Color(0xFFE0F2F1);

class EnterpriseEarningsScreen extends StatefulWidget {
  const EnterpriseEarningsScreen({super.key});

  @override
  State<EnterpriseEarningsScreen> createState() => _EnterpriseEarningsScreenState();
}

class _EnterpriseEarningsScreenState extends State<EnterpriseEarningsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isGeneratingPDF = false;
  List<Map<String, dynamic>> _completedBookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  StreamSubscription? _historySubscription;
  StreamSubscription? _requestsSubscription;
  Map<String, Map<String, dynamic>> _bookingsMap = {};
  DateTime? _startDate;
  DateTime? _endDate;

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

  void _updateBookingsList() {
    final bookings = _bookingsMap.values.toList();
    // Sort by completion date (newest first)
    bookings.sort((a, b) {
      final aTime = a['completedAt'] ?? a['journeyCompletedAt'] ?? a['deliveredAt'] ?? a['timestamp'] ?? 0;
      final bTime = b['completedAt'] ?? b['journeyCompletedAt'] ?? b['deliveredAt'] ?? b['timestamp'] ?? 0;
      return bTime.compareTo(aTime);
    });
    if (mounted) {
      setState(() {
        _completedBookings = bookings;
        _applyDateFilter();
        _isLoading = false;
      });
    }
  }

  void _applyDateFilter() {
    if (_startDate == null && _endDate == null) {
      _filteredBookings = _completedBookings;
      return;
    }

    _filteredBookings = _completedBookings.where((booking) {
      final completedAt = booking['completedAt'] ?? booking['journeyCompletedAt'] ?? booking['deliveredAt'] ?? booking['timestamp'];
      if (completedAt == null) return false;
      
      final bookingDate = DateTime.fromMillisecondsSinceEpoch(completedAt);
      final bookingDateOnly = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
      
      bool matchesStart = _startDate == null;
      if (_startDate != null) {
        final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        matchesStart = bookingDateOnly.isAtSameMomentAs(startDateOnly) || bookingDateOnly.isAfter(startDateOnly);
      }
      
      bool matchesEnd = _endDate == null;
      if (_endDate != null) {
        final endDateOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        matchesEnd = bookingDateOnly.isAtSameMomentAs(endDateOnly) || bookingDateOnly.isBefore(endDateOnly);
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
              primary: kTeal,
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
              primary: kTeal,
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
    
    // Check if there are any bookings to generate PDF for
    if (_filteredBookings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No bookings available to generate PDF'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (_isGeneratingPDF) return; // Prevent multiple simultaneous PDF generations
    
    setState(() {
      _isGeneratingPDF = true;
    });
    
    try {
      final user = _auth.currentUser;
      final userName = user?.email ?? 'Enterprise';
      
      final pdf = pw.Document();
      final filteredBookings = _filteredBookings;
      final totalEarnings = _getFilteredTotalEarnings();
      final bookingCount = filteredBookings.length;
      final averageEarnings = bookingCount > 0 ? totalEarnings / bookingCount : 0.0;
      
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
                          pw.Text('${t.bookings}: ${bookingCount}', style: pw.TextStyle(fontSize: 12)),
                          pw.SizedBox(height: 5),
                          pw.Text('${t.average}: Rs ${averageEarnings.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Rs ${totalEarnings.toStringAsFixed(2)}',
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
            
            // Bookings List
            pw.Text(
              t.earningsHistory,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            
            if (filteredBookings.isEmpty)
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
                        child: pw.Text(t.booking, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.earnings, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.completed, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(t.vehicle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  // Data rows
                  ...filteredBookings.map((booking) {
                    final fare = (booking['finalFare'] ?? booking['offerFare'] ?? 0).toDouble();
                    final completedAt = booking['completedAt'] ?? 
                                       booking['journeyCompletedAt'] ?? 
                                       booking['deliveredAt'] ?? 
                                       booking['timestamp'];
                    final dateStr = completedAt != null 
                        ? DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(completedAt))
                        : t.nA;
                    final vehicleType = booking['vehicleType'] ?? t.nA;
                    
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            booking['loadName'] ?? t.booking,
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Rs ${fare.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(dateStr, style: pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(vehicleType, style: pw.TextStyle(fontSize: 9)),
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

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  double _getFilteredTotalEarnings() {
    double total = 0;
    for (final booking in _filteredBookings) {
      final fare = (booking['finalFare'] ?? booking['offerFare'] ?? 0).toDouble();
      if (fare > 0) {
        total += fare; // Enterprise receives full fare
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

      // Listen to enterprise_history for completed bookings
      _historySubscription = _db.child('enterprise_history/${user.uid}').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final booking in event.snapshot.children) {
            final bookingKey = booking.key;
            if (bookingKey == null) continue;
            
            final bookingData = Map<String, dynamic>.from(booking.value as Map);
            bookingData['requestId'] = bookingKey;
            bookingData['status'] = 'completed';
            _bookingsMap[bookingKey] = bookingData;
          }
        }
        _updateBookingsList();
      }, onError: (error) {
        print('Error loading enterprise history: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });

      // Listen to requests for completed bookings
      _requestsSubscription = _db.child('requests').onValue.timeout(timeout).listen((event) {
        if (event.snapshot.exists) {
          for (final request in event.snapshot.children) {
            final requestKey = request.key;
            if (requestKey == null) continue;
            
            final requestData = Map<String, dynamic>.from(request.value as Map);
            final acceptedEnterpriseId = requestData['acceptedEnterpriseId'] as String?;
            
            if (acceptedEnterpriseId == user.uid &&
                requestData['status'] == 'completed') {
              requestData['requestId'] = requestKey;
              requestData['status'] = 'completed';
              
              if (!_bookingsMap.containsKey(requestKey)) {
                if (requestData['journeyCompletedAt'] == null && 
                    requestData['completedAt'] == null && 
                    requestData['deliveredAt'] == null) {
                  requestData['completedAt'] = DateTime.now().millisecondsSinceEpoch;
                }
                _bookingsMap[requestKey] = requestData;
              }
            }
          }
        }
        _updateBookingsList();
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
    final bookingCount = _filteredBookings.length;
    final averageEarnings = bookingCount > 0 ? totalEarnings / bookingCount : 0.0;

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
              : RefreshIndicator(
                  onRefresh: _loadEarnings,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Date Range Filter
                        Container(
                          margin: EdgeInsets.all(20),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kTeal, kTealDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: Offset(0, 4),
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
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_startDate != null || _endDate != null)
                                    TextButton.icon(
                                      onPressed: _clearDateFilter,
                                      icon: Icon(Icons.clear, size: 16),
                                      label: Text('Clear'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
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
                                          color: Colors.white.withOpacity(0.2),
                                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 18, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              _startDate == null
                                                  ? 'Start Date'
                                                  : DateFormat('dd/MM/yyyy').format(_startDate!),
                                              style: TextStyle(
                                                color: Colors.white,
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
                                          color: Colors.white.withOpacity(0.2),
                                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 18, color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              _endDate == null
                                                  ? 'End Date'
                                                  : DateFormat('dd/MM/yyyy').format(_endDate!),
                                              style: TextStyle(
                                                color: Colors.white,
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
                        // Summary Section
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Total Earnings Card
                              Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [kTeal, kTealDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      t.totalEarnings,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Rs ${totalEarnings.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem(t.bookings, bookingCount.toString(), Icons.book),
                                        _buildStatItem(t.average, 'Rs ${averageEarnings.toStringAsFixed(2)}', Icons.trending_up),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Earnings List
                        if (_filteredBookings.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  t.noEarningsYet,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  t.earningsWillAppearHere,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.earningsHistory,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 16),
                                ..._filteredBookings.map((booking) {
                                  final fare = (booking['finalFare'] ?? booking['offerFare'] ?? 0).toDouble();
                                  final completedAt = booking['completedAt'] ?? 
                                                     booking['journeyCompletedAt'] ?? 
                                                     booking['deliveredAt'] ?? 
                                                     booking['timestamp'];

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [kTeal, kTealDark],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
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
                                                booking['loadName'] ?? t.booking,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.green, width: 1),
                                              ),
                                              child: Text(
                                                t.completed,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                                                  t.earnings,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white.withOpacity(0.8),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Rs ${fare.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  t.completed,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white.withOpacity(0.8),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  _formatTimestamp(completedAt, t),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white.withOpacity(0.9),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (booking['vehicleType'] != null) ...[
                                          SizedBox(height: 8),
                                          Text(
                                            '${t.vehicle}: ${booking['vehicleType']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                        ],
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
          t.earnings,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_isGeneratingPDF)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.picture_as_pdf),
              onPressed: _generateAndDownloadPDF,
              tooltip: _filteredBookings.isEmpty 
                  ? 'No bookings to download' 
                  : 'Download PDF Report',
              color: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

