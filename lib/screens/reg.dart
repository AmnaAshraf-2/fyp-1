import 'package:email_validator/email_validator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/splash/welcome.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => __RegisterScreenState();
}

class __RegisterScreenState extends State<RegisterScreen> {
  bool isLoading = false; // This variable will control the loading state

  final nameTextEditingController = TextEditingController();
  final phoneTextEditingController = TextEditingController();
  final emailTextEditingController = TextEditingController();
  final passwordTextEditingController = TextEditingController();
  final confirmTextEditingController = TextEditingController();

  bool _passwordVisible = false;

  final _formKey = GlobalKey<FormState>();

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: emailTextEditingController.text.trim(),
          password: passwordTextEditingController.text.trim(),
        )
            .then((authResult) async {
          User? currentUser = authResult.user;

          if (currentUser != null) {
            Map<String, dynamic> userMap = {
              "id": currentUser.uid,
              "name": nameTextEditingController.text.trim(),
              "email": emailTextEditingController.text.trim(),
              "phone": phoneTextEditingController.text.trim(),
            };

            DatabaseReference userRef =
                FirebaseDatabase.instance.ref().child("users");

            await userRef.child(currentUser.uid).set(userMap).then((_) {
              print("User data saved successfully!");
            }).catchError((error) {
              print("Error saving user data: $error");
            });

            Fluttertoast.showToast(msg: "Successfully registered");
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (c) => WelcomeScreen()));
          }
        });
      } catch (error) {
        print("Firebase Auth Error: $error");
        Fluttertoast.showToast(msg: "Registration failed: $error");
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
              "Register",
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
                          TextFormField(
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(50)
                            ],
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              hintText: 'Name',
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
                                Icons.person,
                                color: darkTheme
                                    ? Colors.amber.shade400
                                    : Colors.grey,
                              ),
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (text) {
                              if (text == null || text.isEmpty) {
                                return "name can't be empty";
                              }
                              if (text.length < 2) {
                                return 'Please enter a valid name';
                              }
                              if (text.length > 49) {
                                return "name can't be more than 50";
                              }
                            },
                            onChanged: (text) => setState(() {
                              nameTextEditingController.text = text;
                            }),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Form(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                TextFormField(
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(100)
                                  ],
                                  textDirection: TextDirection.ltr,
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
                                IntlPhoneField(
                                  showCountryFlag: false,
                                  dropdownIcon: Icon(
                                    Icons.arrow_drop_down,
                                    color: darkTheme
                                        ? Colors.amber.shade400
                                        : Colors.grey,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'phome',
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
                                  ),
                                  onChanged: (text) => setState(() {
                                    phoneTextEditingController.text =
                                        text.completeNumber;
                                  }),
                                ),
                                Form(
                                    child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    TextFormField(
                                      obscureText: !_passwordVisible,
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(50)
                                      ],
                                      textDirection: TextDirection.ltr,
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
                                    SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                )),
                                Form(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      TextFormField(
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(100)
                                        ],
                                        textDirection: TextDirection.ltr,
                                        decoration: InputDecoration(
                                          hintText: 'Confirm Password',
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
                                            return "password can't be empty";
                                          }
                                          if (EmailValidator.validate(text) ==
                                              true) {
                                            return null;
                                          }
                                          if (text !=
                                              passwordTextEditingController
                                                  .text) {
                                            return "password does not match";
                                          }
                                          if (text.length < 2) {
                                            return 'Please enter a valid password';
                                          }
                                          if (text.length > 49) {
                                            return "password can't be more than 99";
                                          }
                                        },
                                        onChanged: (text) => setState(() {
                                          confirmTextEditingController.text =
                                              text;
                                        }),
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
                                                'Register',
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
                                            "Have an account?",
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
                                                        login()),
                                              );
                                            },
                                            child: Text(
                                              "Log in",
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
