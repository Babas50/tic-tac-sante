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
import 'package:rappel_medicaments/ui/intake_screen.dart';
import 'package:rappel_medicaments/ui/library_screen.dart';
import 'package:rappel_medicaments/ui/onboarding_screen.dart';
import 'package:rappel_medicaments/ui/reminder_edit_screen.dart';

import 'package:rappel_medicaments/core/logic.dart';
import 'package:rappel_medicaments/core/models.dart';
import 'package:rappel_medicaments/core/store.dart';
import 'package:rappel_medicaments/ui/import_screen.dart';

import '../ui_test.dart' show makeStore, sampleDoc, samplePlan, wrap;

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
    await loadFont('AtkinsonHyperlegible',
        ['assets/fonts/AtkinsonHyperlegible-Regular.ttf', 'assets/fonts/AtkinsonHyperlegible-Bold.ttf']);
  });

  final now = DateTime(2026, 11, 22, 12, 40);
  final shots = <String, Widget Function()>{
    'aujourdhui': () => HomeShell(store: makeStore(now)),
    'bibliotheque': () => Scaffold(body: SafeArea(child: LibraryScreen(store: makeStore(now)))),
    'historique': () => Scaffold(body: SafeArea(child: HistoryScreen(store: makeStore(now)))),
    'nouveau-rappel': () => ReminderEditScreen(store: makeStore(now), medId: 'm2'),
    'export': () => ExportScreen(store: makeStore(now)),
    'pdf-enregistre': () => ExportScreen(store: makeStore(now), initialDoc: sampleDoc()),
    'accueil': () => OnboardingScreen(store: makeStore(now)),
    'prise-ponctuelle': () => IntakeScreen(store: makeStore(now)),
    'corriger': () => IntakeScreen(store: makeStore(now), entry: makeStore(now).history.first),
    'importer': () => ImportScreen(store: makeStore(now)),
    'verifier-import': () {
      final s = makeStore(now);
      return ImportPreviewScreen(store: s, plan: samplePlan(s), fileName: 'mes-medicaments.xlsx');
    },
    'historique-ponctuelle': () =>
        Scaffold(body: SafeArea(child: HistoryScreen(store: withExtra(makeStore(now), now)))),
    'aujourdhui-ponctuelle': () => HomeShell(store: withExtra(makeStore(now), now)),
  };
  for (final scale in [1.0, 1.6]) {
    for (final e in shots.entries) {
      testWidgets('capture ${e.key} x$scale', (tester) async {
        tester.view.physicalSize = Size(411 * 2, (e.key == 'nouveau-rappel' || e.key == 'verifier-import' ? 2400 : 1100) * 2.0);
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

/// Ajoute une prise ponctuelle (hors rappel) à 10:15.
AppStore withExtra(AppStore s, DateTime now) {
  final at = DateTime(now.year, now.month, now.day, 10, 15);
  s.history.add(HistoryEntry(
      id: 'x1', reminderId: '${manualPrefix}x1', medId: 'm2', medName: 'Kardégic 75', quantity: 1,
      unit: 'sachet', date: dateKey(at), planned: at, actual: at, status: HistoryStatus.pris, once: true));
  return s;
}
