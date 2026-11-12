import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Official Swiggy Brand Palette
  static const Color swiggyOrange = Color(0xFFFC8019);      // Signature Swiggy Orange
  static const Color swiggyDeepOrange = Color(0xFFF15700);  // Deep Tangy Orange Accent
  static const Color swiggyDark = Color(0xFF282C3F);        // Swiggy Deep Navy-Charcoal Ink
  static const Color swiggyGreen = Color(0xFF1BA672);       // Swiggy Rating / Veg / Offer Green
  static const Color swiggyLightOrange = Color(0xFFFFF3E8); // Swiggy Soft Warm Peach Tint
  static const Color swiggyLightGreen = Color(0xFFE7F7F0);  // Swiggy Soft Mint Green Tint

  static const Color lime = swiggyGreen;
  // Primary brand colors (Common Swiggy Theme)
  static const Color teal = swiggyOrange;
  static const Color deepTeal = swiggyDark;
  static const Color limeGreen = swiggyGreen;

  // Background and text
  static const Color warmIvory = Color(0xFFF8F8FA);         // Swiggy Clean Off-White Canvas
  static const Color lightIvory = Color(0xFFF0F0F5);        // Swiggy Subtle Gray Surface
  static const Color charcoalBlack = swiggyDark;            // Swiggy Dark Text

  // Food highlights
  static const Color goldenOrange = swiggyDeepOrange;

  // Reusable supporting colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color mutedText = Color(0xFF686B78);         // Swiggy Slate Muted Text
  static const Color border = Color(0xFFE9E9EB);            // Swiggy Card & Hairline Border
  static const Color lightTeal = swiggyLightOrange;
  static const Color lightLime = swiggyLightGreen;
  static const Color lightOrange = Color(0xFFFFEDE0);       // Soft Warm Tangy Tint
  static const Color error = Color(0xFFE23744);             // Alert / Non-Veg Error Red
  static const Color success = swiggyGreen;

  // Dark banner / card supporting colors & external checkout theme
  static const Color darkBannerSubtext = Color(0xFFC8CBD4);
  static const Color darkBannerAccent = Color(0xFFFF9E44);
  static const String razorpayThemeHex = '#FC8019';

  // Consistent Swiggy app theme
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: warmIvory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: teal,
        onPrimary: white,
        secondary: deepTeal,
        onSecondary: white,
        surface: warmIvory,
        onSurface: charcoalBlack,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: warmIvory,
        foregroundColor: deepTeal,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: deepTeal),
        titleTextStyle: TextStyle(
          color: deepTeal,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
      ),
    );
  }
}
