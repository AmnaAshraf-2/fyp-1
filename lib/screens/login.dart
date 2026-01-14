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
import 'package:logistics_app/screens/users/enterprise_driver/enterprise_driver_password_setup.dart';
import 'package:logistics_app/screens/users/enterprise_driver/enterprise_driver_dashboard.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/main.dart';
import 'package:logistics_app/services/location_permission_service.dart';
import 'package:logistics_app/phn_auth.dart';

// Import Google Sign-In with conditional import for web
import 'package:google_sign_in/google_sign_in.dart'
    if (dart.library.html) 'package:logistics_app/screens/reg_web_stub.dart';


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
    if (!mounted) return;
    
    try {
      // Load user-specific language preference
      final prefs = await SharedPreferences.getInstance();
      final userLanguageCode = prefs.getString('languageCode_${user.uid}') ?? 'en';
      if (mounted) {
        MyApp.setLocale(context, Locale(userLanguageCode));
      }
      
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              if (kDebugMode) {
                print('⚠️ User data fetch timed out');
              }
              throw TimeoutException('User data fetch timeout');
            },
          );

      if (!mounted) return;

      if (!userSnapshot.exists) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => const WelcomeScreen()),
          );
        }
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
          
          // If registration is complete, navigate first, then request location permission in background
          if (driverDetails != null && 
              vehicleInfo != null && 
              isProfileComplete == true) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => const DriversScreen()),
              );
              // Request location permission in background (non-blocking)
              // Use a small delay to ensure navigation completes first
              if (!kIsWeb && mounted) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    final locationService = LocationPermissionService();
                    locationService.requestLocationPermission(context).catchError((e) {
                      // Silently handle permission errors
                      if (kDebugMode) {
                        print('Location permission request failed: $e');
                      }
                    });
                  }
                });
              }
            }
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
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => const EnterpriseDashboard()),
              );
              // Request location permission in background (non-blocking)
              // Use a small delay to ensure navigation completes first
              if (!kIsWeb && mounted) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    final locationService = LocationPermissionService();
                    locationService.requestLocationPermission(context).catchError((e) {
                      // Silently handle permission errors
                      if (kDebugMode) {
                        print('Location permission request failed: $e');
                      }
                    });
                  }
                });
              }
            }
            return;
          }
          shouldShowWelcome = true;
          break;
        case 'enterprise_driver':
          final needsPasswordSetup = userData['needsPasswordSetup'] ?? false;
          final isProfileComplete = userData['isProfileComplete'] ?? false;
          
          // If password setup is needed, redirect to password setup screen
          if (needsPasswordSetup || !isProfileComplete) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (c) => EnterpriseDriverPasswordSetup(
                    email: user.email ?? '',
                  ),
                ),
              );
            }
            return;
          }
          
          // Password is set, go to enterprise driver dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const EnterpriseDriverDashboard()),
            );
            // Request location permission in background (non-blocking)
            // Use a small delay to ensure navigation completes first
            if (!kIsWeb && mounted) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  final locationService = LocationPermissionService();
                  locationService.requestLocationPermission(context).catchError((e) {
                    // Silently handle permission errors
                    if (kDebugMode) {
                      print('Location permission request failed: $e');
                    }
                  });
                }
              });
            }
          }
          return;
        default:
          shouldShowWelcome = true;
      }

      // If registration incomplete or unknown role, show welcome screen
      if (shouldShowWelcome && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const WelcomeScreen()),
        );
      }
    } catch (e) {
      print('❌ Error in _navigateAfterLogin: $e');
      // On error, show welcome screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const WelcomeScreen()),
        );
      }
      // Make sure loading state is reset on error
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// Google Sign-In function for login (v7.x compatible)
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

      // Check if user exists in realtime db
      final userSnapshot = await FirebaseDatabase.instance
          .ref("users/${userCredential.user!.uid}")
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              if (kDebugMode) {
                print('⚠️ User data fetch timed out during Google sign-in');
              }
              throw TimeoutException('User data fetch timeout');
            },
          );

      if (!userSnapshot.exists) {
        // Not registered → log them out and redirect
        await FirebaseAuth.instance.signOut();
        if (!kIsWeb) {
          await GoogleSignIn().signOut();
        }
        
        Fluttertoast.showToast(
          msg: "Account not found. Please register first.",
          toastLength: Toast.LENGTH_LONG,
        );
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          );
        }
        return;
      }

      // User exists → save prefs
      final prefs = await SharedPreferences.getInstance();
      final userData = userSnapshot.value as Map;
      await prefs.setString('full_name', userData['name'] ?? '');
      await prefs.setString('profile_image', userData['profileImage'] ?? '');
      
      final langKey = 'languageCode_${userCredential.user!.uid}';
      if (!prefs.containsKey(langKey)) {
        await prefs.setString(langKey, 'en');
      }

      Fluttertoast.showToast(msg: "Successfully signed in");
      
      if (mounted) {
        await _navigateAfterLogin(userCredential.user!);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Google Sign-In failed: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (isLoading) return; // Prevent multiple simultaneous login attempts

    setState(() => isLoading = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // First, check if this is a pending enterprise driver (before trying to login)
    // Make this check non-blocking with timeout to prevent login from hanging
    // If this check fails or times out, we'll proceed with normal login
    Map<String, dynamic>? driverData;
    String? driverId;
    
    // Try to check for pending drivers, but don't let it block login
    try {
      DataSnapshot? pendingSnapshot;
      
      // Try orderByChild query with timeout (requires index)
      try {
        pendingSnapshot = await FirebaseDatabase.instance
            .ref('enterprise_drivers_pending')
            .orderByChild('email')
            .equalTo(email)
            .limitToFirst(1)
            .get()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                if (kDebugMode) {
                  print('⚠️ Pending drivers query timed out, trying fallback');
                }
                throw TimeoutException('Query timeout');
              },
            );
      } catch (e) {
        // If orderByChild fails (no index or timeout), try loading all and filtering
        if (kDebugMode) {
          print('⚠️ orderByChild query failed: $e, trying fallback method');
        }
        try {
          final allPendingSnapshot = await FirebaseDatabase.instance
              .ref('enterprise_drivers_pending')
              .get()
              .timeout(const Duration(seconds: 5));
          
          if (allPendingSnapshot.exists) {
            final allPending = allPendingSnapshot.value as Map?;
            if (allPending != null) {
              // Find matching driver by email
              for (var entry in allPending.entries) {
                final data = entry.value as Map?;
                if (data?['email'] == email && data?['needsAuthAccount'] == true) {
                  driverId = entry.key;
                  driverData = Map<String, dynamic>.from(data!);
                  break;
                }
              }
            }
          }
        } catch (e2) {
          if (kDebugMode) {
            print('⚠️ Fallback query also failed: $e2, continuing with normal login');
          }
          // Continue with normal login if both queries fail
        }
      }
      
      // If orderByChild query succeeded, extract data from snapshot
      if (pendingSnapshot != null && pendingSnapshot.exists && pendingSnapshot.children.isNotEmpty) {
        // Get the first matching driver
        final pendingDriver = pendingSnapshot.children.first;
        driverId = pendingDriver.key;
        final data = Map<String, dynamic>.from(pendingDriver.value as Map);
        
        if (data['needsAuthAccount'] == true) {
          driverData = data;
        }
      }
      
      // Process pending driver if found
      if (driverId != null && driverData != null) {
        // This is a pending enterprise driver - create their account
        final tempPassword = 'TempPass${DateTime.now().millisecondsSinceEpoch}';
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
        
        final driverAuthUid = userCredential.user?.uid;
        
        // Batch database operations for better performance
        final batch = <Future>[];
        
        // Move data from pending to main users table
        batch.add(FirebaseDatabase.instance.ref('users/$driverAuthUid').set({
          'uid': driverAuthUid,
          'email': driverData['email'],
          'name': driverData['name'],
          'phone': driverData['phone'],
          'role': 'enterprise_driver',
          'enterpriseId': driverData['enterpriseId'],
          'enterpriseDriverId': driverData['enterpriseDriverId'],
          'createdAt': driverData['createdAt'],
          'isProfileComplete': false,
          'needsPasswordSetup': true,
        }));
        
        // Update driver record in enterprise's drivers list
        batch.add(FirebaseDatabase.instance
            .ref('users/${driverData['enterpriseId']}/drivers/${driverData['enterpriseDriverId']}')
            .update({'authUid': driverAuthUid, 'authAccountCreated': true}));
        
        // Remove from pending
        batch.add(FirebaseDatabase.instance
            .ref('enterprise_drivers_pending/$driverId')
            .remove());
        
        // Execute all operations in parallel
        await Future.wait(batch);
        
        // Send password reset email (non-blocking)
        FirebaseAuth.instance.sendPasswordResetEmail(email: email).catchError((e) {
          if (kDebugMode) {
            print('Password reset email failed: $e');
          }
        });
        
        // Sign in with the temporary password so they can set their own password
        final loginCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
        
        // Now navigate to password setup screen
        if (mounted) {
          Fluttertoast.showToast(
            msg: "Account created. Please set your password.",
            toastLength: Toast.LENGTH_SHORT,
          );
          try {
            await _navigateAfterLogin(loginCredential.user!);
          } catch (e) {
            print('❌ Error navigating after pending driver login: $e');
            if (mounted) {
              setState(() => isLoading = false);
            }
          }
          return;
        }
      }
    } catch (e) {
      // If checking pending drivers fails, continue with normal login flow
      if (kDebugMode) {
        print('⚠️ Error checking pending enterprise drivers: $e');
        print('💡 Continuing with normal login flow');
      }
      // Reset driverData to ensure normal login proceeds
      driverData = null;
      driverId = null;
    }

    // Normal login flow
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        Fluttertoast.showToast(msg: "Login successful");
        // Check registration status and navigate accordingly
        if (mounted) {
          try {
            await _navigateAfterLogin(userCredential.user!);
          } catch (e) {
            print('❌ Error during navigation after login: $e');
            if (mounted) {
              setState(() => isLoading = false);
              Fluttertoast.showToast(msg: "Login successful but navigation failed. Please try again.");
            }
          }
        } else {
          if (mounted) {
            setState(() => isLoading = false);
          }
        }
      } else {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('❌ Login timeout: $e');
      }
      Fluttertoast.showToast(msg: "Login timed out. Please check your connection and try again.");
      if (mounted) {
        setState(() => isLoading = false);
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
        case 'network-request-failed':
          message = "Network error. Please check your connection";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Please try again later";
          break;
        case 'user-disabled':
          message = "This account has been disabled";
          break;
        case 'operation-not-allowed':
          message = "Email/password sign-in is not enabled";
          break;
      }
      
      // Check if the error message indicates API is blocked
      if (e.message != null && 
          (e.message!.contains('blocked') || 
           e.message!.contains('Identity Toolkit') ||
           e.message!.contains('identitytoolkit'))) {
        message = "Authentication service unavailable. Please contact support or try again later.";
        print('⚠️ Firebase Auth API Error: ${e.message}');
        print('💡 This usually means the Identity Toolkit API needs to be enabled in Google Cloud Console');
      }
      
      Fluttertoast.showToast(msg: message);
      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      String errorMessage = "An error occurred";
      
      // Check for API blocked error in generic catch
      if (e.toString().contains('blocked') || 
          e.toString().contains('Identity Toolkit') ||
          e.toString().contains('identitytoolkit')) {
        errorMessage = "Authentication service unavailable. Please contact support.";
        print('⚠️ Authentication API Error: $e');
        print('💡 Enable Identity Toolkit API in Google Cloud Console:');
        print('   https://console.cloud.google.com/apis/library/identitytoolkit.googleapis.com');
      } else {
        print('❌ Login error: $e');
      }
      
      Fluttertoast.showToast(msg: errorMessage);
      if (mounted) {
        setState(() => isLoading = false);
      }
    } finally {
      // Ensure loading state is always reset, even if something unexpected happens
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
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
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.3,
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
                    ),
                    // Bottom section with form
                    Container(
                      padding: const EdgeInsets.all(20),
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
                              onPressed: isLoading ? null : () async {
                                await _submit();
                              },
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text('LOGIN',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                            const SizedBox(height: 20),
                            // Google Sign-In Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 30),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF004d4d),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: isLoading ? null : _signInWithGoogle,
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
                            ),
                            const SizedBox(height: 15),
                            // Phone Authentication Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 30),
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: isLoading ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PhoneAuthScreen(isLogin: true),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.phone),
                              label: const Text(
                                'Continue with Phone',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


