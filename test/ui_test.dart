// Vérifie qu'aucun écran ne déborde (texte coupé ou qui dépasse) avec une
// grande taille de police Android, sur un petit écran.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rappel_medicaments/core/documents.dart';
import 'package:rappel_medicaments/core/logic.dart';
import 'package:rappel_medicaments/core/models.dart';
import 'package:rappel_medicaments/core/store.dart';
import 'package:rappel_medicaments/ui/export_screen.dart';
import 'package:rappel_medicaments/ui/history_screen.dart';
import 'package:rappel_medicaments/ui/intake_screen.dart';
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
    'Prise ponctuelle': (s) => IntakeScreen(store: s),
    'Corriger une prise': (s) => IntakeScreen(store: s, entry: s.history.first),
    'Corriger un oubli': (s) => IntakeScreen(store: s, entry: s.history.last),
    'Corriger un report': (s) => IntakeScreen(store: s, entry: s.history[1]),
    'PDF enregistré': (s) => ExportScreen(store: s, initialDoc: sampleDoc()),
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
    // Le bouton « J'ai pris un médicament » flotte au-dessus des onglets.
    expect(find.text('J\'ai pris un médicament'), findsOneWidget);
    final fab = tester.getRect(find.text('J\'ai pris un médicament'));
    expect(fab.bottom, lessThan(nav.top));
    expect(fab.top, greaterThan(400));
  });

  for (final label in ['1 jour sur 2', 'Tous les ... jours', 'Certains jours de la semaine', 'Une seule fois']) {
    testWidgets('fréquence « $label » en police x2', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 8000 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(ReminderEditScreen(store: makeStore(now), medId: 'm1'), 2.0));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('enregistrer un rappel 1 jour sur 3', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 8000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now);
    final r0 = store.data.reminders.first;
    await tester.pumpWidget(wrap(ReminderEditScreen(store: store, reminder: r0), 1.0));
    await tester.tap(find.text('1 jour sur 3'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer le rappel'));
    await tester.pumpAndSettle();
    final r = store.data.reminder(r0.id)!;
    expect(r.intervalDays, 3);
    expect(r.startDate, isNotNull);
  });

  testWidgets('enregistrer une prise ponctuelle', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 8000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now);
    await tester.pumpWidget(wrap(IntakeScreen(store: store), 1.0));
    await tester.tap(find.text('Kardégic 75'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la prise'));
    await tester.pumpAndSettle();
    final m = store.history.where((h) => h.manual).toList();
    expect(m.length, 1);
    expect(m.first.medName, 'Kardégic 75');
  });

  testWidgets('corriger un oubli en prise', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 8000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now);
    final missed = store.history.last;
    await tester.pumpWidget(wrap(IntakeScreen(store: store, entry: missed), 1.0));
    await tester.tap(find.text('Pris'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la correction'));
    await tester.pumpAndSettle();
    final e = store.history.firstWhere((h) => h.id == missed.id);
    expect(e.status, HistoryStatus.pris);
    expect(e.actual, isNotNull);
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
    // 12:40 : la prise de 12:30 est à prendre.
    final noon = DateTime(now.year, now.month, now.day, 12, 40);
    await tester.pumpWidget(wrap(Scaffold(body: TodayScreen(store: store, clock: () => noon)), 1.0));
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

  testWidgets('une prise validée est une ligne sans bouton ; on l\'annule en deux gestes', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 6000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now);
    final noon = DateTime(now.year, now.month, now.day, 12, 40);
    await tester.pumpWidget(wrap(Scaffold(body: TodayScreen(store: store, clock: () => noon)), 1.0));
    final taken = store.history.firstWhere((h) => h.id == 'h1');
    // Plus de bouton « Annuler » sur la ligne.
    expect(find.textContaining('Annuler'), findsNothing);
    await tester.tap(find.textContaining('Pris à ${hm(taken.actual!)}'));
    await tester.pumpAndSettle();
    expect(find.text('Corriger l\'heure ou la quantité'), findsOneWidget);
    await tester.tap(find.text('Je ne l\'ai pas pris'));
    await tester.pumpAndSettle();
    expect(store.history.any((h) => h.id == 'h1'), isFalse);
  });

  testWidgets('historique : toucher un oubli propose « En fait, je l\'ai pris »', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 6000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now);
    await tester.pumpWidget(wrap(Scaffold(body: HistoryScreen(store: store)), 1.0));
    await tester.tap(find.textContaining('Oublié').first);
    await tester.pumpAndSettle();
    expect(find.text('En fait, je l\'ai pris'), findsOneWidget);
    await tester.tap(find.text('En fait, je l\'ai pris'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer la correction'), findsOneWidget);
  });

  testWidgets('prise hors rappel : rappel de la dernière prise et de la consigne', (tester) async {
    tester.view.physicalSize = const Size(411 * 2, 6000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = makeStore(now);
    final t = DateTime.now().subtract(const Duration(minutes: 30));
    await store.addManualIntake(store.data.meds.first, 1, 'comprimé', t);
    await tester.pumpWidget(wrap(IntakeScreen(store: store), 1.0));
    await tester.tap(find.text(store.data.meds.first.name));
    await tester.pump();
    expect(find.text('Dernière prise aujourd\'hui à ${hm(t)}'), findsOneWidget);
    expect(find.textContaining('Votre consigne : 3 maximum par jour'), findsOneWidget);
  });
}

SavedDoc sampleDoc() {
  final dir = Directory.systemTemp.createTempSync('tts');
  final f = File('${dir.path}/tic-tac-sante-suivi-2026-10-24-au-2026-11-22.pdf')..writeAsBytesSync(List.filled(2048, 0));
  return SavedDoc(f, 'content://exemple/1', DateTime(2026, 11, 22));
}
