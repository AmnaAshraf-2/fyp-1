import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/splash/welcome.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/driver/driver_registration.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_details.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/phn_auth.dart';

// Import Google Sign-In with conditional import for web
import 'package:google_sign_in/google_sign_in.dart'
    if (dart.library.html) 'package:logistics_app/screens/reg_web_stub.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool isLoading = false;
  bool _passwordVisible = false;
  final _formKey = GlobalKey<FormState>();
  String completePhoneNumber = ''; // No need for `late`
  String? selectedRole; // Selected role: customer, driver, or enterprise

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Mask formatters
  late MaskTextInputFormatter phoneMaskFormatter;

  @override
  void initState() {
    super.initState();
    phoneMaskFormatter = MaskTextInputFormatter(
      mask: '+92 ### ### ####',
      filter: {"#": RegExp(r'[0-9]')},
    );
  }

  /// Google Sign-In function for registration (REGISTRATION ONLY - no auto-login)
  Future<void> _signInWithGoogle() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      UserCredential userCredential;
      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        // Web Google Sign-In
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // Mobile Google Sign-In (v7.x)
        final GoogleSignIn googleSignIn = GoogleSignIn();
        googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          Fluttertoast.showToast(msg: "Google Sign-In cancelled");
          if (mounted) {
            setState(() => isLoading = false);
          }
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        if (mounted) {
          setState(() => isLoading = false);
        }
        return;
      }

      final uid = firebaseUser.uid;

      // 🔥 Step 1: Check if this Google UID already exists in your users table
      final userSnapshot = await FirebaseDatabase.instance
          .ref()
          .child("users")
          .child(uid)
          .get();

      if (userSnapshot.exists) {
        // ❌ User already registered - DO NOT log them in
        await FirebaseAuth.instance.signOut(); // Important: sign out immediately
        Fluttertoast.showToast(
          msg: "This Google account is already registered. Please login instead.",
        );
        if (mounted) {
          setState(() => isLoading = false);
        }
        return;
      }

      // Get user display name and photo
      String displayName = firebaseUser.displayName ?? 'Google User';
      String? photoUrl = firebaseUser.photoURL;

      // For mobile, get additional info from GoogleSignInAccount
      if (!kIsWeb && googleUser != null) {
        displayName = googleUser.displayName ?? displayName;
        photoUrl = googleUser.photoUrl ?? photoUrl;
      }

      if (mounted) {
        // 🔥 Step 2: Get role from user (Customer / Driver / Enterprise)
        String? role = await _showRoleSelectionDialog();
        if (role == null) {
          // User cancelled role selection - sign out
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() => isLoading = false);
          }
          return;
        }

        // 🔥 Step 3: Get phone number from user
        String? phoneNumber = await _showPhoneNumberDialog();
        if (phoneNumber == null || phoneNumber.isEmpty) {
          // User cancelled phone number entry - sign out
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() => isLoading = false);
          }
          return;
        }

        // 🔥 Step 4: Save new registration in database
        final userMap = <String, dynamic>{
          "id": uid,
          "name": displayName,
          "email": firebaseUser.email ?? '',
          "phone": phoneNumber,
          "role": role,
          "profileImage": photoUrl ?? '',
          "isProfileComplete": role == 'driver' ? false : true,
          "createdAt": ServerValue.timestamp,
        };

        await FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(uid)
            .set(userMap);

        // Save local data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', displayName);
        await prefs.setString('profile_image', photoUrl ?? '');
        await prefs.setString('userRole', role);
        // Save default language preference (English)
        await prefs.setString('languageCode_${uid}', 'en');

        Fluttertoast.showToast(msg: "Successfully registered with Google");

        // 🔥 Step 5: Navigate according to selected role
        _navigateBasedOnRole(role);
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: "Google Sign-In failed: ${e.message}");
      // Sign out on error to ensure clean state
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    } catch (e) {
      Fluttertoast.showToast(msg: "Error registering with Google: ${e.toString()}");
      // Sign out on error to ensure clean state
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<String> _getSmsCodeFromUser() async {
    String smsCode = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter SMS Code'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              smsCode = value;
            },
          ),
          actions: [
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
    return smsCode;
  }

  Future<void> _phoneSignIn() async {
    if (completePhoneNumber.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter phone number first");
      return;
    }

    setState(() => isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: completePhoneNumber.trim(),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        Fluttertoast.showToast(msg: "Phone Sign-In successful");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const WelcomeScreen()),
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        Fluttertoast.showToast(msg: "Verification failed: ${e.message}");
      },
      codeSent: (String verificationId, int? resendToken) async {
        String smsCode = await _getSmsCodeFromUser();

        if (smsCode.isNotEmpty) {
          try {
            PhoneAuthCredential credential = PhoneAuthProvider.credential(
                verificationId: verificationId, smsCode: smsCode);
            await FirebaseAuth.instance.signInWithCredential(credential);
            Fluttertoast.showToast(msg: "Phone Sign-In successful");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const WelcomeScreen()),
            );
          } catch (e) {
            Fluttertoast.showToast(msg: "Invalid code: ${e.toString()}");
          }
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );

    setState(() => isLoading = false);
  }

  Future<String?> _showRoleSelectionDialog() async {
    String? selectedRole;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final loc = AppLocalizations.of(context);
        return AlertDialog(
          backgroundColor: Colors.white,
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

  Future<String?> _showPhoneNumberDialog() async {
    String? phoneNumber;
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Your Phone Number'),
          content: Form(
            key: formKey,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextFormField(
                controller: phoneController,
                inputFormatters: [phoneMaskFormatter],
                keyboardType: TextInputType.phone,
                style: TextStyle(color: const Color(0xFF004d4d)),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+92 300 123 4567',
                  labelStyle: TextStyle(color: const Color(0xFF004d4d)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: const Color(0xFF004d4d)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: const Color(0xFF004d4d)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: const Color(0xFF004d4d), width: 2),
                  ),
                  prefixIcon: Icon(Icons.phone, color: const Color(0xFF004d4d)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Phone number required";
                  }
                  // Ensure it's a Pakistani number with +92
                  if (!value.startsWith('+92')) {
                    return "Please enter a valid Pakistani number";
                  }
                  // Remove spaces and check if the number has the correct length
                  String cleanNumber = value.replaceAll(' ', '');
                  if (cleanNumber.length != 13) {
                    return "Please enter a valid Pakistani mobile number";
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004d4d),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  phoneNumber = phoneController.text.trim();
                  Navigator.pop(context);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    return phoneNumber;
  }

  void _navigateBasedOnRole(String role) {
    if (role == 'customer') {
      // Customer: welcome screen → customer dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else if (role == 'driver') {
      // Driver: driver registration → vehicle registration → welcome → driver dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverRegistration()),
      );
    } else if (role == 'enterprise') {
      // Enterprise: enterprise registration
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterpriseDetailsScreen()),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedRole == null) {
      Fluttertoast.showToast(msg: "Please select a role");
      return;
    }

    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      // Check if this email is already registered as an enterprise driver
      final email = emailController.text.trim();
      final pendingSnapshot = await FirebaseDatabase.instance
          .ref('enterprise_drivers_pending')
          .get();
      
      if (pendingSnapshot.exists) {
        final pendingDrivers = pendingSnapshot.value as Map;
        for (var entry in pendingDrivers.entries) {
          final data = entry.value as Map?;
          if (data?['email'] == email) {
            Fluttertoast.showToast(
              msg: "This email is registered as an enterprise driver. Please use the login page and check your email for password setup instructions.",
              toastLength: Toast.LENGTH_LONG,
            );
            if (mounted) {
              setState(() => isLoading = false);
            }
            return;
          }
        }
      }

      final authResult =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (authResult.user != null) {
        final userMap = <String, dynamic>{
          "id": authResult.user!.uid,
          "name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "phone": completePhoneNumber.isNotEmpty ? completePhoneNumber : phoneController.text.trim(),
          "role": selectedRole,
          "profileImage": "", // Empty initially, will be updated if user uploads
          "isProfileComplete": selectedRole == 'driver' ? false : true,
          "createdAt": ServerValue.timestamp,
        };

        await FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(authResult.user!.uid)
            .set(userMap);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', nameController.text.trim());
        await prefs.setString('profile_image', ""); // Empty initially
        await prefs.setString('userRole', selectedRole!);
        // Save default language preference (English)
        await prefs.setString('languageCode_${authResult.user!.uid}', 'en');

        Fluttertoast.showToast(msg: "Registration successful");
        if (mounted) {
          _navigateBasedOnRole(selectedRole!);
        }
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: _handleFirebaseError(e.code));
    } catch (e) {
      Fluttertoast.showToast(msg: "Registration failed: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _handleFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email already registered';
      case 'invalid-email':
        return 'Invalid email format';
      case 'weak-password':
        return 'Password too weak';
      default:
        return 'Registration failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/p.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4), // Dark overlay for better visibility
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LAARI branding at the top
                    Padding(
                      padding: const EdgeInsets.only(top: 60, bottom: 40),
                      child: Column(
                        children: [
                          Text(
                            "LAARI",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "MULTI-LINGUAL LOGISTICS MANAGEMENT SYSTEM",
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 1.2,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Form fields centered
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: IgnorePointer(
                        ignoring: isLoading,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildNameField(),
                              const SizedBox(height: 20),
                              _buildEmailField(),
                              const SizedBox(height: 20),
                              _buildPhoneField(),
                              const SizedBox(height: 20),
                              _buildRoleDropdown(),
                              const SizedBox(height: 20),
                              _buildPasswordField(),
                              const SizedBox(height: 20),
                              _buildConfirmPasswordField(),
                              const SizedBox(height: 30),
                              _buildRegisterButton(),
                              const SizedBox(height: 30),
                              _buildLoginLink(),
                              const SizedBox(height: 20),
                              _buildGoogleSignInButton(),
                              const SizedBox(height: 15),
                              _buildPhoneAuthButton(),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: nameController,
        style: TextStyle(color: const Color(0xFF004d4d)),
        decoration: InputDecoration(
          labelText: 'Full Name',
          labelStyle: TextStyle(color: const Color(0xFF004d4d)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d), width: 2),
          ),
          prefixIcon: Icon(Icons.person, color: const Color(0xFF004d4d)),
        ),
        inputFormatters: [LengthLimitingTextInputFormatter(50)],
        validator: (value) {
          if (value == null || value.isEmpty) return "Name required";
          if (value.length < 2) return "Minimum 2 characters";
          return null;
        },
      ),
    );
  }

  Widget _buildEmailField() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: emailController,
        style: TextStyle(color: const Color(0xFF004d4d)),
        decoration: InputDecoration(
          labelText: 'Email',
          labelStyle: TextStyle(color: const Color(0xFF004d4d)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d), width: 2),
          ),
          prefixIcon: Icon(Icons.mail, color: const Color(0xFF004d4d)),
        ),
        keyboardType: TextInputType.emailAddress,
        validator: (value) =>
            EmailValidator.validate(value ?? '') ? null : "Enter valid email",
      ),
    );
  }

  Widget _buildRoleDropdown() {
    final loc = AppLocalizations.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DropdownButtonFormField<String>(
        value: selectedRole,
        dropdownColor: Colors.white,
        decoration: InputDecoration(
          labelText: 'Select Role',
          labelStyle: TextStyle(color: const Color(0xFF004d4d)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d), width: 2),
          ),
          prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF004d4d)),
        ),
        items: [
          DropdownMenuItem(
            value: 'customer',
            child: Text(loc?.customer ?? 'Customer'),
          ),
          DropdownMenuItem(
            value: 'driver',
            child: Text(loc?.driver ?? 'Driver'),
          ),
          DropdownMenuItem(
            value: 'enterprise',
            child: Text(loc?.enterprise ?? 'Enterprise'),
          ),
        ],
        onChanged: (value) {
          setState(() {
            selectedRole = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please select a role";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPhoneField() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: phoneController,
        inputFormatters: [phoneMaskFormatter],
        keyboardType: TextInputType.phone,
        style: TextStyle(color: const Color(0xFF004d4d)),
        decoration: InputDecoration(
          labelText: 'Phone Number',
          hintText: '+92 300 123 4567',
          labelStyle: TextStyle(color: const Color(0xFF004d4d)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d), width: 2),
          ),
          prefixIcon: Icon(Icons.phone, color: const Color(0xFF004d4d)),
        ),
        onChanged: (value) {
          completePhoneNumber = value; // Save the formatted number
          debugPrint("Complete Number: $value");
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Phone number required";
          }
          // Ensure it's a Pakistani number with +92
          if (!value.startsWith('+92')) {
            return "Please enter a valid Pakistani number";
          }
          // Remove spaces and check if the number has the correct length (Pakistani mobile numbers are 13 digits with +92)
          String cleanNumber = value.replaceAll(' ', '');
          if (cleanNumber.length != 13) {
            return "Please enter a valid Pakistani mobile number";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPasswordField() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: passwordController,
        obscureText: !_passwordVisible,
        style: TextStyle(color: const Color(0xFF004d4d)),
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: TextStyle(color: const Color(0xFF004d4d)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d), width: 2),
          ),
          prefixIcon: Icon(Icons.lock, color: const Color(0xFF004d4d)),
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF004d4d),
            ),
            onPressed: () =>
                setState(() => _passwordVisible = !_passwordVisible),
          ),
        ),
        validator: (value) =>
            (value?.length ?? 0) >= 6 ? null : "Minimum 6 characters",
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: confirmPasswordController,
        obscureText: !_passwordVisible,
        style: TextStyle(color: const Color(0xFF004d4d)),
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          labelStyle: TextStyle(color: const Color(0xFF004d4d)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: const Color(0xFF004d4d), width: 2),
          ),
          prefixIcon: Icon(Icons.lock_reset, color: const Color(0xFF004d4d)),
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF004d4d),
            ),
            onPressed: () =>
                setState(() => _passwordVisible = !_passwordVisible),
          ),
        ),
        validator: (value) =>
            value != passwordController.text ? "Passwords don't match" : null,
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
        backgroundColor: Color(0xFF004d4d),
        foregroundColor: const Color(0xFF004d4d),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      onPressed: _submit,
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('REGISTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildLoginLink() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Have an account? ",
            style: TextStyle(color: Colors.white70),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
            child: Text(
              "LOGIN",
              style: TextStyle(
                color: Colors.white,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF004d4d),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      icon: Image.asset(
        'assets/images/g.png',
        height: 20,
        width: 20,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.login, color: const Color(0xFF004d4d));
        },
      ),
      label: const Text(
        'Continue with Google',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      onPressed: isLoading ? null : _signInWithGoogle,
    );
  }

  Widget _buildPhoneAuthButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      icon: const Icon(Icons.phone),
      label: const Text(
        'Continue with Phone',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      onPressed: isLoading ? null : () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PhoneAuthScreen(isLogin: false),
          ),
        );
      },
    );
  }
}

