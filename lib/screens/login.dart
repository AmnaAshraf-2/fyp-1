import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logistics_app/screens/password.dart';
import 'package:logistics_app/screens/reg.dart';
import 'package:logistics_app/splash/welcome.dart';
import 'package:logistics_app/screens/users/driver/drivers.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_dashboard.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _passwordVisible = false;

  Future<void> _navigateAfterLogin(User user) async {
    try {
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get();

      if (!userSnapshot.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const WelcomeScreen()),
        );
        return;
      }

      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      final role = userData['role']?.toString();

      // Check if registration is complete based on role
      bool shouldShowWelcome = false;

      switch (role) {
        case 'driver':
          final driverDetails = userData['driverDetails'];
          final vehicleInfo = userData['vehicleInfo'];
          final isProfileComplete = userData['isProfileComplete'] ?? false;
          
          // If registration is complete, go directly to dashboard
          if (driverDetails != null && 
              vehicleInfo != null && 
              isProfileComplete == true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const DriversScreen()),
            );
            return;
          }
          // If incomplete, show welcome screen (which will redirect to registration)
          shouldShowWelcome = true;
          break;
        case 'customer':
          // Customer registration is usually complete on signup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => const CustomerDashboard()),
          );
          return;
        case 'enterprise':
          final enterpriseDetails = userData['enterpriseDetails'];
          final isProfileComplete = userData['isProfileComplete'] ?? false;
          
          if (enterpriseDetails != null && isProfileComplete == true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const EnterpriseDashboard()),
            );
            return;
          }
          shouldShowWelcome = true;
          break;
        default:
          shouldShowWelcome = true;
      }

      // If registration incomplete or unknown role, show welcome screen
      if (shouldShowWelcome) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const WelcomeScreen()),
        );
      }
    } catch (e) {
      // On error, show welcome screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => const WelcomeScreen()),
      );
    }
  }

  // /// Google Sign-In function
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

  //     // Step 5: Check if user exists in database, if not create profile
  //     await _createOrUpdateUserProfile(userCredential.user!, googleUser);

  //     // Step 6: Navigate to welcome screen
  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(builder: (context) => const WelcomeScreen()),
  //     );

  //     Fluttertoast.showToast(msg: "Successfully signed in with Google");
  //   } catch (e) {
  //     Fluttertoast.showToast(msg: "Error signing in with Google: $e");
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }

  // /// Create or update user profile in database
  // Future<void> _createOrUpdateUserProfile(User user, GoogleSignInAccount googleUser) async {
  //   try {
  //     final database = FirebaseDatabase.instance.ref();
  //     final userRef = database.child('users/${user.uid}');
      
  //     // Check if user already exists
  //     final snapshot = await userRef.get();
      
  //     if (!snapshot.exists) {
  //       // Create new user profile
  //       await userRef.set({
  //         'uid': user.uid,
  //         'email': user.email,
  //         'name': googleUser.displayName ?? 'Google User',
  //         'phone': user.phoneNumber ?? '',
  //         'role': 'customer', // Default role
  //         'profileImage': googleUser.photoUrl ?? '',
  //         'isGoogleUser': true,
  //         'createdAt': DateTime.now().millisecondsSinceEpoch,
  //       });
  //     } else {
  //       // Update existing user with Google info
  //       await userRef.update({
  //         'name': googleUser.displayName ?? 'Google User',
  //         'profileImage': googleUser.photoUrl ?? '',
  //         'isGoogleUser': true,
  //         'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
  //       });
  //     }
  //   } catch (e) {
  //     print('Error creating/updating user profile: $e');
  //   }
  // }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        Fluttertoast.showToast(msg: "Login successful");
        // Check registration status and navigate accordingly
        await _navigateAfterLogin(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login failed. Check email/password";
      switch (e.code) {
        case 'invalid-email':
          message = "Invalid email format";
          break;
        case 'user-not-found':
          message = "No account found";
          break;
        case 'wrong-password':
          message = "Incorrect password";
          break;
      }
      Fluttertoast.showToast(msg: message);
    } catch (e) {
      Fluttertoast.showToast(msg: "An error occurred");
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
            child: Column(
              children: [
                // Top section with LAARI branding
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                ),
                // Bottom section with form
                Container(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: IgnorePointer(
                      ignoring: isLoading,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
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
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(100)
                              ],
                              validator: (value) =>
                                  EmailValidator.validate(value ?? '')
                                      ? null
                                      : "Enter valid email",
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
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
                                    _passwordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: const Color(0xFF004d4d),
                                  ),
                                  onPressed: () => setState(() =>
                                      _passwordVisible = !_passwordVisible),
                                ),
                              ),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(50)
                              ],
                              validator: (value) => (value?.length ?? 0) >= 6
                                  ? null
                                  : "Password must be 6+ characters",
                            ),
                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordScreen()),
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: Colors.white,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 50),
                                backgroundColor: Color(0xFF004d4d),
                                foregroundColor: const Color(0xFF004d4d),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () async {
                                setState(() => isLoading = true);
                                await _submit();
                                setState(() => isLoading = false);
                              },
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text('LOGIN',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            const SizedBox(height: 20),
                            // Google Sign-In Button (Commented Out)
                            // ElevatedButton.icon(
                            //   style: ElevatedButton.styleFrom(
                            //     padding: const EdgeInsets.symmetric(
                            //         vertical: 15, horizontal: 30),
                            //     backgroundColor: Colors.white,
                            //     foregroundColor: const Color(0xFF004d4d),
                            //     shape: RoundedRectangleBorder(
                            //       borderRadius: BorderRadius.circular(30),
                            //     ),
                            //   ),
                            //   onPressed: isLoading ? null : _signInWithGoogle,
                            //   icon: Image.asset(
                            //     'assets/images/g.png',
                            //     height: 20,
                            //     width: 20,
                            //     errorBuilder: (context, error, stackTrace) {
                            //       return Icon(Icons.login, color: const Color(0xFF004d4d));
                            //     },
                            //   ),
                            //   label: const Text(
                            //     'Continue with Google',
                            //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            //   ),
                            // ),
                            const SizedBox(height: 20),
                            Text(
                              "Don't have an account?",
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 5),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const RegisterScreen()),
                              ),
                              child: Text(
                                "REGISTER",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on GoogleSignInAuthentication {
  get accessToken => null;
}
