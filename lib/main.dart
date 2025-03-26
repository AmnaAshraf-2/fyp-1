import 'package:flutter/material.dart';
import 'package:logistics_app/screens/homepage.dart';
import 'package:logistics_app/splash/splashscreen.dart';
import 'package:logistics_app/screens/reg.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      themeMode: ThemeMode.system,
      theme: MyTheme.lightTheme,
      darkTheme: MyTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: RegisterScreen(),
    );
  }
}
