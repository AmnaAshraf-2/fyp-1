import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/splash/welcome.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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

  // /// Google Sign-In function for registration
  // Future<void> _signInWithGoogle() async {
  //   setState(() => isLoading = true);

  //   try {
  //     // Step 1: Trigger Google Sign-In with web client ID
  //     final GoogleSignInAccount? googleUser = await GoogleSignIn(
  //       clientId: "225444114745-56stpvja0vlg37g37pt8mkrc0bm13pom.apps.googleusercontent.com",
  //       scopes: ['email'],
  //     ).signIn();

  //     if (googleUser == null) {
  //       Fluttertoast.showToast(msg: "Google Sign-In cancelled");
  //       setState(() => isLoading = false);
  //       return;
  //     }

  //     // Step 2: Obtain auth details
  //     final GoogleSignInAuthentication googleAuth =
  //         await googleUser.authentication;

  //     // Step 3: Create a credential
  //     final OAuthCredential credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );

  //     // Step 4: Sign in to Firebase
  //     final UserCredential userCredential =
  //         await FirebaseAuth.instance.signInWithCredential(credential);

  //     // Step 5: Create user profile in database
  //     await _createGoogleUserProfile(userCredential.user!, googleUser);

  //     // Step 6: Navigate to welcome screen
  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(builder: (context) => const WelcomeScreen()),
  //     );

  //     Fluttertoast.showToast(msg: "Successfully registered with Google");
  //   } catch (e) {
  //     Fluttertoast.showToast(msg: "Error registering with Google: $e");
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }

  // /// Create user profile for Google registration
  // Future<void> _createGoogleUserProfile(User user, GoogleSignInAccount googleUser) async {
  //   try {
  //     final database = FirebaseDatabase.instance.ref();
  //     final userRef = database.child('users/${user.uid}');
      
  //     // Create new user profile
  //     await userRef.set({
  //       'uid': user.uid,
  //       'email': user.email,
  //       'name': googleUser.displayName ?? 'Google User',
  //       'phone': user.phoneNumber ?? '',
  //       'role': 'customer', // Default role
  //       'profileImage': googleUser.photoUrl ?? '',
  //       'isGoogleUser': true,
  //       'createdAt': DateTime.now().millisecondsSinceEpoch,
  //     });
  //   } catch (e) {
  //     print('Error creating Google user profile: $e');
  //   }
  // }

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

//   Future<void> _signInWithGoogle() async {
//   try {
//     UserCredential userCredential;

//     if (kIsWeb) {
//       // For Web
//       final GoogleAuthProvider googleProvider = GoogleAuthProvider();
//       userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
//     } else {
//       // For Mobile
//       final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
//       if (googleUser == null) {
//         Fluttertoast.showToast(msg: "Google Sign-In cancelled");
//         return;
//       }

//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
//     }

//     // Common success handling
//     if (userCredential.user != null) {
//       Fluttertoast.showToast(msg: "Google Sign-In successful");
//       if (context.mounted) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (c) => const WelcomeScreen()),
//         );
//       }
//     }

//   } catch (e) {
//     Fluttertoast.showToast(msg: "Google Sign-In failed: ${e.toString()}");
//   }
// }
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => isLoading = true);

      final authResult =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (authResult.user != null) {
        final userMap = {
          "id": authResult.user!.uid,
          "name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "phone": completePhoneNumber.isNotEmpty ? completePhoneNumber : phoneController.text.trim(),
        };

        await FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(authResult.user!.uid)
            .set(userMap);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', nameController.text.trim());
        await prefs.setString('profile_image', ""); // Empty initially

        Fluttertoast.showToast(msg: "Registration successful");
        Navigator.pushReplacementNamed(context, '/language');
      }
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(msg: _handleFirebaseError(e.code));
    } catch (e) {
      Fluttertoast.showToast(msg: "Registration failed: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
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
                            "CALCULATE EVERY LOAD",
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
                              _buildPasswordField(),
                              const SizedBox(height: 20),
                              _buildConfirmPasswordField(),
                              const SizedBox(height: 30),
                              _buildRegisterButton(),
                              const SizedBox(height: 30),
                              _buildLoginLink(),
                              const SizedBox(height: 40),
                              // _buildGoogleSignInButton(), // Commented out
                              const SizedBox(height: 10),
                              //  _buildPhoneAuthButton(),
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

  // Widget _buildGoogleSignInButton() {
  //   return ElevatedButton.icon(
  //     style: ElevatedButton.styleFrom(
  //       padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
  //       backgroundColor: Colors.white,
  //       foregroundColor: const Color(0xFF004d4d),
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(30),
  //       ),
  //     ),
  //     icon: Image.asset(
  //       'assets/images/g.png',
  //       height: 20,
  //       width: 20,
  //       errorBuilder: (context, error, stackTrace) {
  //         return Icon(Icons.login, color: const Color(0xFF004d4d));
  //       },
  //     ),
  //     label: const Text(
  //       'Continue with Google',
  //       style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //     ),
  //     onPressed: isLoading ? null : _signInWithGoogle,
  //   );
  // }

  Widget _buildPhoneAuthButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      icon: const Icon(Icons.phone),
      label: const Text('Continue with Phone'),
      onPressed: _phoneSignIn,
    );
  }
}
