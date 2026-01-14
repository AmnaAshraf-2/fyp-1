import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:logistics_app/splash/welcome.dart';
import 'package:logistics_app/screens/reg.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/screens/users/driver/driver_registration.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/main.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PhoneAuthScreen extends StatefulWidget {
  final bool isLogin; // true for login, false for registration
  
  const PhoneAuthScreen({super.key, this.isLogin = false});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;
  String _countryCode = '+92';
  String? _selectedRole; // For registration only
  final TextEditingController _nameController = TextEditingController(); // For registration only

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    if (_phoneController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter phone number");
      return;
    }

    setState(() => _isLoading = true);
    final fullPhone = _countryCode + _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (credential) async {
          // Auto-verification completed (Android only)
          await _signInWithCredential(credential);
        },
        verificationFailed: (e) {
          String errorMessage = "Verification failed: ${e.message ?? e.code}";
          
          // Handle specific error cases
          if (e.message?.contains("missing initial state") == true ||
              e.message?.contains("sessionStorage") == true ||
              e.message?.contains("browser sessionStorage") == true) {
            errorMessage = "Authentication error. Please ensure your app is properly configured in Firebase Console. If the issue persists, try again or contact support.";
          } else if (e.code == 'too-many-requests' || 
                     e.message?.contains("blocked all requests") == true ||
                     e.message?.contains("unusual activity") == true ||
                     e.code == '17010') {
            errorMessage = "Too many attempts. Firebase has temporarily blocked requests from this device. Please wait a few minutes and try again.";
          } else if (e.code == 'invalid-phone-number') {
            errorMessage = "Invalid phone number format. Please check and try again.";
          } else if (e.code == 'quota-exceeded') {
            errorMessage = "SMS quota exceeded. Please try again later.";
          }
          
          Fluttertoast.showToast(
            msg: errorMessage,
            toastLength: Toast.LENGTH_LONG,
          );
          setState(() => _isLoading = false);
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          setState(() {
            _isOtpSent = true;
            _isLoading = false;
          });
          Fluttertoast.showToast(msg: "OTP sent to $fullPhone");
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      String errorMessage = "Error: ${e.toString()}";
      
      // Handle specific error cases in catch block
      if (e.toString().contains("missing initial state") ||
          e.toString().contains("sessionStorage") ||
          e.toString().contains("browser sessionStorage")) {
        errorMessage = "Authentication error. Please ensure your app is properly configured in Firebase Console. If the issue persists, try again or contact support.";
      } else if (e.toString().contains("blocked all requests") ||
                 e.toString().contains("unusual activity")) {
        errorMessage = "Too many attempts. Firebase has temporarily blocked requests from this device. Please wait a few minutes and try again.";
      }
      
      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty || _verificationId == null) {
      Fluttertoast.showToast(msg: "Please enter OTP");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _signInWithCredential(credential);
    } catch (e) {
      Fluttertoast.showToast(msg: "Invalid OTP. Please try again.");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Check if user exists in database
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get();

      if (widget.isLogin) {
        // LOGIN FLOW
        if (!userSnapshot.exists) {
          // User not registered
          await FirebaseAuth.instance.signOut();
          Fluttertoast.showToast(
            msg: "Phone number not registered. Please register first.",
            toastLength: Toast.LENGTH_LONG,
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // User exists - proceed with login
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', userData['name'] ?? '');
        await prefs.setString('profile_image', userData['profileImage'] ?? '');
        await prefs.setString('userRole', userData['role'] ?? '');
        
        final langKey = 'languageCode_${user.uid}';
        if (!prefs.containsKey(langKey)) {
          await prefs.setString(langKey, 'en');
        }

        Fluttertoast.showToast(msg: "Login successful");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          );
        }
      } else {
        // REGISTRATION FLOW
        if (userSnapshot.exists) {
          // User already registered
          await FirebaseAuth.instance.signOut();
          Fluttertoast.showToast(
            msg: "This phone number is already registered. Please login instead.",
            toastLength: Toast.LENGTH_LONG,
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // New user - get name and role
        if (mounted) {
          final name = await _showNameDialog();
          if (name == null || name.isEmpty) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              setState(() => _isLoading = false);
            }
            return;
          }

          // Ensure context is still valid and wait for name dialog to fully close
          if (!mounted) {
            await FirebaseAuth.instance.signOut();
            return;
          }
          
          // Use WidgetsBinding to ensure name dialog is fully closed before showing role dialog
          await WidgetsBinding.instance.endOfFrame;
          
          if (!mounted) {
            await FirebaseAuth.instance.signOut();
            return;
          }
          
          final role = await _showRoleSelectionDialog();
          if (role == null) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              setState(() => _isLoading = false);
            }
            return;
          }

          // Save user to database
          final fullPhone = _countryCode + _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
          final userMap = <String, dynamic>{
            "id": user.uid,
            "name": name,
            "email": "", // Phone auth doesn't provide email
            "phone": fullPhone,
            "role": role,
            "profileImage": "",
            "isProfileComplete": role == 'driver' ? false : true,
            "createdAt": ServerValue.timestamp,
          };

          await FirebaseDatabase.instance
              .ref('users/${user.uid}')
              .set(userMap);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('full_name', name);
          await prefs.setString('profile_image', '');
          await prefs.setString('userRole', role);
          await prefs.setString('languageCode_${user.uid}', 'en');

          // Set loading to false before navigation
          if (mounted) {
            setState(() => _isLoading = false);
          }
          
          Fluttertoast.showToast(msg: "Registration successful");
          
          // Wait a frame to ensure dialogs are fully closed before navigation
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              _navigateBasedOnRole(role);
            }
          }
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showNameDialog() async {
    String? name;
    final nameController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Your Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'John Doe',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004d4d),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  name = nameController.text.trim();
                  Navigator.pop(context);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    
    nameController.dispose();
    return name;
  }

  Future<String?> _showRoleSelectionDialog() async {
    String? selectedRole;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(loc != null ? 'Select Your Role' : 'Select Your Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(loc?.customer ?? 'Customer'),
                leading: const Icon(Icons.person, color: Color(0xFF004d4d)),
                onTap: () {
                  selectedRole = 'customer';
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(loc?.driver ?? 'Driver'),
                leading: const Icon(Icons.drive_eta, color: Color(0xFF004d4d)),
                onTap: () {
                  selectedRole = 'driver';
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(loc?.enterprise ?? 'Enterprise'),
                leading: const Icon(Icons.business, color: Color(0xFF004d4d)),
                onTap: () {
                  selectedRole = 'enterprise';
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
    return selectedRole;
  }

  void _navigateBasedOnRole(String role) {
    if (!mounted) return;
    
    // Use WidgetsBinding to ensure navigation happens after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (role == 'customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      } else if (role == 'driver') {
        // Navigate to driver registration screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverRegistration()),
        );
      } else if (role == 'enterprise') {
        // Navigate to enterprise details screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnterpriseDetailsScreen()),
        );
      }
    });
  }

  void _resetOtp() {
    setState(() {
      _isOtpSent = false;
      _otpController.clear();
      _verificationId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isLogin ? "Phone Login" : "Phone Registration"),
        backgroundColor: const Color(0xFF004d4d),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android,
              size: 80,
              color: const Color(0xFF004d4d),
            ),
            const SizedBox(height: 30),
            if (!_isOtpSent)
              IntlPhoneField(
                controller: _phoneController,
                initialCountryCode: 'PK',
                onCountryChanged: (country) {
                  _countryCode = '+${country.dialCode}';
                },
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            if (_isOtpSent) ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  hintText: '123456',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                maxLength: 6,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _resetOtp,
                child: const Text('Change Phone Number'),
              ),
            ],
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (!_isOtpSent)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004d4d),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _verifyPhoneNumber,
                child: const Text('Send OTP', style: TextStyle(fontSize: 16)),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004d4d),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _verifyOtp,
                child: const Text('Verify OTP', style: TextStyle(fontSize: 16)),
              ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                widget.isLogin ? 'Back to Login' : 'Back to Register',
                style: const TextStyle(color: Color(0xFF004d4d)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
