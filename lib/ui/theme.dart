import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';

const ink = Color(0xFF1A1A1A);
const brand = Color(0xFF6A3DE8);
const okGreen = Color(0xFF1B7A3A);
const warnOrange = Color(0xFF9A4A00);
const dangerRed = Color(0xFFB3261E);

/// Hauteur minimale des boutons (exigence : 52 px minimum).
const minButtonHeight = 56.0;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brand,
    brightness: Brightness.light,
  ).copyWith(
    primary: brand,
    onSurface: ink,
    surface: const Color(0xFFFFFBF5),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Roboto');
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
        headlineSmall: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink),
        titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink),
        titleMedium: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: ink),
        bodyLarge: const TextStyle(fontSize: 20, color: ink, height: 1.3),
        bodyMedium: const TextStyle(fontSize: 18, color: ink, height: 1.3),
        bodySmall: const TextStyle(fontSize: 16, color: ink, height: 1.3),
        labelLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ).apply(fontFamily: 'Roboto');
  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: const Color(0xFFFFFBF5),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, minButtonHeight),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        backgroundColor: brand,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, minButtonHeight),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        foregroundColor: ink,
        side: const BorderSide(color: ink, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, minButtonHeight),
        padding: buttonPadding,
        textStyle: text.labelLarge,
        foregroundColor: brand,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF555555), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brand, width: 2.5),
      ),
      hintStyle: const TextStyle(fontSize: 18, color: Color(0xFF5C5C5C)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontSize: 18, color: Colors.white),
    ),
  );
}

/// Couleurs et icônes par moment de la journée. Le texte reste foncé sur
/// fond clair pour un fort contraste.
class MomentStyle {
  final Color background;
  final Color accent; // assez foncé pour du texte sur [background]
  final IconData icon;
  const MomentStyle(this.background, this.accent, this.icon);
}

MomentStyle momentStyle(Moment m) => switch (m) {
      Moment.matin => const MomentStyle(Color(0xFFFFF1C2), Color(0xFF8A4B00), Icons.wb_sunny_rounded),
      Moment.midi => const MomentStyle(Color(0xFFFFE0CC), Color(0xFFA33100), Icons.light_mode_rounded),
      Moment.apresMidi => const MomentStyle(Color(0xFFD9F3E3), Color(0xFF11603A), Icons.park_rounded),
      Moment.soir => const MomentStyle(Color(0xFFEAE0FF), Color(0xFF4B23B8), Icons.wb_twilight_rounded),
      Moment.nuit => const MomentStyle(Color(0xFFDCE5FF), Color(0xFF1D3A8F), Icons.bedtime_rounded),
    };

const medColors = <Color>[
  Color(0xFFD32F2F),
  Color(0xFFEF6C00),
  Color(0xFFC79100),
  Color(0xFF2E7D32),
  Color(0xFF00796B),
  Color(0xFF1565C0),
  Color(0xFF7B1FA2),
  Color(0xFFC2185B),
];

const medIcons = <IconData>[
  Icons.medication_rounded,
  Icons.medication_liquid_rounded,
  Icons.water_drop_rounded,
  Icons.vaccines_rounded,
  Icons.air_rounded,
  Icons.healing_rounded,
  Icons.local_pharmacy_rounded,
  Icons.favorite_rounded,
];
