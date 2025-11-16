import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:logistics_app/splash/welcome.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;
  String _countryCode = '+1';

  Future<void> _verifyPhoneNumber() async {
    setState(() => _isLoading = true);
    final fullPhone = _countryCode + _phoneController.text;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhone,
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _navigateToWelcome();
      },
      verificationFailed: (e) {
        Fluttertoast.showToast(msg: "Error: ${e.message}");
        setState(() => _isLoading = false);
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        setState(() {
          _isOtpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      _navigateToWelcome();
    } catch (e) {
      Fluttertoast.showToast(msg: "Invalid OTP");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToWelcome() {
    Fluttertoast.showToast(msg: "Phone verification successful");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Phone Sign-In")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!_isOtpSent)
              IntlPhoneField(
                controller: _phoneController,
                initialCountryCode: 'US',
                onCountryChanged: (country) {
                  _countryCode = '+${country.dialCode}';
                },
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            if (_isOtpSent)
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (!_isOtpSent)
              ElevatedButton(
                onPressed: _verifyPhoneNumber,
                child: const Text('Send OTP'),
              )
            else
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _verifyOtp,
                    child: const Text('Verify OTP'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isOtpSent = false),
                    child: const Text('Change Number'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
