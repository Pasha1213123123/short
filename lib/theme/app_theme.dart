import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color success;
  final Color warning;

  const AppColorsExtension({
    required this.success,
    required this.warning,
  });

  @override
  AppColorsExtension copyWith({Color? success, Color? warning}) {
    return AppColorsExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

class AppTheme {
  static const Color _primaryColor = Colors.red;
  static const Color _primaryVariant = Colors.redAccent;

  static const Color _darkBackground = Colors.black;
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkOnSurface = Colors.white;
  static const Color _darkSecondary = Colors.grey;

  static const Color _lightBackground = Color(0xFFF2F2F2);
  static const Color _lightSurface = Colors.white;
  static const Color _lightOnSurface = Colors.black;
  static const Color _lightSecondary = Color(0xFF757575);

  static final LinearGradient videoOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withOpacity(0.2),
      Colors.black.withOpacity(0.8)
    ],
    stops: const [0.5, 0.7, 1.0],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: _lightBackground,
      extensions: const [
        AppColorsExtension(
          success: Color(0xFF2E7D32),
          warning: Color(0xFFED6C02),
        ),
      ],
      colorScheme: const ColorScheme.light(
        primary: _primaryColor,
        secondary: _primaryVariant,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: _lightOnSurface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _darkSurface,
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: _primaryColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _lightSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurface,
        selectedColor: _primaryColor,
        secondarySelectedColor: _primaryColor,
        labelStyle: const TextStyle(color: _lightOnSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _primaryColor,
        inactiveTrackColor: _lightSecondary.withOpacity(0.3),
        thumbColor: _primaryColor,
        overlayColor: _primaryColor.withOpacity(0.2),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            fontFamily: 'Roboto',
            bodyColor: _lightOnSurface,
            displayColor: _lightOnSurface,
          ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: _darkBackground,
      extensions: const [
        AppColorsExtension(
          success: Color(0xFF4CAF50),
          warning: Color(0xFFFFC107),
        ),
      ],
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        secondary: _primaryVariant,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _darkSurface,
        contentTextStyle: TextStyle(color: _darkOnSurface),
        actionTextColor: _primaryColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _darkSecondary.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurface.withOpacity(0.8),
        selectedColor: _primaryColor,
        secondarySelectedColor: _primaryColor,
        labelStyle: const TextStyle(color: _darkOnSurface),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _primaryColor,
        inactiveTrackColor: Colors.white.withOpacity(0.3),
        thumbColor: _primaryColor,
        overlayColor: _primaryColor.withOpacity(0.2),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Roboto',
            bodyColor: _darkOnSurface,
            displayColor: _darkOnSurface,
          ),
    );
  }
}
