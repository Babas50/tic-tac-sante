import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';

// Direction « Officine » : fond blanc, une seule couleur de marque (bleu-vert
// pharmacie), vert réservé à « pris », ambre à « reporté », rouge à « oublié ».
// Police Atkinson Hyperlegible, conçue pour les personnes malvoyantes.

const appFont = 'AtkinsonHyperlegible';

const ink = Color(0xFF13211F);
const muted = Color(0xFF465755);
const brand = Color(0xFF0D5C63);
const brandSoft = Color(0xFFDCEDEC);
const surface = Color(0xFFFFFFFF);
const surfaceAlt = Color(0xFFEFF5F4);
const lineColor = Color(0xFFD3DFDE);
const outlineColor = Color(0xFF7E9593);
const okGreen = Color(0xFF1B6B3D);
const okSoft = Color(0xFFE3F3E9);
const warnOrange = Color(0xFF874700);
const warnSoft = Color(0xFFFFF0D4);
const dangerRed = Color(0xFFA4261D);
const dangerSoft = Color(0xFFFDE7E5);

/// Hauteur minimale des boutons (exigence : 52 px minimum).
const minButtonHeight = 56.0;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brand,
    brightness: Brightness.light,
  ).copyWith(
    primary: brand,
    onPrimary: Colors.white,
    secondaryContainer: brandSoft,
    onSecondaryContainer: brand,
    onSurface: ink,
    onSurfaceVariant: muted,
    surface: surface,
    outline: outlineColor,
    outlineVariant: lineColor,
    error: dangerRed,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: appFont);
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
        headlineSmall: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink, height: 1.15),
        titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink, height: 1.2),
        titleMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink, height: 1.25),
        bodyLarge: const TextStyle(fontSize: 19, color: ink, height: 1.35),
        bodyMedium: const TextStyle(fontSize: 17, color: ink, height: 1.35),
        bodySmall: const TextStyle(fontSize: 16, color: muted, height: 1.35),
        labelLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ).apply(fontFamily: appFont);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: surface,
    dividerColor: lineColor,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, minButtonHeight),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, minButtonHeight),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        foregroundColor: brand,
        backgroundColor: Colors.white,
        side: const BorderSide(color: brand, width: 2),
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
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: brandSoft,
      checkmarkColor: brand,
      labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink, fontFamily: appFont),
      side: const BorderSide(color: outlineColor, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: brand,
      foregroundColor: Colors.white,
      extendedTextStyle: text.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : outlineColor),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand : surfaceAlt),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brand, width: 2.5),
      ),
      hintStyle: const TextStyle(fontSize: 18, color: muted),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: TextStyle(fontSize: 18, color: Colors.white, fontFamily: appFont),
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
      Moment.matin => const MomentStyle(surfaceAlt, muted, Icons.wb_twilight_rounded),
      Moment.midi => const MomentStyle(surfaceAlt, muted, Icons.wb_sunny_rounded),
      Moment.apresMidi => const MomentStyle(surfaceAlt, muted, Icons.light_mode_rounded),
      Moment.soir => const MomentStyle(surfaceAlt, muted, Icons.wb_twilight_rounded),
      Moment.nuit => const MomentStyle(surfaceAlt, muted, Icons.bedtime_rounded),
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
