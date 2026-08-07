import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nomoride/core/utils/size_utils.dart';

class ThemeHelper {
  static ThemeData get themeDataData {
    return ThemeData(
      visualDensity: VisualDensity.standard,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE6C27A),
        primary: const Color(0xFFE6C27A),
        secondary: const Color(0xFF0F0F14),
        onPrimary: Colors.black,
        onSecondary: const Color(0xFFF5E6C8),
        background: const Color(0xFF0F0F14),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F14),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE6C27A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          visualDensity: const VisualDensity(
            vertical: -4,
            horizontal: -4,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 32.fSize,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 28.fSize,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 24.fSize,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 22.fSize,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 20.fSize,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 18.fSize,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 16.fSize,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 14.fSize,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: GoogleFonts.montserrat(
          color: const Color(0xFFF5E6C8),
          fontSize: 12.fSize,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.openSans(
          color: const Color(0xFFF5E6C8),
          fontSize: 16.fSize,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.openSans(
          color: const Color(0xFFF5E6C8),
          fontSize: 14.fSize,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: GoogleFonts.openSans(
          color: const Color(0xFFF5E6C8),
          fontSize: 12.fSize,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: GoogleFonts.openSans(
          color: const Color(0xFFF5E6C8),
          fontSize: 14.fSize,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: GoogleFonts.openSans(
          color: const Color(0xFFF5E6C8),
          fontSize: 12.fSize,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: GoogleFonts.openSans(
          color: const Color(0xFFF5E6C8),
          fontSize: 10.fSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class AppColours {
  static const Color primary = Color(0xFFE6C27A);
  static const Color secondary = Color(0xFFF5E6C8);
  static const Color secondary2 = Color.fromRGBO(245, 230, 200, 1);
  static Color hintcolor = const Color(0xFFF5E6C8).withValues(alpha: 0.4);
  static const Color background = Color(0xFF0F0F14);

  static Color grey = const Color(0xFFF5E6C8).withValues(alpha: 0.6);
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static Color grey1 = const Color(0xFFE6C27A).withValues(alpha: 0.1);
  static Color border = const Color(0xFFE6C27A).withValues(alpha: 0.5);
  static Color border1 = const Color(0xFFE6C27A);

  static const Color success = Color(0xFF4ADE80);
  static Color successBackground = success.withValues(alpha: 0.12);
  static Color successBorder = success.withValues(alpha: 0.4);
}

class CustomTextStyles {
  // Montserrat Variants
  static TextStyle get montserratRegular => GoogleFonts.montserrat(
        color: AppColours.secondary,
        fontWeight: FontWeight.w400,
      );
  static TextStyle get montserratMedium => GoogleFonts.montserrat(
        color: AppColours.secondary,
        fontWeight: FontWeight.w500,
      );
  static TextStyle get montserratSemiBold => GoogleFonts.montserrat(
        color: AppColours.secondary,
        fontWeight: FontWeight.w600,
      );
  static TextStyle get montserratBold => GoogleFonts.montserrat(
        color: AppColours.secondary,
        fontWeight: FontWeight.w700,
      );

  // Open Sans Variants
  static TextStyle get openSansRegular => GoogleFonts.openSans(
        color: AppColours.secondary,
        fontWeight: FontWeight.w400,
      );
  static TextStyle get openSansMedium => GoogleFonts.openSans(
        color: AppColours.secondary,
        fontWeight: FontWeight.w500,
      );
  static TextStyle get openSansSemiBold => GoogleFonts.openSans(
        color: AppColours.secondary,
        fontWeight: FontWeight.w600,
      );
  static TextStyle get openSansBold => GoogleFonts.openSans(
        color: AppColours.secondary,
        fontWeight: FontWeight.w700,
      );
}
