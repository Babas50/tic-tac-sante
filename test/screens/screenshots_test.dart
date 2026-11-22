// Génère des captures d'écran (polices réelles) : flutter test test/screens --update-goldens
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rappel_medicaments/ui/export_screen.dart';
import 'package:rappel_medicaments/ui/history_screen.dart';
import 'package:rappel_medicaments/ui/home_shell.dart';
import 'package:rappel_medicaments/ui/library_screen.dart';
import 'package:rappel_medicaments/ui/onboarding_screen.dart';
import 'package:rappel_medicaments/ui/reminder_edit_screen.dart';

import '../ui_test.dart' show makeStore, wrap;

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  const fonts = '/opt/flutter/bin/cache/artifacts/material_fonts';
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await loadFont('Roboto', ['$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Medium.ttf',
      '$fonts/Roboto-Bold.ttf', '$fonts/Roboto-Black.ttf']);
    await loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  final now = DateTime(2026, 11, 22, 12, 40);
  final shots = <String, Widget Function()>{
    'aujourdhui': () => HomeShell(store: makeStore(now)),
    'bibliotheque': () => Scaffold(body: SafeArea(child: LibraryScreen(store: makeStore(now)))),
    'historique': () => Scaffold(body: SafeArea(child: HistoryScreen(store: makeStore(now)))),
    'nouveau-rappel': () => ReminderEditScreen(store: makeStore(now), medId: 'm2'),
    'export': () => ExportScreen(store: makeStore(now)),
    'accueil': () => OnboardingScreen(store: makeStore(now)),
  };
  for (final scale in [1.0, 1.6]) {
    for (final e in shots.entries) {
      testWidgets('capture ${e.key} x$scale', (tester) async {
        tester.view.physicalSize = const Size(411 * 2, 1100 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(wrap(e.value(), scale));
        await tester.pump(const Duration(milliseconds: 500));
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('../../build/screens/${e.key}-x$scale.png'));
      });
    }
  }
}
