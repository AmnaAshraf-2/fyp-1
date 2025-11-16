import "package:flutter/material.dart";

class MyTheme {
  // Dark teal color from the image
  static const Color primaryTeal = Color(0xFF004d4d);
  
  static final darkTheme = ThemeData(
      scaffoldBackgroundColor: primaryTeal,
      colorScheme: ColorScheme.dark(
        primary: primaryTeal,
        surface: primaryTeal,
        background: primaryTeal,
      ));
      
  static final lightTheme = ThemeData(
      scaffoldBackgroundColor: primaryTeal,
      colorScheme: ColorScheme.light(
        primary: primaryTeal,
        surface: primaryTeal,
        background: primaryTeal,
      ));
}
