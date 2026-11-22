// Vérifie qu'aucun écran ne déborde (texte coupé ou qui dépasse) avec une
// grande taille de police Android, sur un petit écran.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rappel_medicaments/core/logic.dart';
import 'package:rappel_medicaments/core/models.dart';
import 'package:rappel_medicaments/core/store.dart';
import 'package:rappel_medicaments/ui/export_screen.dart';
import 'package:rappel_medicaments/ui/history_screen.dart';
import 'package:rappel_medicaments/ui/home_shell.dart';
import 'package:rappel_medicaments/ui/library_screen.dart';
import 'package:rappel_medicaments/ui/med_edit_screen.dart';
import 'package:rappel_medicaments/ui/onboarding_screen.dart';
import 'package:rappel_medicaments/ui/reminder_edit_screen.dart';
import 'package:rappel_medicaments/ui/reminders_list_screen.dart';
import 'package:rappel_medicaments/ui/settings_screen.dart';
import 'package:rappel_medicaments/ui/theme.dart';
import 'package:rappel_medicaments/ui/today_screen.dart';

import 'sample.dart';

AppStore makeStore(DateTime now) {
  final data = sampleData(now);
  final occ = occurrencesOn(data, now);
  final history = <HistoryEntry>[
    HistoryEntry(id: 'h1', reminderId: occ[0].reminder.id, medId: occ[0].reminder.medId,
        medName: occ[0].medName, quantity: 1, unit: 'comprimé', date: occ[0].date,
        planned: occ[0].planned, actual: occ[0].planned.add(const Duration(minutes: 3)),
        status: HistoryStatus.pris),
    HistoryEntry(id: 'h2', reminderId: occ[1].reminder.id, medId: occ[1].reminder.medId,
        medName: occ[1].medName, quantity: 1, unit: 'gélule', date: occ[1].date,
        planned: occ[1].planned, actual: now, until: now.add(const Duration(minutes: 30)),
        status: HistoryStatus.decale),
    HistoryEntry(id: 'h3', reminderId: 'r4', medId: 'm3', medName: 'Collyre', quantity: 2,
        unit: 'goutte', date: dateKey(now.subtract(const Duration(days: 1))),
        planned: now.subtract(const Duration(days: 1)), status: HistoryStatus.oublie, once: true),
  ];
  return AppStore.memory(data, history);
}

Widget wrap(Widget child, double scale) => MaterialApp(
      theme: buildTheme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, w) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: w!,
      ),
      home: child,
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final now = DateTime.now();
  final screens = <String, Widget Function(AppStore)>{
    'Accueil (onglets)': (s) => HomeShell(store: s),
    'Aujourd\'hui': (s) => Scaffold(body: TodayScreen(store: s)),
    'Bibliothèque': (s) => Scaffold(body: LibraryScreen(store: s)),
    'Historique': (s) => Scaffold(body: HistoryScreen(store: s)),
    'Réglages': (s) => Scaffold(body: SettingsScreen(store: s)),
    'Nouveau rappel': (s) => ReminderEditScreen(store: s, medId: 'm1'),
    'Modifier rappel': (s) => ReminderEditScreen(store: s, reminder: s.data.reminders.first),
    'Nouveau médicament': (s) => MedEditScreen(store: s),
    'Modifier médicament': (s) => MedEditScreen(store: s, med: s.data.meds.first),
    'Tous les rappels': (s) => RemindersListScreen(store: s),
    'Export médecin': (s) => ExportScreen(store: s),
    'Premier lancement': (s) => OnboardingScreen(store: s),
  };

  for (final width in [320.0, 411.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final e in screens.entries) {
        testWidgets('${e.key} : largeur $width, police x$scale', (tester) async {
          tester.view.physicalSize = Size(width * 2, 6000 * 2);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final store = makeStore(now);
          await tester.pumpWidget(wrap(e.value(store), scale));
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('la barre d\'onglets reste compacte et le contenu est visible', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(HomeShell(store: makeStore(now)), 1.0));
    final nav = tester.getRect(find.text('Réglages'));
    expect(nav.top, greaterThan(600));
    expect(find.text('Nouveau rappel'), findsOneWidget);
    expect(tester.getRect(find.text('Nouveau rappel')).top, lessThan(400));
  });

  testWidgets('premier lancement : les 3 étapes', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 6000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now)..data.onboardingDone = false;
    await tester.pumpWidget(wrap(OnboardingScreen(store: store), 2.0));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('1. Afficher les notifications'), findsOneWidget);
    expect(find.text('Autoriser'), findsWidgets);
  });

  testWidgets('« J\'ai pris » en un geste', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 6000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now);
    store.history.clear();
    await tester.pumpWidget(wrap(Scaffold(body: TodayScreen(store: store)), 1.0));
    final before = store.history.where((h) => h.status == HistoryStatus.pris).length;
    await tester.tap(find.text('J\'ai pris').first);
    await tester.pump();
    expect(store.history.where((h) => h.status == HistoryStatus.pris).length, before + 1);
  });

  testWidgets('les boutons font au moins 52 px de haut', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 6000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(Scaffold(body: TodayScreen(store: makeStore(now))), 1.0));
    final buttons = find.byWidgetPredicate((w) => w is ButtonStyleButton);
    expect(buttons, findsWidgets);
    for (final el in buttons.evaluate()) {
      expect(tester.getSize(find.byWidget(el.widget)).height, greaterThanOrEqualTo(52));
    }
  });
}
