import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logistics_app/global/global.dart';
import 'package:logistics_app/screens/password.dart';
import 'package:logistics_app/screens/reg.dart';
import 'package:logistics_app/splash/welcome.dart';

class login extends StatefulWidget {
  const login({super.key});

  @override
  State<login> createState() => _loginState();
}

class _loginState extends State<login> {
  bool isLoading = false; // This variable will control the loading state

  final emailTextEditingController = TextEditingController();
  final passwordTextEditingController = TextEditingController();
  bool _passwordVisible = false;

  final _formKey = GlobalKey<FormState>();
  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Sign in the existing user
        final UserCredential authResult =
            await firebaseAuth.signInWithEmailAndPassword(
          email: emailTextEditingController.text.trim(),
          password: passwordTextEditingController.text.trim(),
        );

        User? currentUser = authResult.user;

        if (currentUser != null) {
          await Fluttertoast.showToast(msg: "Login successful");
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => WelcomeScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        // Handle common errors like wrong password or user not found
        await Fluttertoast.showToast(msg: e.message ?? "Login failed");
      } catch (e) {
        await Fluttertoast.showToast(msg: "An error occurred");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool darkTheme =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
            body: ListView(padding: EdgeInsets.all(8), children: [
          Column(children: [
            Image.asset(darkTheme ? '' : ''),
            SizedBox(
              height: 20,
            ),
            Text(
              "Log In",
              style: TextStyle(
                color: darkTheme ? Colors.amber.shade400 : Colors.blue,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 20, 15, 50),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Form(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                TextFormField(
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(100)
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'Email',
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: darkTheme
                                        ? Colors.black45
                                        : Colors.grey.shade200,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(40),
                                        borderSide: BorderSide(
                                          width: 0,
                                          style: BorderStyle.none,
                                        )),
                                    prefixIcon: Icon(
                                      Icons.mail,
                                      color: darkTheme
                                          ? Colors.amber.shade400
                                          : Colors.grey,
                                    ),
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (text) {
                                    if (text == null || text.isEmpty) {
                                      return "email can't be empty";
                                    }
                                    if (EmailValidator.validate(text) == true) {
                                      return null;
                                    }
                                    if (text.length < 2) {
                                      return 'Please enter a valid email';
                                    }
                                    if (text.length > 49) {
                                      return "email can't be more than 99";
                                    }
                                  },
                                  onChanged: (text) => setState(() {
                                    emailTextEditingController.text = text;
                                  }),
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Form(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      TextFormField(
                                        obscureText: !_passwordVisible,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(50)
                                        ],
                                        decoration: InputDecoration(
                                            hintText: 'Password',
                                            hintStyle: TextStyle(
                                              color: Colors.grey,
                                            ),
                                            filled: true,
                                            fillColor: darkTheme
                                                ? Colors.black45
                                                : Colors.grey.shade200,
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(40),
                                                borderSide: BorderSide(
                                                  width: 0,
                                                  style: BorderStyle.none,
                                                )),
                                            prefixIcon: Icon(
                                              Icons.password,
                                              color: darkTheme
                                                  ? Colors.amber.shade400
                                                  : Colors.grey,
                                            ),
                                            suffix: IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _passwordVisible =
                                                        !_passwordVisible;
                                                  });
                                                },
                                                icon: Icon(
                                                  _passwordVisible
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                  color: darkTheme
                                                      ? Colors.amber.shade400
                                                      : Colors.grey,
                                                ))),
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
                                        validator: (text) {
                                          if (text == null || text.isEmpty) {
                                            return "password can't be empty";
                                          }
                                          if (EmailValidator.validate(text) ==
                                              true) {
                                            return null;
                                          }
                                          if (text.length < 6) {
                                            return 'Please enter a valid password';
                                          }
                                          if (text.length > 49) {
                                            return "password can't be more than 99";
                                          }
                                          return null;
                                        },
                                        onChanged: (text) => setState(() {
                                          passwordTextEditingController.text =
                                              text;
                                        }),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      ForgotPasswordScreen()),
                                            );
                                          },
                                          child: Text(
                                            "Forgot Password?",
                                            style: TextStyle(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: Colors.blue,
                                              decorationThickness: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 10,
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: darkTheme
                                              ? Colors.amber.shade400
                                              : Colors
                                                  .grey, // Use backgroundColor
                                          foregroundColor: Colors
                                              .white, // Use foregroundColor
                                        ),
                                        onPressed: () async {
                                          setState(() {
                                            isLoading =
                                                true; // Set loading to true when the button is pressed
                                          });

                                          // Call your registration or login function
                                          _submit();

                                          setState(() {
                                            isLoading =
                                                false; // Set loading to false after the operation finishes
                                          });
                                        },
                                        child: isLoading
                                            ? CircularProgressIndicator(
                                                color: Colors
                                                    .white, // Color of the progress indicator
                                              )
                                            : Text(
                                                'LoginS',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                ),
                                              ),
                                      ),
                                      SizedBox(
                                        height: 10,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Don't have an account?",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 15,
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        RegisterScreen()),
                                              );
                                            },
                                            child: Text(
                                              "Sign Up",
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: Colors
                                                    .blue, // hyperlink color
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: Colors
                                                    .blue, // make underline blue
                                                decorationThickness:
                                                    1.2, // slightly bolder underline
                                                height:
                                                    1.4, // adds a bit of space between text and underline
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ]),
            )
          ]),
        ])));
  }
}
