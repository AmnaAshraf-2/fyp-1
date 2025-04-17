import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/splash/welcome.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool isLoading = false;
  bool _passwordVisible = false;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

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
          "phone": phoneController.text.trim(),
        };

        await FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(authResult.user!.uid)
            .set(userMap);

        Fluttertoast.showToast(msg: "Registration successful");
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (c) => const WelcomeScreen()));
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
        backgroundColor: const Color(0xFFFFF9E6),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: IgnorePointer(
                  ignoring: isLoading,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Logistics Guru",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "CALCULATE EVERY LOAD",
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildNameField(),
                            const SizedBox(height: 15),
                            _buildEmailField(),
                            const SizedBox(height: 15),
                            _buildPhoneField(),
                            const SizedBox(height: 15),
                            _buildPasswordField(),
                            const SizedBox(height: 15),
                            _buildConfirmPasswordField(),
                            const SizedBox(height: 25),
                            _buildRegisterButton(),
                            const SizedBox(height: 25),
                            _buildLoginLink(),
                          ],
                        ),
                      )
                    ],
                  ),
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
        decoration: InputDecoration(
          labelText: 'Full Name',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.person, color: Colors.orange),
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
        decoration: InputDecoration(
          labelText: 'Email',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.mail, color: Colors.orange),
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
      child: IntlPhoneField(
        controller: phoneController,
        initialCountryCode: 'PK',
        showCountryFlag: false,
        disableLengthCheck: true,
        decoration: InputDecoration(
          labelText: 'Phone Number',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (phone) => phoneController.text = phone.completeNumber,
      ),
    );
  }

  Widget _buildPasswordField() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: passwordController,
        obscureText: !_passwordVisible,
        decoration: InputDecoration(
          labelText: 'Password',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.lock, color: Colors.orange),
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.orange,
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
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.lock_reset, color: Colors.orange),
        ),
        validator: (value) =>
            value != passwordController.text ? "Passwords don't match" : null,
      ),
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      onPressed: _submit,
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('REGISTER', style: TextStyle(fontSize: 18)),
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
            style: TextStyle(color: Colors.grey.shade700),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
            child: Text(
              "LOGIN",
              style: TextStyle(
                color: Colors.orange.shade700,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        ],
      ),
    );
  }
}
